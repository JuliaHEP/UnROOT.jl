# https://github.com/root-project/root/blob/a4deb370c9b9870f0391036890981f648559ef68/tree/ntuple/v7/inc/ROOT/RNTupleAnchor.hxx#L69
Base.@kwdef struct ROOT_3a3a_Experimental_3a3a_RNTuple <: ROOTStreamedObject
    fVersionEpoch::UInt16
    fVersionMajor::UInt16
    fVersionMinor::UInt16
    fVersionPatch::UInt16
    fSeekHeader::UInt64
    fNBytesHeader::UInt64
    fLenHeader::UInt64
    fSeekFooter::UInt64
    fNBytesFooter::UInt64
    fLenFooter::UInt64
    fChecksum::UInt64
end

function ROOT_3a3a_Experimental_3a3a_RNTuple(io, tkey::TKey, refs)
    local_io = datastream(io, tkey)
    skip(local_io, 6)
    _before_anchor = position(local_io)
    anchor_checksum = xxh3_64(read(local_io, 2*4 + 6*8))
    seek(local_io, _before_anchor)
    anchor = ROOT_3a3a_Experimental_3a3a_RNTuple(;
                    fVersionEpoch = readtype(local_io, UInt16),
                    fVersionMajor = readtype(local_io, UInt16),
                    fVersionMinor = readtype(local_io, UInt16),
                    fVersionPatch = readtype(local_io, UInt16),
                    fSeekHeader = readtype(local_io, UInt64),
                    fNBytesHeader = readtype(local_io, UInt64),
                    fLenHeader = readtype(local_io, UInt64),
                    fSeekFooter = readtype(local_io, UInt64),
                    fNBytesFooter = readtype(local_io, UInt64),
                    fLenFooter = readtype(local_io, UInt64),
                    fChecksum = readtype(local_io, UInt64),
                                       )

    @assert anchor.fChecksum == anchor_checksum "RNtuple anchor checksum doesn't match"


    header_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekHeader, anchor.fNBytesHeader), anchor.fLenHeader)
    header_io = IOBuffer(header_bytes)
    header = _rntuple_read(header_io, RNTupleEnvelope{RNTupleHeader})

    footer_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekFooter, anchor.fNBytesFooter), anchor.fLenFooter)
    footer_io = IOBuffer(footer_bytes)
    footer = _rntuple_read(footer_io, RNTupleEnvelope{RNTupleFooter})
    @assert header.checksum == footer.payload.header_checksum "header and footer don't go together"

    append!(header.payload.field_records, footer.payload.extension_header_links.field_records)
    append!(header.payload.column_records, footer.payload.extension_header_links.column_records)

    schema = parse_fields(header.payload)

    rnt = RNTuple(io, header.payload, footer.payload, schema)
    return rnt
end

function decompress_bytes(compbytes::Vector{UInt8}, NTarget::Integer)
    if length(compbytes) >= NTarget
        return compbytes
    else
        uncomp_data = Vector{UInt8}(undef, NTarget)
        decompress_bytes!(uncomp_data, compbytes, NTarget)
        return uncomp_data
    end
end

function decompress_bytes!(uncomp_data, compbytes, NTarget::Integer)
    resize!(uncomp_data, NTarget)
    # not compressed
    if length(compbytes) >= NTarget
        copyto!(uncomp_data, compbytes)
        return uncomp_data
    end

    # compressed
    io = IOBuffer(compbytes)
    fulfilled = 0
    while fulfilled < NTarget # careful with 0/1-based index when thinking about offsets
        compression_header = unpack(io, CompressionHeader)
        cname, _, compbytes, uncompbytes = unpack(compression_header)
        rawbytes = read(io, compbytes)
        if cname == @SVector UInt8['L', '4']
            # skip checksum which is 8 bytes
            # original: lz4_decompress(rawbytes[9:end], uncompbytes)
            input = @view rawbytes[9:end]
            input_ptr = pointer(input)
            input_size = length(input)
            output_ptr = pointer(uncomp_data) + fulfilled
            output_size = uncompbytes
            _decompress_lz4!(input_ptr, input_size, output_ptr, output_size)
        elseif cname == @SVector UInt8['Z', 'L']
            output = @view(uncomp_data[fulfilled+1:fulfilled+uncompbytes])
            zlib_decompress!(Decompressor(), output, rawbytes, uncompbytes)
        elseif cname == @SVector UInt8['X', 'Z']
            @view(uncomp_data[fulfilled+1:fulfilled+uncompbytes]) .= transcode(XzDecompressor, rawbytes)
        elseif cname == @SVector UInt8['Z', 'S']
            @view(uncomp_data[fulfilled+1:fulfilled+uncompbytes]) .= transcode(ZstdDecompressor, rawbytes)
        else
            error("Unsupported compression type '$(String(compression_header.algo))'")
        end
        fulfilled += uncompbytes
    end
    return uncomp_data
end

#fall back
_rntuple_read(io, ::Type{T}) where T = read(io, T)

function _rntuple_read(io, ::Type{String})
    len = read(io, UInt32)
    String(read(io, len))
end

"""
    macro SimpleStruct

Define reading method on the fly for `_rntuple_read`

# Example
```
julia> @SimpleStruct struct Locator
           num_bytes::Int32
           offset::UInt64
       end
```
would automatically define the following reading method:
```
function _rntuple_read(io, ::Type{Locator})
    num_bytes = _rntuple_read(io, Int32)
    offset = _rntuple_read(io, UInt64)
    Locator(num_bytes, offset)
end
```

Notice `_rntuple_read` falls back to `read` for all types that are not defined by us.
"""
macro SimpleStruct(ex)
    _ex = deepcopy(ex)
    Base.remove_linenums!(ex)
    T = ex.args[2]
    field_exprs = ex.args[3].args
    field_types = [e.args[2] for e in field_exprs]
    _body_read = [
                  Expr(:call, :_rntuple_read, :io, x)
                  for x in field_types
                 ]
    body = Expr(:call, T, _body_read...)

    _read_def = quote
        function _rntuple_read(io, ::Type{$T})
           $body
        end
    end
    esc(Expr(:block, _ex, _read_def))
end

struct RNTupleEnvelope{T}
    type_id::UInt16
    envelope_length::UInt64
    payload::T
    checksum::UInt64
end
function _rntuple_read(io, ::Type{RNTupleEnvelope{T}}) where T
    bytes = read(io)
    seek(io, 0)
    id_length = read(io, UInt64)
    # 16/48 split
    type_id = UInt16(0xffff & id_length)
    payload_length = id_length >> 16
    payload = _rntuple_read(io, T)
    _checksum = xxh3_64(bytes[begin:end-8])
    @assert _checksum == reinterpret(UInt64, @view bytes[end-7:end])[1] "Envelope checksum doesn't match"
    return RNTupleEnvelope(type_id, payload_length, payload, _checksum)
end

struct RNTupleFrame{T}
    payload::T
end
function _rntuple_read(io, ::Type{RNTupleFrame{T}}) where T
    pos = position(io)
    Size = read(io, Int64)
    end_pos = pos + Size
    @assert Size >= 0
    res = _rntuple_read(io, T)
    seek(io, end_pos)
    return RNTupleFrame(res)
end

# const RNTupleListFrame{T} = Vector{T}
function _rntuple_read(io, ::Type{Vector{T}}) where T
    pos = position(io)
    Size = read(io, Int64)
    @assert Size < 0
    NumItems = read(io, Int32)
    end_pos = pos - Size
    res = T[_rntuple_read(io, RNTupleFrame{T}).payload for _=1:NumItems]
    seek(io, end_pos)
    return res
end
