#!/usr/bin/env python
# Example taken from https://root.cern.ch/how/how-write-ttree-python
# and modified to run...
"""
Creates a simple ROOT file with a tree containing a branch with a large array.

"""
from ROOT import TFile, TTree
from array import array

f = TFile('tree_with_large_array.root', 'recreate')
t = TTree('t1', 'tree with large array')

n = array('i', [0])
t.Branch('large_array', n, 'large_array/I')

for i in range(100_000):
    n[0] = i
    t.Fill()

f.Write()
f.Close()
