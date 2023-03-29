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

## Lazy tree construction

As seen in the previous section, `LazyTree`s are cheap and offer a convenient
way to create an object that isolates the branches of interest. It's fairly
common that multiple branches are present with slightly differring names, like
`pos.x`, `pos.y` etc. The `LazyTree` function also takes regular expressions, as
seen in the example below where `r"Evt/trks/trks.pos.[xyz]"` is passed, that
will match the corresponding branches:

```julia-repl
julia> f = UnROOT.samplefile("km3net_offline.root")
ROOTFile with 2 entries and 25 streamers.
/Users/tamasgal/Dev/UnROOT.jl/test/samples/km3net_offline.root
├─ E (TTree)
│  └─ "Evt"
└─ Header (Head)

julia> t = LazyTree(f, "E", ["Evt/trks/trks.id", r"Evt/trks/trks.pos.[xyz]"])
 Row │ Evt_trks_trks_i                     Evt_trks_trks_p                     Evt_trks_trks_p                     Evt_trks_trks_p      ⋯
     │ SubArray{Int32,                     SubArray{Float6                     SubArray{Float6                     SubArray{Float6      ⋯
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 1   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [615.0, 615.0, 585.0, 583.0, 583.0  [446.0, 446.0, 448.0, 448.0, 448.0  [125.0, 125.0, 70.7, ⋯
 2   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [533.0, 533.0, 559.0, 560.0, 559.0  [465.0, 465.0, 456.0, 452.0, 496.0  [80.7, 80.7, 39.1, 3 ⋯
 3   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [593.0, 593.0, 581.0, 580.0, 581.0  [457.0, 457.0, 449.0, 449.0, 449.0  [194.0, 194.0, 96.5, ⋯
 4   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [590.0, 590.0, 571.0, 574.0, 572.0  [440.0, 440.0, 431.0, 432.0, 432.0  [204.0, 204.0, 124.0 ⋯
 5   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [546.0, 546.0, 565.0, 562.0, 565.0  [440.0, 440.0, 446.0, 427.0, 425.0  [58.6, 58.6, 30.1, 3 ⋯
 6   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [585.0, 585.0, 564.0, 579.0, 575.0  [424.0, 424.0, 436.0, 446.0, 445.0  [202.0, 202.0, 183.0 ⋯
 7   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [533.0, 533.0, 557.0, 554.0, 554.0  [440.0, 440.0, 425.0, 411.0, 418.0  [47.3, 47.3, 30.1, 2 ⋯
 8   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [569.0, 569.0, 555.0, 575.0, 578.0  [469.0, 469.0, 443.0, 440.0, 453.0  [200.0, 200.0, 179.0 ⋯
 9   │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [557.0, 557.0, 575.0, 580.0, 609.0  [412.0, 412.0, 426.0, 421.0, 448.0  [209.0, 209.0, 101.0 ⋯
 10  │ [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11  [532.0, 532.0, 572.0, 572.0, 573.0  [443.0, 443.0, 453.0, 454.0, 454.0  [172.0, 172.0, 126.0 ⋯
                                                                                                                         1 column omitted

julia> names(t)
4-element Vector{String}:
 "Evt_trks_trks_id"
 "Evt_trks_trks_pos_y"
 "Evt_trks_trks_pos_x"
 "Evt_trks_trks_pos_z"

julia> t.Evt_trks_trks_pos_y
10-element LazyBranch{SubArray{Float64, 1, Vector{Float64}, Tuple{UnitRange{Int64}}, true}, UnROOT.Nooffsetjagg, ArraysOfArrays.VectorOfVectors{Float64, Vector{Float64}, Vector{Int32}, Vector{Tuple{}}}}:
 [615.1089636184813, 615.1089636184813, 584.7490001284564, 582.9922451367319, 583.4532742304276, 583.212063675951, 583.182239372315, 582.5351568422853, 581.7743452806689, 583.6562661040083  …  597.4671030654561, 575.2131287145014, 582.7727094920472, 588.1060616488143, 574.8482883396676, 603.955888460846, 593.4457411811859, 576.6419859859786, 574.836340445788, 576.5382993955498]
 ...
 ...
```

Branch names are normalised so that they contain valid characters for
identifiers. The branchname `Evt/trks/trks.pos.y` for example is therefore
converted to `Evt_trks_trks_posy`, which might be a bit inconvenient to use.
`LazyTree` can rename branches based on regular expressions and subsitution
strings (in Julia these are created with `s""`) which can be passed as `Pair`s.
The example below shows how to use this:

```julia-repl
julia> t = LazyTree(f, "E", [r"Evt/trks/trks.(dir|pos).([xyz])" => s"\1_\2"])
 Row │ pos_z                dir_z                pos_y                dir_y                dir_x                 ⋯     │ SubArray{Float6      SubArray{Float6      SubArray{Float6      SubArray{Float6      SubArray{Float6       ⋯─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────── 1   │ [125.0, 125.0, 70.7  [-0.873, -0.873, -0  [615.0, 615.0, 585.  [-0.487, -0.487, -0  [0.0369, 0.0369, 0.   ⋯ 2   │ [80.7, 80.7, 39.1,   [-0.835, -0.835, -0  [533.0, 533.0, 559.  [0.521, 0.521, 0.52  [-0.175, -0.175, -0   ⋯ 3   │ [194.0, 194.0, 96.5  [-0.989, -0.989, -0  [593.0, 593.0, 581.  [-0.122, -0.122, -0  [-0.0817, -0.0817,    ⋯ 4   │ [204.0, 204.0, 124.  [-0.968, -0.968, -0  [590.0, 590.0, 571.  [-0.23, -0.23, -0.2  [-0.102, -0.102, -0   ⋯ 5   │ [58.6, 58.6, 30.1,   [-0.821, -0.821, -0  [546.0, 546.0, 565.  [0.54, 0.54, 0.54,   [0.187, 0.187, 0.18   ⋯ 6   │ [202.0, 202.0, 183.  [-0.602, -0.602, -0  [585.0, 585.0, 564.  [-0.685, -0.685, -0  [0.41, 0.41, 0.41,    ⋯ 7   │ [47.3, 47.3, 30.1,   [-0.527, -0.527, -0  [533.0, 533.0, 557.  [0.715, 0.715, 0.71  [-0.459, -0.459, -0   ⋯ 8   │ [200.0, 200.0, 179.  [-0.57, -0.57, -0.5  [569.0, 569.0, 555.  [-0.397, -0.397, -0  [-0.719, -0.719, -0   ⋯ 9   │ [209.0, 209.0, 101.  [-0.978, -0.978, -0  [557.0, 557.0, 575.  [0.168, 0.168, 0.16  [0.124, 0.124, 0.12   ⋯ 10  │ [172.0, 172.0, 126.  [-0.74, -0.74, -0.7  [532.0, 532.0, 572.  [0.651, 0.651, 0.65  [0.172, 0.172, 0.17   ⋯                                                                                                  1 column omitted

julia> names(t)
6-element Vector{String}:
 "pos_z"
 "dir_z"
 "pos_y"
 "dir_y"
 "dir_x"
 "pos_x"
```
