#!/usr/bin/env python
# Example taken from https://root.cern.ch/how/how-write-ttree-python
# and modified to run...
"""
Creates a simple ROOT file with a tree containing histograms.

"""
from ROOT import TFile, TTree, TH1F
from array import array

h = TH1F('h1', 'test', 100, -10., 10.)

f = TFile('tree_with_histos.root', 'recreate')
t = TTree('t1', 'tree with histos')

maxn = 10
n = array('i', [0])
d = array('f', maxn * [0.])
t.Branch('mynum', n, 'mynum/I')
t.Branch('myval', d, 'myval[mynum]/F')

for i in range(25):
    n[0] = min(i, maxn)
    for j in range(n[0]):
        d[j] = i * 0.1 + j
    t.Fill()

f.Write()
f.Close()
