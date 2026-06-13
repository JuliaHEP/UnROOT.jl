using XXHashNative: xxh64

# ROOT compression block framing for the RNTuple writer.
#
# ROOT stores a compressed buffer as a sequence of blocks. Each block starts
# with a 9-byte header
#
#     [2-byte algorithm tag][1-byte method][3-byte LE compressed size][3-byte LE uncompressed size]
#
# For LZ4 an 8-byte big-endian XxHash-64 checksum of the compressed bytes
# follows the header and is *included* in the compressed size. A single block
# can describe at most 2^24-1 bytes, so larger payloads are split.
#
# This mirrors `uproot.compression.compress` and is the inverse of the read
# path in `decompress_bytes!` / `decompress_datastreambytes`.

const _RNT_3BYTE_MAX = (1 << 24) - 1

# ROOT's fCompress code: algorithm * 100 + level.
_rnt_compression_algo(fCompress::Integer) = Int(fCompress) ÷ 100
_rnt_compression_level(fCompress::Integer) = Int(fCompress) % 100

function _write_3byte_le!(io::IO, n::Integer)
    write(io, UInt8(n & 0xff))
    write(io, UInt8((n >> 8) & 0xff))
    write(io, UInt8((n >> 16) & 0xff))
    return nothing
end

# Compress one block (already <= 2^24-1 bytes) and emit its framed bytes.
function _write_compressed_block!(io::IO, algo::Int, level::Int, block::Vector{UInt8})
    if algo == Const.kLZ4
        comp = lz4_hc_compress(block, level)
        write(io, UInt8('L'), UInt8('4'), 0x01)
        _write_3byte_le!(io, length(comp) + 8)   # compressed size counts the checksum
        _write_3byte_le!(io, length(block))
        write(io, hton(xxh64(comp)))              # 8-byte big-endian checksum
        write(io, comp)
    elseif algo == Const.kZLIB
        comp = _zlib_compress(block)
        write(io, UInt8('Z'), UInt8('L'), 0x08)
        _write_3byte_le!(io, length(comp))
        _write_3byte_le!(io, length(block))
        write(io, comp)
    elseif algo == Const.kZSTD
        comp = transcode(ZstdCompressor, block)
        write(io, UInt8('Z'), UInt8('S'), 0x01)
        _write_3byte_le!(io, length(comp))
        _write_3byte_le!(io, length(block))
        write(io, comp)
    else
        error("Unsupported RNTuple write-compression algorithm code $algo " *
              "(supported: $(Const.kLZ4)=LZ4, $(Const.kZLIB)=ZLIB, $(Const.kZSTD)=ZSTD)")
    end
    return nothing
end

function _zlib_compress(block::Vector{UInt8})
    # zlib output is at most a few bytes larger than the input for incompressible data
    out = Vector{UInt8}(undef, length(block) + 64)
    n = zlib_compress!(Compressor(), out, block)
    resize!(out, n)
    return out
end

"""
    _root_compress(payload, fCompress) -> Vector{UInt8}

Compress `payload` using ROOT's block framing for the `fCompress` setting
(`algorithm*100 + level`; `0` means no compression). Returns the on-disk bytes.
As ROOT does, if compression does not shrink the data the original `payload` is
returned unchanged, so a reader detects the absence of compression by comparing
the on-disk size to the uncompressed size.
"""
function _root_compress(payload::AbstractVector{UInt8}, fCompress::Integer)
    (fCompress == 0 || isempty(payload)) && return payload
    algo = _rnt_compression_algo(fCompress)
    level = _rnt_compression_level(fCompress)
    level == 0 && return payload

    n = length(payload)
    io = IOBuffer()
    pos = 1
    while pos <= n
        stop = min(pos + _RNT_3BYTE_MAX - 1, n)
        block = payload isa Vector{UInt8} && pos == 1 && stop == n ?
                payload : collect(@view payload[pos:stop])
        _write_compressed_block!(io, algo, level, block)
        pos = stop + 1
    end
    out = take!(io)
    return length(out) < n ? out : convert(Vector{UInt8}, payload)
end
