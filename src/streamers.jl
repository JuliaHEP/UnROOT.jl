function read_streamers(io, tkey::TKey)
    refs = Dict{Int32, Any}()

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
    objects = []
    for i ∈ 1:size
        push!(objects, readobjany!(stream, tkey, refs))
        skip(stream, readtype(stream, UInt8))
    end

    endcheck(stream, preamble)
    Streamers(refs, TList(preamble, name, size, objects))
end

function readobjany!(io, tkey::TKey, refs)
    beg = position(io) - origin(tkey)
    bcnt = readtype(io, UInt32)
    if Int64(bcnt) & Const.kByteCountMask == 0 || Int64(bcnt) == Const.kNewClassTag
        error("New class or 0 bytes")
        version = 0
        start = 0
        tag = bcnt
        bcnt = 0
    else
        version = 1
        start = position(io) - origin(tkey)
        tag = readtype(io, UInt32)
    end

    if Int64(tag) & Const.kClassMask == 0
        # reference object
        if tag == 0
            return missing
        elseif tag == 1
            error("Returning parent is not implemented yet")
        elseif !haskey(refs, tag)
            # skipping
            seek(io, origin(tkey) + beg + bcnt + 4)
            return missing
        else
            return refs[tag]
        end

    elseif tag == Const.kNewClassTag
        cname = readtype(io, CString)
        streamer = getfield(@__MODULE__, Symbol(cname))

        if version > 0
            refs[start + Const.kMapOffset] = streamer
        else
            refs[length(refs) + 1] = streamer
        end

        obj = unpack(io, tkey, refs, streamer)

        if version > 0
            refs[beg + Const.kMapOffset] = obj
        else
            refs[length(refs) + 1] = obj
        end

        return obj
    else
        # reference class, new object
        ref = Int64(tag) & ~Const.kClassMask
        haskey(refs, ref) || error("Invalid class reference.")

        streamer = refs[ref]
        obj = unpack(io, tkey, refs, streamer)

        if version > 0
            refs[beg + Const.kMapOffset] = obj
        else
            refs[length(refs) + 1] = obj
        end

        return obj
    end
end

struct TStreamerInfo
    fName
    fTitle
    fCheckSum
    fClassVersion
    fElements
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{TStreamerInfo})
    preamble = Preamble(io)
    fName, fTitle = nametitle(io)
    fCheckSum = readtype(io, UInt32)
    fClassVersion = readtype(io, Int32)
    fElements = readobjany!(io, tkey, refs)
    endcheck(io, preamble)
    TStreamerInfo(fName, fTitle, fCheckSum, fClassVersion, fElements)
end

struct TList
    preamble
    name
    size
    objects
end

Base.length(l::TList) = length(l.objects)


function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{TList})
    preamble = Preamble(io)
    skiptobj(io)

    name = readtype(io, String)
    size = readtype(io, Int32)
    objects = []
    for i ∈ 1:size
        push!(objects, readobjany!(io, tkey, refs))
        skip(io, readtype(io, UInt8))
    end

    endcheck(io, preamble)
    TList(preamble, name, size, objects)
end

struct Streamers
    refs::Dict{Int32, Any}
    streamers::TList
end


struct TObjArray
    name
    low
    elements
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{TObjArray})
    preamble = Preamble(io)
    skiptobj(io)
    name = readtype(io, String)
    size = readtype(io, Int32)
    low = readtype(io, Int32)
    elements = [readobjany!(io, tkey, refs) for i in 1:size]
    endcheck(io, preamble)
    return TObjArray(name, low, elements)
end

mutable struct TStreamerElement
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

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{TStreamerElement})
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

    if fType == 11 && (fTypeName == "Bool_t" || fTypeName == "bool")
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


function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{TStreamerBase})
    preamble = Preamble(io)
    sb = unpack(io, tkey, refs, TStreamerElement)
    obj = TStreamerBase(sb.version, sb.fOffset, sb.fName, sb.fTitle, sb.fType, sb.fSize, sb.fArrayLength,
                        sb.fArrayDim, sb.fMaxIndex, sb.fTypeName, sb.fXmin, sb.fXmax, sb.fFactor,
                        0)
    if obj.version >= 2
        obj.fBaseVersion = readtype(io, Int32)
    end
    endcheck(io, preamble)
    obj
end


struct TStreamerBasicType
    element::TStreamerElement
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerBasicType})
    preamble = Preamble(io)
    element = unpack(io, tkey, refs, TStreamerElement)
    if Const.kOffsetL < element.fType < Const.kOffsetP
        element.fType -= Const.kOffsetP
    end
    basic = true
    if element.fType ∈ (Const.kBool, Const.kUChar, Const.kChar)
        element.fSize = 1
    elseif element.fType in (Const.kUShort, Const.kShort)
        element.fSize = 2
    elseif element.fType in (Const.kBits, Const.kUInt, Const.kInt, Const.kCounter)
        element.fSize = 4
    elseif element.fType in (Const.kULong, Const.kULong64, Const.kLong, Const.kLong64)
        element.fSize = 8
    elseif element.fType in (Const.kFloat, Const.kFloat16)
        element.fSize = 4
    elseif element.fType in (Const.kDouble, Const.kDouble32)
        element.fSize = 8
    elseif element.fType == Const.kCharStar
        element.fSize = sizeof(Int)
    else
        basic = false
    end

    if basic && element.fArrayLength > 0
        element.fSize *= element.fArrayLength
    end

    endcheck(io, preamble)
    T(element)
end


struct TStreamerBasicPointer
    element::TStreamerElement
    fCountVersion
    fCountName
    fCountClass
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerBasicPointer})
    preamble = Preamble(io)
    element = unpack(io, tkey, refs, TStreamerElement)
    fCountVersion = readtype(io, Int32)
    fCountName = readtype(io, String)
    fCountClass = readtype(io, String)
    endcheck(io, preamble)
    T(element, fCountVersion, fCountName, fCountClass)
end

struct TStreamerLoop
    element::TStreamerElement
    fCountVersion
    fCountName
    fCountClass
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerLoop})
    preamble = Preamble(io)
    element = unpack(io, tkey, refs, TStreamerElement)
    fCountVersion = readtype(io, Int32)
    fCountName = readtype(io, String)
    fCountClass = readtype(io, String)
    endcheck(io, preamble)
    T(element, fCountVersion, fCountName, fCountClass)
end


struct TStreamerSTL
    element::TStreamerElement
    fSTLType
    fCtype
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerSTL})
    preamble = Preamble(io)
    element = unpack(io, tkey, refs, TStreamerElement)

    fSTLtype = readtype(io, Int32)
    fCtype = readtype(io, Int32)

    if fSTLtype == Const.kSTLmultimap || fSTLtype == Const.kSTLset
        if startswith(element.fTypeName, "std::set") || startswith(element.fTypeName, "set")
            fSTLtype = Const.kSTLset
        elseif startswith(element.fTypeName, "std::multimap") || startswith(element.fTypeName, "multimap")
            fSTLtype = Const.kSTLmultimap
        end
    end

    endcheck(io, preamble)
    T(element, fSTLtype, fCtype)
end


struct TStreamerSTLstring
    element::TStreamerSTL
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerSTLstring})
    preamble = Preamble(io)
    element = unpack(io, tkey, refs, TStreamerSTL)
    endcheck(io, preamble)
    T(element)
end




const TObjString = String

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TObjString})
    preamble = Preamble(io)
    skiptobj(io)
    value = readtype(io, String)
    endcheck(io, preamble)
    T(value)
end


abstract type AbstractTStreamerObject end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{T}) where T<:AbstractTStreamerObject
    preamble = Preamble(io)
    element = unpack(io, tkey, refs, TStreamerElement)
    endcheck(io, preamble)
    T(element)
end

struct TStreamerObject <: AbstractTStreamerObject
    element::TStreamerElement
end

struct TStreamerObjectAny <: AbstractTStreamerObject
    element::TStreamerElement
end

struct TStreamerObjectAnyPointer <: AbstractTStreamerObject
    element::TStreamerElement
end

struct TStreamerObjectPointer <: AbstractTStreamerObject
    element::TStreamerElement
end

struct TStreamerString <: AbstractTStreamerObject
    element::TStreamerElement
end



function TTree(tkey::TKey)
end
