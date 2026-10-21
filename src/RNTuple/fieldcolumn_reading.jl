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

"""
    _active_pages(field::LeafField, page_list) -> (pages, columnrecord)

The pages of `field` in this cluster together with the column record they
belong to. A field may have several column representations; in every cluster
exactly one of them is active while the others are suppressed (no pages), so
the first representation that has pages is the active one.
"""
function _active_pages(field::LeafField, page_list)
    pages = _pages_or_empty(page_list, field.content_col_idx)
    isempty(pages) || return pages, field.columnrecord
    for (idx, cr) in zip(field.alt_col_idx, field.alt_columnrecords)
        alt = _pages_or_empty(page_list, idx)
        isempty(alt) || return alt, cr
    end
    return pages, field.columnrecord
end

# number of leading zero elements this cluster contributes for a column.
# Entry-aligned columns (top-level leaves and offset columns) have element
# index == entry index, so the padding is the part of [first_entry,
# first_entry+n_entries) that lies before the column's first element index.
# Content columns have first_ele_idx == 0 and therefore zero padding.
_deferred_pad(ci::ClusterInfo, cr::ColumnRecord) =
    clamp(cr.first_ele_idx - ci.first_entry, 0, ci.n_entries)
# fallback for callers passing a bare page list (single-cluster semantics)
_deferred_pad(pl, cr::ColumnRecord) = cr.first_ele_idx

# number of elements described by a list of page descriptions (the sign of
# `num_elements` only records whether a page carries a checksum)
_num_elements(pagedescs) = sum(p -> abs(Int(p.num_elements)), pagedescs; init=0)

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
# `std::bitset<N>`: the bits are stored in a Bit column, which we read as a
# BitVector that cannot be reinterpreted; go through a plain Vector{Bool}
function _field_output_type(::Type{StdArrayField{N, LeafField{Bool}}}) where {N}
    return Base.ReinterpretArray{SVector{N, Bool}, 1, Bool, Vector{Bool}, false}
end
function read_field(io, field::StdArrayField{N, LeafField{Bool}}, page_list) where {N}
    content = convert(Vector{Bool}, read_field(io, field.content_col, page_list))
    res = reinterpret(SVector{N, Bool}, content)
    return res::_field_output_type(field)
end

_field_output_type(::Type{StringField{O, T}}) where {O, T} = Vector{String}
function read_field(io, field::StringField{O, T}, page_list) where {O, T}
    pages, cr = _active_pages(field.content_col, page_list)

    offset = read_field(io, field.offset_col, page_list)
    content = read_pagedesc(io, pages, cr)

    jloffset = _one_based_offsets(offset)
    res = String.(VectorOfVectors(content, jloffset))
    return res::_field_output_type(field)
end

# RNTuple offset columns hold, for every entry, the (0-based, exclusive) end
# index of that entry in the content column; turn them into the 1-based
# element pointers `[1, end_1 + 1, end_2 + 1, ...]` that `VectorOfVectors` expects
function _one_based_offsets(offset::AbstractVector{T}) where {T}
    o = one(T)
    res = Vector{T}(undef, length(offset) + 1)
    @inbounds res[1] = o
    @inbounds @simd for i in eachindex(offset)
        res[i + 1] = offset[i] + o
    end
    return res
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
    leaf = field.leaf_field
    pages, cr = _active_pages(leaf, page_list)
    pad = _deferred_pad(page_list, leaf.columnrecord)
    n = _num_elements(pages)
    bytes = Vector{UInt8}(undef, (pad + n) * sizeof(T))
    fill!(@view(bytes[1:pad * sizeof(T)]), 0x00)
    if _jltype(cr) === T
        read_pagedesc!(@view(bytes[pad * sizeof(T) + 1:end]), io, pages, cr)
    else
        alt = reinterpret(_jltype(cr), read_pagedesc(io, pages, cr))
        copyto!(reinterpret(T, @view(bytes[pad * sizeof(T) + 1:end])), convert.(T, alt))
    end
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
    pages, cr = _active_pages(field, page_list)
    pad = _deferred_pad(page_list, field.columnrecord)
    n = _num_elements(pages)
    res = Vector{T}(undef, pad + n)
    fill!(@view(res[1:pad]), zero(T))
    AT = _jltype(cr)
    if AT === T && Base.elsize(Vector{T}) == sizeof(T) == cld(Int(cr.nbits), 8) && n > 0
        # decode the pages straight into the result vector
        GC.@preserve res begin
            dst = unsafe_wrap(Vector{UInt8}, Ptr{UInt8}(pointer(res, pad + 1)), n * sizeof(T))
            read_pagedesc!(dst, io, pages, cr)
        end
    elseif n > 0
        # a secondary representation with a different on-disk type (e.g. Real16
        # for a float field), or an element type whose array stride differs
        # from its size: decode, then convert
        decoded = reinterpret(AT, read_pagedesc(io, pages, cr))
        @inbounds for i in 1:n
            res[pad + i] = convert(T, decoded[i])
        end
    end
    return res::_field_output_type(field)
end

_field_output_type(::Type{LeafField{Bool}}) = BitVector
function read_field(io, field::LeafField{Bool}, page_list)
    pages, cr = _active_pages(field, page_list)
    total_num_elements = _num_elements(pages)

    # pad to nearest 8*k bytes because each chunk needs to be UInt64
    bytes = read_pagedesc(io, pages, cr)
    N_pad = 8 - mod1(length(bytes), 8)
    append!(bytes, zeros(eltype(bytes), N_pad))
    chunks = reinterpret(UInt64, bytes)

    res = BitVector(undef, total_num_elements)
    copyto!(res.chunks, chunks) # don't want jam ReinterpretArray into BitVector
    # BitVector requires the unused bits of the last chunk to be zero
    rem = total_num_elements % 64
    if rem != 0
        @inbounds res.chunks[end] &= (UInt64(1) << rem) - one(UInt64)
    end

    pad = _deferred_pad(page_list, field.columnrecord)
    if !iszero(pad)
        prepend!(res, fill(false, pad))
    end
    return res::_field_output_type(field)
end

# ArraysOfArrays v1 (which introduced PartsView) adds the element type of VectorOfVectors as a fifth type parameter
@static if isdefined(ArraysOfArrays, :PartsView)
    _vov_type(::Type{VT}, ::Type{VI}) where {VT, VI} = VectorOfVectors{eltype(VT), VT, VI, Vector{Tuple{}}, Base.promote_op(view, VT, UnitRange{Int})}
else
    _vov_type(::Type{VT}, ::Type{VI}) where {VT, VI} = VectorOfVectors{eltype(VT), VT, VI, Vector{Tuple{}}}
end

# The data vector that backs a `VectorOfVectors` for a vector field whose
# content field has output type `T`. `VectorOfVectors` needs the type of a
# `view` of its data to be inferrable, which is not the case for a
# `StructArray` with 32 or more columns (e.g. a wide `std::vector<Struct>` in
# NanoAOD-style files); such contents are materialized into a plain
# `Vector{NamedTuple}` instead.
function _vector_content_type(::Type{T}) where {T}
    VT = _field_output_type(T)
    _needs_materialization(VT) ? Vector{eltype(VT)} : VT
end
# `map` over a NamedTuple with 32 or more entries (`Base.Any32`) is not
# inferred precisely, so neither is `view` of such a StructArray
_needs_materialization(::Type{<:StructArray{T, 1, C}}) where {T, C} = fieldcount(C) >= 32
_needs_materialization(::Type) = false
_field_output_type(::Type{VectorField{O, T}}) where {O, T} = _vov_type(_vector_content_type(T), Vector{eltype(O)})
function read_field(io, field::VectorField{O, T}, page_list) where {O, T}
    offset = read_field(io, field.offset_col, page_list)
    jloffset = _one_based_offsets(offset)
    content = read_field(io, field.content_col, page_list)
    VT = _vector_content_type(T)
    data = content isa VT ? content : convert(VT, content)

    res = VectorOfVectors(data, jloffset)
    return res::_field_output_type(field)
end
# a vector of empty structs (e.g. `DataVector<xAOD::Jet_v1>` whose members all
# live in auxiliary stores) has no content column at all: the number of
# elements is known only from the offsets
function read_field(io, field::VectorField{O, StructField{(), Tuple{}}}, page_list) where {O}
    offset = read_field(io, field.offset_col, page_list)
    jloffset = _one_based_offsets(offset)
    data = fill(NamedTuple(), Int(jloffset[end]) - 1)
    res = VectorOfVectors(data, jloffset)
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

# a struct without any member carrying data (e.g. an empty C++ class): one
# empty NamedTuple per entry of the cluster
_field_output_type(::Type{StructField{(), Tuple{}}}) = Vector{NamedTuple{(), Tuple{}}}
function read_field(io, field::StructField{(), Tuple{}}, page_list)
    n = page_list isa ClusterInfo ? page_list.n_entries : 0
    res = fill(NamedTuple(), n)
    return res::_field_output_type(field)
end

"""
    UnionVector{T, N} <: AbstractVector{T}

Lazy view of a `std::variant` field. `tag[i]` selects the alternative (1-based)
holding entry `i` and `kindex[i]` its 1-based index within that alternative's
content vector. A tag of `0` marks a variant without value
(`valueless_by_exception`), which is returned as `missing`.
"""
struct UnionVector{T, N} <: AbstractVector{T}
    kindex::Vector{UInt64}
    tag::Vector{Int32}
    contents::N
    function UnionVector(kindex, tag, contents::N) where N
        T = Union{Missing, eltype.(contents)...}
        return new{T, N}(kindex, tag, contents)
    end
end
Base.length(ary::UnionVector) = length(ary.tag)
Base.size(ary::UnionVector) = (length(ary.tag), )
Base.IndexStyle(::UnionVector) = IndexLinear()
function Base.getindex(ary::UnionVector, i::Int)
    ith_type = ary.tag[i]
    ith_type == 0 && return missing
    ith_ele = ary.kindex[i]
    return ary.contents[ith_type][ith_ele]
end

function _split_switch_bits(content)
    kindex = content .& (typemax(UInt128) >> 64) .+ 1
    tags = Int32.(content .>> 64)
    return kindex, tags
end
function _field_output_type(::Type{UnionField{S, T}}) where {S, T}
    types = _field_output_type.(T.types)
    return UnionVector{Union{Missing, eltype.(types)...}, Tuple{types...}}
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
# into Float32 bit patterns, written into `res` (4 bytes per element)
function _read_lowprecision_pages!(res::AbstractVector{UInt8}, io, pagedescs, cr)
    nbits = Int(cr.nbits)
    (;trunc, quant) = _detect_encoding(cr.type)
    res32 = reinterpret(UInt32, res)
    tmp = Vector{UInt8}(undef, 65536)
    tip = 1
    for pagedesc in pagedescs
        n = abs(Int(pagedesc.num_elements))
        packed_size = div(n * nbits, 8, RoundUp)
        _read_locator!(tmp, io, pagedesc.locator, packed_size)
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
    read_pagedesc!(dst::AbstractVector{UInt8}, io, pagedescs, cr)

Read the decompressed raw bytes given a list of Page Descriptions, either into
a freshly allocated vector or into `dst` (which must hold exactly
`ceil(num_elements * nbits / 8)` bytes, or `4 * num_elements` bytes for the
variable-width float encodings). The `nbits` comes from the column record since
`pagedesc` only contains `num_elements` information.

!!! note
    We handle split, zigzag, delta and low-precision float encodings inside this function.
"""
function read_pagedesc(io, pagedescs::AbstractVector{PageDescription}, cr::ColumnRecord)
    total_num_elements = _num_elements(pagedescs)
    (;trunc, quant) = _detect_encoding(cr.type)
    output_L = (trunc || quant) ? 4 * total_num_elements : div(total_num_elements * Int(cr.nbits), 8, RoundUp)
    res = Vector{UInt8}(undef, output_L)
    return read_pagedesc!(res, io, pagedescs, cr)
end

function read_pagedesc!(res::AbstractVector{UInt8}, io, pagedescs::AbstractVector{PageDescription}, cr::ColumnRecord)
    nbits = Int(cr.nbits)
    (;split, zigzag, delta, trunc, quant) = _detect_encoding(cr.type)

    if trunc || quant
        return _read_lowprecision_pages!(res, io, pagedescs, cr)
    end

    # scratch buffer for one decompressed page; grown on demand
    tmp = Vector{UInt8}(undef, 65536)

    tip = 1
    for pagedesc in pagedescs
        # the sign of `num_elements` records whether the page carries a
        # checksum (negative) or not (positive); we don't verify it either way
        n = abs(Int(pagedesc.num_elements))
        # when nbits == 1 for bits, need RoundUp
        uncomp_size = div(n * nbits, 8, RoundUp)
        dst = @view res[tip:tip+uncomp_size-1]
        ondisk = read_seek_nb(io, pagedesc.locator.offset, pagedesc.locator.num_bytes)
        # uncompressed pages are decoded straight from the file bytes
        src = if length(ondisk) >= uncomp_size
            ondisk
        else
            decompress_bytes!(tmp, ondisk, uncomp_size)
        end
        if split
            if nbits == 16
                split2_reinterpret!(dst, src)
            elseif nbits == 32
                split4_reinterpret!(dst, src)
            elseif nbits == 64
                split8_reinterpret!(dst, src)
            end
        else
            copyto!(dst, 1, src, 1, uncomp_size)
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
