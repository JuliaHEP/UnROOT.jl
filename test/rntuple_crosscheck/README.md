# RNTuple cross-check against uproot

Development tooling (not run by the test suite) to compare every field of every
RNTuple in a file between UnROOT and [uproot](https://github.com/scikit-hep/uproot5).

```bash
python -m venv .venv && .venv/bin/pip install uproot awkward scikit-hep-testdata
# dump the first 300 entries of every field with uproot
.venv/bin/python dump_uproot.py path/to/file.root file.json 300
# compare with UnROOT (the Julia environment needs UnROOT and JSON)
julia --project=<env> compare_uproot.jl path/to/file.root file.json 300
```

`scikit-hep-testdata` ships the RNTuple files used by uproot's own tests
(`skhep_testdata.known_files` matching `rntuple`/`ntpl`); as of September 2026
all 25 of them agree with UnROOT field by field.
