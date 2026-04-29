#include "TFile.h"
#include "TTree.h"

// Generates a tiny file with a TTreeIndex (TTreeIndex_2 layout via
// BuildIndex with both major and minor names).
//
//   root -b -q ttreeindex.C
int ttreeindex() {
    TFile f("ttreeindex.root", "RECREATE");
    TTree t("t", "t");
    Int_t   major;
    Int_t   minor;
    Float_t val;
    t.Branch("major", &major);
    t.Branch("minor", &minor);
    t.Branch("val",   &val);

    const Int_t majors[] = {3, 1, 2, 1, 3, 2};
    const Int_t minors[] = {1, 2, 1, 1, 2, 2};
    for (int i = 0; i < 6; ++i) {
        major = majors[i];
        minor = minors[i];
        val   = static_cast<Float_t>(i) + 0.5f;
        t.Fill();
    }

    t.BuildIndex("major", "minor");
    t.Write();
    f.Close();
    return 0;
}
