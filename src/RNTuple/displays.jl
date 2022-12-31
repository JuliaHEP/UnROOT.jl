function Base.show(io::IO, f::FieldRecord)
    print(io, "parent=$(lpad(Int(f.parent_field_id), 2, "0")), ")
    print(io, "role=$(Int(f.struct_role)), ")
    print(io, "name=$(rpad(f.field_name, 30, " ")), ")
    print(io, "type=$(rpad(f.type_name, 60, " "))")
    # print(io, "alias=$(f.type_alias),")
    # print(io, "desc=$(f.field_desc),")
end

function Base.show(io::IO, f::ColumnRecord)
    print(io, "type=$(lpad(Int(f.type), 2, "0")), ")
    print(io, "nbits=$(lpad(Int(f.nbits), 2, "0")), ")
    print(io, "field_id=$(lpad(Int(f.field_id), 2, "0")), ")
    print(io, "flags=$(f.flags)")
end

function Base.show(io::IO, lf::StringField)
    print(io, "String(offset=$(lf.offset_col.content_col_idx), \
          char=$(lf.content_col.content_col_idx))")
end
function Base.show(io::IO, lf::LeafField{T}) where T
    print(io, "Leaf{$T}(col=$(lf.content_col_idx))")
end
function Base.show(io::IO, lf::VectorField)
    print(io, "VectorField(offset=$(lf.offset_col), content=$(lf.content_col))")
end
function Base.show(io::IO, lf::StructField)
    print(io, replace("StructField{$(lf.names .=> lf.content_cols))", " => " => "="))
end
function Base.show(io::IO, lf::UnionField)
    print(io, "UnionField(switch=$(lf.switch_col), content=$(lf.content_cols))")
end
