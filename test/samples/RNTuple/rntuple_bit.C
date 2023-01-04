R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

void rntuple_bit() {
  std::string rootFileName{"test_ntuple_bit.root"};
  auto model = RNTupleModel::Create();
  auto bit_field = model->MakeField<bool>("one_bit");
  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);
      *bit_field = 1;
      ntuple->Fill();
      *bit_field = 0;
      ntuple->Fill();
      *bit_field = 0;
      ntuple->Fill();
      *bit_field = 1;
      ntuple->Fill();

      *bit_field = 0;
      ntuple->Fill();
      *bit_field = 0;
      ntuple->Fill();

      *bit_field = 1;
      ntuple->Fill();
      *bit_field = 0;
      ntuple->Fill();
      *bit_field = 0;
      ntuple->Fill();
      *bit_field = 1;
      ntuple->Fill();
}
