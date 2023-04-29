#!/usr/bin/env python

import ROOT

t = ROOT.TNtupleD('n1', '', 'x:y')
t.Fill(0.0, 0.0)
t.Fill(1.0, 1.0)

f = ROOT.TFile('TNtupleD.root', 'recreate')
t.Write()
f.Close()

