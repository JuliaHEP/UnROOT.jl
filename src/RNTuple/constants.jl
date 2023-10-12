# the signed ones are not used
@define_integers 64 SignedSwitch Switch
@define_integers 32 SignedIndex32 Index32
@define_integers 64 SignedIndex64 Index64

#https://github.com/root-project/root/blob/master/tree/ntuple/v7/doc/specifications.md
const rntuple_col_type_dict = (
    Index64,
    Index32,
    Switch, # Switch
    UInt8,  # byte in blob
    UInt8,  # char
    Bool,   # it's actually `Bit` in ROOT, there's no byte in RNTuple spec
    Float64,
    Float32,
    Float16,
    UInt64,
    UInt32,
    UInt16,
    UInt8,
    Index64, # split delta encoding
    Index32, # split
    Float64, # split
    Float32, # split
    Float16, # split
    UInt64,  # split
    UInt32,  # split
    UInt16,  # split

    Int64,  
    Int32,  
    Int16,  
    Int8,   
    Int64,  # split + Zig-Zag encoding
    Int32,  # split + Zig-Zag encoding
    Int16,  # split + Zig-Zag encoding
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
    64,  # SplitIndex64 delta encoding
    32,  # SplitIndex32 delta encoding
    64, # split
    32, # split
    16, # split
    64,  # split
    32,  # split
    16,  # split

    64,
    32,
    16,
    8,
    64,  # split + Zig-Zag encoding
    32,  # split + Zig-Zag encoding
    16,  # split + Zig-Zag encoding
)

const rntuple_role_leaf = 0x0000
const rntuple_role_vector = 0x0001
const rntuple_role_struct = 0x0002
const rntuple_role_union = 0x0003
