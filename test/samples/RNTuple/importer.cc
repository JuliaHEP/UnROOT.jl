/* https://opendata.cern.ch/record/12341 */
auto importer = ROOT::Experimental::RNTupleImporter::Create("./Run2012BC_DoubleMuParked_Muons.root", "Events", "./Run2012BC_DoubleMuParked_Muons_rntuple_1000evts.root");
auto c = importer.get();
c->SetMaxEntries(1000);
c->Import()

/* https://github.com/JuliaHEP/UnROOT.jl/issues/331 */
/* https://gist.github.com/Moelf/1c9bf1d3ea176c0958605afcaa9c606a */
