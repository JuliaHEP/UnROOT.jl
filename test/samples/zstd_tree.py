# Run this with a newer version of ROOT
# Otherwise zstd isn't available and the
# 505 will fall back to zlib
from ROOT import TFile, TTree
from array import array

f = TFile('tree_with_int_array_zstd.root', 'recreate', "filename", 505)
t = TTree('t1', '')

n = array('i', [0])
t.Branch('a', n, 'a/I')

for i in range(100):
    n[0] = i
    t.Fill()

f.Write()
f.Close()
