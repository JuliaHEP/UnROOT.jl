"""
Generate a ROOT file with branches of all unsigned integer types.
Used by UnROOT.jl tests to verify correct unsigned type reading.

Run with:
    python unsigned_integers.py
or:
    root -l -q unsigned_integers.py
"""
from array import array
import ROOT as r

f = r.TFile("unsigned_integers.root", "recreate")
t = r.TTree("tree", "Tree with all unsigned integer types")

b_uint8  = array('B', [0])
b_uint16 = array('H', [0])
b_uint32 = array('I', [0])
b_uint64 = array('Q', [0])

# type codes: b=UChar_t, s=UShort_t, i=UInt_t, l=ULong64_t
t.Branch("b_uint8",  b_uint8,  "b_uint8/b")
t.Branch("b_uint16", b_uint16, "b_uint16/s")
t.Branch("b_uint32", b_uint32, "b_uint32/i")
t.Branch("b_uint64", b_uint64, "b_uint64/l")

rows = [
    (200,  60000, 4000000000, 18000000000000000000),
    (255,  65535, 4294967295, 18446744073709551615),
    (1,    1,     1,          1),
]

for u8, u16, u32, u64 in rows:
    b_uint8[0]  = u8
    b_uint16[0] = u16
    b_uint32[0] = u32
    b_uint64[0] = u64
    t.Fill()

t.Write()
f.Close()
print("Written unsigned_integers.root")
