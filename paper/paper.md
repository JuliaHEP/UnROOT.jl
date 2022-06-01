---
title: 'UnROOT: an I/O library for the CERN ROOT file format written in Julia'
tags:
  - Julia
  - HEP
authors:
  - name: Tamás Gál
    orcid: 0000-0001-7821-8673
    affiliation: "1, 2"
  - name: Jerry (Jiahong) Ling
    orcid: 0000-0002-3359-0380
    affiliation: "3"
  - name: Nick Amin
    orcid: 0000-0003-2560-0013
    affiliation: "4"
affiliations:
 - name: Erlangen Centre for Astroparticle Physics
   index: 1
 - name: Friedrich-Alexander-Universität Erlangen-Nürnberg
   index: 2
 - name: Harvard University
   index: 3
 - name: University of California, Santa Barbara
   index: 4
date: 08 October 2021
bibliography: paper.bib
---
# Summary
`UnROOT.jl` is a pure Julia implementation of CERN ROOT[@Brun:1997pa] files I/O
(`.root`) that is fast, memory-efficient, and composes well with Julia's
high-performance iteration, array, and multi-threading interfaces.

# Statement of need
The High-Energy Physics (HEP) community has been troubled by the two-language
problem for a long time. Often, physicists would start prototyping with a
`Python` front-end which glues to a `C/C++/Fortran` back-end. Soon they will hit
a task which is extremely hard to express in columnar (i.e. "vectorized") style,
a type of problems which are normally tackled with libraries like
`numpy`[@harris2020array] or `pandas`[@reback2020pandas]. This usually leads to
either writing `C++` kernels and interface them with `Python`, or porting the
prototype to `C++` and start to maintain two code bases including the wrapper
code. Both options are engineering challenges for physicists who usually have no
or little background in software engineering. Many steps of this process are
critical, like identifying bottlenecks, creating an architecture which is both
performant and maintainable at the same time while still being user-friendly and
logically structured. Using a `Python` front-end and dancing across language
barriers also hinders the ability to parallelize tasks that are conceptually
trivial most of the time.

`UnROOT.jl` attempts to solve all of the above by choosing Julia, a
high-performance language with simple and expressive syntax [@Julia]. Julia is
designed to solve the two-language problem in general. This has been studied for
HEP specifically as well[@JuliaPerformance]. Analysis software written in Julia
can freely escape to a `for-loop` whenever vectorized-style processing is not
flexible enough, without any performance degradation. At the same time,
`UnROOT.jl` transparently supports multi-threading and multi-processing by
simply providing data structures which are a subtype of `AbstractArray`, the
built-in abstract type for array-like objects, which allows to interface with
array-routines from other packages easily, thanks to multiple dispatch, one of
the main features of Julia.

# Features and Functionality

The `ROOT` dataformat is flexible and mostly self-descriptive. Users can define
their own data structures (C++ classes) which derive from `ROOT` classes and
serialise them into directories, trees and branches. The information about the
deserialisation is written to the output file (therfore: self-descriptive) but
there are some basic structures and constants needed to bootstrap the parsing
process.

`UnROOT.jl` understands the core structure of `ROOT` files and is able to
deserialize instances of the commonly used `TH1`, `TH2`, `TDirectory`, and
`TTree` ROOT classes. All basic C++ types for `TTree` branches are supported,
including their nested variants. Additionally, `UnROOT.jl` provides a way to
hook into the deserialisation of custom types, where the automatic parsing
fails. Opening and loading a `TTree` lazily -- i.e. without reading the whole
data into memory -- is simple:

```julia
julia> using UnROOT

julia> f = ROOTFile("test/samples/NanoAODv5_sample.root")
ROOTFile with 2 entries and 21 streamers.
test/samples/NanoAODv5_sample.root
   Events
      "run"
      "luminosityBlock"
      "event"
      "HTXS_Higgs_pt"
      "HTXS_Higgs_y"
      ...

julia> mytree = LazyTree(f, "Events", ["Electron_dxy", "nMuon", r"Muon_(pt|eta)$"])
 Row   Electron_dxy     nMuon   Muon_eta         Muon_pt
       Vector{Float32}  UInt32  Vector{Float32}  Vector{Float32}

 1     [0.000371]       0       []               []
 2     [-0.00982]       2       [0.53, 0.229]    [19.9, 15.3]
 3     []               0       []               []
 4     [-0.00157]       0       []               []
       ...
```

Then, the `LazyTree` object acts as a table which suports sequential or parallel
iteration, selectections and filtering based on ranges or masks, and operations
on whole columns:

```julia
for event in mytree
    # ... Operate on event
end

Threads.@threads for event in mytree # multi-threading
    # ... Operate on event
end

mytree.Muon_pt # whole column as a lazy vector of vectors
```

The `LazyTree` is designed as `<: AbstractArray` which makes it compose well
with the rest of the Julia ecosystem. For example, syntactic loop fusion [^1] or
Query-style tabular manipulations provided by packages like `Query.jl` without
any additional code support just work out-of-the-box.

# Comparison with existing software

This section focusses on the comparison with other existing ROOT I/O solutions
in the Julia universe, however, one honorable mention is `uproot`
[@jim_pivarski_2021_5539722], which is a purely Python-based ROOT I/O library
and played (still plays) an important role for the development of `UnROOT.jl` as
it is by the time of writing the most complete and best documented ROOT I/O
implementation.

`UpROOT.jl` is a wrapper for `uproot` and uses `PyCall` as a bridge. (TODO:
problems of Julia->PyWrapper->Awkward)

- ROOT.jl
- ...



_ (?) Generic statement like: `UpROOT.jl` has demonstrated tree processing
speeds at the same level as the `C++` `ROOT` framework as well as the
Python-based `uproot` library _

# Conclusion

# References


[^1]: https://julialang.org/blog/2017/01/moredots/
