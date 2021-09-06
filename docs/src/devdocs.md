## Related Projects
While the ROOT documentation does not contain a detailed description of the
binary structure, the format can be triangulated by other packages like

- [uproot3](https://github.com/scikit-hep/uproot) (Python), see also [UpROOT.jl](https://github.com/JuliaHEP/UpROOT.jl/)
- [groot](https://godoc.org/go-hep.org/x/hep/groot#hdr-File_layout) (Go)
- [root-io](https://github.com/cbourjau/alice-rs/tree/master/root-io) (Rust)
- [Laurelin](https://github.com/spark-root/laurelin) (Java)

Here's a detailed [from-scratch walk through](https://jiling.web.cern.ch/jiling/dump/ROOT_Fileformat.pdf) 
on reading a jagged branch from a ROOT file, recommended for first time contributors or those who just want to learn
about ROOT file format.

Three's also a [discussion](https://github.com/scikit-hep/uproot/issues/401) reagarding the ROOT binary format
documentation on uproot's issue page.
