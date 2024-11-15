function _showwithkw(io, @nospecialize(k))
    T = typeof(k)

    print(io, T)
    print(io, "(")
    for i in fieldnames(T)
        print(io, i, "=", repr(getfield(k, i)), ", ")
    end
    println(io, ")")
end

function Base.show(io::IO, f::FieldRecord)
    _showwithkw(io, f)
end

function Base.show(io::IO, f::ColumnRecord)
    _showwithkw(io, f)
end

function Base.show(io::IO, f::AliasRecord)
    _showwithkw(io, f)
end
function Base.show(io::IO, f::Locator)
    _showwithkw(io, f)
end

function Base.show(io::IO, lf::StringField)
    print(io, "String(offset=$(lf.offset_col.content_col_idx), char=$(lf.content_col.content_col_idx))")
end
function Base.show(io::IO, lf::LeafField{T}) where T
    print(io, "Leaf{$T}(col=$(lf.content_col_idx))")
end
function Base.show(io::IO, lf::VectorField)
    print(io, "VectorField(offset=$(lf.offset_col), content=$(lf.content_col))")
end
function Base.show(io::IO, lf::StructField{N, T}) where {N, T}
    print(io, replace("StructField{$(N .=> lf.content_cols))", " => " => "="))
end

function Base.show(io::IO, lf::UnionField)
    print(io, "UnionField(switch=$(lf.switch_col), content=$(lf.content_cols))")
end
function Base.summary(io::IO, uv::UnionVector{T, N}) where {T, N}
    print(io, "$(length(uv))-element UnionVector{$T}")
end

function Base.summary(io::IO, rf::RNTupleField{R, F, O, E}) where {R, F, O, E}
    print(io, "$(length(rf))-element RNTupleField{$E}")
end

function Base.show(io::IO, header::RNTupleHeader, indent=0, short=false)
    ind = " "^indent
    println(io, "UnROOT.RNTupleHeader:")
    println(io, "$ind    name: \"$(header.name)\"")
    println(io, "$ind    ntuple_description: \"$(header.ntuple_description)\"")
    println(io, "$ind    writer_identifier: \"$(header.writer_identifier)\"")
    if !short
        l1 = maximum(length, [f.field_name for f in header.field_records])
        l2 = maximum(length, [f.type_name for f in header.field_records])
        println(io, "$ind    field_records: ")
        for (fidx, f) in enumerate(header.field_records)
            print(io, "$ind        ")
            print(io, "(implicit idx=$(lpad(fidx-1, 2, "0"))), ")
            print(io, "parent=$(lpad(Int(f.parent_field_id), 2, "0")), ")
            print(io, "struct_role=$(Int(f.struct_role)), ")
            print(io, "name=$(rpad(f.field_name, l1+1, " ")), ")
            print(io, "type=$(rpad(f.type_name, l2+1, " "))")
            println(io, "repetition=$(f.repetition)")
            # println(io, "desc=$(f.field_desc),")
        end

        println(io, "$ind    column_records: ")
        for g in header.column_records
            print(io, "$ind        ")
            print(io, "type=$(lpad(Int(g.type), 2, "0")), ")
            print(io, "nbits=$(lpad(Int(g.nbits), 2, "0")), ")
            print(io, "field_id=$(lpad(Int(g.field_id), 3, "0")), ")
            print(io, "flags=$(g.flags), ")
            println(io, "first_ele_index=$(g.first_ele_idx)")
        end
    end
end

function Base.show(io::IO, footer::RNTupleFooter, indent=0)
    println(io, "UnROOT.RNTupleFooter:")
    ind = " "^indent
    println(io, "$ind    feature_flag: $(footer.feature_flag)")
    println(io, "$ind    header_checksum: $(repr(footer.header_checksum))")
    println(io, "$ind    extension_header_links: $(footer.extension_header_links)")
    println(io, "$ind    cluster_group_records: $(footer.cluster_group_records)")
end

function Base.show(io::IO, rn::RNTuple)
    println(io, "RNTuple")
    print(io, " └─ ")
    show(io, rn.header, 2, true)
    print(io, " └─ ")
    show(io, rn.footer, 2)
    print(io, " └─ ")
    println(io, "Schema: ")
    _io = IOBuffer()
    print_tree(_io, rn.schema; maxdepth=3, indicate_truncation=true)
    for l in split(String(take!(_io)), '\n')
        print(io, "      ")
        println(io, l)
    end
end
Base.show(io::IO, s::RNTupleSchema) = print_tree(io, s; maxdepth=10)
printnode(io::IO, s::RNTupleSchema) = print(io, "RNTupleSchema with $(length(s)) top fields")
children(s::RNTupleSchema) = Dict(pairs(getfield(s, :namedtuple)))

printnode(io::IO, rn::LeafField) = print(io, rn)

printnode(io::IO, ::StringField) = print(io, "String")
children(rn::StringField) = (offset = rn.offset_col, content = rn.content_col)

printnode(io::IO, ::VectorField) = print(io, "Vector")
children(rn::VectorField) = (offset=rn.offset_col, content=rn.content_col)

printnode(io::IO, ::StructField) = print(io, "Struct")
children(rn::StructField{N, T}) where {N, T} = Dict(N .=> rn.content_cols)

printnode(io::IO, ::UnionField) = print(io, "Union")
children(rn::UnionField) = Dict(:switch => rn.switch_col, (keys(rn.content_cols) .=> rn.content_cols)...)

printnode(io::IO, ::StdArrayField{N, T}) where{N,T} = print(io, "StdArray{$N}")
children(rn::StdArrayField) = (content = rn.content_col,)
