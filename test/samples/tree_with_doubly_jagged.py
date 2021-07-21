#!/usr/bin/env python
import ROOT as r
f = r.TFile("tree_with_doubly_jagged.root", "recreate")
t = r.TTree("t1","t1")
vvi = r.vector("vector<int>")()
vvf = r.vector("vector<float>")()
t.Branch("bi", vvi)
t.Branch("bf", vvf)
data = [
        [[2], [3,5]],
        [[7,9,11], [13]],
        [[17], [19], []],
        [],
        [[]],
        ]
for row in data:
    vvi.clear()
    vvf.clear()
    for subrow in row:
        vi = r.vector("int")()
        vf = r.vector("float")()
        for e in subrow:
            vi.push_back(e)
            vf.push_back(e + 0.5)
        vvi.push_back(vi)
        vvf.push_back(vf)
    t.Fill()
t.Write()
f.Close()
