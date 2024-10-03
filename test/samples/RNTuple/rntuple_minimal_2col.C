R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;
using RNTupleWriteOptions = ROOT::Experimental::RNTupleWriteOptions;

void rntuple_minimal_2col() {
  auto writeOptions = RNTupleWriteOptions();
  writeOptions.SetCompression(0);

  std::string rootFileName1{"test_ntuple_minimal.root"};
  auto model1 = RNTupleModel::Create();
  auto field1 = model1->MakeField<uint32_t>("one_uint");
  auto field2 = model1->MakeField<uint32_t>("two_uint");
  auto ntuple1 =
      RNTupleWriter::Recreate(std::move(model1), "myntuple", rootFileName1, writeOptions);
  // 0xcececece
  *field1 = 3469659854;
  // 0xabababab
  *field2 = 2880154539;
  ntuple1->Fill();
}
