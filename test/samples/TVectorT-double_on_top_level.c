#include <TFile.h>
#include <TVectorT.h>

int main() {
  TFile* file = new TFile("example.root", "RECREATE");
  TVectorT<double>* vec = new TVectorT<double>(3);
  (*vec)[0] = 1.1;
  (*vec)[1] = 2.2;
  (*vec)[2] = 3.3;

  TDirectory* dir = file->GetDirectory("/");
  dir->WriteObject(vec, "vector_double");

  file->Close();

  return 0;
}
