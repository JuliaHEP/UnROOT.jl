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


## Writting out `.root` files
Currently `UnROOT.jl` is focused on reading only, however, it's semi-trivial to leverage Python world
for write operation since it's not performance critical.

You have the following choice:
- [PythonCall.jl](https://github.com/cjdoris/PythonCall.jl) -- we will demo how to use this one
- [PyCall.jl](https://github.com/JuliaPy/PyCall.jl)

Checkout [configuration docs for PythonCall.jl](https://cjdoris.github.io/PythonCall.jl/stable/pythoncall/#pythoncall-config)

Most importantly, you probably want to set:
```julia
ENV["JULIA_PYTHONCALL_EXE"] = readchomp(`which python`)
```
before the `using PythonCall` line. Especially if you're using LCG or Athena or CMSSW environment.

### Write out a `TTree`
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
