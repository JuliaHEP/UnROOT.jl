/* https://root.cern/doc/master/ntpl001__staff_8C.html */
/* https://github.com/scikit-hep/uproot5/pull/630 */
R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

struct LV{
   float pt;
   float eta;
   float phi;
   float mass;
};

void rntuple_int_vfloat_tlv_vtlv() {
  std::string rootFileName{"test_ntuple_int_vfloat_tlv_vtlv.root"};
  auto model = RNTupleModel::Create();
  auto int_field = model->MakeField<int>("one_integers");
  auto v_float_field = model->MakeField<std::vector<float>>("two_v_floats");
  auto lv_field = model->MakeField<LV>("three_LV");
  auto v_lv_field = model->MakeField<std::vector<LV>>("four_v_LVs");
  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);

  *int_field = 9;
  v_float_field->clear();
  v_float_field->emplace_back(9.0);
  v_float_field->emplace_back(8.0);
  v_float_field->emplace_back(7.0);
  v_float_field->emplace_back(6.0);
  lv_field->pt = 19.0;
  lv_field->eta = 19.0;
  lv_field->phi = 19.0;
  lv_field->mass = 19.0;
  v_lv_field->clear();
  v_lv_field->emplace_back(*lv_field);
  v_lv_field->emplace_back(*lv_field);
  v_lv_field->emplace_back(*lv_field);
  v_lv_field->emplace_back(*lv_field);
  ntuple->Fill();

  *int_field = 8;
  v_float_field->clear();
  v_float_field->emplace_back(5.0);
  v_float_field->emplace_back(4.0);
  v_float_field->emplace_back(3.0);
  lv_field->pt = 18.0;
  lv_field->eta = 18.0;
  lv_field->phi = 18.0;
  lv_field->mass = 18.0;
  v_lv_field->emplace_back(*lv_field);
  v_lv_field->emplace_back(*lv_field);
  v_lv_field->emplace_back(*lv_field);
  ntuple->Fill();

  *int_field = 7;
  v_float_field->clear();
  v_float_field->emplace_back(2.0);
  v_float_field->emplace_back(1.0);
  lv_field->pt = 17.0;
  lv_field->eta = 17.0;
  lv_field->phi = 17.0;
  lv_field->mass = 17.0;
  v_lv_field->emplace_back(*lv_field);
  v_lv_field->emplace_back(*lv_field);
  ntuple->Fill();

  *int_field = 6;
  v_float_field->clear();
  v_float_field->emplace_back(0.0);
  v_float_field->emplace_back(-1.0);
  v_lv_field->emplace_back(*lv_field);
  ntuple->Fill();

  *int_field = 5;
  v_float_field->clear();
  v_float_field->emplace_back(-2.0);
  lv_field->pt = 16.0;
  lv_field->eta = 16.0;
  lv_field->phi = 16.0;
  lv_field->mass = 16.0;
  ntuple->Fill();
}
