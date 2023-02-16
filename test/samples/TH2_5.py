import ROOT as r
f = r.TFile("TH2_5.root", "recreate")
th2f = r.TH2F("myTH2F", "", 10, -2, 2, 10, -2, 2)
for x,y,w in [
        [-1.5, -1.5, 20.0],
        [+1.5, +1.5, 1.0],
        [-1.5, +1.5, 20.0],
        [+1.5, -1.5, 1.0],
        ]:
    th2f.Fill(x, y, w)
f.Write()
f.Close()
