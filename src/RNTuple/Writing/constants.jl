const RNTUPLE_WRITE_TYPE_IDX_DICT = Dict(
    Float64 => (0x10, sizeof(UInt64) * 8),
    Float32 => (0x11, sizeof(UInt32) * 8),
    Float16 => (0x12, sizeof(UInt16) * 8),
    UInt64 => (0x0A, sizeof(UInt64) * 8),
    UInt32 => (0x0B, sizeof(UInt32) * 8),
    UInt16 => (0x0C, sizeof(UInt16) * 8),
    Int64 => (0x16, sizeof(Int64) * 8),
    Int32 => (0x17, sizeof(Int32) * 8),
    Int16 => (0x18, sizeof(Int16) * 8),
    Int8 => (0x19, sizeof(Int8) * 8),
)

const RNTUPLE_WRITE_TYPE_CPPNAME_DICT = Dict(
    Float16 => "std::float16_t",
    Float32 => "std::float32_t",
    Float64 => "std::float64_t",
    Int8 => "std::int8_t",
    Int16 => "std::int16_t",
    Int32 => "std::int32_t",
    Int64 => "std::int64_t",
    UInt16 => "std::uint16_t",
    UInt32 => "std::uint32_t",
    UInt64 => "std::uint64_t",
)
