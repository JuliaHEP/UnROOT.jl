R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

void rntuple_nanoAOD_importer() {
    auto importer = ROOT::Experimental::RNTupleImporter::Create("./Run2012BC_DoubleMuParked_Muons.root", "Events", "./Run2012BC_DoubleMuParked_Muons_rntuple_1000evts.root");
    auto c = importer.get();
    c->SetMaxEntries(1000);
    c->Import();
}
