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

Both of which are compostable with `@batch` from `Polyester.jl` for multi-threading:
```julia
julia> using Polyester # need to install it first as it's an optional dependency

julia> @batch for event in mytree
           ...
       end

julia> @batch for (i, event) in enumerate(mytree)
           ...
       end
```
On finer control over `@batch`, such as batch size or per-core/thread, see [Polyester](https://github.com/JuliaSIMD/Polyester.jl)'s page.

Only one basket per branch will be cached so you don't have to worry about running out of RAM.
At the same time, `event` inside the for-loop is not materialized until a field is accessed. If your event
is fairly small or you need all of them anyway, you can `collect(event)` first inside the loop.
