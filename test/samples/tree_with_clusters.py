#!/usr/bin/env python
import ROOT as r

f = r.TFile("tree_with_clusters.root", "recreate")
t = r.TTree("t1","t1")
v1 = r.vector("int")()
v2 = r.vector("int")()
t.Branch("b1", v1, 500) # default bufsize is 32000, but making sure
t.Branch("b2", v2, 1000) # default bufsize is 32000, but making sure
t.SetAutoFlush(10000)
for irow in range(2500):
    v1.clear()
    v2.clear()
    for e in [irow+q for q in range(2)]:
        v1.push_back(e)
        v2.push_back(e+1)
    t.Fill()
t.Write()
f.Close()
