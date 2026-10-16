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
        alt_col_idx::Vector{Int}
        alt_columnrecords::Vector{ColumnRecord}
    end

Base case of field nesting, this links to a column in the RNTuple by 1-based index
(`content_col_idx`). `T` is the `eltype` of this field which mostly uses Julia native
types except for `Switch`.

A field may have several *column representations* (e.g. a `float` field stored as
`Real32` in some clusters and `Real16` in others). `content_col_idx`/`columnrecord`
describe the primary representation; `alt_col_idx`/`alt_columnrecords` the
secondary ones. In every cluster exactly one representation is active, the others
are suppressed (they have no pages), see [`_active_pages`](@ref).
"""
struct LeafField{T}
    content_col_idx::Int
    columnrecord::ColumnRecord
    alt_col_idx::Vector{Int}
    alt_columnrecords::Vector{ColumnRecord}
end
LeafField{T}(idx, cr::ColumnRecord) where {T} = LeafField{T}(idx, cr, Int[], ColumnRecord[])
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

_jltype(cr::ColumnRecord) = RNT_COL_TYPE_TABLE[cr.type+0x01].jltype

# Build the leaf for one field from its 1-based column indices. `primary` holds
# the columns of the primary representation, `alts` the columns of each secondary
# representation (same layout as `primary`).
function _make_leaf(column_records, primary::Vector{Int}, alts::Vector{Vector{Int}})
    if length(primary) == 2 && column_records[primary[2]].type == 0x02 #Char
        # std::string: an index column followed by a Char column
        all(length(a) == 2 for a in alts) || error("inconsistent column representations of a string field")
        index_record = column_records[primary[1]]
        char_record = column_records[primary[2]]
        LeafType = _jltype(index_record)
        return StringField(
            LeafField{LeafType}(primary[1], index_record, [a[1] for a in alts], [column_records[a[1]] for a in alts]),
            LeafField{Char}(primary[2], char_record, [a[2] for a in alts], [column_records[a[2]] for a in alts])
        )
    elseif length(primary) == 1
        all(length(a) == 1 for a in alts) || error("inconsistent column representations of a leaf field")
        record = column_records[only(primary)]
        LeafType = _jltype(record)
        return LeafField{LeafType}(only(primary), record, [only(a) for a in alts], [column_records[only(a)] for a in alts])
    else
        error("un-handled RNTuple case ($(length(primary)) columns attached to one field), report issue to UnROOT.jl")
    end
end

"""
    _search_col_type(field_id, column_records, alias_columns)

Find the column(s) attached to the (0-based) `field_id` and wrap them into a
[`LeafField`](@ref) or [`StringField`](@ref). Alias columns (projected fields)
redirect to the physical columns of another field. Returns `nothing` when no
column is attached to the field (e.g. the `std::atomic<T>` wrapper field, whose
payload lives in a sub-field).
"""
function _search_col_type(field_id, column_records::Vector, alias_columns::Vector)
    col_ids = findall(col -> col.field_id == field_id, column_records)
    # alias records are 0-based physical column ids
    alias_ids = [Int(a.physical_id) + 1 for a in alias_columns if a.field_id == field_id]
    ids = isempty(alias_ids) ? col_ids : alias_ids
    isempty(ids) && return nothing

    # group the columns by representation index; the lowest index is the primary one
    reps = sort!(unique(column_records[i].representation_idx for i in ids))
    by_rep = [filter(i -> column_records[i].representation_idx == r, ids) for r in reps]
    return _make_leaf(column_records, by_rep[1], by_rep[2:end])
end

# 1-based indices of the sub-fields of the (0-based) `field_id`
function _subfield_indices(field_id, field_records)
    ids = findall(f -> f.parent_field_id == field_id, field_records)
    # top-level fields are their own parent
    return filter!(!=(field_id + 1), ids)
end


function _parse_field(field_id, field_records, column_records, alias_columns, ::Val{rntuple_role_leaf})
    # field_id in 0-based index
    field = field_records[field_id + 1]
    res = _search_col_type(field_id, column_records, alias_columns)
    if iszero(field.repetition)
        if res === nothing
            # no column attached: a transparent wrapper such as `std::atomic<T>`,
            # whose payload is the single sub-field
            subs = _subfield_indices(field_id, field_records)
            length(subs) == 1 || error("leaf field '$(field.field_name)' of type '$(field.type_name)' has no column and $(length(subs)) sub-fields")
            sub_field = field_records[only(subs)]
            return _parse_field(only(subs) - 1, field_records, column_records, alias_columns, Val(sub_field.struct_role))
        end
        if eltype(res) <: Union{Index32, Index64}
            # https://github.com/root-project/root/pull/12127
            return RNTupleCardinality(res)
        else
            return res
        end
    elseif res !== nothing
        # fixed-size array whose elements live directly in the field's own column:
        # `std::bitset<N>` (a Bit column)
        return StdArrayField(field.repetition, res)
    else
        # `std::array<T, N>`: the element type is described by a sub-field
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

# ROOT names the sub-fields holding the base classes of a record ":_0", ":_1", ...
_is_base_class_field(f::FieldRecord) = occursin(r"^:_\d+$", f.field_name)

"""
    _parse_field(field_id, ..., ::Val{rntuple_role_struct})

Parse a record (struct) field. The members of base classes (ROOT stores every
base class as a sub-field named `:_N`) are flattened into the record, as ROOT
and uproot do. When the same member name is inherited through more than one
base class (or clashes with an own member), the inherited ones are disambiguated
as `BaseClass::member`. Members that carry no data at all (recursively empty
structs) are dropped.
"""
function _parse_field(field_id, field_records, column_records, alias_columns, ::Val{rntuple_role_struct})
    element_ids = _subfield_indices(field_id, field_records)

    # (name, parsed field, base class type name or nothing)
    entries = Tuple{Symbol, Any, Union{Nothing, String}}[]
    for element_idx in element_ids
        sub_field = field_records[element_idx]
        col = _parse_field(element_idx - 1, field_records, column_records, alias_columns, Val(sub_field.struct_role))
        if _is_base_class_field(sub_field) && col isa StructField
            for (n, c) in zip(_struct_names(col), col.content_cols)
                push!(entries, (n, c, sub_field.type_name))
            end
        elseif !isvoid(typeof(col))
            push!(entries, (Symbol(sub_field.field_name), col, nothing))
        end
    end

    # disambiguate inherited members whose names clash
    counts = Dict{Symbol, Int}()
    for (n, _, _) in entries
        counts[n] = get(counts, n, 0) + 1
    end
    names = Tuple(
        (base !== nothing && counts[n] > 1) ? Symbol(base, "::", n) : n
        for (n, _, base) in entries
    )
    content_cols = Tuple(c for (_, c, _) in entries)
    return StructField{names, typeof(content_cols)}(content_cols)
end
_struct_names(::StructField{N, T}) where {N, T} = N

struct UnionField{S,T}
    switch_col::S
    content_cols::T
end
isvoid(::Type{<:UnionField}) = false

function _parse_field(field_id, field_records, column_records, alias_columns, ::Val{rntuple_role_union})
    switch_col = _search_col_type(field_id, column_records, alias_columns)
    element_ids = _subfield_indices(field_id, field_records)
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
