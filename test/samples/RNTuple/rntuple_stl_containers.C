/* https://root.cern/doc/master/ntpl001__staff_8C.html */
/* https://github.com/scikit-hep/uproot5/pull/662 */
/* tests a bunch of stl container */

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

void rntuple_stl_containers() {
  std::string rootFileName{"test_ntuple_stl_containers.root"};
  auto model = RNTupleModel::Create();
  auto string = model->MakeField<std::string>("string");
  auto vector_int32 = model->MakeField<std::vector<int32_t>>("vector_int32");
  auto array_float = model->MakeField<std::array<float, 3>>("array_float");
  auto vector_vector_int32 = model->MakeField<std::vector<std::vector<int32_t>>>("vector_vector_int32");
  auto vector_string = model->MakeField<std::vector<std::string>>("vector_string");
  auto vector_vector_string = model->MakeField<std::vector<std::vector<std::string>>>("vector_vector_string");
  auto variant_int32_string = model->MakeField<std::variant<int32_t, std::string>>("variant_int32_string");
  auto vector_variant_int64_string = model->MakeField<std::vector<std::variant<int64_t, std::string>>>("vector_variant_int64_string");
  auto tuple_int32_string = model->MakeField<std::tuple<int32_t, std::string>>("tuple_int32_string");
  auto pair_int32_string = model->MakeField<std::pair<int32_t, std::string>>("pair_int32_string");
  auto vector_tuple_int32_string = model->MakeField<std::vector<std::tuple<int32_t, std::string>>>("vector_tuple_int32_string");

  auto ntuple =
      RNTupleWriter::Recreate(std::move(model), "ntuple", rootFileName);



  *string = "one";
  vector_int32->emplace_back(1);
  *array_float = std::array<float, 3>{1,1,1};
  vector_string->emplace_back("one");
  vector_vector_int32->emplace_back(std::vector<int32_t>{ 1 });
  vector_vector_string->emplace_back(std::vector<std::string>{ "one" });
  *variant_int32_string = 1;
  vector_variant_int64_string->emplace_back("one");
  *tuple_int32_string = std::tuple<int32_t, std::string>({1, "one"});
  *pair_int32_string = std::pair<int32_t, std::string>({1, "one"});
  vector_tuple_int32_string->emplace_back(std::tuple<int32_t, std::string>({1, "one"}));

  ntuple->Fill();

  *string = "two";
  vector_int32->emplace_back(2);
  *array_float = std::array<float, 3>{2,2,2};
  vector_string->emplace_back("two");
  vector_vector_int32->emplace_back(std::vector<int32_t>{ 2 });
  vector_vector_string->emplace_back(std::vector<std::string>{ "two" });
  *variant_int32_string = "two";
  vector_variant_int64_string->emplace_back(2);
  *tuple_int32_string = std::tuple<int32_t, std::string>({2, "two"});
  *pair_int32_string = std::pair<int32_t, std::string>({2, "two"});
  vector_tuple_int32_string->emplace_back(std::tuple<int32_t, std::string>({2, "two"}));
  ntuple->Fill();

  *string = "three";
  vector_int32->emplace_back(3);
  *array_float = std::array<float, 3>{3,3,3};
  vector_string->emplace_back("three");
  vector_vector_int32->emplace_back(std::vector<int32_t>{ 3 });
  vector_vector_string->emplace_back(std::vector<std::string>{ "three" });
  *variant_int32_string = "three";
  vector_variant_int64_string->emplace_back(3);
  *tuple_int32_string = std::tuple<int32_t, std::string>({3, "three"});
  vector_tuple_int32_string->emplace_back(std::tuple<int32_t, std::string>({3, "three"}));
  *pair_int32_string = std::pair<int32_t, std::string>({3, "three"});
  ntuple->Fill();

  *string = "four";
  vector_int32->emplace_back(4);
  *array_float = std::array<float, 3>{4,4,4};
  vector_string->emplace_back("four");
  vector_vector_int32->emplace_back(std::vector<int32_t>{ 4 });
  vector_vector_string->emplace_back(std::vector<std::string>{ "four" });
  *variant_int32_string = 4;
  vector_variant_int64_string->emplace_back(4);
  *tuple_int32_string = std::tuple<int32_t, std::string>({4, "four"});
  *pair_int32_string = std::pair<int32_t, std::string>({4, "four"});
  vector_tuple_int32_string->emplace_back(std::tuple<int32_t, std::string>({4, "four"}));
  ntuple->Fill();

  *string = "five";
  vector_int32->emplace_back(5);
  *array_float = std::array<float, 3>{5,5,5};
  vector_string->emplace_back("five");
  vector_vector_int32->emplace_back(std::vector<int32_t>{ 5 });
  vector_vector_string->emplace_back(std::vector<std::string>{ "five" });
  *variant_int32_string = 5;
  vector_variant_int64_string->emplace_back(5);
  *tuple_int32_string = std::tuple<int32_t, std::string>({5, "five"});
  *pair_int32_string = std::pair<int32_t, std::string>({5, "five"});
  vector_tuple_int32_string->emplace_back(std::tuple<int32_t, std::string>({5, "five"}));
  ntuple->Fill();
}
