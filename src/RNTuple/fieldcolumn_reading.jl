"""
    _field_output_type(::Type{F}) where F

This is function is used in two ways:

- provide a output type prediction for each "field" in RNTuple so we can
achieve type stability
- it's also used to enforce the type stability in [`read_field`](@ref):

```
    # this is basically a type assertion for `res`
    return res::_field_output_type(field)
```
"""
function _field_output_type() end

"""
    read_field(io, field::F, page_list) where F

Read a field from the `io` stream. The `page_list` is a list of PageLinks for the
current cluster group. The type stability is achieved by type asserting
based on type `F` via [`_field_output_type`](@ref) function.
"""
function read_field() end

_field_output_type(x::T) where T = _field_output_type(T)

function _field_output_type(::Type{StdArrayField{N, T}}) where {N, T} 
    content_type = _field_output_type(T)
    elT = eltype(content_type)
    return Base.ReinterpretArray{SVector{N, elT}, 1, elT, content_type, false}
end
function read_field(io, field::StdArrayField{N, T}, page_list) where {N, T}
    content = read_field(io, field.content_col, page_list)
    res = reinterpret(SVector{N, eltype(content)}, content)
    return res::_field_output_type(field)
end

_field_output_type(::Type{StringField{O, T}}) where {O, T} = Vector{String}
function read_field(io, field::StringField{O, T}, page_list) where {O, T}
    nbits = field.content_col.columnrecord.nbits
    pages = page_list[field.content_col.content_col_idx]

    offset = read_field(io, field.offset_col, page_list)
    content = read_pagedesc(io, pages, nbits)

    o = one(eltype(offset))
    jloffset = pushfirst!(offset .+ o, o) #change to 1-indexed, and add a 1 at the beginning
    res = String.(VectorOfVectors(content, jloffset, ArraysOfArrays.no_consistency_checks))
    return res::_field_output_type(field)
end

const T_Reinter{T} = Base.ReinterpretArray{T, 1, UInt8, Vector{UInt8}, false}

struct CardinalityVector{T} <: AbstractVector{T}
    contents::T_Reinter{T}
end
Base.length(ary::CardinalityVector) = length(ary.contents)
Base.size(ary::CardinalityVector) = (length(ary.contents), )
Base.IndexStyle(::CardinalityVector) = IndexLinear()
function Base.getindex(ary::CardinalityVector{T}, i::Int) where {T}
    ary.contents[i] - get(ary.contents, i-1, zero(T))
end


_field_output_type(::Type{RNTupleCardinality{T}}) where {T} = CardinalityVector{T}
function read_field(io, field::RNTupleCardinality{T}, page_list) where T
    nbits = field.leaf_field.columnrecord.nbits
    pages = page_list[field.leaf_field.content_col_idx]
    typenum = field.leaf_field.columnrecord.type
    split = 14 <= typenum <= 21 || 26 <= typenum <= 28
    delta = 14 <= typenum <= 15
    bytes = read_pagedesc(io, pages, nbits; split)
    contents = reinterpret(T, bytes)
    if delta
        cumsum!(contents, contents)
    end
    res = CardinalityVector(contents)
    return res::_field_output_type(field)
end

_from_zigzag(n) = (n >> 1) ⊻ -(n & 1)
_to_zigzag(n) = (n << 1) ⊻ (n >> 63)
function _from_zigzag!(res::AbstractVector)
    @simd for i in eachindex(res)
        res[i] = _from_zigzag(res[i])
    end
    return res
end

function _to_zigzag!(res::AbstractVector)
    @simd for i in eachindex(res)
        res[i] = _to_zigzag(res[i])
    end
    return res
end

function _reset_to_incremental(res::AbstractVector, pages, ::Type{T}) where T
    endpoint = 0
    for pi in firstindex(pages):lastindex(pages)-1
        endpoint += pages[pi].num_elements
        res[endpoint+1] -= sum(@view res[begin:endpoint])
    end
end

_field_output_type(::Type{LeafField{T}}) where {T} = Vector{T}
function read_field(io, field::LeafField{T}, page_list) where T
    nbits = field.columnrecord.nbits
    pages = page_list[field.content_col_idx]
    # handle split encoding within page
    typenum = field.columnrecord.type
    split = 14 <= typenum <= 21 || 26 <= typenum <= 28
    zigzag = 26 <= typenum <= 28
    delta = 14 <= typenum <= 15
    bytes = read_pagedesc(io, pages, nbits; split = split)
    res = collect(reinterpret(T, bytes))
    if zigzag
        _from_zigzag!(res)
    elseif delta
        # the Index32/64 resets to absolute offset page-by-page
        # https://github.com/JuliaHEP/UnROOT.jl/issues/312#issuecomment-1999875348
        if T <: Union{Index32, Index64} && length(pages) > 1
            _reset_to_incremental(res, pages, T)
        end
        cumsum!(res, res)
    end
    return res::_field_output_type(field)
end

_field_output_type(::Type{LeafField{Bool}}) = BitVector
function read_field(io, field::LeafField{Bool}, page_list)
    nbits = field.columnrecord.nbits
    pages = page_list[field.content_col_idx]
    total_num_elements = sum(p.num_elements for p in pages)

    # pad to nearest 8*k bytes because each chunk needs to be UInt64
    bytes = read_pagedesc(io, pages, nbits)
    append!(bytes, zeros(eltype(bytes), 8 - rem(total_num_elements, 8)))
    chunks = reinterpret(UInt64, bytes)

    res = BitVector(undef, total_num_elements)
    copyto!(res.chunks, chunks) # don't want jam ReinterpretArray into BitVector
    return res::_field_output_type(field)
end

_field_output_type(::Type{VectorField{O, T}}) where {O, T} = VectorOfVectors{eltype(_field_output_type(T)), _field_output_type(T), Vector{eltype(O)}, Vector{Tuple{}}}
function read_field(io, field::VectorField{O, T}, page_list) where {O, T}
    offset = read_field(io, field.offset_col, page_list)
    content = read_field(io, field.content_col, page_list)

    o = one(eltype(offset))
    jloffset = pushfirst!(offset .+ o, o) #change to 1-indexed, and add a 1 at the beginning
    res = VectorOfVectors(content, jloffset)
    return res::_field_output_type(field)
end

function _field_output_type(::Type{StructField{N, T}}) where {N, T}
    types = Tuple{eltype.(_field_output_type.(T.types))...}
    types2 = Tuple{_field_output_type.(T.types)...}
    StructArray{NamedTuple{N, types}, 1, NamedTuple{N, types2}, Int64}
end

"""
    read_field(io, field::StructField{N, T}, page_list) where {N, T}

Since each field of the struct is stored in a separate field of the RNTuple,
this function returns a `StructArray` to maximize efficiency.
"""
function read_field(io, field::StructField{N, T}, page_list) where {N, T}
    contents = (read_field(io, col, page_list) for col in field.content_cols)
    res = StructArray(NamedTuple{N}(contents))
    return res::_field_output_type(field)
end

struct UnionVector{T, N} <: AbstractVector{T}
    kindex::Vector{UInt64}
    tag::Vector{Int32}
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
    kindex = content .& (typemax(UInt128) >> 64) .+ 1
    tags = Int32.(content .>> 64)
    return kindex, tags
end
function _field_output_type(::Type{UnionField{S, T}}) where {S, T}
    types = _field_output_type.(T.types)
    return UnionVector{Union{eltype.(types)...}, Tuple{types...}}
end
function read_field(io, field::UnionField{S, T}, page_list) where {S, T}
    switch = read_field(io, field.switch_col, page_list)
    content = Tuple(read_field(io, col, page_list) for col in field.content_cols)
    res = UnionVector(_split_switch_bits(switch)..., content)
    return res::_field_output_type(field)
end
