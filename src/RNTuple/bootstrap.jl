# https://github.com/root-project/root/blob/e9fa243af91217e9b108d828009c81ccba7666b5/tree/ntuple/v7/inc/ROOT/RMiniFile.hxx#L65
@with_kw struct ROOT_3a3a_Experimental_3a3a_RNTuple <: ROOTStreamedObject
    fCheckSum::Int32
    fVersion::UInt32
    fSize::UInt32
    fSeekHeader::UInt64
    fNBytesHeader::UInt32
    fLenHeader::UInt32
    fSeekFooter::UInt64
    fNBytesFooter::UInt32
    fLenFooter::UInt32
    fReserved::UInt64
end

function decompress_bytes(compbytes, NTarget)
    # not compressed
    length(compbytes) >= NTarget && return compbytes

    # compressed
    io = IOBuffer(compbytes)
    fufilled = 0
    uncomp_data = Vector{UInt8}(undef, NTarget)
    while fufilled < NTarget # careful with 0/1-based index when thinking about offsets
        compression_header = unpack(io, CompressionHeader)
        cname, _, compbytes, uncompbytes = unpack(compression_header)
        rawbytes = read(io, compbytes)
        if cname == "L4"
            # skip checksum which is 8 bytes
            # original: lz4_decompress(rawbytes[9:end], uncompbytes)
            input = @view rawbytes[9:end]
            input_ptr = pointer(input)
            input_size = length(input)
            output_ptr = pointer(uncomp_data) + fufilled
            output_size = uncompbytes
            _decompress_lz4!(input_ptr, input_size, output_ptr, output_size)
        elseif cname == "ZL"
            output = @view(uncomp_data[fufilled+1:fufilled+uncompbytes])
            zlib_decompress!(Decompressor(), output, rawbytes, uncompbytes)
        elseif cname == "XZ"
            @view(uncomp_data[fufilled+1:fufilled+uncompbytes]) .= transcode(XzDecompressor, rawbytes)
        elseif cname == "ZS"
            @view(uncomp_data[fufilled+1:fufilled+uncompbytes]) .= transcode(ZstdDecompressor, rawbytes)
        else
            error("Unsupported compression type '$(String(compression_header.algo))'")
        end

        fufilled += uncompbytes
    end
    return uncomp_data
end

#fall back
_rntuple_read(io, T) = read(io, T)

function _rntuple_read(io, ::Type{String})
    len = read(io, UInt32)
    String(read(io, len))
end


@with_kw struct RNTupleEnvelope{T}
    version::UInt16
    min_version::UInt16
    payload::T
    crc32::UInt32
end
function _rntuple_read(io, ::Type{RNTupleEnvelope{T}}) where T
    bytes = read(io)
    seek(io, 0)
    version, min_version = (read(io, UInt16) for _=1:2)
    payload = _rntuple_read(io, T)
    _crc32 = crc32(@view bytes[begin:end-4]) 
    @assert _crc32 == reinterpret(UInt32, @view bytes[end-3:end])[1]
    return RNTupleEnvelope(;version, min_version, payload, crc32 = _crc32)
end

struct RNTupleFrame{T} end
function _rntuple_read(io, ::Type{RNTupleFrame{T}}) where T
    pos = position(io)
    Size = read(io, UInt32)
    end_pos = pos + Size
    @assert Size >= 0
    res = _rntuple_read(io, T)
    seek(io, end_pos)
    return res
end

struct RNTupleListFrame{T} end
function _rntuple_read(io, ::Type{RNTupleListFrame{T}}) where T
    pos = position(io)
    Size, NumItems = (read(io, Int32) for _=1:2)
    @assert Size < 0
    end_pos = pos - Size
    res = [_rntuple_read(io, RNTupleFrame{T}) for _=1:NumItems]
    seek(io, end_pos)
    return res
end

# without the inner Frame for each item
struct RNTupleListNoFrame{T} end
function _rntuple_read(io, ::Type{RNTupleListNoFrame{T}}) where T
    pos = position(io)
    Size, NumItems = (read(io, Int32) for _=1:2)
    @assert Size < 0
    end_pos = pos - Size
    res = [_rntuple_read(io, T) for _=1:NumItems]
    seek(io, end_pos)
    return res
end
