function _find_cluster_idx(rn::RNTuple, event_id::Integer)
    idx = findfirst(rn.footer.cluster_summaries) do cluster
        cluster.num_first_entry + cluster.num_entries > event_id
    end
    return idx
end

_field_output_type(x::T) where T = _field_output_type(T)

_field_output_type(::Type{StringField{O, T}}) where {O, T} = Vector{String}
function read_field(io, field::StringField{O, T}, page_list, cluster_idx) where {O, T}
    nbits = field.content_col.nbits
    pages = page_list[cluster_idx][field.content_col.content_col_idx]

    offset = read_field(io, field.offset_col, page_list, cluster_idx)
    content = read_pagedesc(io, pages, nbits)

    o = one(eltype(offset))
    jloffset = pushfirst!(offset .+ o, o) #change to 1-indexed, and add a 1 at the beginning
    res = String.(VectorOfVectors(content, jloffset, ArraysOfArrays.no_consistency_checks))
    return res::_field_output_type(field)
end

_field_output_type(::Type{LeafField{T}}) where {T} = Base.ReinterpretArray{T, 1, UInt8, Vector{UInt8}, false}
function read_field(io, field::LeafField{T}, page_list, cluster_idx) where T
    nbits = field.nbits
    pages = page_list[cluster_idx][field.content_col_idx]
    bytes = read_pagedesc(io, pages, nbits)
    res = reinterpret(T, bytes)
    return res::_field_output_type(field)
end

_field_output_type(::Type{VectorField{O, T}}) where {O, T} = VectorOfVectors{eltype(_field_output_type(T)), _field_output_type(T), Vector{Int32}, Vector{Tuple{}}}
function read_field(io, field::VectorField{O, T}, page_list, cluster_idx) where {O, T}
    offset = read_field(io, field.offset_col, page_list, cluster_idx)
    content = read_field(io, field.content_col, page_list, cluster_idx)

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
function read_field(io, field::StructField{N, T}, page_list, cluster_idx) where {N, T}
    contents = (read_field(io, col, page_list, cluster_idx) for col in field.content_cols)
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
Base.IndexStyle(ary::UnionVector) = IndexLinear()
function Base.getindex(ary::UnionVector, i::Int)
    ith_ele = ary.kindex[i]
    ith_type = ary.tag[i]
    return ary.contents[ith_type][ith_ele]
end
function Base.show(io::IO, ::Type{UnionVector{T, N}}) where {T, N}
    print(io, "UnionVector{$T}")
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
function read_field(io, field::UnionField{S, T}, page_list, cluster_idx) where {S, T}
    switch = read_field(io, field.switch_col, page_list, cluster_idx)
    content = Tuple(read_field(io, col, page_list, cluster_idx) for col in field.content_cols)
    res = UnionVector(_split_switch_bits(switch)..., content)
    return res::_field_output_type(field)
end

function _read_field_cluster(rn, field_name, event_id)
    #TODO handle cluster groups
    bytes = _read_envlink(rn.io, only(rn.footer.cluster_group_records).page_list_link);
    page_list = _rntuple_read(IOBuffer(bytes), RNTupleEnvelope{PageLink}).payload
    cluster_idx = _find_cluster_idx(rn, event_id)
    read_field(rn.io, getfield(rn.schema, field_name), page_list, cluster_idx)
end
