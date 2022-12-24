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

function _rntuple_read(io, ::Type{String})
    len = read(io, UInt32)
    String(read(io, len))
end


struct RNTupleEnvelope{T} end
function _rntuple_read(io, ::Type{RNTupleEnvelope{T}}) where T
    bytes = read(io)
    seek(io, 0)
    Version, MinVersion = (read(io, UInt16) for _=1:2)
    Payload = _rntuple_read(io, T)

    @assert crc32(@view bytes[begin:end-4]) == reinterpret(UInt32, last(bytes, 4))[1]
    return Payload
end

struct RNTupleFrame{T} end
function _rntuple_read(io, ::Type{RNTupleFrame{T}}) where T
    Size = read(io, UInt32)
    @assert Size >= 0
    return _rntuple_read(io, T)
end

struct RNTupleListFrame{T} end
function _rntuple_read(io, ::Type{RNTupleListFrame{T}}) where T
    Size, NumItems = (read(io, Int32) for _=1:2)
    @assert Size < 0
    return [_rntuple_read(io, RNTupleFrame{T}) for _=1:NumItems]
end

@with_kw struct FieldRecord
    FieldVersion::UInt32
    TypeVersion::UInt32
    ParentFieldID::UInt32
    StructralRole::UInt16
    Flags::UInt16
    FieldName::String
    TypeName::String
    TypeAlias::String
    Description::String
end
function _rntuple_read(io, ::Type{FieldRecord})
    FieldVersion = read(io, UInt32)
    TypeVersion = read(io, UInt32)
    ParentFieldID = read(io, UInt32)
    StructralRole = read(io, UInt16)
    Flags = read(io, UInt16)
    FieldName, TypeName, TypeAlias, Description = (_rntuple_read(io, String) for _=1:4)
    FieldRecord(; FieldVersion, TypeVersion, ParentFieldID, StructralRole, Flags, FieldName, TypeName, TypeAlias, Description)
end

@with_kw struct ColumnRecord
    Type::UInt16
    Nbits::UInt16
    FieldID::UInt32
    Flags::UInt32
end
function _rntuple_read(io, ::Type{ColumnRecord})
    Type = read(io, UInt16)
    Nbits = read(io, UInt16)
    FieldID = read(io, UInt32)
    Flags = read(io, UInt32)
    ColumnRecord(; Type, Nbits, FieldID, Flags)
end

@with_kw struct RNTupleHeader
    FeatureFlag::UInt64
    RC_tag::UInt32
    Name::String
    Description::String
    Writer::String
    FieldRecords::Vector{FieldRecord}
    ColumnRecords::Vector{ColumnRecord}
    # AliasColumns::
    # ExtraTypeInfos::
end
function _rntuple_read(io, ::Type{RNTupleHeader})
    FeatureFlag = read(io, UInt64)
    RC_tag = read(io, UInt32)
    Name, Description, Writer = (_rntuple_read(io, String) for _=1:3)
    FieldRecords = _rntuple_read(io, RNTupleListFrame{FieldRecord})
    ColumnRecords = _rntuple_read(io, RNTupleListFrame{ColumnRecord})
    RNTupleHeader(; FeatureFlag, RC_tag, Name, Description, Writer, FieldRecords, ColumnRecords)
end

function RNTupleHeader(io, anchor::ROOT_3a3a_Experimental_3a3a_RNTuple)
    header_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekHeader, anchor.fNBytesHeader), anchor.fLenHeader)
    _io = IOBuffer(header_bytes)
    _rntuple_read(_io, RNTupleEnvelope{RNTupleHeader})
end

@with_kw struct ClusterSummary
    NumFirstEntry::UInt64
    NumEntries::UInt64
end

@with_kw struct ClusterGroup
    NumClusters::UInt32
end

