import ROOT as r

f = r.TFile("tree_cycles_hist.root", "recreate")
t = r.TTree("Events", "")

obj = r.vector("float")()
t.Branch("Jet_pt", obj)
rows = [[], [27.324586868286133, 24.88954734802246, 20.853023529052734], [], [20.330659866333008], [], []]
for i,row in enumerate(rows):
    obj.clear()
    for x in row:
        obj.push_back(x)
    t.Fill()
    if i == 3:
        t.Write()


th1f = r.TH1F("myTH1F", "", 2, -2, 2)
th1d = r.TH1D("myTH1D", "", 2, -2, 2)
th2f = r.TH2F("myTH2F", "", 2, -2, 2, 4, -2, 2)
th2d = r.TH2D("myTH2D", "", 2, -2, 2, 4, -2, 2)

for x,y,w in [
        [-1.5, -1.5, 20.0],
        [+1.5, +1.5, 1.0],
        [-1.5, +1.5, 20.0],
        [+1.5, -1.5, 1.0],
        ]:
    th1f.Fill(x, w)
    th1d.Fill(x, w)
    th2f.Fill(x, y, w)
    th2d.Fill(x, y, w)

f.Write()
f.Close()
