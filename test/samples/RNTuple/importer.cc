root [0] auto importer = ROOT::Experimental::RNTupleImporter::Create("./Run2012BC_DoubleMuParked_Muons.root", "Events", "./Run2012BC_DoubleMuParked_Muons_rntuple_1000evts.root");
root [2] auto c = importer.get();
root [4] c->SetMaxEntries(1000);
root [5] c->Import()
