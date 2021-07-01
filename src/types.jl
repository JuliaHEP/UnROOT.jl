@io struct TKey32
    fNbytes::Int32
    fVersion::Int16
    fObjlen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey::Int32
    fSeekPdir::Int32
    fClassName::String
    fName::String
    fTitle::String
end

@io struct TKey64
    fNbytes::Int32
    fVersion::Int16
    fObjlen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey::Int64
    fSeekPdir::Int64
    fClassName::String
    fName::String
    fTitle::String
end

const TKey = Union{TKey32, TKey64}

function unpack(io, ::Type{TKey})
    start = position(io)
    skip(io, 4)
    fVersion = readtype(io, Int16)
    seek(io, start)
    if fVersion <= 1000
        return unpack(io, TKey32)
    end
    unpack(io, TKey64)
end

@with_kw struct TBasketKey
    fNbytes::Int32
    fVersion
    fObjlen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey
    fSeekPdir
    fClassName::String
    fName::String
    fTitle::String
    fBufferSize::Int32
    fNevBufSize::Int32
    fNevBuf::Int32
    fLast::Int32
end

function unpack(io, T::Type{TBasketKey})
    start = position(io)
    fields = Dict{Symbol, Any}()
    fields[:fNbytes] = readtype(io, Int32)
    fields[:fVersion] = readtype(io, Int16)  # FIXME if "complete" it's UInt16 (acc. uproot)

    inttype = fields[:fVersion] <= 1000 ? Int32 : Int64

    fields[:fObjlen] = readtype(io, Int32)
    fields[:fDatime] = readtype(io, UInt32)
    fields[:fKeylen] = readtype(io, Int16)
    fields[:fCycle] = readtype(io, Int16)
    fields[:fSeekKey] = readtype(io, inttype)
    fields[:fSeekPdir] = readtype(io, inttype)
    fields[:fClassName] = readtype(io, String)
    fields[:fName] = readtype(io, String)
    fields[:fTitle] = readtype(io, String)

    # if complete (which is true for compressed, it seems?)
    seek(io, start + fields[:fKeylen] - 18 - 1)
    fields[:fVersion] = readtype(io, Int16)  # FIXME if "complete" it's UInt16 (acc. uproot)
    fields[:fBufferSize] = readtype(io, Int32)
    fields[:fNevBufSize] = readtype(io, Int32)
    fields[:fNevBuf] = readtype(io, Int32)
    fields[:fLast] = readtype(io, Int32)

    T(; fields...)
end

iscompressed(t::T) where T<:Union{TKey, TBasketKey} = t.fObjlen != t.fNbytes - t.fKeylen
origin(t::T) where T<:Union{TKey, TBasketKey} = iscompressed(t) ? -t.fKeylen : t.fSeekKey
seekstart(io, t::T) where T<:Union{TKey, TBasketKey} = seek(io, t.fSeekKey + t.fKeylen)

function datastream(io, tkey::T) where T<:Union{TKey, TBasketKey}
    start = position(io)
    if !iscompressed(tkey)
        @debug ("Uncompressed datastream of $(tkey.fObjlen) bytes " *
                "at $start (TKey '$(tkey.fName)' ($(tkey.fClassName)))")
        skip(io, 1)   # ???
        return io
    end
    @debug "Compressed stream at $(start)"
    seekstart(io, tkey)
    compression_header = unpack(io, CompressionHeader)
    skipped = 0 #FIXME How to compute this here?
    io_buf = IOBuffer(read(io, tkey.fNbytes - skipped))
    if String(compression_header.algo) == "ZL"
        return IOBuffer(read(ZlibDecompressorStream(io_buf), tkey.fObjlen))
    elseif String(compression_header.algo) == "XZ"
        #FIXME doesn't work, why
        return IOBuffer(read(XzDecompressorStream(io_buf), tkey.fObjlen))
    elseif String(compression_header.algo) == "L4"
        #FIXME doesn't work
        skip(io_buf, 8) #skip checksum
        stream = IOBuffer(lz4_decompress(read(io_buf), tkey.fObjlen))
    else
        error("Unsupported compression type '$(String(compression_header.algo))'")
    end

end


@io struct FilePreamble
    identifier::SVector{4, UInt8}  # Root file identifier ("root")
    fVersion::Int32                # File format version
end

@io struct FileHeader32
    fBEGIN::Int32                  # Pointer to first data record
    fEND::UInt32                   # Pointer to first free word at the EOF
    fSeekFree::UInt32              # Pointer to FREE data record
    fNbytesFree::Int32             # Number of bytes in FREE data record
    nfree::Int32                   # Number of free data records
    fNbytesName::Int32             # Number of bytes in TNamed at creation time
    fUnits::UInt8                  # Number of bytes for file pointers
    fCompress::Int32               # Compression level and algorithm
    fSeekInfo::UInt32              # Pointer to TStreamerInfo record
    fNbytesInfo::Int32             # Number of bytes in TStreamerInfo record
    fUUID::SVector{18, UInt8}      # Universal Unique ID
end


@io struct FileHeader64
    fBEGIN::Int32                  # Pointer to first data record
    fEND::UInt64                   # Pointer to first free word at the EOF
    fSeekFree::UInt64              # Pointer to FREE data record
    fNbytesFree::Int32             # Number of bytes in FREE data record
    nfree::Int32                   # Number of free data records
    fNbytesName::Int32             # Number of bytes in TNamed at creation time
    fUnits::UInt8                  # Number of bytes for file pointers
    fCompress::Int32               # Compression level and algorithm
    fSeekInfo::UInt64              # Pointer to TStreamerInfo record
    fNbytesInfo::Int32             # Number of bytes in TStreamerInfo record
    fUUID::SVector{18, UInt8}      # Universal Unique ID
end

const FileHeader = Union{FileHeader32, FileHeader64}


@io struct ROOTDirectoryHeader32
    fVersion::Int16
    fDatimeC::UInt32
    fDatimeM::UInt32
    fNbytesKeys::Int32
    fNbytesName::Int32
    fSeekDir::Int32
    fSeekParent::Int32
    fSeekKeys::Int32
end

@io struct ROOTDirectoryHeader64
    fVersion::Int16
    fDatimeC::UInt32
    fDatimeM::UInt32
    fNbytesKeys::Int32
    fNbytesName::Int32
    fSeekDir::Int64
    fSeekParent::Int64
    fSeekKeys::Int64
end

const ROOTDirectoryHeader = Union{ROOTDirectoryHeader32, ROOTDirectoryHeader64}

function unpack(io::IOStream, ::Type{ROOTDirectoryHeader})
    fVersion = readtype(io, Int16)
    skip(io, -2)

    if fVersion <= 1000
        return unpack(io, ROOTDirectoryHeader32)
    else
        return unpack(io, ROOTDirectoryHeader64)
    end

end


@io struct CompressionHeader
    algo::SVector{2, UInt8}
    method::UInt8
    c1::UInt8
    c2::UInt8
    c3::UInt8
    u1::UInt8
    u2::UInt8
    u3::UInt8
end


# Built-in types
function THashList end
function TRef end
function TArray end
function TArrayC end
function TArrayS end
function TArrayL end
function TArrayL64 end
function TArrayF end
function TRefArray end

function aliasfor(classname)
    if classname == "ROOT::TIOFeatures"
        return ROOT_3a3a_TIOFeatures
    else
        nothing
    end
end
