"""
    rnt_ary_to_page(ary::AbstractVector, cr::ColumnRecord) end

Turns an AbstractVector into a page of an RNTuple. The element type must be primitive for this to work.

"""
function rnt_ary_to_page(ary::AbstractVector, cr::ColumnRecord) end

function rnt_ary_to_page(ary::AbstractVector{Float64}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    if split
        Page_write(split8_encode(reinterpret(UInt8, ary)))
    else
        Page_write(reinterpret(UInt8, ary))
    end
end

function rnt_ary_to_page(ary::AbstractVector{Float32}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    if split
        Page_write(split4_encode(reinterpret(UInt8, ary)))
    else
        Page_write(reinterpret(UInt8, ary))
    end
end

function rnt_ary_to_page(ary::AbstractVector{Float16}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    if split
        Page_write(split2_encode(reinterpret(UInt8, ary)))
    else
        Page_write(reinterpret(UInt8, ary))
    end
end

function rnt_ary_to_page(ary::AbstractVector{UInt64}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    if split
        Page_write(split8_encode(reinterpret(UInt8, ary)))
    else
        Page_write(reinterpret(UInt8, ary))
    end
end

function rnt_ary_to_page(ary::AbstractVector{UInt32}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    if split
        Page_write(split4_encode(reinterpret(UInt8, ary)))
    else
        Page_write(reinterpret(UInt8, ary))
    end
end

function rnt_ary_to_page(ary::AbstractVector{UInt16}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    if split
        Page_write(split2_encode(reinterpret(UInt8, ary)))
    else
        Page_write(reinterpret(UInt8, ary))
    end
end

function rnt_ary_to_page(ary::AbstractVector{Int64}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    Page_write(reinterpret(UInt8, ary))
end

function rnt_ary_to_page(ary::AbstractVector{Int32}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    Page_write(reinterpret(UInt8, ary))
end

function rnt_ary_to_page(ary::AbstractVector{Int16}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    Page_write(reinterpret(UInt8, ary))
end

function rnt_ary_to_page(ary::AbstractVector{Int8}, cr::ColumnRecord)
    (;split, zigzag, delta) = _detect_encoding(cr.type)
    Page_write(reinterpret(UInt8, ary))
end

function split8_encode(src::AbstractVector{UInt8})
    @views [src[1:8:end-7]; src[2:8:end-6]; src[3:8:end-5]; src[4:8:end-4]; src[5:8:end-3]; src[6:8:end-2]; src[7:8:end-1]; src[8:8:end]]
end
function split4_encode(src::AbstractVector{UInt8})
    @views [src[1:4:end-3]; src[2:4:end-2]; src[3:4:end-1]; src[4:4:end]]
end
function split2_encode(src::AbstractVector{UInt8})
    @views [src[1:2:end-1]; src[2:2:end]]
end

_to_zigzag(n) = (n << 1) ⊻ (n >> (sizeof(n)*8-1))
function _to_zigzag(res::AbstractVector)
    out = similar(res)
    @simd for i in eachindex(out, res)
        out[i] = _to_zigzag(res[i])
    end
    return out
end
