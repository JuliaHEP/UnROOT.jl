R__LOAD_LIBRARY(ROOTNTuple)
#include <ROOT/RField.hxx>
#include <ROOT/RNTuple.hxx>
#include <ROOT/RNTupleModel.hxx>
#include <ROOT/RRawFile.hxx>

using RNTupleModel = ROOT::Experimental::RNTupleModel;
using RNTupleWriter = ROOT::Experimental::RNTupleWriter;

void rntuple_split_3e4() {
    std::string rootFileName{"test_ntuple_split_3e4.root"};
    auto model = RNTupleModel::Create();
    auto splitint_field = model->MakeField<int32_t>("one_int32");
    auto splitint_field2 = model->MakeField<uint32_t>("two_uint32");
    auto splitint_field3 = model->MakeField<std::vector<float>>("three_vint32");


    auto ntuple = RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);
    for(auto i=30000; i>0; i--){
        // 0x04030201
        *splitint_field = 67305985;
        // 0xffddccbb
        *splitint_field2 = 4293844428;
        // 0x3dccbbaa
        splitint_field3->emplace_back(0.099967316);
        if (i % 10 == 0){
            splitint_field3->clear();
        }
        ntuple->Fill();
    }
}
