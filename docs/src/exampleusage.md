## Chunk Iteration
```julia
t = LazyTree(...)
res = 0.0
for rang in Iterators.partition(1:lastindex(t), 10^6)
    res += sum(t[rang].nMuon) #
end
res
```
Note, `t[rang]` is eager, if you don't need all branches, it's much better to use `t.nMuon[rang]`, or limit which
branches are selected during `LazyTree()` creation time.

This pattern works the best over network, for local files, stick with:
```
for evt in t
    ...
end
```
usually is the best approach.


## Writing out `.root` files

### Write out an `RNTuple` (native)
`UnROOT.jl` writes RNTuples natively. Any [Tables.jl](https://github.com/JuliaData/Tables.jl)
table whose columns hold numbers, `Bool`s, `String`s or (nested) `Vector`s of these can be
written; the files are readable by UnROOT itself, [uproot](https://github.com/scikit-hep/uproot5)
and ROOT (≥ 6.34). The one-shot form writes a single RNTuple into a fresh file:

```julia
julia> using UnROOT

julia> table = (x = collect(1.0:5.0), s = ["a", "b", "c", "d", "e"], v = [rand(Int32, i) for i in 1:5]);

julia> open(io -> UnROOT.write_rntuple(io, table; rntuple_name="events"), "example.root", "w")

julia> LazyTree("example.root", "events")
```

The incremental interface follows the shape of uproot's writing API: open a file with
[`UnROOT.recreate`](@ref) (or [`UnROOT.create`](@ref), which refuses to overwrite), assign
tables to names to create RNTuples, and `append!` to add clusters. Re-open an existing file
with [`UnROOT.update`](@ref) to keep appending later, or to add further RNTuples to it:

```julia
julia> UnROOT.recreate("example.root") do f
           f["events"] = table                      # first cluster
           append!(f["events"], table)              # second cluster
           UnROOT.mkrntuple(f, "meta", (run = Int32, tag = String))   # empty RNTuple
       end

julia> UnROOT.update("example.root") do f
           append!(f["events"], table)              # third cluster
           append!(f["meta"], (run = Int32[1], tag = ["v1"]))
           length(f["events"])
       end
15
```

Each `append!` writes one cluster, so favour a few large appends over many small ones.
Appending works on RNTuples written by ROOT or uproot as well, as long as their schema
only uses the types listed above (the compression of the file is reused unless `update`
is given a `compression` keyword). See the docstrings of [`UnROOT.write_rntuple`](@ref),
[`UnROOT.mkrntuple`](@ref) and [`UnROOT.WritableROOTFile`](@ref) for details and limitations.

### Write out a `TTree` (via Python)
Writing `TTree`s is not implemented natively, but it's semi-trivial to leverage Python
for that since it's not performance critical.

You have the following choice:
- [PythonCall.jl](https://github.com/cjdoris/PythonCall.jl) -- we will demo how to use this one
- [PyCall.jl](https://github.com/JuliaPy/PyCall.jl)

Checkout [configuration docs for PythonCall.jl](https://cjdoris.github.io/PythonCall.jl/stable/pythoncall/#pythoncall-config)

Most importantly, you probably want to set:
```julia
ENV["JULIA_PYTHONCALL_EXE"] = readchomp(`which python`)
```
before the `using PythonCall` line. Especially if you're using LCG or Athena or CMSSW environment.

```julia
julia> using PythonCall

julia> const up = pyimport("uproot")

julia> pywith(up.recreate("./example.root")) do file
           file["mytree"] = Dict("branch1"=>1:1000, "branch2"=>rand(1000))
       end

# read it back with UnROOT.jl
julia> using UnROOT

julia> LazyTree("./example.root", "mytree")
 Row │ branch1  branch2              
     │ Int64    Float64              
─────┼───────────────────────────────
 1   │ 1        0.5775868298287866
 2   │ 2        0.7245212475492369
 3   │ 3        0.009249240901789912
 4   │ 4        0.9010206670973542
 5   │ 5        0.7609879879740359
 6   │ 6        0.00916447384387542
 7   │ 7        0.5636229077934333
 8   │ 8        0.32617388561103156
  ⋮  │    ⋮              ⋮
```

### Write out a histogram
A histogram is just a tuple of `(bincontent, binedges)`, see 
[FHist.jl docs](https://moelf.github.io/FHist.jl/dev/writingtoroot/) for details.
