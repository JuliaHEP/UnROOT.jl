# the signed ones are not used
@define_integers 96 SignedSwitch Switch
@define_integers 32 SignedIndex32 Index32
@define_integers 64 SignedIndex64 Index64
Base.promote_rule(::Type{Int64}, ::Type{Index64}) = Int64
Base.promote_rule(::Type{Index64}, ::Type{Int64}) = Int64

@kwdef struct RNTuple_ColumnType
    type::UInt8
    nbits::Int
    name::Symbol
    jltype::DataType
    issplit::Bool = false
    isdelta::Bool = false
    iszigzag::Bool = false
end

#https://github.com/root-project/root/blob/1de46e89958fd3946d2d6995c810391b781d39ac/tree/ntuple/v7/doc/BinaryFormatSpecification.md?plain=1#L479
const rntuple_col_type_table = (
RNTuple_ColumnType(type = 0x00, nbits =  1, name = :Bit         , jltype = Bool),
RNTuple_ColumnType(type = 0x01, nbits =  8, name = :Byte        , jltype = UInt8),
RNTuple_ColumnType(type = 0x02, nbits =  8, name = :Char        , jltype = UInt8),
RNTuple_ColumnType(type = 0x03, nbits =  8, name = :Int8        , jltype = Int8 ),
RNTuple_ColumnType(type = 0x04, nbits =  8, name = :UInt8       , jltype = UInt8),
RNTuple_ColumnType(type = 0x05, nbits = 16, name = :Int16       , jltype = Int16),
RNTuple_ColumnType(type = 0x06, nbits = 16, name = :UInt16      , jltype = UInt16),
RNTuple_ColumnType(type = 0x07, nbits = 32, name = :Int32       , jltype = Int32),
RNTuple_ColumnType(type = 0x08, nbits = 32, name = :UInt32      , jltype = UInt32),
RNTuple_ColumnType(type = 0x09, nbits = 64, name = :Int64       , jltype = Int64),
RNTuple_ColumnType(type = 0x0A, nbits = 64, name = :UInt64      , jltype = UInt64),
RNTuple_ColumnType(type = 0x0B, nbits = 16, name = :Real16      , jltype = Float16),
RNTuple_ColumnType(type = 0x0C, nbits = 32, name = :Real32      , jltype = Float32),
RNTuple_ColumnType(type = 0x0D, nbits = 64, name = :Real64      , jltype = Float64),
RNTuple_ColumnType(type = 0x0E, nbits = 32, name = :Index32     , jltype = Index32),
RNTuple_ColumnType(type = 0x0F, nbits = 64, name = :Index64     , jltype = Index64),
RNTuple_ColumnType(type = 0x10, nbits = 96, name = :Switch      , jltype = Switch),
RNTuple_ColumnType(type = 0x11, nbits = 16, name = :SplitInt16  , jltype = Int16, issplit=true, iszigzag=true),
RNTuple_ColumnType(type = 0x12, nbits = 16, name = :SplitUInt16 , jltype = UInt16, issplit=true),
RNTuple_ColumnType(type = 0x13, nbits = 64, name = :SplitInt32  , jltype = Int32, issplit=true, iszigzag=true),
RNTuple_ColumnType(type = 0x14, nbits = 32, name = :SplitUInt32 , jltype = UInt32, issplit=true),
RNTuple_ColumnType(type = 0x15, nbits = 64, name = :SplitInt64  , jltype = Int64, issplit=true, iszigzag=true),
RNTuple_ColumnType(type = 0x16, nbits = 64, name = :SplitUInt64 , jltype = UInt64, issplit=true),
RNTuple_ColumnType(type = 0x17, nbits = 16, name = :SplitReal16 , jltype = Float16, issplit=true),
RNTuple_ColumnType(type = 0x18, nbits = 32, name = :SplitReal32 , jltype = Float32, issplit=true),
RNTuple_ColumnType(type = 0x19, nbits = 64, name = :SplitReal64 , jltype = Float64, issplit=true),
RNTuple_ColumnType(type = 0x1A, nbits = 32, name = :SplitIndex32, jltype = Index32, issplit=true, isdelta=true),
RNTuple_ColumnType(type = 0x1B, nbits = 64, name = :SplitIndex64, jltype = Index64, issplit=true, isdelta=true),
# (0x1C, 10-31, :Real32Trunc  ), #??
# (0x1D,  1-32, :Real32Quant  ), #??
)

# for each Julia type, we pick just one canonical representation for writing
const RNTUPLE_WRITE_TYPE_IDX_DICT = Dict(
    Index64 => (0x0F, sizeof(Index64) * 8),
    Index32 => (0x0E, sizeof(Index32) * 8),
    Char => (0x02, 8),
    Bool => (0x00, 1),
    Float64 => (0x0D, sizeof(Float64) * 8),
    Float32 => (0x0C, sizeof(Float32) * 8),
    Float16 => (0x0B, sizeof(Float16) * 8),
    UInt64 => (0x0A, sizeof(UInt64) * 8),
    UInt32 => (0x08, sizeof(UInt32) * 8),
    UInt16 => (0x06, sizeof(UInt16) * 8),
    UInt8 => (0x04, sizeof(UInt8) * 8),
    Int64 => (0x09, sizeof(Int64) * 8),
    Int32 => (0x07, sizeof(Int32) * 8),
    Int16 => (0x05, sizeof(Int16) * 8),
    Int8 => (0x03, sizeof(Int8) * 8),
)

const RNTUPLE_WRITE_TYPE_CPPNAME_DICT = Dict(
    Bool => "bool",
    Float16 => "std::float16_t",
    Float32 => "float",
    Float64 => "double",
    Int8 => "std::int8_t",
    Int16 => "std::int16_t",
    Int32 => "std::int32_t",
    Int64 => "std::int64_t",
    UInt8 => "std::uint8_t",
    UInt16 => "std::uint16_t",
    UInt32 => "std::uint32_t",
    UInt64 => "std::uint64_t",
)

const rntuple_role_leaf = 0x0000
const rntuple_role_vector = 0x0001
const rntuple_role_struct = 0x0002
const rntuple_role_union = 0x0003
