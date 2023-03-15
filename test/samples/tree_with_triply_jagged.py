#!/usr/bin/env python
import ROOT as r
f = r.TFile("tree_with_triply_jagged.root", "recreate")
t = r.TTree("t1","t1")
vvvi = r.vector("vector<vector<int>>")()
vvvf = r.vector("vector<vector<float>>")()
t.Branch("bi", vvvi)
t.Branch("bf", vvvf)
data = [
        [[[1,2],[2]], [[3,5]]],
        [[[7,9,11], [13,15,16]]],
        [[[17,18], [19]], []],
        [],
        [[]],
        [[[]]],
        [[[100]]],
        ]
for row in data:
    vvvi.clear()
    vvvf.clear()
    for subrow in row:
        vvi = r.vector("vector<int>")()
        vvf = r.vector("vector<float>")()
        for subsubrow in subrow:
            vi = r.vector("int")()
            vf = r.vector("float")()
            for e in subsubrow:
                vi.push_back(e)
                vf.push_back(e + 0.5)
            vvi.push_back(vi)
            vvf.push_back(vf)
        vvvi.push_back(vvi)
        vvvf.push_back(vvf)
    t.Fill()
t.Write()
f.Close()
