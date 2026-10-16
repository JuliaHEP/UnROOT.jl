"""
    rnt_col_to_ary(col) -> Vector{Vector}

Normalize each user-facing "column" into a collection of Vector{<:Real} ready to be written to a page.
After calling this on all user-facing "column", we should have as many `ary`s as our `ColumnRecord`s and
in the same order.
"""
rnt_col_to_ary(col::AbstractVector{<:Real}) = Any[col]
function rnt_col_to_ary(col::AbstractVector{<:AbstractVector})
    vov = VectorOfVectors(col)
    content = flatview(vov)
    # 0-based indexing
    offset = ArraysOfArrays.element_ptr(vov) .- 1
    offset_adjust = @view offset[begin+1:end]

    Any[rnt_col_to_ary(offset_adjust); rnt_col_to_ary(content)]
end
function rnt_col_to_ary(col::AbstractVector{<:AbstractString})
    rnt_col_to_ary(codeunits.(col))
end

"""
    rnt_ary_to_page(ary::AbstractVector, cr::ColumnRecord) end

Turns an AbstractVector into a page of an RNTuple. The element type must be primitive for this to work.

"""
function rnt_ary_to_page(ary::AbstractVector, cr::ColumnRecord) end

function rnt_ary_to_page(ary::AbstractVector{Bool}, cr::ColumnRecord)
    chunks = BitVector(ary).chunks
    bytes = reinterpret(UInt8, chunks)
    # bit-packed pages store exactly ceil(n/8) bytes; BitVector chunks are
    # 64-bit padded, so truncate (unused trailing bits are zero by invariant)
    Page_write(bytes[1:cld(length(ary), 8)], Int32(length(ary)))
end

function rnt_ary_to_page(ary::AbstractVector{T}, cr::ColumnRecord) where {T<:Number}
    Page_write(page_encode(ary, cr), Int32(length(ary)))
end

"""
    _column_storage_type(cr::ColumnRecord) -> Type

The Julia element type whose bytes make up a page of column `cr` (before any
split/zigzag/delta transformation): index columns are stored as plain `Int32`
or `Int64`, everything else as the table's `jltype`.
"""
function _column_storage_type(cr::ColumnRecord)
    col_type = RNT_COL_TYPE_TABLE[cr.type+1]
    jl = col_type.jltype
    if jl === Index64
        return Int64
    elseif jl === Index32
        return Int32
    elseif jl === Switch || col_type.istrunc || col_type.isquant
        error("UnROOT cannot write pages of column type $(col_type.name)")
    end
    return jl
end

# `(u)intN` view of the storage type with the same width, for zigzag/delta arithmetic
_signed_type(::Type{T}) where {T} = T === Float16 ? Int16 : T === Float32 ? Int32 : T === Float64 ? Int64 : signed(T)

# delta encoding of index columns: each element minus its predecessor (the first
# stays as is), in wrapping arithmetic; the reader undoes this with `cumsum!`
function _delta_encode(ary::AbstractVector{T}) where {T<:Integer}
    out = Vector{T}(undef, length(ary))
    prev = zero(T)
    @inbounds for i in eachindex(ary)
        v = ary[i]
        out[i] = v - prev
        prev = v
    end
    return out
end

function page_encode(ary::AbstractVector, cr::ColumnRecord)
    col_type = RNT_COL_TYPE_TABLE[cr.type+1]
    nbits = col_type.nbits
    T = _column_storage_type(cr)
    data = eltype(ary) === T ? ary : convert(Vector{T}, ary)
    # value transformation (the reader applies the inverse after un-splitting)
    if col_type.isdelta
        data = _delta_encode(reinterpret(_signed_type(T), data))
    elseif col_type.iszigzag
        data = _to_zigzag(reinterpret(_signed_type(T), data))
    end
    src = reinterpret(UInt8, data)
    if col_type.issplit
        if nbits == 64
            split8_encode(src)
        elseif nbits == 32
            split4_encode(src)
        elseif nbits == 16
            split2_encode(src)
        end
    else
        src
    end
end
function split8_encode(src::AbstractVector{UInt8})
    @views [
        src[1:8:end-7]
        src[2:8:end-6]
        src[3:8:end-5]
        src[4:8:end-4]
        src[5:8:end-3]
        src[6:8:end-2]
        src[7:8:end-1]
        src[8:8:end]
    ]
end
function split4_encode(src::AbstractVector{UInt8})
    @views [src[1:4:end-3]; src[2:4:end-2]; src[3:4:end-1]; src[4:4:end]]
end
function split2_encode(src::AbstractVector{UInt8})
    @views [src[1:2:end-1]; src[2:2:end]]
end

_to_zigzag(n) = (n << 1) ⊻ (n >> (sizeof(n) * 8 - 1))
function _to_zigzag(res::AbstractVector)
    out = similar(res)
    @simd for i in eachindex(out, res)
        out[i] = _to_zigzag(res[i])
    end
    return out
end
