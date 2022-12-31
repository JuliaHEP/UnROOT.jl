function read_col_page(io, col_record::ColumnRecord, page::PageDescription)
    nbits = col_record.nbits
    T = rntuple_col_type_dict[col_record.type]
    bytes = read_pagedesc(io, page, nbits)
    reinterpret(T, bytes)
end

function _search_col_type(field_id, column_records)
    res = filter(column_records) do col
        col.field_id == field_id
    end
    if length(res) == 2 && res[1].type == 2 && res[2].type == 5
        return String
    else
        return rntuple_col_type_dict[only(res).type]
    end
end

_parse_field(field_id, field_records, column_records, role) = error("Don't know how to handle role = $role")
function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_leaf})
    return _search_col_type(field_id, column_records)
end

function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_vector})
    element_idx = findlast(field_records) do field
        field.parent_field_id == field_id
    end
    sub_field = field_records[element_idx]

    # go back to 0-based
    return Vector{_parse_field(element_idx-1, field_records, column_records, Val(sub_field.struct_role))}
end

function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_struct})
    element_ids = findall(field_records) do field
        field.parent_field_id == field_id
    end
    # need 1-based index here
    setdiff!(element_ids, field_id+1)
    sub_fields = @view field_records[element_ids]

    names = Tuple(Symbol(sub_field.field_name) for sub_field in sub_fields)
    types = [
        _parse_field(element_idx-1, field_records, column_records, Val(sub_field.struct_role))
    for (element_idx, sub_field) in zip(element_ids, sub_fields)
    ]

    return NamedTuple{names, Tuple{types...}}
end

function _parse_field(field_id, field_records, column_records, ::Val{rntuple_role_union})
    element_ids = findall(field_records) do field
        field.parent_field_id == field_id
    end
    # need 1-based index here
    setdiff!(element_ids, field_id+1)
    sub_fields = @view field_records[element_ids]

    types = [
        _parse_field(element_idx-1, field_records, column_records, Val(sub_field.struct_role))
    for (element_idx, sub_field) in zip(element_ids, sub_fields)
    ]

    return Union{types...}
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
