#include "TString.h"
#include "TFile.h"
#include "TTree.h"

#include <string>
#include "stdlib.h"

int create_a_tree() {

  TFile *f = new TFile("issue11_tdirectory.root", "recreate");
  f->mkdir("Data");
  f->cd("Data");  
  TTree *t = new TTree("mytree", "mytree");

  auto app = "EXYZ";
  const uint Np = 10;

  //
  double v[Np][4];
  for (uint n=0; n<Np; n++) {
    for (uint i=0; i<4; i++) {
      t->Branch(TString::Format("Particle%d_%c", n, app[i]), &v[n][i]);
    }
  }

  const int Nev = 23;
  double inc = 0.0;

  for (uint i=0; i<Nev; i++) {
    for (uint n=0; n<Np; n++) {
      for (uint i=0; i<4; i++) {
	v[n][i] = inc;
        inc += 0.1;
      }
    }
    t->Fill();
  }

  t->Write();
  f->Close();

  return 0;
}

