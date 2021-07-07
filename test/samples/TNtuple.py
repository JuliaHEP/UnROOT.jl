#!/usr/bin/env python
# Example taken from https://root.cern.ch/how/how-write-ttree-python
# and modified to run...
"""
Creates a simple ROOT file with a tree containing a branch with a large array.

"""
from ROOT import TFile, TNtuple
from array import array

f = TFile('TNtuple.root', 'recreate')
t = TNtuple('n1', 'ntuple with 3 columes', "x:y:z")

x = array('i', [0])
y = array('f', [0])
z = array('d', [0])

for i in range(100):
    x[0] = i
    y[0] = i + i / 13
    z[0] = i + i / 17
    t.Fill(x[0], y[0], z[0])
f.Write()
f.Close()
