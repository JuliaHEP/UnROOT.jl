_field_output_type(x::T) where T = _field_output_type(T)

function _field_output_type(::Type{StdArrayField{N, T}}) where {N, T} 
    elT = eltype(_field_output_type(T))
    return Base.ReinterpretArray{SVector{N, elT}, 1, UInt8, Vector{UInt8}, false}
end
function read_field(io, field::StdArrayField{N, T}, page_list) where {N, T}
    content = read_field(io, field.content_col, page_list)

    res = reinterpret(SVector{N, eltype(content)}, content)
    return res::_field_output_type(field)
end

_field_output_type(::Type{StringField{O, T}}) where {O, T} = Vector{String}
function read_field(io, field::StringField{O, T}, page_list) where {O, T}
    nbits = field.content_col.nbits
    pages = page_list[field.content_col.content_col_idx]

    offset = read_field(io, field.offset_col, page_list)
    content = read_pagedesc(io, pages, nbits)

    o = one(eltype(offset))
    jloffset = pushfirst!(offset .+ o, o) #change to 1-indexed, and add a 1 at the beginning
    res = String.(VectorOfVectors(content, jloffset, ArraysOfArrays.no_consistency_checks))
    return res::_field_output_type(field)
end

_field_output_type(::Type{LeafField{T}}) where {T} = Base.ReinterpretArray{T, 1, UInt8, Vector{UInt8}, false}
function read_field(io, field::LeafField{T}, page_list) where T
    nbits = field.nbits
    pages = page_list[field.content_col_idx]
    bytes = read_pagedesc(io, pages, nbits)
    res = reinterpret(T, bytes)
    return res::_field_output_type(field)
end

_field_output_type(::Type{LeafField{Bool}}) = BitVector
function read_field(io, field::LeafField{Bool}, page_list)
    nbits = field.nbits
    pages = page_list[field.content_col_idx]
    total_num_elements = sum(p.num_elements for p in pages)

    # pad to nearest 8*k bytes because each chunk needs to be UInt64
    original_bytes = read_pagedesc(io, pages, nbits)
    bytes = vcat(original_bytes, zeros(eltype(original_bytes), 8 - rem(total_num_elements, 8)))
    chunks = reinterpret(UInt64, bytes)

    res = BitVector(undef, total_num_elements)
    copyto!(res.chunks, chunks) # don't want jam ReinterpretArray into BitVector
    return res::_field_output_type(field)
end

_field_output_type(::Type{VectorField{O, T}}) where {O, T} = VectorOfVectors{eltype(_field_output_type(T)), _field_output_type(T), Vector{Int32}, Vector{Tuple{}}}
function read_field(io, field::VectorField{O, T}, page_list) where {O, T}
    offset = read_field(io, field.offset_col, page_list)
    content = read_field(io, field.content_col, page_list)

    o = one(eltype(offset))
    jloffset = pushfirst!(offset .+ o, o) #change to 1-indexed, and add a 1 at the beginning
    res = VectorOfVectors(content, jloffset, ArraysOfArrays.no_consistency_checks)
    return res::_field_output_type(field)
end

function _field_output_type(::Type{StructField{N, T}}) where {N, T}
    types = Tuple{eltype.(_field_output_type.(T.types))...}
    types2 = Tuple{_field_output_type.(T.types)...}
    StructArray{NamedTuple{N, types}, 1, NamedTuple{N, types2}, Int64}
end
"""
    Since each field of the struct is stored in a separate field of the RNTuple,
    this function returns a `StructArray` for efficiency / performance reason.
"""
function read_field(io, field::StructField{N, T}, page_list) where {N, T}
    contents = (read_field(io, col, page_list) for col in field.content_cols)
    res = StructArray(NamedTuple{N}(contents))
    return res::_field_output_type(field)
end

struct UnionVector{T, N} <: AbstractVector{T}
    kindex::Vector{UInt64}
    tag::Vector{Int8}
    contents::N
    function UnionVector(kindex, tag, contents::N) where N
        T = Union{eltype.(contents)...}
        return new{T, N}(kindex, tag, contents)
    end
end
Base.length(ary::UnionVector) = length(ary.tag)
Base.size(ary::UnionVector) = (length(ary.tag), )
Base.IndexStyle(::UnionVector) = IndexLinear()
function Base.getindex(ary::UnionVector, i::Int)
    ith_ele = ary.kindex[i]
    ith_type = ary.tag[i]
    return ary.contents[ith_type][ith_ele]
end

function _split_switch_bits(content)
    kindex = Int64.(content) .& 0x00000000000FFFFF .+ 1
    tags = Int8.(UInt64.(content) .>> 44)
    return kindex, tags
end
function _field_output_type(::Type{UnionField{S, T}}) where {S, T}
    type = Union{eltype.(_field_output_type.(T.types))...}
    type2 = Tuple{_field_output_type.(T.types)...}
    return UnionVector{type, type2}
end
function read_field(io, field::UnionField{S, T}, page_list) where {S, T}
    switch = read_field(io, field.switch_col, page_list)
    content = Tuple(read_field(io, col, page_list) for col in field.content_cols)
    res = UnionVector(_split_switch_bits(switch)..., content)
    return res::_field_output_type(field)
end
