#!/usr/bin/env python
# Example taken from https://root.cern.ch/how/how-write-ttree-python
# and modified to run...
import ROOT
from ROOT import TFile, TTree
from array import array

f = TFile('tree_with_jagged_array.root', 'recreate')
t = TTree('t1', 'tree with jagged array')

n = ROOT.vector('int')()
t.Branch('int32_array', n)

for i in range(100):
    if i % 10 == 0:
        n.clear()
    t.Fill()
    n.push_back(i)

f.Write()
f.Close()
