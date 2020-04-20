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

iscompressed(t::TKey) = t.fObjlen != t.fNbytes - t.fKeylen
origin(t::TKey) = iscompressed(t) ? -t.fKeylen : t.fSeekKey
seekstart(io, t::TKey) = seek(io, t.fSeekKey + t.fKeylen)

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

struct TStreamerInfo
    fName
    fTitle
    fCheckSum
    fClassVersion
    fElements
end

function nametitle(io)
    preamble = Preamble(io)
    skiptobj(io)
    name = readtype(io, String)
    title = readtype(io, String)
    endcheck(io, preamble)
    name, title
end

function unpack(io, tkey::TKey, ::Type{TStreamerInfo})
    preamble = Preamble(io)
    fName, fTitle = nametitle(io)
    fCheckSum = readtype(io, UInt32)
    fClassVersion = readtype(io, Int32)
    @show fName, fTitle, fCheckSum, fClassVersion
    fElements = readobjany(io, tkey)
    endcheck(io, preamble)
    TStreamerInfo(fName, fTitle, fCheckSum, fClassVersion, fElements)
end

struct TObjArray
    name
    low
    elements
end

function unpack(io, tkey::TKey, ::Type{TObjArray})
    println("          TObjArray")
    @show position(io)
    preamble = Preamble(io)
    skiptobj(io)
    name = readtype(io, String)
    size = readtype(io, Int32)
    low = readtype(io, Int32)
    @show name size low
    @show position(io)
    elements = [readobjany(io, tkey) for i in 1:size]
    endcheck(io, preamble)
    return TObjArray(name, low, elements)
end

struct TStreamerElement
    version
    fOffset
    fName
    fTitle
    fType
    fSize
    fArrayLength
    fArrayDim
    fMaxIndex
    fTypeName
    fXmin
    fXmax
    fFactor
end

function unpack(io, tkey::TKey, ::Type{TStreamerElement})
    preamble = Preamble(io)
    fOffset = 0
    fName, fTitle = nametitle(io)
    fType = readtype(io, Int32)
    fSize = readtype(io, Int32)
    fArrayLength = readtype(io, Int32)
    fArrayDim = readtype(io, Int32)

    n = preamble.version == 1 ? readtype(io, Int32) : 5
    fMaxIndex = [readtype(io, Int32) for _ in 1:n]

    fTypeName = readtype(io, String)

    if fType == 11 && (fTypename == "Bool_t" || fTypename == "bool")
        fType = 18
    end

    fXmin = 0.0
    fXmax = 0.0
    fFactor = 0.0

    if preamble.version == 3
        fXmin = readtype(io, Float64)
        fXmax = readtype(io, Float64)
        fFactor = readtype(io, Float64)
    end

    endcheck(io, preamble)

    TStreamerElement(
        preamble.version,
        fOffset,
        fName,
        fTitle,
        fType,
        fSize,
        fArrayLength,
        fArrayDim,
        fMaxIndex,
        fTypeName,
        fXmin,
        fXmax,
        fFactor
    )
end


mutable struct TStreamerBase
    version
    fOffset
    fName
    fTitle
    fType
    fSize
    fArrayLength
    fArrayDim
    fMaxIndex
    fTypeName
    fXmin
    fXmax
    fFactor
    fBaseVersion
end


function unpack(io, tkey::TKey, ::Type{TStreamerBase})
    preamble = Preamble(io)
    sb = unpack(io, tkey, TStreamerElement)
    obj = TStreamerBase(sb.version, sb.fOffset, sb.fName, sb.fTitle, sb.fType, sb.fSize, sb.fArrayLength,
                        sb.fArrayDim, sb.fMaxIndex, sb.fTypeName, sb.fXmin, sb.fXmax, sb.fFactor,
                        0)
    if obj.version >= 2
        obj.fBaseVersion = readtype(io, Int32)
    end
    endcheck(io, preamble)
    obj
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

struct TList
    preamble
    name
    size
    objects
end


function unpack(io::IOStream, tkey::TKey, ::Type{TList})
    if iscompressed(tkey)
        seekstart(io, tkey)
        compression_header = unpack(io, CompressionHeader)
        if String(compression_header.algo) != "ZL"
            error("Unsupported compression type '$(String(compression_header.algo))'")
        end

        stream = IOBuffer(read(ZlibDecompressorStream(io), tkey.fObjlen))
    else
        stream = io
    end
    preamble = Preamble(stream)
    skiptobj(stream)

    name = readtype(stream, String)
    size = readtype(stream, Int32)
    @show size
    @show origin(tkey)
    objects = []
    for i ∈ 1:size
        push!(objects, readobjany(stream, tkey))
    end

    @warn "Skipping streamer parsing as it is not implemented yet."
    # read(stream)

    endcheck(stream, preamble)
    TList(preamble, name, size, objects)
end


function readobjany(io, tkey::TKey)
    println("====== Reading objany")
    @show position(io)
    beg = position(io) - origin(tkey)
    @show beg
    bcnt = readtype(io, UInt32)
    if Int64(bcnt) & Const.kByteCountMask == 0 || Int64(bcnt) == Const.kNewClassTag
        println("New class or 0 bytes")
        version = 0
        start = 0
        tag = bcnt
        bcnt = 0
    else
        version = 1
        start = position(io) - origin(tkey)
        tag = readtype(io, UInt32)
    end
    @show Int64(bcnt) version start Int64(tag)

    if Int64(tag) & Const.kClassMask == 0
        if tag == 0
            return missing
        elseif tag == 1
            error("Returning parent is not implemented yet")
        else
            # skipping
            seek(io, origin(tkey) + beg + bcnt + 4)
        end
    elseif tag == Const.kNewClassTag
        cname = readtype(io, CString)
        @show cname
        streamer = getfield(@__MODULE__, Symbol(cname))

        # here need a reference to the corresponding streamer class
        # if version > 0
        #     ref = start + Const.kMapOffset
        # else
        #     ref = NUMBER_OF_REFS + 1
        # end
        # println("ref $(start + Const.kMapOffset) needs to be parsed as '$cname'")

        obj = unpack(io, tkey, streamer)

        return obj
    else
        error("Reference class not implemented yet.")
    end
    println("-----")
end
