# Native Julia implementations of XXH3-64 (seed 0) and XXH64, the two hash
# functions used by the ROOT file format:
#
#   * XXH3-64 protects every RNTuple envelope (header, footer, page list),
#     the RNTuple anchor and every RNTuple page.
#   * XXH64 protects the payload of every LZ4 compression block.
#
# Both follow the reference specification in
# https://github.com/Cyan4973/xxHash/blob/dev/doc/xxhash_spec.md and are
# validated against the reference implementation in the test suite.
#
# XXH3-64 is only implemented for seed 0 (the only seed ROOT uses); the
# non-zero seed variant for long inputs needs a derived secret.

const _XXH_PRIME32_1 = 0x9E3779B1 % UInt64
const _XXH_PRIME32_2 = 0x85EBCA77 % UInt64
const _XXH_PRIME32_3 = 0xC2B2AE3D % UInt64
const _XXH_PRIME64_1 = 0x9E3779B185EBCA87
const _XXH_PRIME64_2 = 0xC2B2AE3D27D4EB4F
const _XXH_PRIME64_3 = 0x165667B19E3779F9
const _XXH_PRIME64_4 = 0x85EBCA77C2B2AE63
const _XXH_PRIME64_5 = 0x27D4EB2F165667C5
const _XXH3_PRIME_MX1 = 0x165667919E3779F9
const _XXH3_PRIME_MX2 = 0x9FB21C651E98DF25

# the default 192-byte XXH3 secret (kSecret in xxhash.h)
const _XXH3_SECRET = UInt8[
    0xb8, 0xfe, 0x6c, 0x39, 0x23, 0xa4, 0x4b, 0xbe, 0x7c, 0x01, 0x81, 0x2c, 0xf7, 0x21, 0xad, 0x1c,
    0xde, 0xd4, 0x6d, 0xe9, 0x83, 0x90, 0x97, 0xdb, 0x72, 0x40, 0xa4, 0xa4, 0xb7, 0xb3, 0x67, 0x1f,
    0xcb, 0x79, 0xe6, 0x4e, 0xcc, 0xc0, 0xe5, 0x78, 0x82, 0x5a, 0xd0, 0x7d, 0xcc, 0xff, 0x72, 0x21,
    0xb8, 0x08, 0x46, 0x74, 0xf7, 0x43, 0x24, 0x8e, 0xe0, 0x35, 0x90, 0xe6, 0x81, 0x3a, 0x26, 0x4c,
    0x3c, 0x28, 0x52, 0xbb, 0x91, 0xc3, 0x00, 0xcb, 0x88, 0xd0, 0x65, 0x8b, 0x1b, 0x53, 0x2e, 0xa3,
    0x71, 0x64, 0x48, 0x97, 0xa2, 0x0d, 0xf9, 0x4e, 0x38, 0x19, 0xef, 0x46, 0xa9, 0xde, 0xac, 0xd8,
    0xa8, 0xfa, 0x76, 0x3f, 0xe3, 0x9c, 0x34, 0x3f, 0xf9, 0xdc, 0xbb, 0xc7, 0xc7, 0x0b, 0x4f, 0x1d,
    0x8a, 0x51, 0xe0, 0x4b, 0xcd, 0xb4, 0x59, 0x31, 0xc8, 0x9f, 0x7e, 0xc9, 0xd9, 0x78, 0x73, 0x64,
    0xea, 0xc5, 0xac, 0x83, 0x34, 0xd3, 0xeb, 0xc3, 0xc5, 0x81, 0xa0, 0xff, 0xfa, 0x13, 0x63, 0xeb,
    0x17, 0x0d, 0xdd, 0x51, 0xb7, 0xf0, 0xda, 0x49, 0xd3, 0x16, 0x55, 0x26, 0x29, 0xd4, 0x68, 0x9e,
    0x2b, 0x16, 0xbe, 0x58, 0x7d, 0x47, 0xa1, 0xfc, 0x8f, 0xf8, 0xb8, 0xd1, 0x7a, 0xd0, 0x31, 0xce,
    0x45, 0xcb, 0x3a, 0x8f, 0x95, 0x16, 0x04, 0x28, 0xaf, 0xd7, 0xfb, 0xca, 0xbb, 0x4b, 0x40, 0x7e,
]

# Little-endian loads at 0-based byte offset `p`. The caller guarantees bounds.
# Dense byte vectors take an unaligned pointer load; anything else is assembled
# byte by byte.
@inline function _xxh_le32(b::DenseVector{UInt8}, p::Int)
    GC.@preserve b ltoh(unsafe_load(Ptr{UInt32}(pointer(b, p + 1))))
end
@inline function _xxh_le64(b::DenseVector{UInt8}, p::Int)
    GC.@preserve b ltoh(unsafe_load(Ptr{UInt64}(pointer(b, p + 1))))
end
@inline function _xxh_le32(b::AbstractVector{UInt8}, p::Int)
    @inbounds UInt32(b[p+1]) | UInt32(b[p+2]) << 8 | UInt32(b[p+3]) << 16 | UInt32(b[p+4]) << 24
end
@inline function _xxh_le64(b::AbstractVector{UInt8}, p::Int)
    UInt64(_xxh_le32(b, p)) | UInt64(_xxh_le32(b, p + 4)) << 32
end
@inline _xxh_rotl64(x::UInt64, r) = (x << r) | (x >> (64 - r))

@inline function _xxh3_mul128_fold64(a::UInt64, b::UInt64)
    p = UInt128(a) * UInt128(b)
    return (p % UInt64) ⊻ ((p >> 64) % UInt64)
end
@inline function _xxh3_avalanche(h::UInt64)
    h ⊻= h >> 37
    h *= _XXH3_PRIME_MX1
    return h ⊻ (h >> 32)
end
@inline function _xxh64_avalanche(h::UInt64)
    h ⊻= h >> 33
    h *= _XXH_PRIME64_2
    h ⊻= h >> 29
    h *= _XXH_PRIME64_3
    return h ⊻ (h >> 32)
end
@inline function _xxh3_rrmxmx(h::UInt64, len::Int)
    h ⊻= _xxh_rotl64(h, 49) ⊻ _xxh_rotl64(h, 24)
    h *= _XXH3_PRIME_MX2
    h ⊻= (h >> 35) + UInt64(len)
    h *= _XXH3_PRIME_MX2
    return h ⊻ (h >> 28)
end
@inline function _xxh3_mix16B(b, p::Int, s::Int)
    lo = _xxh_le64(b, p)
    hi = _xxh_le64(b, p + 8)
    return _xxh3_mul128_fold64(lo ⊻ _xxh_le64(_XXH3_SECRET, s), hi ⊻ _xxh_le64(_XXH3_SECRET, s + 8))
end

function _xxh3_len_0()
    return _xxh64_avalanche(_xxh_le64(_XXH3_SECRET, 56) ⊻ _xxh_le64(_XXH3_SECRET, 64))
end
function _xxh3_len_1to3(b, len::Int)
    @inbounds c1 = b[1]; c2 = b[(len >> 1) + 1]; c3 = b[len]
    combined = UInt32(c1) << 16 | UInt32(c2) << 24 | UInt32(c3) | UInt32(len) << 8
    bitflip = UInt64(_xxh_le32(_XXH3_SECRET, 0) ⊻ _xxh_le32(_XXH3_SECRET, 4))
    return _xxh64_avalanche(UInt64(combined) ⊻ bitflip)
end
function _xxh3_len_4to8(b, len::Int)
    i1 = _xxh_le32(b, 0)
    i2 = _xxh_le32(b, len - 4)
    bitflip = _xxh_le64(_XXH3_SECRET, 8) ⊻ _xxh_le64(_XXH3_SECRET, 16)
    input64 = UInt64(i2) + UInt64(i1) << 32
    return _xxh3_rrmxmx(input64 ⊻ bitflip, len)
end
function _xxh3_len_9to16(b, len::Int)
    bitflip1 = _xxh_le64(_XXH3_SECRET, 24) ⊻ _xxh_le64(_XXH3_SECRET, 32)
    bitflip2 = _xxh_le64(_XXH3_SECRET, 40) ⊻ _xxh_le64(_XXH3_SECRET, 48)
    lo = _xxh_le64(b, 0) ⊻ bitflip1
    hi = _xxh_le64(b, len - 8) ⊻ bitflip2
    acc = UInt64(len) + bswap(lo) + hi + _xxh3_mul128_fold64(lo, hi)
    return _xxh3_avalanche(acc)
end
function _xxh3_len_17to128(b, len::Int)
    acc = UInt64(len) * _XXH_PRIME64_1
    if len > 32
        if len > 64
            if len > 96
                acc += _xxh3_mix16B(b, 48, 96)
                acc += _xxh3_mix16B(b, len - 64, 112)
            end
            acc += _xxh3_mix16B(b, 32, 64)
            acc += _xxh3_mix16B(b, len - 48, 80)
        end
        acc += _xxh3_mix16B(b, 16, 32)
        acc += _xxh3_mix16B(b, len - 32, 48)
    end
    acc += _xxh3_mix16B(b, 0, 0)
    acc += _xxh3_mix16B(b, len - 16, 16)
    return _xxh3_avalanche(acc)
end
function _xxh3_len_129to240(b, len::Int)
    acc = UInt64(len) * _XXH_PRIME64_1
    nrounds = len >> 4
    for i in 0:7
        acc += _xxh3_mix16B(b, 16i, 16i)
    end
    acc = _xxh3_avalanche(acc)
    for i in 8:nrounds-1
        acc += _xxh3_mix16B(b, 16i, 16(i - 8) + 3)  # XXH3_MIDSIZE_STARTOFFSET
    end
    acc += _xxh3_mix16B(b, len - 16, 136 - 17)     # XXH3_SECRET_SIZE_MIN - XXH3_MIDSIZE_LASTOFFSET
    return _xxh3_avalanche(acc)
end
# one 64-byte stripe at byte offset `p`, keyed with the secret at offset `s`
@inline function _xxh3_accumulate512!(acc::NTuple{8,UInt64}, b, p::Int, s::Int)
    Base.Cartesian.@nexprs 8 i -> begin
        dv_i = _xxh_le64(b, p + 8(i - 1))
        dk_i = dv_i ⊻ _xxh_le64(_XXH3_SECRET, s + 8(i - 1))
    end
    # acc[i ⊻ 1] += data; acc[i] += lo32(key) * hi32(key)
    return (
        acc[1] + dv_2 + UInt64(dk_1 % UInt32) * (dk_1 >> 32),
        acc[2] + dv_1 + UInt64(dk_2 % UInt32) * (dk_2 >> 32),
        acc[3] + dv_4 + UInt64(dk_3 % UInt32) * (dk_3 >> 32),
        acc[4] + dv_3 + UInt64(dk_4 % UInt32) * (dk_4 >> 32),
        acc[5] + dv_6 + UInt64(dk_5 % UInt32) * (dk_5 >> 32),
        acc[6] + dv_5 + UInt64(dk_6 % UInt32) * (dk_6 >> 32),
        acc[7] + dv_8 + UInt64(dk_7 % UInt32) * (dk_7 >> 32),
        acc[8] + dv_7 + UInt64(dk_8 % UInt32) * (dk_8 >> 32),
    )
end
@inline function _xxh3_scramble(acc::NTuple{8,UInt64}, s::Int)
    return ntuple(Val(8)) do i
        a = acc[i]
        a ⊻= a >> 47
        a ⊻= _xxh_le64(_XXH3_SECRET, s + 8(i - 1))
        a * _XXH_PRIME32_1
    end
end
function _xxh3_len_long(b, len::Int)
    acc = (_XXH_PRIME32_3, _XXH_PRIME64_1, _XXH_PRIME64_2, _XXH_PRIME64_3,
           _XXH_PRIME64_4, _XXH_PRIME32_2, _XXH_PRIME64_5, _XXH_PRIME32_1)
    secretsize = length(_XXH3_SECRET)              # 192
    stripes_per_block = (secretsize - 64) ÷ 8      # 16
    block_len = 64 * stripes_per_block             # 1024
    nb_blocks = (len - 1) ÷ block_len
    for n in 0:nb_blocks-1
        for s in 0:stripes_per_block-1
            acc = _xxh3_accumulate512!(acc, b, n * block_len + 64s, 8s)
        end
        acc = _xxh3_scramble(acc, secretsize - 64)
    end
    # the last, partial block: full stripes first, then the final 64 bytes of
    # the input keyed with the secret at (secretsize - 64 - XXH_SECRET_LASTACC_START)
    nb_stripes = ((len - 1) - block_len * nb_blocks) ÷ 64
    for s in 0:nb_stripes-1
        acc = _xxh3_accumulate512!(acc, b, nb_blocks * block_len + 64s, 8s)
    end
    acc = _xxh3_accumulate512!(acc, b, len - 64, secretsize - 64 - 7)
    result = UInt64(len) * _XXH_PRIME64_1          # merge with the secret at XXH_SECRET_MERGEACCS_START
    for i in 0:3
        result += _xxh3_mul128_fold64(acc[2i + 1] ⊻ _xxh_le64(_XXH3_SECRET, 11 + 16i),
                                      acc[2i + 2] ⊻ _xxh_le64(_XXH3_SECRET, 11 + 16i + 8))
    end
    return _xxh3_avalanche(result)
end

"""
    xxh3_64(bytes::AbstractVector{UInt8}) -> UInt64

XXH3 64-bit hash (seed 0) of `bytes`, as used for RNTuple envelope, anchor and
page checksums.
"""
function xxh3_64(b::AbstractVector{UInt8})
    Base.require_one_based_indexing(b)
    len = length(b)
    if len == 0
        return _xxh3_len_0()
    elseif len <= 3
        return _xxh3_len_1to3(b, len)
    elseif len <= 8
        return _xxh3_len_4to8(b, len)
    elseif len <= 16
        return _xxh3_len_9to16(b, len)
    elseif len <= 128
        return _xxh3_len_17to128(b, len)
    elseif len <= 240
        return _xxh3_len_129to240(b, len)
    else
        return _xxh3_len_long(b, len)
    end
end
xxh3_64(s::AbstractString) = xxh3_64(codeunits(s))

@inline function _xxh64_round(acc::UInt64, input::UInt64)
    acc += input * _XXH_PRIME64_2
    acc = _xxh_rotl64(acc, 31)
    return acc * _XXH_PRIME64_1
end
@inline function _xxh64_merge_round(acc::UInt64, val::UInt64)
    acc ⊻= _xxh64_round(UInt64(0), val)
    return acc * _XXH_PRIME64_1 + _XXH_PRIME64_4
end

"""
    xxh64(bytes::AbstractVector{UInt8}, seed=0) -> UInt64

XXH64 hash of `bytes`, as used for the checksum of ROOT's LZ4 compression blocks.
"""
function xxh64(b::AbstractVector{UInt8}, seed::UInt64 = UInt64(0))
    Base.require_one_based_indexing(b)
    len = length(b)
    p = 0
    if len >= 32
        v1 = seed + _XXH_PRIME64_1 + _XXH_PRIME64_2
        v2 = seed + _XXH_PRIME64_2
        v3 = seed
        v4 = seed - _XXH_PRIME64_1
        while p + 32 <= len
            v1 = _xxh64_round(v1, _xxh_le64(b, p))
            v2 = _xxh64_round(v2, _xxh_le64(b, p + 8))
            v3 = _xxh64_round(v3, _xxh_le64(b, p + 16))
            v4 = _xxh64_round(v4, _xxh_le64(b, p + 24))
            p += 32
        end
        h = _xxh_rotl64(v1, 1) + _xxh_rotl64(v2, 7) + _xxh_rotl64(v3, 12) + _xxh_rotl64(v4, 18)
        h = _xxh64_merge_round(h, v1)
        h = _xxh64_merge_round(h, v2)
        h = _xxh64_merge_round(h, v3)
        h = _xxh64_merge_round(h, v4)
    else
        h = seed + _XXH_PRIME64_5
    end
    h += UInt64(len)
    while p + 8 <= len
        h ⊻= _xxh64_round(UInt64(0), _xxh_le64(b, p))
        h = _xxh_rotl64(h, 27) * _XXH_PRIME64_1 + _XXH_PRIME64_4
        p += 8
    end
    if p + 4 <= len
        h ⊻= UInt64(_xxh_le32(b, p)) * _XXH_PRIME64_1
        h = _xxh_rotl64(h, 23) * _XXH_PRIME64_2 + _XXH_PRIME64_3
        p += 4
    end
    while p < len
        @inbounds h ⊻= UInt64(b[p + 1]) * _XXH_PRIME64_5
        h = _xxh_rotl64(h, 11) * _XXH_PRIME64_1
        p += 1
    end
    return _xxh64_avalanche(h)
end
