/* https://root.cern/doc/master/ntpl001__staff_8C.html */
R__LOAD_LIBRARY(ROOTNTuple);
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

void rntuple_1jag_int_float() {
  std::string rootFileName{"test_ntuple_1jag_int_float.root"};
  auto model = RNTupleModel::Create();
  auto v_int = model->MakeField<std::vector<int>>("one_v_integers");
  auto v_float = model->MakeField<std::vector<float>>("two_v_floats");
  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);

  for (int i = 100; i > 0; i--) {
      if (i % 10 == 0){
          v_int->clear();
          v_float->clear();
      }
      ntuple->Fill();
      v_int->emplace_back(i);
      v_float->emplace_back(i / 10.0);
  }
}
