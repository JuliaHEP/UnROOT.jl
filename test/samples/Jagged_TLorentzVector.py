#!/usr/bin/env python
import ROOT as r
from array import array

f = r.TFile("Jagged_TLorentzVector.root", "recreate")
t = r.TTree("t1","t1")

#x y z e
p4s = r.vector(r.TLorentzVector)()
t.Branch("LVs", p4s)
t.Fill()

for i in range(1, 30):
    if i % 10 == 0:
        p4s.clear()
    x = 10**i
    p4s.push_back(r.TLorentzVector(1*x, 2*x, 3*x, 4*x))
    t.Fill()

t.Write()
f.Close()
