R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;
using RNTupleWriteOptions = ROOT::Experimental::RNTupleWriteOptions;

void rntuple_minimal() {
  std::string rootFileName1{"test_ntuple_min1.root"};
  auto model1 = RNTupleModel::Create();
  auto field1 = model1->MakeField<int>("one_int");
  auto writeOptions = RNTupleWriteOptions();
  writeOptions.SetCompression(0);
  auto ntuple1 =
      RNTupleWriter::Recreate(std::move(model1), "ntuple", rootFileName1, writeOptions);
  // 0xcccccc
  *field1 = 13421772;
  ntuple1->Fill();
  ntuple1->Fill();

  std::string rootFileName2{"test_ntuple_min2.root"};
  auto model2 = RNTupleModel::Create();
  auto field2 = model2->MakeField<int>("one_int");
  auto ntuple2 =
      RNTupleWriter::Recreate(std::move(model2), "ntuple", rootFileName2, writeOptions);
      // 0xeeeeee
  *field2 = 15658734;
  ntuple2->Fill();
  ntuple2->Fill();
}
