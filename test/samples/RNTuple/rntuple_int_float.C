/* https://root.cern/doc/master/ntpl001__staff_8C.html */
R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

void rntuple_int_float() {
  std::string rootFileName{"test_ntuple_int_float.root"};
  auto model = RNTupleModel::Create();
  auto int_field = model->MakeField<int>("one_integers");
  auto float_field = model->MakeField<float>("two_floats");
  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);

  *int_field = 9;
  *float_field = 9.9;
  ntuple->Fill();

  *int_field = 8;
  *float_field = 8.8;
  ntuple->Fill();

  *int_field = 7;
  *float_field = 7.7;
  ntuple->Fill();

  *int_field = 6;
  *float_field = 6.6;
  ntuple->Fill();

  *int_field = 5;
  *float_field = 5.5;
  ntuple->Fill();

  *int_field = 4;
  *float_field = 4.4;
  ntuple->Fill();

  *int_field = 3;
  *float_field = 3.3;
  ntuple->Fill();

  *int_field = 2;
  *float_field = 2.2;
  ntuple->Fill();

  *int_field = 1;
  *float_field = 1.1;
  ntuple->Fill();

  *int_field = 0;
  *float_field = 0.0;
  ntuple->Fill();
}
