<img style="height:9em;" alt="UnROOT.jl" src="docs/src/assets/unroot.svg"/>

<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-8-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
[![JOSS](https://joss.theoj.org/papers/bab42b0c60f9dc7ef3b8d6460bc7229c/status.svg)](https://joss.theoj.org/papers/bab42b0c60f9dc7ef3b8d6460bc7229c)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliahep.github.io/UnROOT.jl/dev)
[![Build Status](https://github.com/JuliaHEP/UnROOT.jl/workflows/CI/badge.svg)](https://github.com/JuliaHEP/UnROOT.jl/actions)
[![Codecov](https://codecov.io/gh/JuliaHEP/UnROOT.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaHEP/UnROOT.jl)

UnROOT.jl is a reader for the [CERN ROOT](https://root.cern) file format
written entirely in Julia, without any dependence on ROOT or Python.

## Important API changes in v0.9.0
<details><summary>Click to expand exmaple for RNTuple</summary>
<p>

We decided to alter the behaviour of `getindex(f::ROOTfile, s::AbstractString)` which is essentially
the method called called when `f["foo/bar"]` is used. Before `v0.9.0`, `UnROOT` tried to do a best guess
and return a tree/branch or even fully parsed data. This lead to two bigger issues.

  1. Errors prevented any further exploration once `UnROOT` bumped into something it could not interpret, although it might not even be requested by the user (e.g. the interpretation of a single branch in a tree, while others would work fine)
  2. Unpredictable behaviour (type instability): the path dictates which type of data is returned.

Starting from `v0.9.0` we introduce an interface where `f["..."]` always returns genuine ROOT datatypes (or custom ones if you provide interpretations) and only perfroms the actual parsing when explicitly requested by the user via helper methods like `LazyBranch(f, "...")`.

Long story short, the following pattern can be used to fix your code when upgrading to `v0.9.0`:

    f("foo/bar") => LazyBranch(f, "foo/bar")
    
The `f["foo/bar"]` accessor should now work on almost all files and is a handy utility to explore the ROOT data structures.

See [PR199](https://github.com/JuliaHEP/UnROOT.jl/pull/199) for more details.
</p>
</details>
  
## Installation Guide
1. Download the latest [Julia release](https://julialang.org/downloads/)
2. Open up Julia REPL (hit `]` once to enter Pkg mode, hit backspace to exit it)
```julia
julia>]
(v1.8) pkg> add UnROOT
```
## Quick Start (see [docs](https://JuliaHEP.github.io/UnROOT.jl/dev/) for more)

### TTree
```julia
julia> using UnROOT

julia> f = ROOTFile("test/samples/NanoAODv5_sample.root")
ROOTFile with 2 entries and 21 streamers.
test/samples/NanoAODv5_sample.root
├─ Events (TTree)
│  ├─ "run"
│  ├─ "luminosityBlock"
│  ├─ "event"
│  ├─ "⋮"
│  ├─ "L1_UnpairedBunchBptxPlus"
│  ├─ "L1_ZeroBias"
│  └─ "L1_ZeroBias_copy"
└─ untagged (TObjString)


julia> mytree = LazyTree(f, "Events", ["Electron_dxy", "nMuon", r"Muon_(pt|eta)$"])
 Row │ Electron_dxy                      nMuon   Muon_pt          Muon_eta        
     │ SubArray{Float3                   UInt32  SubArray{Float3  SubArray{Float3 
─────┼────────────────────────────────────────────────────────────────────────────
 1   │ [0.000371]                        0       []               []
 2   │ [-0.00982]                        2       [19.9, 15.3]     [0.53, 0.229]
 3   │ []                                0       []               []
 4   │ [-0.00157]                        0       []               []
 5   │ []                                0       []               []
 6   │ [-0.00126]                        0       []               []
 7   │ [0.0612, 0.000642]                2       [22.2, 4.43]     [-1.13, 1.98]
 8   │ [0.00587, 0.000549, -0.00617]     0       []               []
  ⋮  │                ⋮                    ⋮            ⋮                ⋮
                                                                  992 rows omitted
```

### RNTuple
<details><summary>Click to expand exmaple for RNTuple</summary>
<p>

```julia
julia> using UnROOT

julia> f = ROOTFile("./test/samples/RNTuple/test_ntuple_stl_containers.root");

julia> f["ntuple"]
UnROOT.RNTuple with 5 rows, 13 fields, and metadata:
  header: 
    name: "ntuple"
    ntuple_description: ""
    writer_identifier: "ROOT v6.29/01"
    schema: 
      RNTupleSchema with 13 top fields
      ├─ :lorentz_vector ⇒ Struct
      ├─ :vector_tuple_int32_string ⇒ Vector
      ├─ :string ⇒ String
      ├─ :vector_string ⇒ Vector
      ├─ :vector_vector_int32 ⇒ Vector
      ├─ :vector_variant_int64_string ⇒ Vector
      ├─ :vector_vector_string ⇒ Vector
      ├─ :variant_int32_string ⇒ Union
      ├─ :array_float ⇒ StdArray{3}
      ├─ :tuple_int32_string ⇒ Struct
      ├─ :array_lv ⇒ StdArray{3}
      ├─ :pair_int32_string ⇒ Struct
      └─ :vector_int32 ⇒ Vector
      
  footer: 
    cluster_summaries: UnROOT.ClusterSummary[ClusterSummary(num_first_entry=0, num_entries=5)]

julia> LazyTree(f, "ntuple")
 Row │ string  vector_int32     array_float      vector_vector_i     vector_string       vector_vector_s     variant_int32_s  vector_variant_     ⋯
     │ String  Vector{Int32}    StaticArraysCor  Vector{Vector{I     Vector{String}      Vector{Vector{S     Union{Int32, St  Vector{Union{In     ⋯
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 1   │ one     [1]              [1.0, 1.0, 1.0]  Vector{Int32}[Int3  ["one"]             [["one"]]           1                Union{Int64, Strin  ⋯
 2   │ two     [1, 2]           [2.0, 2.0, 2.0]  Vector{Int32}[Int3  ["one", "two"]      [["one"], ["two"]]  two              Union{Int64, Strin  ⋯
 3   │ three   [1, 2, 3]        [3.0, 3.0, 3.0]  Vector{Int32}[Int3  ["one", "two", "th  [["one"], ["two"],  three            Union{Int64, Strin  ⋯
 4   │ four    [1, 2, 3, 4]     [4.0, 4.0, 4.0]  Vector{Int32}[Int3  ["one", "two", "th  [["one"], ["two"],  4                Union{Int64, Strin  ⋯
 5   │ five    [1, 2, 3, 4, 5]  [5.0, 5.0, 5.0]  Vector{Int32}[Int3  ["one", "two", "th  [["one"], ["two"],  5                Union{Int64, Strin  ⋯
                                                                                                                                  5 columns omitted
```
   
</p>
</details>

### LazyTree as unified table / iteration interface
You can iterate through a `LazyTree`:
```julia
julia> for event in mytree
           @show event.Electron_dxy
           break
       end
event.Electron_dxy = Float32[0.00037050247]

julia> Threads.@threads for event in mytree # multi-threading
           ...
       end
```

Only one basket per branch will be cached so you don't have to worry about running out of RAM.
At the same time, `event` inside the for-loop is not materialized until a field is accessed. This means you should avoid double-access, 
see [performance tips](https://juliahep.github.io/UnROOT.jl/dev/performancetips/#Don't-%22double-access%22)

XRootD is also supported, depending on the protocol:
-   the "url" has to start with `http://` or `https://`:
-   (1.6+ only) or the "url" has to start with `root://` and have another `//` to separate server and file path
```julia
julia> r = ROOTFile("https://scikit-hep.org/uproot3/examples/Zmumu.root")
ROOTFile with 1 entry and 18 streamers.
https://scikit-hep.org/uproot3/examples/Zmumu.root
└─ events (TTree)
   ├─ "Type"
   ├─ "Run"
   ├─ "Event"
   ├─ "⋮"
   ├─ "phi2"
   ├─ "Q2"
   └─ "M"

julia> r = ROOTFile("root://eospublic.cern.ch//eos/root-eos/cms_opendata_2012_nanoaod/Run2012B_DoubleMuParked.root")
ROOTFile with 1 entry and 19 streamers.
root://eospublic.cern.ch//eos/root-eos/cms_opendata_2012_nanoaod/Run2012B_DoubleMuParked.root
└─ Events (TTree)
   ├─ "run"
   ├─ "luminosityBlock"
   ├─ "event"
   ├─ "⋮"
   ├─ "Electron_dxyErr"
   ├─ "Electron_dz"
   └─ "Electron_dzErr"

```

## TBranch of custom struct

We provide an experimental interface for hooking up UnROOT with your custom types
that only takes 2 steps, as explained [in the docs](https://JuliaHEP.github.io/UnROOT.jl/dev/advanced/custom_branch/).
As a show case for this functionality, the `TLorentzVector` support in UnROOT is implemented
with the said plug-in system.

## Support & Contributiing
- Use Github issues for any bug reporting or feature request; feel free to make PRs, 
bug fixing, feature tuning, quality of life, docs, examples etc.
- See `CONTRIBUTING.md` for more information and recommended workflows in contributing to this package.

<!-- 
## TODOs

- [x] Parsing the file header
- [x] Read the `TKey`s of the top level dictionary
- [x] Reading the available trees
- [x] Reading the available streamers
- [x] Reading a simple dataset with primitive streamers
- [x] Reading of raw basket bytes for debugging
- [ ] Automatically generate streamer logic
- [x] Prettier `show` for `Lazy*`s
- [ ] Clean up `Cursor` use
- [x] Reading `TNtuple` #27
- [x] Reading histograms (`TH1D`, `TH1F`, `TH2D`, `TH2F`, etc.) #48
- [ ] Clean up the `readtype`, `unpack`, `stream!` and `readobjany` construct
- [ ] Refactor the code and add more docs
- [ ] Class name detection of sub-branches
- [ ] High-level histogram interface -->

## Acknowledgements

Special thanks to Jim Pivarski ([@jpivarski](https://github.com/jpivarski))
from the [Scikit-HEP](https://github.com/scikit-hep) project, who is the
main author of [uproot](https://github.com/scikit-hep/uproot), a native
Python library to read and write ROOT files, which was and is a great source
of inspiration and information for reverse engineering the ROOT binary
structures.


## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://www.tamasgal.com"><img src="https://avatars.githubusercontent.com/u/1730350?v=4?s=100" width="100px;" alt="Tamas Gal"/><br /><sub><b>Tamas Gal</b></sub></a><br /><a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=tamasgal" title="Code">💻</a> <a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=tamasgal" title="Documentation">📖</a> <a href="#infra-tamasgal" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#data-tamasgal" title="Data">🔣</a> <a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=tamasgal" title="Tests">⚠️</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Moelf"><img src="https://avatars.githubusercontent.com/u/5306213?v=4?s=100" width="100px;" alt="Jerry Ling"/><br /><sub><b>Jerry Ling</b></sub></a><br /><a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=Moelf" title="Code">💻</a> <a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=Moelf" title="Tests">⚠️</a> <a href="#data-Moelf" title="Data">🔣</a> <a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=Moelf" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/8me"><img src="https://avatars.githubusercontent.com/u/17862090?v=4?s=100" width="100px;" alt="Johannes Schumann"/><br /><sub><b>Johannes Schumann</b></sub></a><br /><a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=8me" title="Code">💻</a> <a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=8me" title="Tests">⚠️</a> <a href="#data-8me" title="Data">🔣</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/aminnj"><img src="https://avatars.githubusercontent.com/u/5760027?v=4?s=100" width="100px;" alt="Nick Amin"/><br /><sub><b>Nick Amin</b></sub></a><br /><a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=aminnj" title="Code">💻</a> <a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=aminnj" title="Tests">⚠️</a> <a href="#data-aminnj" title="Data">🔣</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://giordano.github.io"><img src="https://avatars.githubusercontent.com/u/765740?v=4?s=100" width="100px;" alt="Mosè Giordano"/><br /><sub><b>Mosè Giordano</b></sub></a><br /><a href="#infra-giordano" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/oschulz"><img src="https://avatars.githubusercontent.com/u/546147?v=4?s=100" width="100px;" alt="Oliver Schulz"/><br /><sub><b>Oliver Schulz</b></sub></a><br /><a href="#ideas-oschulz" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/mmikhasenko"><img src="https://avatars.githubusercontent.com/u/22725744?v=4?s=100" width="100px;" alt="Misha Mikhasenko"/><br /><sub><b>Misha Mikhasenko</b></sub></a><br /><a href="#data-mmikhasenko" title="Data">🔣</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://yuan-ru-lin.github.io"><img src="https://avatars.githubusercontent.com/u/7196133?v=4?s=100" width="100px;" alt="Yuan-Ru Lin"/><br /><sub><b>Yuan-Ru Lin</b></sub></a><br /><a href="https://github.com/JuliaHEP/UnROOT.jl/commits?author=Yuan-Ru-Lin" title="Tests">⚠️</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
