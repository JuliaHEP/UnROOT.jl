# the signed ones are not used
@define_integers 96 SignedSwitch Switch
@define_integers 32 SignedIndex32 Index32
@define_integers 64 SignedIndex64 Index64

#https://github.com/root-project/root/blob/master/tree/ntuple/v7/doc/specifications.md
const rntuple_col_type_dict = (
    Index64,
    Index32,
    Switch, # Switch
    UInt8,  # byte in blob
    UInt8,  # char
    Bool,   # it's actually `Bit` in ROOT, there's no byte bool in RNTuple spec
    Float64,
    Float32,
    Float16,
    UInt64,
    UInt32,
    UInt16,
    UInt8,
    Index64, # split delta
    Index32, # split delta
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
const rntuple_col_nbits_dict = Tuple([(sizeof.(rntuple_col_type_dict[1:5]) .* 8) ...; 1; (sizeof.(rntuple_col_type_dict[7:end]) .* 8)...])

const rntuple_role_leaf = 0x0000
const rntuple_role_vector = 0x0001
const rntuple_role_struct = 0x0002
const rntuple_role_union = 0x0003
