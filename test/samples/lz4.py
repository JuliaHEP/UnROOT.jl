#!/usr/bin/env python
# Example taken from https://root.cern.ch/how/how-write-ttree-python
# and modified to run...
"""
Creates a simple ROOT file with a tree containing a branch with a large array.

"""
from ROOT import TFile, TTree
from array import array

f = TFile('tree_with_large_array_lz4.root', 'recreate', "filename", 401)
t = TTree('t1', 'tree with large array')

n = array('i', [0])
t.Branch('int32_array', n, 'large_array/I')
m = array('f', [0])
t.Branch('float_array', m, 'large_array/F')

for i in range(100_000):
    n[0] = i
    m[0] = i + i / 17
    t.Fill()

f.Write()
f.Close()
