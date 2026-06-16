R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

#include <iostream>
#include <vector>
#include <set>
#include <variant>
#include <tuple>

struct LV{
   float pt;
   float eta;
   float phi;
   float mass;
};

void rntuple_soa() {
  std::string rootFileName{"test_ntuple_soa.root"};
  auto model = RNTupleModel::Create();
  auto vec_lv = model->MakeField<std::vector<LV>>("vec_lv");

  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);

  for ( float i=0.0; i<2; i++ ){
      vec_lv->emplace_back(LV{i,i,i});
  }
  ntuple->Fill();

  vec_lv->clear();
  for ( float i=0.0; i<5; i++ ){
      vec_lv->emplace_back(LV{i,i,i});
  }
  ntuple->Fill();
}
