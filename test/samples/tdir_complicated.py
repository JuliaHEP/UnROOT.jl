import ROOT

# Structure is like this
# - a
# - b
# - mydir:
#     - c
#     - d
#     - Events:
#         - Jet_pt
#     - mysubdir:
#         - e
#         - f

f = ROOT.TFile("tdir_complicated.root", "recreate")

ROOT.TH1F("a", "", 2, -2, 2).Write()
ROOT.TH1F("b", "", 2, -2, 2).Write()

f.mkdir("mydir")
f.cd("mydir")

t = ROOT.TTree("Events", "")
obj = ROOT.vector("float")()
t.Branch("Jet_pt", obj)
rows = [[], [27.324586868286133, 24.88954734802246, 20.853023529052734], [], [20.330659866333008], [], []]
for i,row in enumerate(rows):
    obj.clear()
    for x in row:
        obj.push_back(x)
    t.Fill()
t.Write()


ROOT.TH1F("c", "", 2, -2, 2).Write()
ROOT.TH1F("d", "", 2, -2, 2).Write()

f.mkdir("mydir/mysubdir")
f.cd("mydir/mysubdir")

ROOT.TH1F("e", "", 2, -2, 2).Write()
ROOT.TH1F("f", "", 2, -2, 2).Write()

f.Close()
