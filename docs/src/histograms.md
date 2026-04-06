# Histograms

UnROOT can read ROOT histogram objects (`TH1`, `TH2`, `TH3` and their typed
variants such as `TH1F`, `TH2D`, `TH3I`, etc.) directly from a ROOT file.
Reading a histogram returns a plain `Dict{Symbol, Any}` containing all stored
fields.  The helper function `UnROOT.parseTH` converts that raw dictionary into
convenient Julia objects — either a lightweight tuple or an
[FHist.jl](https://moelf.github.io/FHist.jl/stable/) histogram (`Hist1D`,
`Hist2D`, or `Hist3D`).

## Opening and inspecting the raw dictionary

```julia-repl
julia> using UnROOT

julia> f = ROOTFile("path/to/file.root")
ROOTFile with 5 entries and 18 streamers.

julia> keys(f)
5-element Vector{String}:
 "myTH1F"
 "myTH1D"
 "myTH2F"
 "myTH2D"
 "myTH1D_nonuniform"

julia> h = f["myTH1F"]
Dict{Symbol, Any} with 106 entries:
  :fName            => "myTH1F"
  :fTitle           => ""
  :fEntries         => 4.0
  :fXaxis_fNbins    => 2
  :fXaxis_fXmin     => -2.0
  :fXaxis_fXmax     => 2.0
  :fN               => Float32[0.0, 40.0, 2.0, 0.0]
  :fSumw2           => [0.0, 800.0, 2.0, 0.0]
  ⋮                 => ⋮
```

The `:fN` array stores bin contents **including overflow bins** — the first and
last entries correspond to the underflow and overflow bins respectively.
`:fSumw2` stores the sum of squared weights per bin (also including overflows),
and has length zero when the histogram was filled without explicit weights.

Common fields for all histogram dimensions:

| Field | Description |
|---|---|
| `:fName`, `:fTitle` | histogram name and title |
| `:fEntries` | number of fills |
| `:fN` | flat bin-content array (includes overflow bins) |
| `:fSumw2` | sum of squared weights (empty when unweighted) |
| `:fXaxis_fNbins`, `:fXaxis_fXmin`, `:fXaxis_fXmax` | X axis binning |
| `:fYaxis_fNbins`, `:fYaxis_fXmin`, `:fYaxis_fXmax` | Y axis binning (TH2/TH3) |
| `:fZaxis_fNbins`, `:fZaxis_fXmin`, `:fZaxis_fXmax` | Z axis binning (TH3) |
| `:fXaxis_fXbins` | variable-width bin edges (empty for uniform axes) |

## `parseTH` — raw tuple mode

`UnROOT.parseTH(h)` (or equivalently `parseTH(h; raw=true)`) strips the
overflow bins, reshapes the counts array to the correct dimensionality, and
returns a four-element tuple `(counts, edges, sumw2, nentries)`.

### 1D histogram

```julia-repl
julia> h = f["myTH1F"]

julia> counts, edges, sumw2, nentries = UnROOT.parseTH(h)

julia> counts
2-element Vector{Float32}:
 40.0
  2.0

julia> edges
(-2.0:2.0:2.0,)

julia> sumw2
2-element Vector{Float64}:
 800.0
   2.0

julia> nentries
4.0
```

Non-uniform bin widths are handled transparently — `edges` will contain a plain
`Vector` instead of a `StepRange`:

```julia-repl
julia> counts, edges, sumw2, nentries = UnROOT.parseTH(f["myTH1D_nonuniform"])

julia> edges
([-2.0, 1.0, 2.0],)
```

### 2D histogram

For a 2D histogram `counts` is a matrix of shape `(Nx, Ny)` and `edges` is a
two-element tuple:

```julia-repl
julia> h = f["myTH2D"]

julia> counts, edges, sumw2, nentries = UnROOT.parseTH(h)

julia> size(counts)
(2, 4)

julia> edges
(-2.0:2.0:2.0, -2.0:1.0:2.0)
```

### 3D histogram

For a 3D histogram `counts` is an array of shape `(Nx, Ny, Nz)` and `edges` is
a three-element tuple:

```julia-repl
julia> f3 = ROOTFile("path/to/th3_file.root")

julia> h = f3["th3f"]

julia> counts, edges, sumw2, nentries = UnROOT.parseTH(h)

julia> size(counts)
(4, 3, 2)

julia> edges
(0.0:1.0:4.0, 0.0:1.0:3.0, 0.0:1.0:2.0)

julia> counts[1, 1, 1]
2.0

julia> sum(counts)
21.0
```

## `parseTH` — FHist mode

Passing `raw=false` converts the histogram directly into an FHist.jl type.
This gives access to the full FHist API: `bincounts`, `binedges`, `sumw2`,
`nentries`, `integral`, `project`, `rebin`, plotting, etc.

### 1D → `Hist1D`

```julia-repl
julia> using FHist

julia> h1 = UnROOT.parseTH(f["myTH1F"]; raw=false)
edges: [-2.0, 0.0, 2.0]
bin counts: [40.0, 2.0]
total count: 42.0

julia> bincounts(h1)
2-element Vector{Float32}:
 40.0
  2.0

julia> binedges(h1)
([-2.0, 0.0, 2.0],)
```

### 2D → `Hist2D`

```julia-repl
julia> h2 = UnROOT.parseTH(f["myTH2D"]; raw=false)
edges: ([-2.0, 0.0, 2.0], [-2.0, -1.0, 0.0, 1.0, 2.0])
bin counts: [20.0 0.0 0.0 20.0; 1.0 0.0 0.0 1.0]
total count: 42.0

julia> size(bincounts(h2))
(2, 4)
```

### 3D → `Hist3D`

```julia-repl
julia> h3 = UnROOT.parseTH(f3["th3f"]; raw=false)
Hist3D{Float64}, edges=([0.0, 1.0, 2.0, 3.0, 4.0], [0.0, 1.0, 2.0, 3.0], [0.0, 1.0, 2.0]), integral=21.0

julia> size(bincounts(h3))
(4, 3, 2)

julia> bincounts(h3)[1, 1, 1]
2.0
```

## Unweighted histograms

ROOT does not fill `:fSumw2` by default when a histogram is filled without
explicit weights.  In that case `length(h[:fSumw2]) == 0`.  `parseTH` detects
this and falls back to using the bin counts themselves as the squared-weight
array, which is the conventional treatment for unweighted histograms
(Poisson statistics: `sumw2[i] = counts[i]`).

```julia-repl
julia> length(f["myTH1F"][:fSumw2])   # weighted — fSumw2 is populated
4

julia> # for an unweighted TH2I the field would be empty:
julia> length(h_unweighted[:fSumw2])
0
```

## Closing the file

Always close the file when you are done to release the file handle:

```julia-repl
julia> close(f)
```
