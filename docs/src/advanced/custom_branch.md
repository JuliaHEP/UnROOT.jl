# Parse Custom Branch
It is possible to parse Branches with custom structure as long as you know how the bytes should be interpreted.
As an example, the `TLorentzVector` is added using this mechanism and we will walk through the steps needed:

### 1. Provide a map between `fClassName` of your struct (as seen in .root) to a Julia type.
Pass a `Dict{String, Type}` to `ROOTFile(filepath; customstructs)`. The `TLorentzVector` is shipped [by default](https://github.com/tamasgal/UnROOT.jl/blob/06b692523bbff3f467f6b7fe3544e411a719bc9e/src/root.jl#L21):
```julia
ROOTFile(filepath; customstructs = Dict("TLorentzVector" => LorentzVector{Float64}))
```

This `Dict` will subsequently be used by the `auto_T_JaggT` function [at here](https://github.com/tamasgal/UnROOT.jl/blob/06b692523bbff3f467f6b7fe3544e411a719bc9e/src/root.jl#L213-L222) such that when we encounter a branch with this `fClassName`, we will return your `Type` as the detected element type of this branch.

### 2. Extend the raw bytes interpreting function `UnROOT.interped_data`
By default, given a branch element type and a "jaggness" type, a general function [is defined](https://github.com/tamasgal/UnROOT.jl/blob/06b692523bbff3f467f6b7fe3544e411a719bc9e/src/root.jl#L149) which will try to parse the raw bytes into Julia data structure. The `::Type{T}` will match what you have provided in the `Dict` in the previous step.

Thus, to "teach" UnROOT how to interpret bytes for your type `T`, you would want to defined a more specific `UnROOT.interped_data` than the default one. Taking the `TLorentzVector` [as example](https://github.com/tamasgal/UnROOT.jl/blob/06b692523bbff3f467f6b7fe3544e411a719bc9e/src/custom.jl#L23) again, we define a function:
```julia
using LorentzVector
const LVF64 = LorentzVector{Float64}
function UnROOT.interped_data(rawdata, rawoffsets, ::Type{LVF64}, ::Type{J}) where {T, J <: JaggType}
    # `rawoffsets` is actually redundant, since we know each TLV is always 64 bytes (withe 32 bytes header)
    [
     reinterpret(LVF64, x) for x in Base.Iterators.partition(rawdata, 64)
    ]
end

function Base.reinterpret(::Type{LVF64}, v::AbstractVector{UInt8}) where T
    # x,y,z,t in ROOT
    v4 = ntoh.(reinterpret(Float64, v[1+32:end]))
    # t,x,y,z in LorentzVectors.jl
    LVF64(v4[4], v4[1], v4[2], v4[3])
end
```

The `Base.reinterpret` function is just a helper function, you could instead write everything inside `UnROOT.interped_data`. We then builds on these, to interpret Jagged TLV branch: https://github.com/tamasgal/UnROOT.jl/blob/4747f6f5fd97ed1a872765485b4eb9e99ec5a650/src/custom.jl#L47

### More details
To expand a bit what we're doing here, the `rawdata` for a single `TLV` is always `64 bytes` long and the first `32 bytes` are TObject header which we don't care (which is why we don't care about `rawoffsets` here). The last `32 bytes` make up 4 `Float64` and we simply parse them and return a collection of (julia) `LorentzVector{Float64}`.

In general, if `auto_T_JaggT` returned `MyType` as promised branch element type, then
```julia
UnROOT.interped_data(rawdata, rawoffsets, ::Type{MyType},
```
should return `Vector{MyType}` because `UnROOT.interped_data` receives raw bytes of a basket at a time.

And that's it! Afterwards both `LazyBranch` and `LazyTree` will be able to constructed with correct type and also knows how to interpret bytes when you indexing or iterating through them

## Reading Raw Data from Branch
Alternatively, reading raw data is also possible
using the `UnROOT.array(f::ROOTFile, path; raw=true)` method. The output can
be then reinterpreted using a custom type with the method
`UnROOT.splitup(data, offsets, T::Type; skipbytes=0, jagged=true)`. This provides more fine grain control in case
your branch is highly irregular. You can then define suitable Julia `type` and `readtype` method for parsing these data.
Alternatively, you can of course parse the `data` and `offsets` entirely manually.
Here is it in action, with the help of the `type`s from `custom.jl`, and some data from the KM3NeT experiment:
``` julia
julia> using UnROOT

julia> f = ROOTFile("test/samples/km3net_online.root")
ROOTFile("test/samples/km3net_online.root") with 10 entries and 41 streamers.

julia> data, offsets = array(f, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
2058-element Array{UInt8,1}:
 0x00
 0x03
   ⋮
   
julia> UnROOT.splitup(data, offsets, UnROOT.KM3NETDAQHit)
4-element Vector{Vector{UnROOT.KM3NETDAQHit}}:
 [UnROOT.KM3NETDAQHit(1073742790, 0x00, 9, 0x60)......
```
