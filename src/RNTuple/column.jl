function read_col_page(io, col_record::ColumnRecord, page::PageDescription)
    nbits = col_record.nbits
    T = rntuple_col_type_dict[col_record.type]
    bytes = read_pagedesc(io, page, nbits)
    reinterpret(T, bytes)
end

_parse_field(field_id, field_records, column_records, role) = error("Don't know how to handle role = $role")

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

"""
    struct LeafField{T}
        content_col_idx::Int
    end

Base case of field nesting, this links to a column in the RNTuple by 0-based index.
`T` is the `eltype` of this field which mostly uses Julia native types except for
`Switch`.
"""
struct LeafField{T}
    content_col_idx::Int
end

function _search_col_type(field_id, column_records)
    col_id = Tuple(findall(column_records) do col
        col.field_id == field_id
    end)
    if length(col_id) == 2 && 
        column_records[col_id[1]].type == 2 && 
        column_records[col_id[2]].type == 5
        return StringField(LeafField{Int32}(col_id[1]), LeafField{Char}(col_id[2]))
    else
        return LeafField{rntuple_col_type_dict[column_records[only(col_id)].type]}(only(col_id))
    end
end


function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_leaf})
    return _search_col_type(field_id, column_records)
end

struct VectorField{O, T}
    offset_col::O
    content_col::T
end

function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_vector})
    offset_col = _search_col_type(field_id, column_records)

    element_idx = findlast(field_records) do field
        field.parent_field_id == field_id
    end
    # go back to 0-based
    content_col = _parse_field(element_idx-1, field_records, 
                               column_records, Val(field_records[element_idx].struct_role))

    return VectorField(offset_col, content_col)
end

# the parent field is only structral, no column attached
struct StructField{N, T}
    names::N
    content_cols::T
end

function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_struct})
    element_ids = findall(field_records) do field
        field.parent_field_id == field_id
    end
    # need 1-based index here
    setdiff!(element_ids, field_id+1) # ignore itself
    sub_fields = @view field_records[element_ids]

    names = Tuple(Symbol(sub_field.field_name) for sub_field in sub_fields)
    content_cols = Tuple(
        _parse_field(element_idx-1, field_records, column_records, Val(sub_field.struct_role))
    for (element_idx, sub_field) in zip(element_ids, sub_fields)
    )

    return StructField(names, content_cols)
end

struct UnionField{S, T}
    switch_col::S
    content_cols::T
end

function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_union})
    switch_col = _search_col_type(field_id, column_records)
    element_ids = findall(field_records) do field
        field.parent_field_id == field_id
    end
    # need 1-based index here
    setdiff!(element_ids, field_id+1)
    sub_fields = @view field_records[element_ids]

    content_cols = Tuple(
        _parse_field(element_idx-1, field_records, column_records, Val(sub_field.struct_role))
    for (element_idx, sub_field) in zip(element_ids, sub_fields)
    )

    return UnionField(switch_col, content_cols)
end

function parse_fields(hr::RNTupleHeader)
    parse_fields(hr.field_records, hr.column_records)
end

function parse_fields(field_records, column_records)
    fields = Dict{String, Any}()
    for (idx, field) in enumerate(field_records)
        this_id = idx - 1 # 0-based
        if this_id == field.parent_field_id
            fields[field.field_name] = _parse_field(
                this_id, 
                field_records, column_records, Val(field.struct_role)
            )
        end
    end
    fields
end
