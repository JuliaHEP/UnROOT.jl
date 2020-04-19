#!/usr/bin/env python
# Example taken from https://root.cern.ch/how/how-write-ttree-python
"""
Creates a simple ROOT file with a tree containing instances of a custom struct.

"""
from ROOT import TFile, TTree
from ROOT import gROOT, AddressOf

gROOT.ProcessLine("struct MyStruct {\
   Int_t     fMyInt1;\
   Int_t     fMyInt2;\
   Int_t     fMyInt3;\
   Char_t    fMyCode[4];\
};")

from ROOT import MyStruct
mystruct = MyStruct()

f = TFile('tree_with_custom_struct.root', 'RECREATE')
tree = TTree('T', 'Just A Tree')
tree.Branch('myints', mystruct, 'MyInt1/I:MyInt2:MyInt3')
tree.Branch('mycode', AddressOf(mystruct, 'fMyCode'), 'MyCode/C')

for i in range(10):
    mystruct.fMyInt1 = i
    mystruct.fMyInt2 = i * i
    mystruct.fMyInt3 = i * i * i
    mystruct.fMyCode = "%03d" % i  # note string assignment

    tree.Fill()

f.Write()
f.Close()
