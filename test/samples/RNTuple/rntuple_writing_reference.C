R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

void rntuple_writing_reference() {
  std::string rootFileName{"test_ntuple_writing_reference.root"};
  auto model = RNTupleModel::Create();
  auto one_integers = model->MakeField<int32_t>("one_integers");
  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);
      *one_integers = 5;
      ntuple->Fill();
      *one_integers = 4;
      ntuple->Fill();
      *one_integers = 3;
      ntuple->Fill();
      *one_integers = 2;
      ntuple->Fill();
      *one_integers = 1;
      ntuple->Fill();
}
