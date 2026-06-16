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

"""
    ClusterInfo

Wraps one cluster's page locations (the outer list, one item per column)
together with the cluster's entry range. The entry range is needed to handle
deferred (extension) columns: clusters written before a column was added omit
it from the page list entirely, and clusters overlapping the column's
`first_ele_idx` need leading zero elements.
"""
struct ClusterInfo{O}
    pages::O
    first_entry::Int64
    n_entries::Int64
end
Base.getindex(c::ClusterInfo, i) = c.pages[i]
Base.length(c::ClusterInfo) = length(c.pages)

# pages of column `idx` in this cluster; a column is absent from a cluster's
# page list when the cluster predates the column (deferred/extension columns)
_pages_or_empty(pl, idx) = idx <= length(pl) ? pl[idx] : PageDescription[]

# number of leading zero elements this cluster contributes for a column.
# Entry-aligned columns (top-level leaves and offset columns) have element
# index == entry index, so the padding is the part of [first_entry,
# first_entry+n_entries) that lies before the column's first element index.
# Content columns have first_ele_idx == 0 and therefore zero padding.
_deferred_pad(ci::ClusterInfo, cr::ColumnRecord) =
    clamp(cr.first_ele_idx - ci.first_entry, 0, ci.n_entries)
# fallback for callers passing a bare page list (single-cluster semantics)
_deferred_pad(pl, cr::ColumnRecord) = cr.first_ele_idx

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
    cr = field.content_col.columnrecord
    pages = _pages_or_empty(page_list, field.content_col.content_col_idx)

    offset = read_field(io, field.offset_col, page_list)
    content = read_pagedesc(io, pages, cr)

    o = one(eltype(offset))
    jloffset = pushfirst!(offset .+ o, o) #change to 1-indexed, and add a 1 at the beginning
    res = String.(VectorOfVectors(content, jloffset))
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
    cr = field.leaf_field.columnrecord
    pages = _pages_or_empty(page_list, field.leaf_field.content_col_idx)
    pad = _deferred_pad(page_list, cr)
    bytes = vcat(zeros(UInt8, pad * sizeof(T)), read_pagedesc(io, pages, cr))
    contents = reinterpret(T, bytes)
    res = CardinalityVector(contents)
    return res::_field_output_type(field)
end

# logical shift is required: the encoded value is conceptually unsigned, and an
# arithmetic shift sign-extends encodings of large-magnitude values
_from_zigzag(n) = (n >>> 1) ⊻ (-(n & 1))
function _from_zigzag!(res::AbstractVector)
    @simd for i in eachindex(res)
        res[i] = _from_zigzag(res[i])
    end
    return res
end

_field_output_type(::Type{LeafField{T}}) where {T} = Vector{T}
function read_field(io, field::LeafField{T}, page_list) where T
    cr = field.columnrecord
    pages = _pages_or_empty(page_list, field.content_col_idx)
    pad = _deferred_pad(page_list, cr)
    res = fill(zero(T), pad)
    append!(res, reinterpret(T, read_pagedesc(io, pages, cr)))
    return res::_field_output_type(field)
end

_field_output_type(::Type{LeafField{Bool}}) = BitVector
function read_field(io, field::LeafField{Bool}, page_list)
    cr = field.columnrecord
    pages = _pages_or_empty(page_list, field.content_col_idx)
    total_num_elements = sum(abs(p.num_elements) for p in pages; init=0)

    # pad to nearest 8*k bytes because each chunk needs to be UInt64
    bytes = read_pagedesc(io, pages, cr)
    N_pad = 8 - mod1(length(bytes), 8)
    append!(bytes, zeros(eltype(bytes), N_pad))
    chunks = reinterpret(UInt64, bytes)

    res = BitVector(undef, total_num_elements)
    copyto!(res.chunks, chunks) # don't want jam ReinterpretArray into BitVector

    pad = _deferred_pad(page_list, cr)
    if !iszero(pad)
        prepend!(res, fill(false, pad))
    end
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

function _detect_encoding(typenum)
    col_type = RNT_COL_TYPE_TABLE[typenum+1]
    split = col_type.issplit
    zigzag = col_type.iszigzag
    delta = col_type.isdelta
    trunc = col_type.istrunc
    quant = col_type.isquant
    return (;split, zigzag, delta, trunc, quant)
end

"""
    _unpack_bits!(out::AbstractVector{UInt32}, packed::AbstractVector{UInt8}, nbits)

Unpack a little-endian bit stream of `nbits`-wide unsigned values (the on-disk
layout of `Real32Trunc`/`Real32Quant` pages) into `out`.
"""
function _unpack_bits!(out::AbstractVector{UInt32}, packed::AbstractVector{UInt8}, nbits::Integer)
    mask = (UInt64(1) << nbits) - 1  # nbits <= 32, computed in 64-bit
    @inbounds for i in eachindex(out)
        bitpos = (i - 1) * nbits
        byte0 = bitpos >> 3
        shift = bitpos & 7
        v = UInt64(0)
        nb = min(8, length(packed) - byte0)
        for k in 1:nb
            v |= UInt64(packed[byte0 + k]) << (8 * (k - 1))
        end
        out[i] = UInt32((v >> shift) & mask)
    end
    return out
end

# decode pages of variable-bit-width float columns (Real32Trunc/Real32Quant)
# into Float32 bit patterns
function _read_lowprecision_pages(io, pagedescs, cr, list_num_elements, total_num_elements)
    nbits = Int(cr.nbits)
    (;trunc, quant) = _detect_encoding(cr.type)
    res = Vector{UInt8}(undef, 4 * total_num_elements)
    res32 = reinterpret(UInt32, res)
    tmp = Vector{UInt8}(undef, 65536)
    tip = 1
    for i in eachindex(list_num_elements, pagedescs)
        n = list_num_elements[i]
        packed_size = div(n * nbits, 8, RoundUp)
        _read_locator!(tmp, io, pagedescs[i].locator, packed_size)
        out = view(res32, tip:tip+n-1)
        _unpack_bits!(out, tmp, nbits)
        if trunc
            # truncated mantissa: stored bits are the nbits MSBs of the Float32
            out .<<= (32 - nbits)
        elseif quant
            scale = (cr.max_value - cr.min_value) / ((Int64(1) << nbits) - 1)
            @. out = reinterpret(UInt32, Float32(cr.min_value + out * scale))
        end
        tip += n
    end
    return res
end

"""
    read_pagedesc(io, pagedescs::AbstractVector{PageDescription}, cr::ColumnRecord)

Read the decompressed raw bytes given a Page Description. The
`nbits` need to be provided according to the element type of the
column since `pagedesc` only contains `num_elements` information.

!!! note
    We handle split, zigzag, and delta encodings inside this function.
"""
function read_pagedesc(io, pagedescs::AbstractVector{PageDescription}, cr::ColumnRecord)
    nbits = cr.nbits
    (;split, zigzag, delta, trunc, quant) = _detect_encoding(cr.type)
    # negative on-disk num_elements means the page carries a checksum (which
    # we don't verify); positive means no checksum, which we don't support
    list_num_elements = [-p.num_elements for p in pagedescs]
    if any(<(0), list_num_elements)
        error("Pages without checksum (positive num_elements) are not supported")
    end
    total_num_elements = sum(list_num_elements; init=0)

    if trunc || quant
        return _read_lowprecision_pages(io, pagedescs, cr, list_num_elements, total_num_elements)
    end
    output_L = div(total_num_elements*nbits, 8, RoundUp)
    res = Vector{UInt8}(undef, output_L)

    # a page max size is 64KB
    tmp = Vector{UInt8}(undef, 65536)

    tip = 1
    for i in eachindex(list_num_elements, pagedescs)
        pagedesc = pagedescs[i]
        # when nbits == 1 for bits, need RoundUp
        uncomp_size = div(list_num_elements[i] * nbits, 8, RoundUp)
        dst = @view res[tip:tip+uncomp_size-1]
        _read_locator!(tmp, io, pagedesc.locator, uncomp_size)
        if split
            if nbits == 16
                split2_reinterpret!(dst, tmp)
            elseif nbits == 32
                split4_reinterpret!(dst, tmp)
            elseif nbits == 64
                split8_reinterpret!(dst, tmp)
            end
        else
            dst .= tmp
        end

        shim = if nbits == 16
            reinterpret(Int16, dst)
        elseif nbits == 32
            reinterpret(Int32, dst)
        elseif nbits == 64
            reinterpret(Int64, dst)
        end

        if delta
            cumsum!(shim, shim)
        elseif zigzag
            _from_zigzag!(shim)
        end

        tip += uncomp_size
    end

    return res
end
