_parse_field(field_id, field_records, column_records, alias_columns, role) = error("Don't know how to handle role = $role")

"""
    isvoid(::Type{T})

Internal function to determine (by only looking at the type) if a RNTuple field is recursively
empty. A field is empty is there's no more data column attached to it from this point forward.

For example, the :_0 field is empty here:
```
├─ Symbol("AntiKt4TruthDressedWZJetsAux:") ⇒ Struct
│                                            ├─ :m ⇒ Vector
│                                            │       ├─ :offset ⇒ Leaf{UnROOT.Index64}(col=23)
│                                            │       └─ :content ⇒ Leaf{Float32}(col=24)
│                                            ├─ Symbol(":_0") ⇒ Struct
│                                            │                  ├─ Symbol(":_2") ⇒ Struct
│                                            │                  ├─ Symbol(":_1") ⇒ Struct
│                                            │                  ├─ Symbol(":_0") ⇒ Struct
│                                            │                  │                  └─ Symbol(":_0") ⇒ Struct
│                                            │                  └─ Symbol(":_3") ⇒ Struct
```

When we parse the schema, we discard anything that cannot possibly produce redable data.

"""
isvoid(::Type{Tuple{}}) = true
isvoid(x::Type{<:Tuple}) = all(isvoid, fieldtypes(x))

"""
    StdArrayField<N, T>

Special base-case field for a leaf field representing `std::array<T, N>`. This is because RNTuple
would serialize it as a leaf field but with `flags == 0x0001` in the field description.
In total, there are two field descriptions associlated with `array<>`, one for meta-data (the `N`),
the other one for the actual data.
"""
struct StdArrayField{N, T}
    content_col::T
    StdArrayField(N, col::T) where T = new{N, T}(col)
end
isvoid(::Type{<:StdArrayField}) = false

"""
    StringField

Special base-case field for String leaf field. This is because RNTuple
splits a leaf String field into two columns (instead of split in field records).
So we need an offset column and a content column (that contains `Char`s).
"""
struct StringField{O, T}
    offset_col::O
    content_col::T
end
isvoid(::Type{<:StringField}) = false

"""
    struct LeafField{T}
        content_col_idx::Int
        columnrecord::ColumnRecord
    end

Base case of field nesting, this links to a column in the RNTuple by 0-based index.
`T` is the `eltype` of this field which mostly uses Julia native types except for
`Switch`.

The `type` field is the RNTuple spec type number, used to record split encoding.
"""
struct LeafField{T}
    content_col_idx::Int
    columnrecord::ColumnRecord
end
Base.eltype(::Type{LeafField{T}}) where {T} = T
isvoid(::Type{<:LeafField}) = false

"""
    struct RNTupleCardinality{T}
        content_col_idx::Int
        nbits::Int
    end

Special field. The cardinality is basically a counter, but the data column is
a leaf column of Index32 or Index64. To get a number from Cardinality, one needs to
compute `ary[i] - ary[i-1]`.
"""
struct RNTupleCardinality{T}
    leaf_field::LeafField{T}
end
isvoid(::Type{<:RNTupleCardinality}) = false

function _search_col_type(field_id, column_records, col_id::Int...)
    if length(col_id) == 2 && column_records[col_id[2]].type == 0x02 #Char
        index_record = column_records[col_id[1]]
        char_record = column_records[col_id[2]]
        index_typenum = index_record.type
        LeafType = rntuple_col_type_table[index_typenum+0x01].jltype
        return StringField(
            LeafField{LeafType}(col_id[1],index_record),
            LeafField{Char}(col_id[2], char_record)
        )
    elseif length(col_id) == 1
        record = column_records[only(col_id)]
        LeafType = rntuple_col_type_table[record.type+0x01].jltype
        return LeafField{LeafType}(only(col_id), record)
    else
        error("un-handled RNTuple case, report issue to UnROOT.jl")
    end
end

function find_alias(field_id, alias_columns)::Int
    for a in alias_columns
        if a.field_id == field_id
            return a.physical_id
        end
    end
    return -1
end

function _search_col_type(field_id, column_records::Vector, alias_columns::Vector)
    col_id = Tuple(findall(column_records) do col
        col.field_id == field_id
    end)
    physical_id = find_alias(field_id, alias_columns)

    if physical_id != -1
        _search_col_type(field_id, column_records, physical_id + 1)
    elseif !isempty(col_id)
        _search_col_type(field_id, column_records, col_id...)
    else
        error("Unreachable reached, no alias column and empty column match")
    end
end


function _parse_field(field_id, field_records, column_records, alias_columns, ::Val{rntuple_role_leaf})
    # field_id in 0-based index
    field = field_records[field_id + 1]
    if iszero(field.repetition)
        res = _search_col_type(field_id, column_records, alias_columns)
        if eltype(res) <: Union{Index32, Index64}
            # https://github.com/root-project/root/pull/12127
            return RNTupleCardinality(res)
        else
            return res
        end
    else
        # `std::array<>` for some reason splits in Field records and pretent to be a leaf field
        element_idx = findlast(field_records) do field
            field.parent_field_id == field_id
        end
        sub_field = field_records[element_idx]
        content_col = _parse_field(element_idx - 1, field_records, column_records, alias_columns, Val(sub_field.struct_role))
        return StdArrayField(field.repetition, content_col)
    end
end

struct VectorField{O, T}
    offset_col::O
    content_col::T
end
isvoid(::Type{VectorField{N,T}}) where {N,T} = isvoid(T)

function _parse_field(field_id, field_records, column_records, alias_columns, ::Val{rntuple_role_vector})
    offset_col = _search_col_type(field_id, column_records, alias_columns)

    element_idx = findlast(field_records) do field
        field.parent_field_id == field_id
    end
    # go back to 0-based
    content_col = _parse_field(element_idx - 1, field_records,
        column_records, alias_columns, Val(field_records[element_idx].struct_role))

    return VectorField(offset_col, content_col)
end

# the parent field is only structral, no column attached
struct StructField{N, T}
    content_cols::T
end
function isvoid(::Type{StructField{N,T}}) where {N,T} 
    isvoid(T) #|| all(startswith(":_"), String.(N))
end

function _parse_field(field_id, field_records, column_records, alias_columns, ::Val{rntuple_role_struct})
    element_ids = findall(field_records) do field
        field.parent_field_id == field_id
    end
    # need 1-based index here
    setdiff!(element_ids, field_id + 1) # ignore itself
    sub_fields = @view field_records[element_ids]

    names = Tuple(Symbol(sub_field.field_name) for sub_field in sub_fields)
    content_cols = Tuple(
        _parse_field(element_idx - 1, field_records, column_records, alias_columns, Val(sub_field.struct_role))
        for (element_idx, sub_field) in zip(element_ids, sub_fields)
    )

    mask = findall(!isvoid, typeof.(content_cols))
    masked_cols = content_cols[mask]
    return StructField{names[mask],typeof(masked_cols)}(masked_cols)
end

struct UnionField{S,T}
    switch_col::S
    content_cols::T
end
isvoid(::Type{<:UnionField}) = false

function _parse_field(field_id, field_records, column_records, alias_columns, ::Val{rntuple_role_union})
    switch_col = _search_col_type(field_id, column_records, alias_columns)
    element_ids = findall(field_records) do field
        field.parent_field_id == field_id
    end
    # need 1-based index here
    setdiff!(element_ids, field_id + 1)
    sub_fields = @view field_records[element_ids]

    content_cols = Tuple(
        _parse_field(element_idx - 1, field_records, column_records, alias_columns, Val(sub_field.struct_role))
        for (element_idx, sub_field) in zip(element_ids, sub_fields)
    )

    return UnionField(switch_col, content_cols)
end

function parse_fields(hr::RNTupleHeader)
    parse_fields(hr.field_records, hr.column_records, hr.alias_columns)
end

function parse_fields(field_records, column_records, alias_columns)
    fields = map(eachindex(field_records)) do idx
        field = field_records[idx]
        this_id = idx - 1 # 0-based
        if this_id == field.parent_field_id
            parsed = _parse_field(
                this_id,
                field_records,
                column_records,
                alias_columns,
                Val(field.struct_role)
            )
            Symbol(field.field_name) => parsed
        end
    end
    filter!(!isnothing, fields)
    NamedTuple(fields)
end
