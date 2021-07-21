#!/usr/bin/env python
import ROOT as r

f = r.TFile("tree_with_vector_multiple_baskets.root", "recreate")
t = r.TTree("t1","t1")
vi = r.vector("int")()
t.Branch("b1", vi, 32000) # default bufsize is 32000, but making sure
for irow in range(2500):
    vi.clear()
    for e in [irow+q for q in range(2)]:
        vi.push_back(e)
    t.Fill()
t.Write()
f.Close()

