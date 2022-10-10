#include "TFile.h"
#include "TTree.h"

int maketree(){
    TFile f("tree_with_varfix_doubly_jagged.root", "RECREATE", "");
    TTree tree = TTree("outtree", "outtree");
    int nparticles{};
    double P[100][4];
    tree.Branch("nparticles", &nparticles, "nparticles/I");
    tree.Branch("P", P, "P[nparticles][4]/D");
    double counter1 = 1;
    double counter2 = 1;
    for (auto ev = 0; ev<3; ++ev){
        nparticles = 4-ev;
        for (auto i = nparticles; i>=0; --i){
            counter1 += 3;
            for (auto j = 0; j<=3; ++j){
                P[i][j] = counter1 / (counter2);
                counter2++;
            }
        }
        tree.Fill();
    }
    f.Write();
    f.Close();
    return 0;
}
