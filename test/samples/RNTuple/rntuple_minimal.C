R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>


using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;
using RNTupleWriteOptions = ROOT::Experimental::RNTupleWriteOptions;

void rntuple_minimal() {
  auto writeOptions = RNTupleWriteOptions();
  writeOptions.SetCompression(0);
  writeOptions.SetContainerFormat(ROOT::Experimental::ENTupleContainerFormat::kBare);

  std::string rootFileName1{"test_ntuple_min1.root"};
  auto model1 = RNTupleModel::Create();
  auto field1 = model1->MakeField<uint32_t>("one_uint");
  auto ntuple1 =
      RNTupleWriter::Recreate(std::move(model1), "ntuple", rootFileName1, writeOptions);
  // 0xcccccccc
  *field1 = 3435973836;
  ntuple1->Fill();

  std::string rootFileName2{"test_ntuple_min2.root"};
  auto model2 = RNTupleModel::Create();
  auto field2 = model2->MakeField<uint32_t>("one_uint");
  auto ntuple2 =
      RNTupleWriter::Recreate(std::move(model2), "ntuple", rootFileName2, writeOptions);
      // 0xeeeeee
  *field2 = 4008636142;
  ntuple2->Fill();
}
