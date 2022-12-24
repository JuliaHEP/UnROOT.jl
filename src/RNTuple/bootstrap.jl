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

function ROOT_3a3a_Experimental_3a3a_RNTuple(io, tkey::TKey, refs)
    io = datastream(io, tkey)
    skip(io, 6)
    ROOT_3a3a_Experimental_3a3a_RNTuple(
                    fCheckSum = readtype(io, Int32),
                    fVersion = readtype(io, UInt32),
                    fSize = readtype(io, UInt32),
                    fSeekHeader = readtype(io, UInt64),
                    fNBytesHeader = readtype(io, UInt32),
                    fLenHeader = readtype(io, UInt32),
                    fSeekFooter = readtype(io, UInt64),
                    fNBytesFooter = readtype(io, UInt32),
                    fLenFooter = readtype(io, UInt32),
                    fReserved = readtype(io, UInt64),
                                       )
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

abstract type RNTupleFramed end
abstract type RNTupleEnveloped end

# struct RNTUpleEnvelope
#     Version::UInt16
#     MinVersion::UInt16
#     CRC32::UInt32
# end

function _read_rntuple_string(io)
    len = read(io, UInt32)
    String(read(io, len))
end

@with_kw struct RNTupleHeader <: RNTupleEnveloped
    FeatureFlag::UInt64
    RC_tag::UInt32
    Name::String
    Description::String
    Writer::String
    # FieldRecords::
    # ColumnRecords::
    # AliasColumns::
    # ExtraTypeInfos::
end

function _read_envelope(io)
    Version, MinVersion = (read(io, UInt16) for _=1:2)
    Version, MinVersion
end

function RNTupleHeader(io, anchor::ROOT_3a3a_Experimental_3a3a_RNTuple)
    header_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekHeader, anchor.fNBytesHeader), anchor.fLenHeader)
    _io = IOBuffer(header_bytes)
    Version, MinVersion = _read_envelope(_io)
    FeatureFlag = read(_io, UInt64)
    RC_tag = read(_io, UInt32)
    Name, Description, Writer = (_read_rntuple_string(_io) for _=1:3)
    RNTupleHeader(; FeatureFlag, RC_tag, Name, Description, Writer)

end


@with_kw struct FieldDescription
    FieldVersion::UInt32
    TypeVersion::UInt32
    ParentFieldID::UInt32
    StructralRole::UInt16
    Flags::UInt16
end


@with_kw struct ColumnDescription
    Type::UInt16
    Nbits::UInt16
    FieldID::UInt32
    Flags::UInt32
end

@with_kw struct ClusterSummary
    NumFirstEntry::UInt64
    NumEntries::UInt64
end

@with_kw struct ClusterGroup
    NumClusters::UInt32
end

