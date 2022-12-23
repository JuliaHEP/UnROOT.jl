/* https://root.cern/doc/master/ntpl001__staff_8C.html */
/* this file tests when we have multiple pages, each page stores 65536 bytes,
 * thus we need to make it longer */
/* https://github.com/scikit-hep/uproot5/pull/630 */

R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

void rntuple_int_5e4() {
  std::string rootFileName{"test_ntuple_int_5e4.root"};
  auto model = RNTupleModel::Create();
  auto int_field = model->MakeField<int>("one_integers");
  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);
  for(auto i=50000; i>0; i--){
      *int_field = i;
      ntuple->Fill();
  }
}
