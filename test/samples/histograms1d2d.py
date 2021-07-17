#!/usr/bin/env python
import ROOT as r
import array

f = r.TFile("histograms1d2d.root", "recreate")

th1f = r.TH1F("myTH1F", "", 2, -2, 2)
th1d = r.TH1D("myTH1D", "", 2, -2, 2)
th2f = r.TH2F("myTH2F", "", 2, -2, 2, 4, -2, 2)
th2d = r.TH2D("myTH2D", "", 2, -2, 2, 4, -2, 2)
th1d_nonuniform = r.TH1D("myTH1D_nonuniform", "", 2, array.array("d", [-2,1.0,2.0]))

for x,y,w in [
        [-1.5, -1.5, 20.0],
        [+1.5, +1.5, 1.0],
        [-1.5, +1.5, 20.0],
        [+1.5, -1.5, 1.0],
        ]:
    th1f.Fill(x, w)
    th1d.Fill(x, w)
    th1d_nonuniform.Fill(x, w)
    th2f.Fill(x, y, w)
    th2d.Fill(x, y, w)

f.Write()
f.Close()

import uproot3
f = uproot3.open("histograms1d2d.root")

def summarize(h):
    print("-"*20)
    print("h._fName =", h._fName)
    print("h._fEntries =", h._fEntries)
    print("h._fSumw2 =", h._fSumw2)
    print("h._fXaxis._fXmin =", h._fXaxis._fXmin)
    print("h._fXaxis._fXmax =", h._fXaxis._fXmax)
    print("h._fXaxis._fXbins =", h._fXaxis._fXbins)
    print("h._fXaxis._fNbins =", h._fXaxis._fNbins)
    if b"TH2" in h._fName:
        print("h._fYaxis._fXmin =", h._fXaxis._fXmin)
        print("h._fYaxis._fXmax =", h._fXaxis._fXmax)
        print("h._fYaxis._fXbins =", h._fXaxis._fXbins)
        print("h._fYaxis._fNbins =", h._fXaxis._fNbins)
    print("numpy =", h.numpy())
    print("-"*20)
    print()

for v in f.values():
    summarize(v)
