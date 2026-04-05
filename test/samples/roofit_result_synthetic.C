#include <RooArgList.h>
#include <RooFitResult.h>
#include <RooRealVar.h>
#include <TFile.h>
#include <TMatrixDSym.h>

#include <string>
#include <utility>
#include <vector>

namespace {

RooFitResult *make_result(const char *name, bool with_covariance)
{
  RooRealVar init_x("x", "x", 1.0);
  RooRealVar init_y("y", "y", -2.0);
  init_x.setError(0.3);
  init_y.setError(0.4);
  RooArgList init(init_x, init_y);

  RooRealVar final_x("x", "x", 1.5);
  RooRealVar final_y("y", "y", -1.5);
  final_x.setError(2.0);
  final_y.setError(3.0);
  RooArgList final(final_x, final_y);

  auto *result = new RooFitResult(name, name);
  result->setStatus(3);
  result->setCovQual(with_covariance ? 3 : 0);
  result->setNumInvalidNLL(2);
  result->setMinNLL(12.5);
  result->setEDM(0.125);
  result->setInitParList(init);
  result->setFinalParList(final);

  std::vector<std::pair<std::string, int>> history{
      {"MIGRAD", 3},
      {"HESSE", with_covariance ? 0 : 4},
  };
  result->setStatusHistory(history);

  if (with_covariance) {
    TMatrixDSym cov(2);
    cov(0, 0) = 4.0;
    cov(1, 1) = 9.0;
    cov(0, 1) = 3.0;
    cov(1, 0) = 3.0;

    TMatrixDSym cor(2);
    cor(0, 0) = 1.0;
    cor(1, 1) = 1.0;
    cor(0, 1) = 0.5;
    cor(1, 0) = 0.5;

    std::vector<double> global_corr{0.8, 0.9};
    result->fillCorrMatrix(global_corr, cor, cov);
  }

  return result;
}

} // namespace

void RooFitResult_write(const char *output = "roofit_result_synthetic.root")
{
  TFile file(output, "RECREATE");

  auto *full = make_result("fit_full", true);
  auto *nocov = make_result("fit_nocov", false);

  file.WriteObject(full, "fit_full");
  file.WriteObject(nocov, "fit_nocov");

  delete full;
  delete nocov;
}

int main(int argc, char **argv)
{
  RooFitResult_write(argc > 1 ? argv[1] : "roofit_result_synthetic.root");
  return 0;
}
