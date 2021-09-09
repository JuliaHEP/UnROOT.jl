from array import array
import ROOT as r

f = r.TFile("issue87_uncompressed_a.root", "recreate", "", 0) # UNCOMPRESSED!
t = r.TTree("Events", "")
obj = r.vector("float")()
t.Branch("Jet_pt", obj)
for row in [[27.3245, 24.8896, 20.8534], [], [5.3306]]:
    obj.clear()
    for x in row: obj.push_back(x)
    t.Fill()
t.Write()
f.Close()

f = r.TFile("issue87_uncompressed_b.root", "recreate", "", 0) # UNCOMPRESSED!
t = r.TTree("Events", "")

maxn = 10
n = array("i", [0])
d = array("f", maxn * [0.])
t.Branch("mynum", n, "mynum/I")
t.Branch("myval", d, "myval[mynum]/F")

for i in range(25):
    n[0] = min(i, maxn)
    for j in range(n[0]):
        d[j] = i * 0.1 + j
    t.Fill()

t.Write()
f.Close()
