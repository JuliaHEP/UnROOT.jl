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
    if fVersion <= 1000
        seek(io, start)
        return unpack(io, TKey32)
    end
    unpack(io, TKey64)
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

struct TList
    preamble
    name
    size
    objects
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

function unpack(io::IOStream, tkey::TKey, ::Type{TList})
    if tkey.fObjlen != tkey.fNbytes - tkey.fKeylen
        # Compressed
        seek(io, tkey.fSeekKey + tkey.fKeylen)
        compression_header = unpack(io, CompressionHeader)
        if String(compression_header.algo) != "ZL"
            error("Unsupported compression type '$(String(compression_header.algo))'")
        end

        stream = IOBuffer(read(ZlibDecompressorStream(io), tkey.fObjlen))
    else
        # Uncompressed
        stream = io
    end
    preamble = Preamble(stream)
    skiptobj(stream)

    name = readtype(stream, String)
    size = readtype(stream, Int32)
    objects = []
    for i ∈ 1:size
        push!(objects, i)
    end

    @warn "Skipping streamer parsing as it is not implemented yet."
    read(stream)

    endcheck(stream, preamble)
    TList(preamble, name, size, objects)
end
