# ROOTIO.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://tamasgal.github.io/ROOTIO.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tamasgal.github.io/ROOTIO.jl/dev)
[![Build Status](https://travis-ci.com/tamasgal/ROOTIO.jl.svg?branch=master)](https://travis-ci.com/tamasgal/ROOTIO.jl)
[![Codecov](https://codecov.io/gh/tamasgal/ROOTIO.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tamasgal/ROOTIO.jl)

ROOTIO.jl is a (WIP) reader for the [CERN ROOT](https://root.cern) file format
written entirely in Julia, without depending on any official ROOT libraries.
In contrast to the C++ ROOT framework, this packages focuses only on parsing of
the files.

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
everything is in a very early alpha stage, as mentioned above. Here is a quick
demo of reading a simple branch containing a vector of integers using the
preliminary high-level API:

```julia
julia> using ROOTIO

julia> f = ROOTFile("test/samples/tree_with_histos.root")
ROOTFile("test/samples/tree_with_histos.root") with 1 entry and 4 streamers.

julia> array(f, "t1/mynum")
25-element Array{Int32,1}:
  0
  1
  2
  3
  4
  5
  6
  7
  8
  9
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
```

There is also a `raw` keyword which you can pass to `array()`, so it will skip
the interpretation and return the raw bytes. This is similar to `uproot.asdebug`
and can be used to read data where the streamers are not available (yet).
Here is it in action, using some data from the KM3NeT experiment:

``` julia
julia> using ROOTIO

julia> f = ROOTFile("test/samples/km3net_online.root")
ROOTFile("test/samples/km3net_online.root") with 10 entries and 41 streamers.

julia> array(f, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits"; raw=true)
2058-element Array{UInt8,1}:
 0x00
 0x03
 0x00
 0x01
 0x00
   ⋮
 0x56
 0x45
 0x4e
 0x54
 0x00
```

This is what happens behind the scenes with some additional debug output:

``` julia
julia> using ROOTIO

julia> f = ROOTFile("test/samples/tree_with_histos.root")
Compressed stream at 1509
ROOTFile("test/samples/tree_with_histos.root") with 1 entry and 4 streamers.

julia> keys(f)
1-element Array{String,1}:
 "t1"

julia> keys(f["t1"])
Compressed datastream of 1317 bytes at 1509 (TKey 't1' (TTree))
2-element Array{String,1}:
 "mynum"
 "myval"

julia> f["t1"]["mynum"]
Compressed datastream of 1317 bytes at 6180 (TKey 't1' (TTree))
ROOTIO.TBranch
  cursor: ROOTIO.Cursor
  fName: String "mynum"
  fTitle: String "mynum/I"
  fFillColor: Int16 0
  fFillStyle: Int16 1001
  fCompress: Int32 101
  fBasketSize: Int32 32000
  fEntryOffsetLen: Int32 0
  fWriteBasket: Int32 1
  fEntryNumber: Int64 25
  fIOFeatures: ROOTIO.ROOT_3a3a_TIOFeatures
  fOffset: Int32 0
  fMaxBaskets: UInt32 0x0000000a
  fSplitLevel: Int32 0
  fEntries: Int64 25
  fFirstEntry: Int64 0
  fTotBytes: Int64 170
  fZipBytes: Int64 116
  fBranches: ROOTIO.TObjArray
  fLeaves: ROOTIO.TObjArray
  fBaskets: ROOTIO.TObjArray
  fBasketBytes: Array{Int32}((10,)) Int32[116, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  fBasketEntry: Array{Int64}((10,)) [0, 25, 0, 0, 0, 0, 0, 0, 0, 0]
  fBasketSeek: Array{Int64}((10,)) [238, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  fFileName: String ""


julia> seek(f.fobj, 238)
IOStream(<file test/samples/tree_with_histos.root>)

julia> basketkey = ROOTIO.unpack(f.fobj, ROOTIO.TKey)
ROOTIO.TKey64(116, 1004, 100, 0x6526eafb, 70, 0, 238, 100, "TBasket", "mynum", "t1")

julia> s = ROOTIO.datastream(f.fobj, basketkey)
Compressed datastream of 100 bytes at 289 (TKey 'mynum' (TBasket))
IOBuffer(data=UInt8[...], readable=true, writable=false, seekable=true, append=false, size=100, maxsize=Inf, ptr=1, mark=-1)

julia> [ROOTIO.readtype(s, Int32) for _ in 1:f["t1"]["mynum"].fEntries]
Compressed datastream of 1317 bytes at 6180 (TKey 't1' (TTree))
25-element Array{Int32,1}:
  0
  1
  2
  3
  4
  5
  6
  7
  8
  9
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
 10
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
- [x] Reading the available trees
- [ ] Reading the available streamers
- [x] Reading a simple dataset with primitive streamers
- [x] Reading of raw basket bytes for debugging
- [ ] Automatically generate streamer logic

## Acknowledgements

Special thanks to Jim Pivarski ([@jpivarski](https://github.com/jpivarski))
from the [Scikit-HEP](https://github.com/scikit-hep) project, who is the
main author of [uproot](https://github.com/scikit-hep/uproot), a native
Python library to read and write ROOT files, which was and is a great source
of inspiration and information for reverse engineering the ROOT binary
structures.
