import ROOT as r

# https://github.com/tamasgal/UnROOT.jl/issues/61
# needs to be run in a specific environment to trigger the issue
# in the first place

f = r.TFile("issue61.root", "recreate")
t = r.TTree("Events", "")

obj = r.vector("float")()
t.Branch("Jet_pt", obj)

rows = [[], [27.324586868286133, 24.88954734802246, 20.853023529052734], [], [20.330659866333008], [], []]
for row in rows:
    obj.clear()
    for x in row:
        obj.push_back(x)
    t.Fill()
t.Write()
f.Close()
