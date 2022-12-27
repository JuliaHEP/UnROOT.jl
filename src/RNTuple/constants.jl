#https://github.com/root-project/root/blob/master/tree/ntuple/v7/doc/specifications.md
const rntuple_col_type_dict = Base.ImmutableDict(
    1  => UInt64,
    2  => UInt32,
    3  => UInt64, # Switch
    4  => UInt8,
    5  => UInt8,  # char
    6  => Bool,   # it's actually `Bit` in ROOT, there's no byte in RNTuple spec
    7  => Float64,
    8  => Float32,
    9  => Float16,
    10 => Int64,
    11 => Int32,
    12 => Int16,
    13 => Int8,
    14 => UInt32,  # SplitIndex64 delta encoding
    15 => UInt64,  # SplitIndex32 delta encoding
    16 => Float64, # split
    17 => Float32, # split
    18 => Float16, # split
    19 => Int64,  # split
    20 => Int32,  # split
    21 => Int16,  # split
)

const rntuple_role_leaf = 0
const rntuple_role_vector = 1
const rntuple_role_struct = 2
const rntuple_role_union = 3
