#https://github.com/root-project/root/blob/master/tree/ntuple/v7/doc/specifications.md
const rntuple_col_type_dict = (
    UInt64,
    UInt32,
    UInt64, # Switch
    UInt8,
    UInt8,  # char
    Bool,   # it's actually `Bit` in ROOT, there's no byte in RNTuple spec
    Float64,
    Float32,
    Float16,
    Int64,
    Int32,
    Int16,
    Int8,
    UInt32,  # SplitIndex64 delta encoding
    UInt64,  # SplitIndex32 delta encoding
    Float64, # split
    Float32, # split
    Float16, # split
    Int64,  # split
    Int32,  # split
    Int16,  # split
)
const rntuple_col_nbits_dict = (
    64,
    32,
    64, # Switch
    8,
    8,  # char
    1,   # it's actually `Bit` in ROOT, there's no byte in RNTuple spec
    64,
    32,
    16,
    64,
    32,
    16,
    8,
    32,  # SplitIndex64 delta encoding
    64,  # SplitIndex32 delta encoding
    64, # split
    32, # split
    16, # split
    64,  # split
    32,  # split
    16,  # split
)

const rntuple_role_leaf = 0
const rntuple_role_vector = 1
const rntuple_role_struct = 2
const rntuple_role_union = 3
