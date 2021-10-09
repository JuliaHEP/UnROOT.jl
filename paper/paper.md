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
    orcid: 0000-
    affiliation: "4"
affiliations:
 - name: Erlangen Centre for Astroparticle Physics
   index: 1
 - name: Friedrich-Alexander-Universität Erlangen-Nürnberg
   index: 2
 - name: Harvard University
   index: 3
date: 08 October 2021
bibliography: paper.bib
---
# Summary
`UnROOT.jl` is a pure Julia implementation of CERN ROOT files I/O (`.root`) that is fast,
memory-efficient, and composes well with Julia's high-performance iteration, array, and
multi-threading interfaces.

# Statement of need
The High-Energy Physics (HEP) community has been troubled by the two-language
problem for a long time. Often, physicists would start prototyping with a
`Python` front-end which glues to a `C/C++/Fortran` back-end. Soon they will hit
a task which is extremely hard to express in columnar (i.e. "vectorized") style,
a type of problems which are normally tackled with libraries like `numpy` or
`pandas`. This usually leads to either writing `C++` kernels and interface it
with `Python`, or, porting the prototype to `C++` and start to maintain two code
bases including the wrapper code. Both options are engineering challenges for
physicists who usually have no or little background in software engineering.

Using a `Python` front-end and dancing across language barriers also hinders the ability
to parallelize tasks that are conceptually trivial most of the time.

`UnROOT.jl` attempts to solve all of the above by choosing Julia, a
high-performance language with simple and expressive syntax. Users can freely
escape to a `for-loop` whenever vectorized-style processing is not flexible
enough, without any performance degradation. At the same time, `UnROOT.jl`
transparently supports multi-threading and multi-processing by simply being a
subtype of `AbstractArray` -- the limit is the sky.

# Features and Functionality


# Comparison with existing software

Julia and other languages...

- UpROOT.jl
- ROOT.jl
- uproot
- ...

# Conclusion

# References

