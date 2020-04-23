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

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerInfo})
    preamble = Preamble(io)
    fName, fTitle = nametitle(io)
    fCheckSum = readtype(io, UInt32)
    fClassVersion = readtype(io, Int32)
    fElements = readobjany!(io, tkey, refs)
    endcheck(io, preamble)
    T(fName, fTitle, fCheckSum, fClassVersion, fElements)
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


abstract type AbstractTStreamerElement end

@premix @with_kw mutable struct TStreamerElementTemplate
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

@TStreamerElementTemplate mutable struct TStreamerElement end

@pour initparse begin
    fields = Dict{Symbol, Any}()
end

function parsefields!(io, fields, ::Type{TStreamerElement})
    preamble = Preamble(io)
    fields[:version] = preamble.version
    fields[:fOffset] = 0
    fields[:fName], fields[:fTitle] = nametitle(io)
    fields[:fType] = readtype(io, Int32)
    fields[:fSize] = readtype(io, Int32)
    fields[:fArrayLength] = readtype(io, Int32)
    fields[:fArrayDim] = readtype(io, Int32)

    n = preamble.version == 1 ? readtype(io, Int32) : 5
    fields[:fMaxIndex] = [readtype(io, Int32) for _ in 1:n]

    fields[:fTypeName] = readtype(io, String)

    if fields[:fType] == 11 && (fields[:fTypeName] == "Bool_t" || fields[:fTypeName] == "bool")
        fields[:fType] = 18
    end

    fields[:fXmin] = 0.0
    fields[:fXmax] = 0.0
    fields[:fFactor] = 0.0

    if preamble.version == 3
        fields[:fXmin] = readtype(io, Float64)
        fields[:fXmax] = readtype(io, Float64)
        fields[:fFactor] = readtype(io, Float64)
    end

    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerElement})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end


@TStreamerElementTemplate mutable struct TStreamerBase
    fBaseVersion
end

function parsefields!(io, fields, ::Type{TStreamerBase})
    preamble = Preamble(io)
    parsefields!(io, fields, TStreamerElement)
    fields[:fBaseVersion] = fields[:version] >= 2 ? readtype(io, Int32) : 0
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerBase})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end


@TStreamerElementTemplate mutable struct TStreamerBasicType end

function parsefields!(io, fields, ::Type{TStreamerBasicType})
    parsefields!(io, fields, TStreamerElement)

    if Const.kOffsetL < fields[:fType] < Const.kOffsetP
        fields[:fType] -= Const.kOffsetP
    end
    basic = true
    if fields[:fType] ∈ (Const.kBool, Const.kUChar, Const.kChar)
        fields[:fSize] = 1
    elseif fields[:fType] in (Const.kUShort, Const.kShort)
        fields[:fSize] = 2
    elseif fields[:fType] in (Const.kBits, Const.kUInt, Const.kInt, Const.kCounter)
        fields[:fSize] = 4
    elseif fields[:fType] in (Const.kULong, Const.kULong64, Const.kLong, Const.kLong64)
        fields[:fSize] = 8
    elseif fields[:fType] in (Const.kFloat, Const.kFloat16)
        fields[:fSize] = 4
    elseif fields[:fType] in (Const.kDouble, Const.kDouble32)
        fields[:fSize] = 8
    elseif fields[:fType] == Const.kCharStar
        fields[:fSize] = sizeof(Int)
    else
        basic = false
    end

    if basic && fields[:fArrayLength] > 0
        fields[:fSize] *= fields[:fArrayLength]
    end

end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerBasicType})
    @initparse
    preamble = Preamble(io)
    parsefields!(io, fields, T)
    endcheck(io, preamble)
    T(;fields...)
end


@TStreamerElementTemplate mutable struct TStreamerBasicPointer
    fCountVersion
    fCountName
    fCountClass
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerBasicPointer})
    @initparse
    preamble = Preamble(io)
    parsefields!(io, fields, TStreamerElement)
    fields[:fCountVersion] = readtype(io, Int32)
    fields[:fCountName] = readtype(io, String)
    fields[:fCountClass] = readtype(io, String)
    endcheck(io, preamble)
    T(;fields...)
end

@TStreamerElementTemplate mutable struct TStreamerLoop
    fCountVersion
    fCountName
    fCountClass
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerLoop})
    @initparse
    preamble = Preamble(io)
    parsefields!(io, fields, TStreamerElement)
    fields[:fCountVersion] = readtype(io, Int32)
    fields[:fCountName] = readtype(io, String)
    fields[:fCountClass] = readtype(io, String)
    endcheck(io, preamble)
    T(;fields...)
end


@TStreamerElementTemplate mutable struct TStreamerSTL
    fSTLtype
    fCtype
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TStreamerSTL})
    @initparse
    preamble = Preamble(io)
    parsefields!(io, fields, TStreamerElement)

    fields[:fSTLtype] = readtype(io, Int32)
    fields[:fCtype] = readtype(io, Int32)

    if fields[:fSTLtype] == Const.kSTLmultimap || fields[:fSTLtype] == Const.kSTLset
        if startswith(fields[:fTypeName], "std::set") || startswith(fields[:fTypeName], "set")
            fields[:fSTLtype] = Const.kSTLset
        elseif startswith(fields[:fTypeName], "std::multimap") || startswith(fields[:fTypeName], "multimap")
            fields[:fSTLtype] = Const.kSTLmultimap
        end
    end

    endcheck(io, preamble)
    T(;fields...)
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
    @initparse
    preamble = Preamble(io)
    parsefields!(io, fields, TStreamerElement)
    endcheck(io, preamble)
    T(;fields...)
end

@TStreamerElementTemplate mutable struct TStreamerObject <: AbstractTStreamerObject end
@TStreamerElementTemplate mutable struct TStreamerObjectAny <: AbstractTStreamerObject end
@TStreamerElementTemplate mutable struct TStreamerObjectAnyPointer <: AbstractTStreamerObject end
@TStreamerElementTemplate mutable struct TStreamerObjectPointer <: AbstractTStreamerObject end
@TStreamerElementTemplate mutable struct TStreamerString <: AbstractTStreamerObject end



function TTree(io, tkey::TKey)
    preamble = Preamble(io)
end
