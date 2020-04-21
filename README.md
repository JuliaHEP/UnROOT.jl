# ROOTIO.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://tamasgal.github.io/ROOTIO.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tamasgal.github.io/ROOTIO.jl/dev)
[![Build Status](https://travis-ci.com/tamasgal/ROOTIO.jl.svg?branch=master)](https://travis-ci.com/tamasgal/ROOTIO.jl)
[![Codecov](https://codecov.io/gh/tamasgal/ROOTIO.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tamasgal/ROOTIO.jl)

ROOTIO.jl is a reader for the [CERN ROOT](https://root.cern) file format written
entirely in Julia, without depending on any official ROOT libraries. In contrast
to the C++ ROOT framework, this packages focuses only on the parsing of the
binary files and make them available as Julia structures.

While the ROOT documentation does not contain a detailed description of the
binary structure, the format can be triangulated by other packages like

- [uproot](https://github.com/scikit-hep/uproot) (Python)
- [groot](https://godoc.org/go-hep.org/x/hep/groot#hdr-File_layout) (Go)
- [root-io](https://github.com/cbourjau/alice-rs/tree/master/root-io) (Rust)
- [Laurelin](https://github.com/spark-root/laurelin) (Java)
- [ROOT](https://github.com/root-project/root) (Official C++ implementation)

Here is also a short discussion about the [ROOT binary format
documentation](https://github.com/scikit-hep/uproot/issues/401) 

## Status
The project is in early alpha prototyping phase and contributions are very
welcome.

At least the reading of the top level dictionary is already working, but
everything is in a very early alpha stage, as mentioned above:

``` julia
julia> using ROOTIO

julia> f = ROOTFile("test/samples/km3net_online.root")
ROOTFile("test/samples/km3net_online.root") with 10 entries and 56 streamers.

julia> keys(f)
10-element Array{String,1}:
 "JTRIGGER::JTriggerParameters"
 "META"                        
 "E"                           
 "KM3NET_TIMESLICE"            
 "KM3NET_TIMESLICE_L0"         
 "KM3NET_TIMESLICE_L1"         
 "KM3NET_TIMESLICE_L2"         
 "KM3NET_TIMESLICE_SN"         
 "KM3NET_EVENT"                
 "KM3NET_SUMMARYSLICE"         

julia> f.streamers.streamers.objects[1:4]
4-element Array{Any,1}:
 ROOTIO.TStreamerInfo("TNamed", "", 0xdfb74a3c, 1, ROOTIO.TObjArray("", 0, Any[ROOTIO.TStreamerBase(0x0004, 0, "TObject", "Basic ROOT object", 66, 0, 0, 0, Int32[0, -1877229523, 0, 0, 0], "BASE", 0.0, 0.0, 0.0, 1), ROOTIO.TStreamerString(ROOTIO.TStreamerElement(0x0004, 0, "fName", "object identifier", 65, 24, 0, 0, Int32[0, 0, 0, 0, 0], "TString", 0.0, 0.0, 0.0)), ROOTIO.TStreamerString(ROOTIO.TStreamerElement(0x0004, 0, "fTitle", "object title", 65, 24, 0, 0, Int32[0, 0, 0, 0, 0], "TString", 0.0, 0.0, 0.0))]))
 ROOTIO.TStreamerInfo("TObject", "", 0x901bc02d, 1, ROOTIO.TObjArray("", 0, ROOTIO.TStreamerBasicType[ROOTIO.TStreamerBasicType(ROOTIO.TStreamerElement(0x0004, 0, "fUniqueID", "object unique identifier", 13, 4, 0, 0, Int32[0, 0, 0, 0, 0], "unsigned int", 0.0, 0.0, 0.0)), ROOTIO.TStreamerBasicType(ROOTIO.TStreamerElement(0x0004, 0, "fBits", "bit field status word", 15, 4, 0, 0, Int32[0, 0, 0, 0, 0], "unsigned int", 0.0, 0.0, 0.0))]))                                                                                
 ROOTIO.TStreamerInfo("TList", "", 0x69c5c3bb, 5, ROOTIO.TObjArray("", 0, ROOTIO.TStreamerBase[ROOTIO.TStreamerBase(0x0004, 0, "TSeqCollection", "Sequenceable collection ABC", 0, 0, 0, 0, Int32[0, -60015674, 0, 0, 0], "BASE", 0.0, 0.0, 0.0, 0)]))                                                                                                                                                                                                                                                                              
 ROOTIO.TStreamerInfo("TSeqCollection", "", 0xfc6c3bc6, 0, ROOTIO.TObjArray("", 0, ROOTIO.TStreamerBase[ROOTIO.TStreamerBase(0x0004, 0, "TCollection", "Collection abstract base class", 0, 0, 0, 0, Int32[0, 1474546588, 0, 0, 0], "BASE", 0.0, 0.0, 0.0, 3)]))                                                                                                                                                                                                                                                                    

julia> f["KM3NET_TIMESLICE_L2"]
ROOTIO.TKey32(2475, 4, 18062, 0x62db5265, 53, 1, 1593451, 100, "TTree", "KM3NET_TIMESLICE_L2", "")
```

## Main challenges

- ROOT data is generally stored as big endian and is a
  self-descriptive format, i.e. so-called streamers are stored in the files
  which describe the actual structure of the data in the corresponding branches.
  These streamers are read during runtime and need to be used to generate
  Julia structs and `unpack` methods on the fly.
- Performance is very important for a low level I/O library.


## Low hanging fruits

Pick one ;)

- [x] Parsing the file header
- [x] Read the `TKey`s of the top level dictionary
- [ ] Reading the available trees
- [ ] Reading the available streamers
- [ ] Reading a simple dataset with primitive streamers
