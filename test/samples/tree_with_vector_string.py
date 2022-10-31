#!/usr/bin/env python
import ROOT as r
f = r.TFile("tree_with_vector_string.root", "recreate")
t = r.TTree("t1","t1")
vi = r.vector("string")()
t.Branch("vs", vi)
data = [
        ["ab"],
        ["bcc", "cdd"],
        ["Weight",
        "MEWeight",
        "WeightNormalisation",
        "NTrials",
        "UserHook",
        "MUR0.5_MUF0.5_PDF303200_PSMUR0.5_PSMUF0.5",
        "ME_ONLY_MUR0.5_MUF0.5_PDF303200_PSMUR0.5_PSMUF0.5",
        "MUR0.5_MUF1_PDF303200_PSMUR0.5_PSMUF1",
        "ME_ONLY_MUR0.5_MUF1_PDF303200_PSMUR0.5_PSMUF1",
        "MUR1_MUF0.5_PDF303200_PSMUR1_PSMUF0.5"]
        ]
for row in data:
    vi.clear()
    for string in row:
        vi.push_back(string)
    t.Fill()
t.Write()
f.Close()
