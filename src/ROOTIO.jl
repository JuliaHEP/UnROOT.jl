module ROOTIO

export ROOTFile

import Base: keys
using StaticArrays

include("io.jl")

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


struct ROOTFile
    format_version::Int32
    header::FileHeader
    fobj::IOStream
end


function ROOTFile(filename::AbstractString)
    fobj = Base.open(filename)
    preamble = unpack(fobj, FilePreamble)
    String(preamble.identifier) == "root" || error("Not a ROOT file!")
    format_version = preamble.fVersion

    if format_version < 1000000
        header = unpack(fobj, FileHeader32)
    else
        header = unpack(fobj, FileHeader64)
    end
    ROOTFile(format_version, header, fobj)
end


@io struct TKey32
    fNBytes::Int32
    fVersion::Int16
    fObjLen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey::Int32
    fSeekPdir::Int32
    fClassName::ROOTString
    fName::ROOTString
    fTitle::ROOTString
end

@io struct TKey64
    fNBytes::Int32
    fVersion::Int16
    fObjLen::Int32
    fDatime::UInt32
    fKeylen::Int16
    fCycle::Int16
    fSeekKey::Int64
    fSeekPdir::Int64
    fClassName::ROOTString
    fName::ROOTString
    fTitle::ROOTString
end

const TKey = Union{TKey32, TKey64}

function Base.keys(f::ROOTFile)
    # f.header.fSeekInfo -> TKey for streamers
    tkeys = Vector{TKey}()

    cursor = f.header.fBEGIN
    while true
        seek(f.fobj, cursor)
        tkey = unpack(f.fobj, TKey32)
        if tkey.fVersion > 1000
            seek(f.fobj, f.header.fBEGIN)
            tkey = unpack(f.fobj, TKey64)
        end
        push!(tkeys, tkey)

        cursor += tkey.fNBytes
    end

    tkeys
end

end # module
