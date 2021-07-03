# A collection of bootstrapped code which should be generated
# dynamically in future.

abstract type TNamed <: ROOTStreamedObject end
struct TNamed_1 <: TNamed end
function readfields!(io, fields, ::Type{TNamed_1})
    parsefields!(io, fields, TObject)
    fields[:fName] = readtype(io, String)
    fields[:fTitle] = readtype(io, String)
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

abstract type TBranchElement <: ROOTStreamedObject end
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

# FIXME preliminary TTree implementation
function TTree(io, tkey::TKey, refs)
    io = datastream(io, tkey)

    @initparse

    preamble = Preamble(io, Missing)
    # @show preamble

    stream!(io, fields, TNamed)

    stream!(io, fields, TAttLine)
    stream!(io, fields, TAttFill)
    stream!(io, fields, TAttMarker)

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
    while !eof(io)
        read(io, 1)
    end
    # unpack(io, tkey, refs, Undefined)
    # println(fields[:fBranches])

    endcheck(io, preamble)
    TTree(;fields...)
end

# FIXME what to do with auto.py's massive type translation?
# https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/interp/auto.py#L360-L365
