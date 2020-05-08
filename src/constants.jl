module Const

const kByteCountMask  = Int64(0x40000000)
const kByteCountVMask = Int64(0x4000)
const kClassMask      = Int64(0x80000000)
const kNewClassTag    = Int64(0xFFFFFFFF)

const kIsOnHeap       = UInt32(0x01000000)
const kIsReferenced   = UInt32(16)

const kMapOffset      = 2

const kNullTag              = 0
const kNotDeleted           = UInt32(0x02000000)
const kZombie               = UInt32(0x04000000)
const kBitMask              = UInt32(0x00FFFFFF)
const kDisplacementMask     = UInt32(0xFF000000)

# core/zip/inc/Compression.h
const kZLIB                 = 1
const kLZMA                 = 2
const kOldCompressionAlgo   = 3
const kLZ4                  = 4
const kZSTD                 = 5
const kUndefinedCompressionAlgorithm = 6

# constants for streamers
const kBase                 = 0
const kChar                 = 1
const kShort                = 2
const kInt                  = 3
const kLong                 = 4
const kFloat                = 5
const kCounter              = 6
const kCharStar             = 7
const kDouble               = 8
const kDouble32             = 9
const kLegacyChar           = 10
const kUChar                = 11
const kUShort               = 12
const kUInt                 = 13
const kULong                = 14
const kBits                 = 15
const kLong64               = 16
const kULong64              = 17
const kBool                 = 18
const kFloat16              = 19
const kOffsetL              = 20
const kOffsetP              = 40
const kObject               = 61
const kAny                  = 62
const kObjectp              = 63
const kObjectP              = 64
const kTString              = 65
const kTObject              = 66
const kTNamed               = 67
const kAnyp                 = 68
const kAnyP                 = 69
const kAnyPnoVT             = 70
const kSTLp                 = 71

const kSkip                 = 100
const kSkipL                = 120
const kSkipP                = 140

const kConv                 = 200
const kConvL                = 220
const kConvP                = 240

const kSTL                  = 300
const kSTLstring            = 365

const kStreamer             = 500
const kStreamLoop           = 501


# TBranchElement fTypes
# https://groups.google.com/d/msg/polyglot-root-io/yeC0mAizQcA/zuUHOFBABwAJ

const kTopLevelTClonesArray   = 3
const kSubbranchTClonesArray  = 31
const kTopLevelSTLCollection  = 4
const kSubbranchSTLCollection = 41

# constants from core/foundation/inc/ESTLType.h

const kNotSTL               = 0
const kSTLvector            = 1
const kSTLlist              = 2
const kSTLdeque             = 3
const kSTLmap               = 4
const kSTLmultimap          = 5
const kSTLset               = 6
const kSTLmultiset          = 7
const kSTLbitset            = 8
const kSTLforwardlist       = 9
const kSTLunorderedset      = 10
const kSTLunorderedmultiset = 11
const kSTLunorderedmap      = 12
const kSTLunorderedmultimap = 13
const kSTLend               = 14
const kSTLany               = 300

# IOFeatures

const kGenerateOffsetMap    = 1

end
