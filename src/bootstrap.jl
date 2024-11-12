# A collection of bootstrapped code which should be generated
# dynamically in future.

struct RecoveredTBasket
    data::Vector{UInt8}
    offsets::Vector{UInt32}
end
function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{RecoveredTBasket})
    @initparse
    start = position(io)
    #_format1 = struct.Struct(">ihiIhh")
    fNbytes = readtype(io, Int32)
    fVersion = readtype(io, Int16)
    fObjlen = readtype(io, Int32)
    fDatime = readtype(io, UInt32)
    fKeylen = readtype(io, Int16)
    fCycle = readtype(io, Int16)

    # skipping class name, name and title
    seek(io, start + fKeylen - 18 - 1)

    fVersion = readtype(io, UInt16)
    fBufferSize = readtype(io, Int32)
    fNevBufSize = readtype(io, Int32)
    fNevBuf = readtype(io, Int32)
    fLast = readtype(io, Int32)

    # one-byte terminator
    skip(io, 1)

    # then if you have offsets data, read them in
    if fNevBufSize > 8
        byteoffsets = read(io, fNevBuf * 4 + 8)
        skip(io, -4)
    else
        byteoffsets = Int32[]
    end

    # there's a second TKey here, but it doesn't contain any new information (in fact, less)
    skip(io, fKeylen)

    # the data (not including offsets)
    size = fLast - fKeylen
    contents = read(io, size)

    # put the offsets back in, in the way that we expect it
    if fNevBufSize > 8
        contents = vcat(contents, byteoffsets)
        size += length(byteoffsets)
    end
    fObjlen = size
    fNbytes = fObjlen + fKeylen
    @debug "Found $(length(contents)) bytes of basket data (not yet supported) in a TTree."
    RecoveredTBasket(contents, byteoffsets)
end

abstract type TNamed <: ROOTStreamedObject end
# TODO: we probably should switch over to @kwdef at some point, but that's another big refactoring
# Cursor is not needed here but it's mandatory due to the historical design of UnROOT and the
# parsefields approach
Base.@kwdef struct TNamed_1 <: TNamed
    cursor::Cursor
    fName::String
    fTitle::String
end
function readfields!(io, fields, ::Type{TNamed_1})
    parsefields!(io, fields, TObject)
    fields[:fName] = readtype(io, String)
    fields[:fTitle] = readtype(io, String)
end
# TODO: this is an ugly hack due to some ambiguities of readfields!-definitions.
# A big cleanup is needed!
# We need to define something like the following (that's not working, too tired already...)
# parsefields!(c::Cursor, fields, TObject) = parsefields!(c.io, fields, TObject)
# readtype(c::Cursor, ::Type{T}) where T = readtype(c.io, T)
function readfields!(c::Cursor, fields, ::Type{TNamed_1})
    parsefields!(c.io, fields, TObject)
    fields[:fName] = readtype(c.io, String)
    fields[:fTitle] = readtype(c.io, String)
end

abstract type TAttLine <: ROOTStreamedObject end
struct TAttLine_1 <: TAttLine end
function readfields!(io, fields, T::Type{TAttLine_1})
    fields[:fLineColor] = readtype(io, Int16)
    fields[:fLineStyle] = readtype(io, Int16)
    fields[:fLineWidth] = readtype(io, Int16)
end
struct TAttLine_2 <: TAttLine end
function readfields!(io, fields, T::Type{TAttLine_2})
    fields[:fLineColor] = readtype(io, Int16)
    fields[:fLineStyle] = readtype(io, Int16)
    fields[:fLineWidth] = readtype(io, Int16)
end

abstract type TAttFill <: ROOTStreamedObject end
struct TAttFill_1 <: TAttFill end
function readfields!(io, fields, T::Type{TAttFill_1})
    fields[:fFillColor] = readtype(io, Int16)
    fields[:fFillStyle] = readtype(io, Int16)
end
struct TAttFill_2 <: TAttFill end
function readfields!(io, fields, T::Type{TAttFill_2})
    fields[:fFillColor] = readtype(io, Int16)
    fields[:fFillStyle] = readtype(io, Int16)
end

abstract type TAttMarker <: ROOTStreamedObject end
struct TAttMarker_2 <: TAttFill end
function readfields!(io, fields, T::Type{TAttMarker_2})
    fields[:fMarkerColor] = readtype(io, Int16)
    fields[:fMarkerStyle] = readtype(io, Int16)
    fields[:fMarkerSize] = readtype(io, Float32)
end
const TAttMarker_1 = TAttMarker_2

abstract type TAttAxis <: ROOTStreamedObject end
struct TAttAxis_4 <: TAttAxis end
function readfields!(io, fields, T::Type{TAttAxis_4})
    fields[:fNdivisions] = readtype(io, Int32)
    fields[:fAxisColor] = readtype(io, Int16)
    fields[:fLabelColor] = readtype(io, Int16)
    fields[:fLabelFont] = readtype(io, Int16)
    fields[:fLabelOffset] = readtype(io, Float32)
    fields[:fLabelSize] = readtype(io, Float32)
    fields[:fTickLength] = readtype(io, Float32)
    fields[:fTitleOffset] = readtype(io, Float32)
    fields[:fTitleSize] = readtype(io, Float32)
    fields[:fTitleColor] = readtype(io, Int16)
    fields[:fTitleFont] = readtype(io, Int16)
end

abstract type TAxis <: ROOTStreamedObject end
struct TAxis_10 <: TAxis end
function readfields!(io, fields, T::Type{TAxis_10})
    # overrides things like fName,... that were set from the parent TH1 :(
    stream!(io, fields, TNamed)
    stream!(io, fields, TAttAxis)
    fields[:fNbins] = readtype(io, Int32)
    fields[:fXmin] = readtype(io, Float64)
    fields[:fXmax] = readtype(io, Float64)
    fields[:fXbins] = readtype(io, TArrayD)
    fields[:fFirst] = readtype(io, Int16)
    fields[:fLast] = readtype(io, Int16)
    fields[:fBits2] = readtype(io, UInt16)
    fields[:fTimeDisplay] = readtype(io, Bool)
    fields[:fTimeFormat] = readtype(io, String)
end

abstract type TH1 <: ROOTStreamedObject end
struct TH1_8 <: TH1 end
function readfields!(io, fields, T::Type{TH1_8}) end

abstract type TH2 <: ROOTStreamedObject end
struct TH2_4 <: TH2 end
struct TH2_5 <: TH2 end
function readfields!(io, fields, T::Type{TH2_4}) end
function readfields!(io, fields, T::Type{TH2_5}) end

abstract type TH3 <: ROOTStreamedObject end
struct TH3_6 <: TH3 end
function readfields!(io, fields, T::Type{TH3_6}) end

@with_kw struct ROOT_3a3a_TIOFeatures <: ROOTStreamedObject
    fIOBits
end

function parsefields!(io, fields, T::Type{ROOT_3a3a_TIOFeatures})
    preamble = Preamble(io, T)
    skip(io, 4)
    fields[:fIOBits] = readtype(io, UInt8)
    endcheck(io, preamble)
end

# FIXME maybe this is unpack, rather than readtype?
function readtype(io, T::Type{ROOT_3a3a_TIOFeatures})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end


# FIXME this should be generated
@with_kw struct TLeaf
    # FIXME these two come from TNamed
    fName
    fTitle

    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount
end

function parsefields!(io, fields, ::Type{T}) where {T<:TLeaf}
    preamble = Preamble(io, T)
    stream!(io, fields, TNamed)
    fields[:fLen] = readtype(io, Int32)
    fields[:fLenType] = readtype(io, Int32)
    fields[:fOffset] = readtype(io, Int32)
    fields[:fIsRange] = readtype(io, Bool)
    fields[:fIsUnsigned] = readtype(io, Bool)
    fields[:fLeafCount] = readtype(io, UInt32)

    # FIXME this needs to be checked, sometimes the TLeaf is too short
    observed = position(io) - preamble.start
    for _ in 1:(preamble.cnt - observed)
        read(io, 1)
    end
    endcheck(io, preamble)
end

# FIXME this should be generated
@with_kw struct TLeafElement
    # FIXME these two come from TNamed
    fName
    fTitle

    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    fID
    fType
end

function parsefields!(io, fields, ::Type{T}) where {T<:TLeafElement}
    parsefields!(io, fields, TLeaf)
    fields[:fID] = readtype(io, Int32)
    fields[:fType] = readtype(io, Int32)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafElement})
    @initparse
    preamble = Preamble(io, T)
    parsefields!(io, fields, T)
    endcheck(io, preamble)
    T(;fields...)
end

# FIXME this should be generated and inherited from TLeaf
@with_kw struct TLeafI
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end

function parsefields!(io, fields, T::Type{TLeafI})
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, Int32)
    fields[:fMaximum] = readtype(io, Int32)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafI})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

primitivetype(l::TLeafI) = l.fIsUnsigned ? UInt32 : Int32

# FIXME this should be generated and inherited from TLeaf
@with_kw struct TLeafS
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end

function parsefields!(io, fields, T::Type{TLeafS})
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, Int16)
    fields[:fMaximum] = readtype(io, Int16)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafS})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

primitivetype(l::TLeafS) = l.fIsUnsigned ? UInt16 : Int16

# FIXME this should be generated and inherited from TLeaf
@with_kw struct TLeafL
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end

function parsefields!(io, fields, T::Type{TLeafL})
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, Int64)
    fields[:fMaximum] = readtype(io, Int64)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafL})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

primitivetype(l::TLeafL) = l.fIsUnsigned ? UInt64 : Int64

# FIXME this should be generated and inherited from TLeaf
@with_kw struct TLeafO
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end
primitivetype(l::TLeafO) = Bool

function parsefields!(io, fields, T::Type{TLeafO})
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, Bool)
    fields[:fMaximum] = readtype(io, Bool)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafO})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

# FIXME this should be generated and inherited from TLeaf
@with_kw struct TLeafF
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end

function parsefields!(io, fields, T::Type{TLeafF})
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, Float32)
    fields[:fMaximum] = readtype(io, Float32)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafF})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

primitivetype(l::TLeafF) = Float32

# FIXME this should be generated and inherited from TLeaf
# https://root.cern/doc/master/TLeafB_8h_source.html#l00026
@with_kw struct TLeafB
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end

function parsefields!(io, fields, T::Type{TLeafB})
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, UInt8)
    fields[:fMaximum] = readtype(io, UInt8)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafB})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

primitivetype(l::TLeafB) = UInt8
# FIXME this should be generated and inherited from TLeaf
@with_kw struct TLeafD
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end

function parsefields!(io, fields, T::Type{TLeafD})
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, Float64)
    fields[:fMaximum] = readtype(io, Float64)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, T::Type{TLeafD})
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

primitivetype(l::TLeafD) = Float64

# FIXME this should be generated and inherited from TLeaf
@with_kw struct TLeafC
    # from TNamed
    fName
    fTitle

    # from TLeaf
    fLen
    fLenType
    fOffset
    fIsRange
    fIsUnsigned
    fLeafCount

    # own fields
    fMinimum
    fMaximum
end

primitivetype(l::TLeafC) = UInt8

function parsefields!(io, fields, ::Type{T}) where {T<:TLeafC}
    preamble = Preamble(io, T)
    parsefields!(io, fields, TLeaf)
    fields[:fMinimum] = readtype(io, Int32)
    fields[:fMaximum] = readtype(io, Int32)
    endcheck(io, preamble)
end

function unpack(io, tkey::TKey, refs::Dict{Int32, Any}, ::Type{T}) where {T<:TLeafC}
    @initparse
    parsefields!(io, fields, T)
    T(;fields...)
end

abstract type TBranch <: ROOTStreamedObject end
abstract type TBranchElement <: ROOTStreamedObject end
function Base.hash(b::Union{TBranch, TBranchElement}, h::UInt)
    h = hash(b.fFileName, h)
    h = hash(b.fName, h)
    h = hash(b.fEntries, h)
end
Base.length(b::Union{TBranch, TBranchElement}) = b.fEntries
Base.eachindex(b::Union{TBranch, TBranchElement}) = Base.OneTo(b.fEntries)
numbaskets(b::Union{TBranch, TBranchElement}) = findfirst(x->x>(b.fEntries-1),b.fBasketEntry)-1

@with_kw struct TBranch_8 <: TBranch
    cursor::Cursor
    # from TNamed
    fName
    fTitle

    # from TAttFill
    fFillColor
    fFillStyle

    fCompress
    fBasketSize
    fEntryOffsetLen
    fWriteBasket
    fEntryNumber

    fOffset
    fMaxBaskets
    fSplitLevel
    fEntries
    fTotBytes
    fZipBytes

    fBranches
    fLeaves
    fBaskets
    fBasketBytes::Vector{Int64}
    fBasketEntry::Vector{Int64}
    fBasketSeek::Vector{Int64}
    fFileName
end
function readfields!(cursor::Cursor, fields, ::Type{T}) where {T<:TBranch_8}
    io = cursor.io
    tkey = cursor.tkey
    refs = cursor.refs

    stream!(io, fields, TNamed)
    stream!(io, fields, TAttFill)

    fields[:fCompress] = readtype(io, Int32)
    fields[:fBasketSize] = readtype(io, Int32)
    fields[:fEntryOffsetLen] = readtype(io, Int32)
    fields[:fWriteBasket] = readtype(io, Int32)
    fields[:fEntryNumber] = readtype(io, Int64)

    fields[:fOffset] = readtype(io, Int32)
    fields[:fMaxBaskets] = readtype(io, UInt32)
    fields[:fSplitLevel] = readtype(io, Int32)
    fields[:fEntries] = readtype(io, Int64)
    fields[:fTotBytes] = readtype(io, Int64)
    fields[:fZipBytes] = readtype(io, Int64)

    fields[:fBranches] = unpack(io, tkey, refs, TObjArray)
    fields[:fLeaves] = unpack(io, tkey, refs, TObjArray)
    fields[:fBaskets] = unpack(io, tkey, refs, TObjArray)
    # fields[:fBaskets] = unpack(io, tkey, refs, Undefined)
    speedbump = true  # FIXME speedbump?

    speedbump && skip(io, 1)

    fields[:fBasketBytes] = [readtype(io, Int32) for _ in 1:fields[:fMaxBaskets]]

    speedbump && skip(io, 1)

    # this is also called fBsketEvent, as far as I understood
    fields[:fBasketEntry] = [readtype(io, Int64) for _ in 1:fields[:fMaxBaskets]]

    speedbump && skip(io, 1)

    fields[:fBasketSeek] = [readtype(io, Int64) for _ in 1:fields[:fMaxBaskets]]
    fields[:fFileName] = readtype(io, String)
end
@with_kw struct TBranch_12 <: TBranch
    cursor::Cursor
    # from TNamed
    fName
    fTitle

    # from TAttFill
    fFillColor
    fFillStyle

    fCompress
    fBasketSize
    fEntryOffsetLen
    fWriteBasket
    fEntryNumber

    fOffset
    fMaxBaskets
    fSplitLevel
    fEntries
    fFirstEntry
    fTotBytes
    fZipBytes

    fBranches
    fLeaves
    fBaskets
    fBasketBytes::Vector{Int64}
    fBasketEntry::Vector{Int64}
    fBasketSeek::Vector{Int64}
    fFileName
end
function readfields!(cursor::Cursor, fields, ::Type{T}) where {T<:TBranch_12}
    io = cursor.io
    tkey = cursor.tkey
    refs = cursor.refs

    stream!(io, fields, TNamed)
    stream!(io, fields, TAttFill)

    fields[:fCompress] = readtype(io, Int32)
    fields[:fBasketSize] = readtype(io, Int32)
    fields[:fEntryOffsetLen] = readtype(io, Int32)
    fields[:fWriteBasket] = readtype(io, Int32)
    fields[:fEntryNumber] = readtype(io, Int64)

    fields[:fOffset] = readtype(io, Int32)
    fields[:fMaxBaskets] = readtype(io, UInt32)
    fields[:fSplitLevel] = readtype(io, Int32)
    fields[:fEntries] = readtype(io, Int64)
    fields[:fFirstEntry] = readtype(io, Int64)
    fields[:fTotBytes] = readtype(io, Int64)
    fields[:fZipBytes] = readtype(io, Int64)

    fields[:fBranches] = unpack(io, tkey, refs, TObjArray)
    fields[:fLeaves] = unpack(io, tkey, refs, TObjArray)
    fields[:fBaskets] = unpack(io, tkey, refs, TObjArray)
    # fields[:fBaskets] = unpack(io, tkey, refs, Undefined)
    speedbump = true  # FIXME speedbump?

    speedbump && skip(io, 1)

    fields[:fBasketBytes] = [readtype(io, Int32) for _ in 1:fields[:fMaxBaskets]]

    speedbump && skip(io, 1)

    # this is also called fBsketEvent, as far as I understood
    fields[:fBasketEntry] = [readtype(io, Int64) for _ in 1:fields[:fMaxBaskets]]

    speedbump && skip(io, 1)

    fields[:fBasketSeek] = [readtype(io, Int64) for _ in 1:fields[:fMaxBaskets]]
    fields[:fFileName] = readtype(io, String)
end
@with_kw struct TBranch_13 <: TBranch
    cursor::Cursor
    # from TNamed
    fName
    fTitle

    # from TAttFill
    fFillColor
    fFillStyle

    fCompress
    fBasketSize
    fEntryOffsetLen
    fWriteBasket
    fEntryNumber

    fIOFeatures

    fOffset
    fMaxBaskets
    fSplitLevel
    fEntries
    fFirstEntry
    fTotBytes
    fZipBytes

    fBranches
    fLeaves
    fBaskets
    fBasketBytes::Vector{Int64}
    fBasketEntry::Vector{Int64}
    fBasketSeek::Vector{Int64}
    fFileName
end
function readfields!(cursor::Cursor, fields, ::Type{T}) where {T<:TBranch_13}
    io = cursor.io
    tkey = cursor.tkey
    refs = cursor.refs

    stream!(io, fields, TNamed)
    stream!(io, fields, TAttFill)

    fields[:fCompress] = readtype(io, Int32)
    fields[:fBasketSize] = readtype(io, Int32)
    fields[:fEntryOffsetLen] = readtype(io, Int32)
    fields[:fWriteBasket] = readtype(io, Int32)
    fields[:fEntryNumber] = readtype(io, Int64)

    fields[:fIOFeatures] = readtype(io, ROOT_3a3a_TIOFeatures)

    fields[:fOffset] = readtype(io, Int32)
    fields[:fMaxBaskets] = readtype(io, UInt32)
    fields[:fSplitLevel] = readtype(io, Int32)
    fields[:fEntries] = readtype(io, Int64)
    fields[:fFirstEntry] = readtype(io, Int64)
    fields[:fTotBytes] = readtype(io, Int64)
    fields[:fZipBytes] = readtype(io, Int64)

    fields[:fBranches] = unpack(io, tkey, refs, TObjArray)
    fields[:fLeaves] = unpack(io, tkey, refs, TObjArray)
    fields[:fBaskets] = unpack(io, tkey, refs, TObjArray)
    # fields[:fBaskets] = unpack(io, tkey, refs, Undefined)
    speedbump = true  # FIXME speedbump?

    speedbump && skip(io, 1)

    fields[:fBasketBytes] = [readtype(io, Int32) for _ in 1:fields[:fMaxBaskets]]

    speedbump && skip(io, 1)

    # this is also called fBsketEvent, as far as I understood
    fields[:fBasketEntry] = [readtype(io, Int64) for _ in 1:fields[:fMaxBaskets]]

    speedbump && skip(io, 1)

    fields[:fBasketSeek] = [readtype(io, Int64) for _ in 1:fields[:fMaxBaskets]]
    fields[:fFileName] = readtype(io, String)
end

@with_kw struct TBranchElement_9 <: TBranchElement
    cursor::Cursor
    # from TNamed
    fName
    fTitle

    # from TAttFill
    fFillColor
    fFillStyle

    fCompress
    fBasketSize
    fEntryOffsetLen
    fWriteBasket
    fEntryNumber

    fOffset
    fMaxBaskets
    fSplitLevel
    fEntries
    fFirstEntry
    fTotBytes
    fZipBytes

    fBranches
    fLeaves
    fBaskets
    fBasketBytes::Vector{Int64}
    fBasketEntry::Vector{Int64}
    fBasketSeek::Vector{Int64}
    fFileName

    # own fields
    fClassName
    fParentName
    fClonesName
    fCheckSum
    fClassVersion
    fID
    fType
    fStreamerType
    fMaximum
    fBranchCount
    fBranchCount2
end

@with_kw struct TBranchElement_10 <: TBranchElement
    cursor::Cursor
    # from TNamed
    fName
    fTitle

    # from TAttFill
    fFillColor
    fFillStyle

    fCompress
    fBasketSize
    fEntryOffsetLen
    fWriteBasket
    fEntryNumber

    fIOFeatures=0x00

    fOffset
    fMaxBaskets
    fSplitLevel
    fEntries
    fFirstEntry
    fTotBytes
    fZipBytes

    fBranches
    fLeaves
    fBaskets
    fBasketBytes::Vector{Int64}
    fBasketEntry::Vector{Int64}
    fBasketSeek::Vector{Int64}
    fFileName

    # own fields
    fClassName
    fParentName
    fClonesName
    fCheckSum
    fClassVersion
    fID
    fType
    fStreamerType
    fMaximum
    fBranchCount
    fBranchCount2
end

function readfields!(cursor::Cursor, fields, ::Type{T}) where {T<:TBranchElement_9}
    io = cursor.io
    tkey = cursor.tkey
    refs = cursor.refs

    stream!(cursor, fields, TBranch)

    fields[:fClassName] = readtype(io, String)
    fields[:fParentName] = readtype(io, String)
    fields[:fClonesName] = readtype(io, String)
    fields[:fCheckSum] = readtype(io, UInt32)
    fields[:fClassVersion] = readtype(io, Int32)
    fields[:fID] = readtype(io, Int32)
    fields[:fType] = readtype(io, Int32)
    fields[:fStreamerType] = readtype(io, Int32)
    fields[:fMaximum] =readtype(io, Int32)
    fields[:fBranchCount] = readobjany!(io, tkey, refs)
    fields[:fBranchCount2] = readobjany!(io, tkey, refs)
end

function readfields!(cursor::Cursor, fields, ::Type{T}) where {T<:TBranchElement_10}
    io = cursor.io
    tkey = cursor.tkey
    refs = cursor.refs

    stream!(cursor, fields, TBranch)

    fields[:fClassName] = readtype(io, String)
    fields[:fParentName] = readtype(io, String)
    fields[:fClonesName] = readtype(io, String)
    fields[:fCheckSum] = readtype(io, UInt32)
    fields[:fClassVersion] = readtype(io, Int16)
    fields[:fID] = readtype(io, Int32)
    fields[:fType] = readtype(io, Int32)
    fields[:fStreamerType] = readtype(io, Int32)
    fields[:fMaximum] =readtype(io, Int32)
    fields[:fBranchCount] = readobjany!(io, tkey, refs)
    fields[:fBranchCount2] = readobjany!(io, tkey, refs)
end

# FIXME preliminary TTree structure
@with_kw struct TTree
    # TNamed
    fName
    fTitle

    # TAttLine
    fLineColor
    fLineStyle
    fLineWidth

    # TAttFill
    fFillColor
    fFillStyle

    # TAttMarker
    fMarkerColor
    fMarkerStyle
    fMarkerSize

    fEntries
    fTotBytes
    fZipBytes
    fSavedBytes
    fFlushedBytes
    fWeight
    fTimerInterval
    fScanField
    fUpdate
    fDefaultEntryOffsetLen
    fNClusterRange
    fMaxEntries
    fMaxEntryLoop
    fMaxVirtualSize
    fAutoSave
    fAutoFlush
    fEstimate

    fClusterRangeEnd
    fClusterSize

    fIOFeatures

    fBranches
    fLeaves

    fAliases
    fIndexValues
    fIndex
    fTreeIndex
    fFriends
end

TH1I(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH2I(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH3I(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH1F(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH2F(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH3F(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH1D(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH2D(io, tkey::TKey, refs) = TH(io, tkey, refs)
TH3D(io, tkey::TKey, refs) = TH(io, tkey, refs)

"""
    TH(io, tkey::TKey, refs)

Internal function used to form a `fields = Dict{Symbol, Any}()` that represents the fields of a
`TH` (histogram) in C++ ROOT.
"""
function TH(io, tkey::TKey, refs)
    fields = Dict{Symbol, Any}()

    io = datastream(io, tkey)
    preamble = Preamble(io, Missing)

    is2d = startswith(tkey.fClassName, "TH2")
    if is2d
        stream!(io, fields, TH2, check=false)
    end

    is3d = startswith(tkey.fClassName, "TH3")
    if is3d
        stream!(io, fields, TH3, check=false)
    end

    stream!(io, fields, TH1, check=false)
    stream!(io, fields, TNamed)
    stream!(io, fields, TAttLine)
    stream!(io, fields, TAttFill)
    stream!(io, fields, TAttMarker)
    fields[:fNcells] = readtype(io, Int32)

    for axis in ["fXaxis_", "fYaxis_", "fZaxis_"]
        subfields = Dict{Symbol, Any}()
        stream!(io, subfields, TAxis, check=false)
        fields[Symbol(axis, :fLabels)] = readobjany!(io, tkey, refs)
        fields[Symbol(axis, :fModLabs)] = readobjany!(io, tkey, refs)
        for (k,v) in subfields
            fields[Symbol(axis, k)] = v
        end
        # FIXME this line makes non-uniform binned histograms work, but not sure why
        readtype(io, Int32)
    end

    fields[:fBarOffset] = readtype(io, Int16)
    fields[:fBarWidth] = readtype(io, Int16)
    for symb in [:fEntries, :fTsumw, :fTsumw2, :fTsumwx, :fTsumwx2, :fMaximum, :fMinimum, :fNormFactor]
        fields[symb] = readtype(io, Float64)
    end

    fields[:fContour] = readtype(io, TArrayD)
    fields[:fSumw2] = readtype(io, TArrayD)
    fields[:fOption] = readtype(io, String)
    # if user saved after calling h.Fit() with a TF1, then this will error
    fields[:fFunctions] = unpack(io, tkey, refs, TList)
    fields[:fBufferSize] = readtype(io, Int32)
    skip(io, 1) # speedbump
    fields[:fBuffer] = readtype(io, TArrayD)
    fields[:fBinStatErrOpt] = readtype(io, Int16)
    fields[:fStatOverflows] = readtype(io, Int16)

    if is2d
        for symb in [:fScalefactor, :fTsumwy, :fTsumwy2, :fTsumwxy]
            fields[symb] = readtype(io, Float64)
        end
    end


    if is3d
        skip(io, 6)  # TAtt3D, not used yet, consist of two fields: cnt (u4), vers (u2)
        for symb in [:fTsumwy, :fTsumwy2, :fTsumwxy, :fTsumwz, :fTsumwz2, :fTsumwxz, :fTsumwyz]
            fields[symb] = readtype(io, Float64)
        end
    end

    if endswith(tkey.fClassName, 'F')
      arraytype = TArrayF
    elseif endswith(tkey.fClassName, 'D')
      arraytype = TArrayD
    elseif endswith(tkey.fClassName, 'I')
      arraytype = TArrayI
    else
      error("Unknown histogram of type $(tkey.fClassName)")
    end

    fields[:fN] = readtype(io, arraytype)
    fields
end

function TDirectory(io, tkey::TKey, refs)
    fobj = io
    seekstart(fobj, tkey)

    # almost verbatim from L95 to L101 of root.jl
    dir_header = unpack(fobj, ROOTDirectoryHeader)
    seek(fobj, dir_header.fSeekKeys)
    header_key = unpack(fobj, TKey)
    n_keys = readtype(fobj, Int32)
    keys = [unpack(fobj, TKey) for _ in 1:n_keys]

    directory = ROOTDirectory(header_key.fName, dir_header, keys, fobj, refs)
    return directory
end

# FIXME idk what is going on but this just looks like a TTree.....
function TNtuple(io, tkey::TKey, refs)
    io = datastream(io, tkey)
    preamble = Preamble(io, Missing)
    tree = TTree(io, tkey, refs; top=false) #embedded tree
end

TNtupleD(io, tkey::TKey, refs) = TNtuple(io, tkey::TKey, refs)

"""

Direct parsing of streamed objects which are not sitting on branches. This function needs to be
rewritten, so that it can create proper types of TObject inherited data (like `TVectorT<*>`).

"""
function parsetobject(f, tkey::TKey, streamer)
    # pass the correct parser from f!
    io = datastream(f.fobj, tkey)
    preamble = Preamble(io, Missing)

    @initparse

    # the first entry in the streamer is a TObject
    parsefields!(io, fields, TObject)

    # simple custom streamers which instantiate the full objects data
    tkey.fClassName ∈ Base.keys(f.customstructs) && return readtype(io, f.customstructs[tkey.fClassName]; tkey=tkey, original_streamer=streamer)

    # FIXME: this is just a hack, for TObject-derivatives which are subclassing map<string,string>
    s = streamer.streamer.fElements.elements[2]
    if s.fTypeName == "map<string,string>"
        skip(io, 3*4)  # unclear what the first 12 bytes are
        # this gives the number of elements
        n = readtype(io, Int32)
        skip(io, 6)  # the usual header stuff?
        keys = [readtype(io, String) for i ∈ 1:n]
        skip(io, 6)  # the usual header stuff?
        values = [readtype(io, String) for i ∈ 1:n]
        return Dict(zip(keys, values))
    end

    # FIXME: generalise this! We also need a hook-in mechanism for this function
    # so that the user can provide custom parsing logic
    if tkey.fClassName == "TVectorT<double>"
        n = readtype(io, UInt32)
        row_lwb = readtype(io, Int32)  # index of the starting element of the vector itself
        skip(io, 1)
        return [readtype(io, Float64) for _ ∈ row_lwb+1:n]
    end

    error("Unable to parse '$(s.fTypeName)' of '$(tkey.fClassName)', " *
          "consider providing a custom streamer by passing " *
          "`customstreamer=Dict(\"$(tkey.fClassName)\" => TheStreamer)` to the `ROOTFile` " *
          "and implement the struct `TheStreamer` and `UnROOT.readtype(io, ::Type{TheStreamer}; tkey, original_streamer)`.")
end


# FIXME preliminary TTree implementation
function TTree(io, tkey::TKey, refs; top=true)
    # if embedded in a Ntuple, don't run datastream again
    io = top ? datastream(io, tkey) : io

    @initparse

    preamble = Preamble(io, Missing)
    # @show preamble

    stream!(io, fields, TNamed)

    stream!(io, fields, TAttLine)
    stream!(io, fields, TAttFill)
    stream!(io, fields, TAttMarker)

    if preamble.version == 5
        fields[:fEntries] = readtype(io, Float64)
        fields[:fTotBytes] = readtype(io, Float64)
        fields[:fZipBytes] = readtype(io, Float64)
        fields[:fSavedBytes] = readtype(io, Float64)
        fields[:fTimerInterval] = readtype(io, Int32)
        fields[:fScanField] = readtype(io, Int32)
        fields[:fUpdate] = readtype(io, Int32)
        fields[:fMaxEntryLoop] = readtype(io, Int32)
        fields[:fMaxVirtualSize] = readtype(io, Int32)
        fields[:fAutoSave] = readtype(io, Int32)
        fields[:fEstimate] = readtype(io, Int32)

        # FIXME what about speedbumps??
        speedbump = true

        # TODO is this really needed? probably to prevent some downstream logic from breaking
        fields[:fIOFeatures] = missing

        fields[:fBranches] = unpack(io, tkey, refs, TObjArray)
        fields[:fLeaves] = unpack(io, tkey, refs, TObjArray)

        fields[:fAliases] = readobjany!(io, tkey, refs)
        fields[:fIndexValues] = readtype(io, TArrayD)
        fields[:fIndex] = readtype(io, TArrayI)
        fields[:fTreeIndex] = readobjany!(io, tkey, refs)
        fields[:fFriends] = readobjany!(io, tkey, refs)

        return TTree(;fields...)
    end

    fields[:fEntries] = readtype(io, Int64)
    fields[:fTotBytes] = readtype(io, Int64)
    fields[:fZipBytes] = readtype(io, Int64)
    fields[:fSavedBytes] = readtype(io, Int64)
    fields[:fFlushedBytes] = readtype(io, Int64)
    fields[:fWeight] = readtype(io, Float64)
    fields[:fTimerInterval] = readtype(io, Int32)
    fields[:fScanField] = readtype(io, Int32)
    fields[:fUpdate] = readtype(io, Int32)
    # See https://github.com/cbourjau/alice-rs/blob/6af19a78fe5521f5b27466d7d20f7dfacd38a38f/root-io/src/tree_reader/tree.rs#L148
    if preamble.version >= 18
        fields[:fDefaultEntryOffsetLen] = readtype(io, Int32)
    end
    if preamble.version >= 19
        fields[:fNClusterRange] = readtype(io, UInt32)
    end
    fields[:fMaxEntries] = readtype(io, Int64)
    fields[:fMaxEntryLoop] = readtype(io, Int64)
    fields[:fMaxVirtualSize] = readtype(io, Int64)
    fields[:fAutoSave] = readtype(io, Int64)
    fields[:fAutoFlush] = readtype(io, Int64)
    fields[:fEstimate] = readtype(io, Int64)

    # FIXME what about speedbumps??
    speedbump = true

    # See https://github.com/cbourjau/alice-rs/blob/6af19a78fe5521f5b27466d7d20f7dfacd38a38f/root-io/src/tree_reader/tree.rs#L148
    if haskey(fields, :fNClusterRange)
        speedbump && skip(io, 1)
        fields[:fClusterRangeEnd] = [readtype(io, Int64) for _ in 1:fields[:fNClusterRange]]
        speedbump && skip(io, 1)
        fields[:fClusterSize] = [readtype(io, Int64) for _ in 1:fields[:fNClusterRange]]
    end

    # for key in keys(fields)
    #     @show key, fields[key]
    # end

    if preamble.version >= 20
        fields[:fIOFeatures] = readtype(io, ROOT_3a3a_TIOFeatures)
    else
        fields[:fIOFeatures] = missing
    end

    fields[:fBranches] = unpack(io, tkey, refs, TObjArray)
    fields[:fLeaves] = unpack(io, tkey, refs, TObjArray)

    fields[:fAliases] = readobjany!(io, tkey, refs)
    fields[:fIndexValues] = readtype(io, TArrayD)
    fields[:fIndex] = readtype(io, TArrayI)
    fields[:fTreeIndex] = readobjany!(io, tkey, refs)
    fields[:fFriends] = readobjany!(io, tkey, refs)

    # uproot unpacks Undefined instances here, we cannot since
    # the Base.GenericIOBuffer{Array{UInt8,1}} from the compression
    # library throws an EOFError when we read more than available.
    # FIXME this needs to be checked though!
    # while !eof(io)
    #     read(io, 1)
    # end
    # unpack(io, tkey, refs, Undefined)
    # println(fields[:fBranches])

    # endcheck(io, preamble)
    TTree(;fields...)
end

# FIXME what to do with auto.py's massive type translation?
# https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/interp/auto.py#L360-L365

abstract type TFriendElement <: ROOTStreamedObject end
Base.@kwdef struct TFriendElement_2 <: TFriendElement
    cursor::Cursor
    fName::String
    fTitle::String
    fTreeName::String
    fOwnFile::Bool
end
function readfields!(io, fields, ::Type{TFriendElement_2})
    stream!(io, fields, TNamed)
    fields[:fTreeName] = readtype(io, String)
    fields[:fOwnFile] = readtype(io, Bool)
end
# TODO: this is an ugly hack due to some ambiguities of readfields!-definitions.
# A big cleanup is needed!
function readfields!(c::Cursor, fields, ::Type{TFriendElement_2})
    stream!(c.io, fields, TNamed)
    fields[:fTreeName] = readtype(c.io, String)
    fields[:fOwnFile] = readtype(c.io, Bool)
end

abstract type TAttBox2D <: ROOTStreamedObject end
struct TAttBox2D_0 <: TAttBox2D end
readfields!(c::Cursor, fields, ::Type{TAttBox2D_0}) = nothing

abstract type TText <: ROOTStreamedObject end
Base.@kwdef struct TText_3 <: TText
    # TNamed
    # TAttText
    # TAttBox2D
    fX::Float64
    fY::Float64
end
function readfields!(c::Cursor, fields, ::Type{TText_3})
    stream!(c, fields, TNamed)
    stream!(c, fields, TAttText)
    stream!(c, fields, TAttBox2D)
    fields[:fX] = readtype(c.io, Float64)
    fields[:fY] = readtype(c.io, Float64)
end

abstract type TLatex <: ROOTStreamedObject end
Base.@kwdef struct TLatex_2 <: TLatex
    cursor::Cursor
    # TText
    fName::String
    fTitle::String
    fTextAngle::Float32
    fTextSize::Float32
    fTextAlign::Int16
    fTextColor::Int16
    fTextFont::Int16
    fX::Float64
    fY::Float64

    # TAttLine
    fLineColor::Int16
    fLineStyle::Int16
    fLineWidth::Int16

    fLimitFactorSize::Int32
    fOriginSize::Float64
end
function readfields!(c::Cursor, fields, ::Type{TLatex_2})
    stream!(c, fields, TText)
    stream!(c.io, fields, TAttLine)  # TODO: define all these methods for the Cursor!
    fields[:fLimitFactorSize] = readtype(c.io, Int32)
    fields[:fOriginSize] = readtype(c.io, Float64)
end

abstract type TAttText <: ROOTStreamedObject end
Base.@kwdef struct TAttText_2 <: TAttText
    cursor::Cursor
    fTextAngle::Float32
    fTextSize::Float32
    fTextAlign::Int16
    fTextColor::Int16
    fTextFont::Int16
end
function readfields!(c::Cursor, fields, ::Type{TAttText_2})
    fields[:fTextAngle] = readtype(c.io, Float32)
    fields[:fTextSize] = readtype(c.io, Float32)
    fields[:fTextAlign] = readtype(c.io, Int16)
    fields[:fTextColor] = readtype(c.io, Int16)
    fields[:fTextFont] = readtype(c.io, Int16)
end

# abstract type TBox <: ROOTStreamedObject end
# struct TBox_3 <: TBox
#     fields::Dict{Symbol, Any}
# end
# function readfields!(io::IO, fields, ::Type{TBox_3})
#     # skiptobj(io)
#     # skip(io, 1)
#     # stream!(io, fields, TAttLine)
#     # stream!(io, fields, TAttFill)
#     # skip(io, 6)  # TAttBBox2D with cnt (u4) and vers (u2)
#     skip(io, 140)
# end

abstract type TPaveText <: ROOTStreamedObject end
Base.@kwdef struct TPaveText_2 <: TPaveText
    cursor::Cursor
    # TBox
    fX1NDC::Float64
    fY1NDC::Float64
    fX2NDC::Float64
    fY2NDC::Float64
    fBorderSize::Int32
    fInit::Int32
    fShadowColor::Int32
    fCornerRadius::Float64
    fOption::String
    fName::String

    fLabel::String
    fLongest::Int32
    fMargin::Float32
    fLines
end
function readfields!(c::Cursor, fields, ::Type{TPaveText_2})
    io = c.io
    tkey = c.tkey
    refs = c.refs

    skip(io, 82)  # TODO: what is this??

    # TPave
    # stream!(io, fields, TBox)  # below is TBox readout since we could not
    # figure out how to read it (see above)
    fields[:fX1NDC] = readtype(io, Float64)
    fields[:fY1NDC] = readtype(io, Float64)
    fields[:fX2NDC] = readtype(io, Float64)
    fields[:fY2NDC] = readtype(io, Float64)
    fields[:fBorderSize] = readtype(io, Int32)
    fields[:fInit] = readtype(io, Int32)
    fields[:fShadowColor] = readtype(io, Int32)
    fields[:fCornerRadius] = readtype(io, Float64)
    fields[:fOption] = readtype(io, String)
    fields[:fName] = readtype(io, String)

    stream!(c, fields, TAttText)

    fields[:fLabel] = readtype(io, String)
    fields[:fLongest] = readtype(io, Int32)
    fields[:fMargin] = readtype(io, Float32)
    fields[:fLines] = readobjany!(io, tkey, refs)
end

abstract type TVirtualPaveStats <: ROOTStreamedObject end
struct TVirtualPaveStats_0 <: TVirtualPaveStats end
readfields!(c::Cursor, fields, ::Type{TVirtualPaveStats_0}) = nothing

abstract type TPaveStats <: ROOTStreamedObject end
Base.@kwdef struct TPaveStats_5 <: TPaveStats
    cursor::Cursor
    # TPaveText
    fX1NDC::Float64
    fY1NDC::Float64
    fX2NDC::Float64
    fY2NDC::Float64
    fBorderSize::Int32
    fInit::Int32
    fShadowColor::Int32
    fCornerRadius::Float64
    fOption::String
    fName::String
    fLabel::String
    fLongest::Int32
    fMargin::Float32
    fLines

    fTextAngle::Float32
    fTextSize::Float32
    fTextAlign::Int16
    fTextColor::Int16
    fTextFont::Int16

    fOptFit::Int32
    fOptStat::Int32
    fFitFormat::String
    fStatFormat::String
    fParent
end
function readfields!(c::Cursor, fields, ::Type{TPaveStats_5})
    tkey = c.tkey
    refs = c.refs

    stream!(c, fields, TPaveText)
    stream!(c, fields, TVirtualPaveStats)
    fields[:fOptFit] = readtype(c.io, Int32)
    fields[:fOptStat] = readtype(c.io, Int32)
    fields[:fFitFormat] = readtype(c.io, String)
    fields[:fStatFormat] = readtype(c.io, String)
    fields[:fParent] = readobjany!(c.io, tkey, refs)
end
