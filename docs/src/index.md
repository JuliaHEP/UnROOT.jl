## Introduction
Apart from the pursue of performance, we also strive to provide intuitive and compostable interface.
After all, "theoretically" fast doesn't mean the performance is accessible for the first-time physics
user.

### Status
We support reading all scalar and jagged branches of "basic" types, provide
indexing and iteration interface with a "per branch" basket-cache. There is a low level
API to provide interpretation functionalities for custom types and classes.
As a metric, UnROOT can read all branches (~1800) of CMS NanoAOD including jagged `TLorentzVector` branch.


## Loops aren't slow
One good thing about Julia is you can always fallback to writing loops since they are not intrinsically
slower (than C/C++), certainly much faster than Python. Continuing the example from README:
```julia
julia> using UnROOT

julia> f = ROOTFile("test/samples/NanoAODv5_sample.root")

julia> mytree = LazyTree(f, "Events", ["Electron_dxy", "nMuon", r"Muon_(pt|eta)$"])
```

There are essentially two loops you can use:
```julia
julia> for event in mytree
           ...
       end

julia> for (i, event) in enumerate(mytree)
           # i will be index of `mytree`: 1, 2, 3...
           ...
       end
```

Both of which are compostable with `@threads` for multi-threading:
```julia
julia> Threads.@threads for event in mytree
           ...
       end

julia> Threads.@threads for (i, event) in enumerate(mytree)
           ...
       end
```
Only one basket per branch will be cached so you don't have to worry about running out of RAM.
At the same time, `event` inside the for-loop is not materialized until a field is accessed.

## Laziness in Indexing, Slicing, and Looping
Laziness (or eagerness) in UnROOT generally refers to if an "event" has read each branches of the tree or not.
As canonical example of eager event, consider indexing:
```julia-repl
julia> const r = LazyTree(ROOTFile("./Run2012BC_DoubleMuParked_Muons.root"), "Events", ["nMuon", "Muon_phi"]);

julia> names(r)
2-element Vector{String}:
 "Muon_phi"
 "nMuon"

julia> r[1]
(Muon_phi = Float32[-0.034272723, 2.5426154], nMuon = 0x00000002)
```

Where the `iterate()` over tree is lazy:
```julia-repl
julia> const r = LazyTree(ROOTFile("./Run2012BC_DoubleMuParked_Muons.root"), "Events", ["nMuon", "Muon_phi"]);

julia> for (i, evt) in enumerate(r)
           @show i, evt
           break
       end
(i, evt) = (1, "LazyEvent with: (:tree, :idx)")
```
And the reading of actual data is delayed until `evt.nMuon` or `evt.Muon_phi` happens. Which
means you should be careful about: [Don't-"double-access"](@ref).

The laziness of the main interfaces are summarized below:

|                        | `mytree`    | `enumerate(mytree)` |
| ---------------------- |:-----------:|:-------------------:|
| `for X in ...`         | 💤          | 💤                  |
| `@threads for X in ...`| 💤          | 💤                  |
| `getindex(tree, row::Int)`| 💤          | N/A                  |
| `getindex(tree, row::Range)`| 🚨          | N/A                  |
