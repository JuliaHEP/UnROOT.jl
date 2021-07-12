#!/usr/bin/env python
import ROOT as r
from array import array

f = r.TFile("lorentzvector.root", "recreate")
t = r.TTree("t1","t1")

#x y z e
p4 = r.TLorentzVector(1, 2, 3, 4)
t.Branch("LV", "TLorentzVector", p4)
t.Fill()

for i in range(1, 4):
     x = 10**i
     p4.SetPxPyPzE(1*x, 2*x, 3*x, 4*x)
     t.Fill()

t.Write()
f.Close()
