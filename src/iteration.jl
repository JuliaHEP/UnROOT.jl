"""
    arrays(f::ROOTFile, treename)

Reads all branches from a tree.
"""
function arrays(f::ROOTFile, treename)
    names = keys(f[treename])
    res = Vector{Vector}(undef, length(names))
    Threads.@threads for i in eachindex(names)
        res[i] = array(f, "$treename/$(names[i])")
    end
    return res
end

"""
    array(f::ROOTFile, path; raw=false)

Reads an array from a branch. Set `raw=true` to return raw data and correct offsets.
"""
function array(f::ROOTFile, path::AbstractString; raw=false)
    return array(f::ROOTFile, _getindex(f, path); raw=raw)
end

function array(f::ROOTFile, branch; raw=false)
    ismissing(branch) && error("No branch found at $path")
    (!raw && length(branch.fLeaves.elements) > 1) && error(
        "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.",
    )

    rawdata, rawoffsets = readbranchraw(f, branch)
    if raw
        return rawdata, rawoffsets
    end
    T, J = auto_T_JaggT(f, branch; customstructs=f.customstructs)
    return interped_data(rawdata, rawoffsets, T, J)
end

"""
    basketarray(f::ROOTFile, path::AbstractString, ith)
    basketarray(f::ROOTFile, branch::Union{TBranch, TBranchElement}, ith)
    basketarray(lb::LazyBranch, ith)

Reads actual data from ith basket of a branch. This function first calls [`readbasket`](@ref)
to obtain raw bytes and offsets of a basket, then calls [`auto_T_JaggT`](@ref) followed
by [`interped_data`](@ref) to translate raw bytes into actual data.
"""
function basketarray(f::ROOTFile, path::AbstractString, ithbasket)
    return basketarray(f, f[path], ithbasket)
end
function basketarray(f::ROOTFile, branch, ithbasket)
    ismissing(branch) && error("No branch found at $path")
    length(branch.fLeaves.elements) > 1 && error(
        "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.",
    )

    rawdata, rawoffsets = readbasket(f, branch, ithbasket)
    T, J = auto_T_JaggT(f, branch; customstructs=f.customstructs)
    return interped_data(rawdata, rawoffsets, T, J)
end

"""
    basketarray_iter(f::ROOTFile, branch::Union{TBranch, TBranchElement})
    basketarray_iter(lb::LazyBranch)

Returns a `Base.Generator` yielding the output of `basketarray()` for all baskets.
"""
function basketarray_iter(f::ROOTFile, branch)
    return (basketarray(f, branch, i) for i in 1:numbaskets(branch))
end

# function barrior to make getting individual index faster
# TODO upstream some types into parametric types for Branch/BranchElement
"""
    LazyBranch(f::ROOTFile, branch)

Construct an accessor for a given branch such that `BA[idx]` and or `BA[1:20]` is
type-stable. And memory footprint is a single basket (<1MB usually). You can also
iterate or map over it. If you want a concrete `Vector`, simply `collect()` the
LazyBranch.

# Example
```julia
julia> rf = ROOTFile("./test/samples/tree_with_large_array.root");

julia> b = rf["t1/int32_array"];

julia> ab = UnROOT.LazyBranch(rf, b);

julia> for entry in ab
           @show entry
           break
       end
entry = 0

julia> ab[begin:end]
0
1
...
```
"""
mutable struct LazyBranch{T,J,B} <: AbstractVector{T}
    f::ROOTFile
    b::Union{TBranch,TBranchElement}
    L::Int64
    fEntry::Vector{Int64}
    buffer::Vector{B}
    buffer_range::Vector{UnitRange{Int64}}

    function LazyBranch(f::ROOTFile, b::Union{TBranch,TBranchElement})
        T, J = auto_T_JaggT(f, b; customstructs=f.customstructs)
        T = (T === Vector{Bool} ? BitVector : T)
        _buffer = T[]
        if J != Nojagg
            # if branch is jagged, fix the buffer and eltype according to what
            # VectorOfVectors would return in `getindex`
            _buffer = VectorOfVectors(T(), Int32[1])
            T = SubArray{eltype(T), 1, T, Tuple{UnitRange{Int64}}, true}
        end
        return new{T,J,typeof(_buffer)}(f, b, length(b),
                                        b.fBasketEntry,
                                        [_buffer for _ in 1:Threads.nthreads()],
                                        [0:-1 for _ in 1:Threads.nthreads()])
    end
end

function Base.hash(lb::LazyBranch, h::UInt)
    h = hash(lb.f, h)
    h = hash(lb.b.fClassName, h)
    h = hash(lb.L, h)
    for br in lb.buffer_range
        h = hash(br, h)
    end
    return h
end
Base.size(ba::LazyBranch) = (ba.L,)
Base.length(ba::LazyBranch) = ba.L
Base.firstindex(ba::LazyBranch) = 1
Base.lastindex(ba::LazyBranch) = ba.L
Base.eltype(ba::LazyBranch{T,J,B}) where {T,J,B} = T

basketarray(lb::LazyBranch, ithbasket) = basketarray(lb.f, lb.b, ithbasket)
basketarray_iter(lb::LazyBranch) = basketarray_iter(lb.f, lb.b)

function Base.show(io::IO, lb::LazyBranch)
    summary(io, lb)
    println(io, ":")
    println(io, "  File: $(lb.f.filename)")
    println(io, "  Branch: $(lb.b.fName)")
    println(io, "  Description: $(lb.b.fTitle)")
    println(io, "  NumEntry: $(lb.L)")
    print(io, "  Entry Type: $(eltype(lb))")
    nothing
end

"""
    Base.getindex(ba::LazyBranch{T, J}, idx::Integer) where {T, J}

Get the `idx`-th element of a `LazyBranch`, starting at `1`. If `idx` is
within the range of `ba.buffer_range`, it will directly return from `ba.buffer`.
If not within buffer, it will fetch the correct basket by calling [`basketarray`](@ref)
and update buffer and buffer range accordingly.

!!! warning
    Because currently we only cache a single basket inside `LazyBranch` at any given
    moment, access a `LazyBranch` from different threads at the same time can cause
    performance issue and incorrect event result.
"""

function Base.getindex(ba::LazyBranch{T,J,B}, idx::Integer) where {T,J,B}
    tid = Threads.threadid()
    br = @inbounds ba.buffer_range[tid]
    localidx = if idx ∉ br
        _localindex_newbasket!(ba, idx, tid)
    else
        idx - br.start + 1
    end
    return @inbounds ba.buffer[tid][localidx]
end

function _localindex_newbasket!(ba::LazyBranch{T,J,B}, idx::Integer, tid::Int) where {T,J,B}
    seek_idx = findfirst(x -> x > (idx - 1), ba.fEntry) - 1 #support 1.0 syntax
    ba.buffer[tid] = basketarray(ba.f, ba.b, seek_idx)
    br = (ba.fEntry[seek_idx] + 1):(ba.fEntry[seek_idx + 1])
    ba.buffer_range[tid] = br
    return idx - br.start + 1
end

Base.IndexStyle(::Type{<:LazyBranch}) = IndexLinear()

function Base.iterate(ba::LazyBranch{T,J,B}, idx=1) where {T,J,B}
    idx > ba.L && return nothing
    return (ba[idx], idx + 1)
end

struct LazyEvent{T<:TypedTables.Table}
    tree::T
    idx::Int64
end
struct LazyTree{T} <: AbstractVector{LazyEvent{T}}
    treetable::T
end
function LazyTree(path::String, x...)
    LazyTree(ROOTFile(path), x...)
end

@inline innertable(t::LazyTree) = Core.getfield(t, :treetable)

Base.propertynames(lt::LazyTree) = propertynames(innertable(lt))
Base.getproperty(lt::LazyTree, s::Symbol) = getproperty(innertable(lt), s)

Base.broadcastable(lt::LazyTree) = lt
Base.IndexStyle(::Type{<:LazyTree}) = IndexLinear()
Base.getindex(lt::LazyTree, row::Int) = LazyEvent(innertable(lt), row)
# kept lazy for broadcasting purpose
Base.getindex(lt::LazyTree, row::CartesianIndex{1}) = LazyEvent(innertable(lt), row[1])
function Base.getindex(lt::LazyTree, rang::UnitRange)
    return LazyTree(innertable(lt)[rang])
end

# a specific event
Base.getindex(lt::LazyTree, ::typeof(!), s::Symbol) = lt[:, s]
Base.getindex(lt::LazyTree, ::Colon, s::Symbol) = getproperty(innertable(lt), s) # the real deal
Base.getindex(lt::LazyTree, row::Int, col::Symbol) = lt[:, col][row]
Base.getindex(lt::LazyTree, rows::UnitRange, col::Symbol) = lt[:, col][rows]
Base.getindex(lt::LazyTree, ::Colon) = lt[1:end]
Base.firstindex(lt::LazyTree) = 1
Base.lastindex(lt::LazyTree) = length(lt)
Base.eachindex(lt::LazyTree) = 1:lastindex(lt)

# allow enumerate() to be chunkable (eg with Threads.@threads)
Base.step(e::Iterators.Enumerate{LazyTree{T}}) where T = 1
Base.firstindex(e::Iterators.Enumerate{LazyTree{T}}) where T = firstindex(e.itr)
Base.lastindex(e::Iterators.Enumerate{LazyTree{T}}) where T = lastindex(e.itr)
Base.eachindex(e::Iterators.Enumerate{LazyTree{T}}) where T = eachindex(e.itr)
Base.getindex(e::Iterators.Enumerate{LazyTree{T}}, row::Int) where T = (row, LazyEvent(innertable(e.itr), row))
# interfacing Table
Base.names(lt::LazyTree) = collect(String.(propertynames(innertable(lt))))
Base.length(lt::LazyTree) = length(innertable(lt))
Base.ndims(::Type{<:LazyTree}) = 1
Base.size(lt::LazyTree) = size(innertable(lt))

function LazyArrays.Vcat(ts::LazyTree...)
    cs = Tables.columns.(innertable.(ts))
    LazyTree(TypedTables.Table(map(Vcat, cs...)))
end
Base.vcat(ts::LazyTree...) = Vcat(ts...)
Base.reduce(::typeof(vcat), ts::AbstractVector{<:LazyTree}) = Vcat((ts)...)
Base.mapreduce(f::Function, ::typeof(vcat), ts::AbstractVector{<:LazyTree}) = Vcat(f.(ts)...)
Base.mapreduce(f::Function, ::typeof(Vcat), ts::AbstractVector{<:LazyTree}) = Vcat(f.(ts)...)

function getbranchnamesrecursive(obj)
    out = Vector{String}()
    for b in obj.fBranches.elements
        push!(out, b.fName)
        for subname in getbranchnamesrecursive(b)
            push!(out, "$(b.fName)/$(subname)")
        end
    end
    return out
end

"""
    LazyTree(f::ROOTFile, s::AbstractString, branche::Union{AbstractString, Regex})
    LazyTree(f::ROOTFile, s::AbstractString, branches::Vector{Union{AbstractString, Regex}})

Constructor for `LazyTree`, which is close to an `DataFrame` (interface wise),
and a lazy `TypedTables.Table` (speed wise). Looping over a `LazyTree` is fast and type
stable. Internally, `LazyTree` contains a typed table whose branch are [`LazyBranch`](@ref).
This means that at any given time only `N` baskets are cached, where `N` is the number of branches.

!!! note
    Accessing with `[start:stop]` will return a `LazyTree` with concrete internal table.

# Example
```julia
julia> mytree = LazyTree(f, "Events", ["Electron_dxy", "nMuon", r"Muon_(pt|eta)\$"])
 Row │ Electron_dxy     nMuon   Muon_eta         Muon_pt
     │ Vector{Float32}  UInt32  Vector{Float32}  Vector{Float32}
─────┼───────────────────────────────────────────────────────────
 1   │ [0.000371]       0       []               []
 2   │ [-0.00982]       2       [0.53, 0.229]    [19.9, 15.3]
 3   │ []               0       []               []
 4   │ [-0.00157]       0       []               []
 ⋮   │     ⋮            ⋮             ⋮                ⋮
```
"""
function LazyTree(f::ROOTFile, s::AbstractString, branches)
    tree = f[s]
    tree isa TTree || error("$s is not a tree name.")
    if length(branches) > 30
        @warn "Your tree is quite wide, with $(length(branches)) branches, this will take compiler a moment."
    end
    d = Dict{Symbol,LazyBranch}()
    _m(s::AbstractString) = isequal(s)
    _m(r::Regex) = Base.Fix1(occursin, r)
    branches = mapreduce(b -> filter(_m(b), getbranchnamesrecursive(tree)), ∪, branches)
    SB = Symbol.(branches)
    for b in SB
        d[b] = f["$s/$b"]
    end
    return LazyTree(TypedTables.Table(d))
end

function LazyTree(f::ROOTFile, s::AbstractString)
    return LazyTree(f, s, keys(f[s]))
end

function LazyTree(f::ROOTFile, s::AbstractString, branch::Union{AbstractString,Regex})
    return LazyTree(f, s, [branch])
end

function Base.show(io::IO, evt::LazyEvent)
    idx = Core.getfield(evt, :idx)
    fields = propertynames(Core.getfield(evt, :tree))
    nfields = length(fields)
    sfields = nfields < 20 ? ": $(fields)" : ""
    println(io, "UnROOT.LazyEvent at index $(idx) with $(nfields) columns:")
    show(io, collect(evt))
end

@inline function Base.getproperty(evt::LazyEvent, s::Symbol)
    @inbounds getproperty(Core.getfield(evt, :tree), s)[Core.getfield(evt, :idx)]
end
Base.collect(evt::LazyEvent) = @inbounds Core.getfield(evt, :tree)[Core.getfield(evt, :idx)]

function Base.iterate(tree::T, idx=1) where {T<:LazyTree}
    idx > length(tree) && return nothing
    return LazyEvent(innertable(tree), idx), idx + 1
end

function Base.getindex(ba::LazyBranch{T,J,B}, range::UnitRange) where {T,J,B}
    ib1 = findfirst(x -> x > (first(range) - 1), ba.fEntry) - 1
    ib2 = findfirst(x -> x > (last(range) - 1), ba.fEntry) - 1
    offset = ba.fEntry[ib1]
    range = (first(range)-offset):(last(range)-offset)
    return vcat([basketarray(ba, i) for i in ib1:ib2]...)[range]
end

_clusterranges(t::LazyTree) = _clusterranges([getproperty(t,p) for p in propertynames(t)])
function _clusterranges(lbs::AbstractVector{<:LazyBranch})
    basketentries = [lb.b.fBasketEntry[1:numbaskets(lb.b)+1] for lb in lbs]
    common = mapreduce(Set, ∩, basketentries) |> collect |> sort
    return [common[i]+1:common[i+1] for i in 1:length(common)-1]
end
_clusterbytes(t::LazyTree; kw...) = _clusterbytes([getproperty(t,p) for p in propertynames(t)]; kw...)
function _clusterbytes(lbs::AbstractVector{<:LazyBranch}; compressed=false)
    basketentries = [lb.b.fBasketEntry[1:numbaskets(lb.b)+1] for lb in lbs]
    common = mapreduce(Set, ∩, basketentries) |> collect |> sort
    bytes = zeros(Float64, length(common)-1)
    for lb in lbs
        b = lb.b
        finflate = compressed ? 1.0 : b.fTotBytes/b.fZipBytes
        entries = b.fBasketEntry[1:numbaskets(b)+1]
        basketbytes = b.fBasketBytes[1:numbaskets(b)+1] * finflate
        iclusters = searchsortedlast.(Ref(common), entries[1:end-1])
        pairs = zip(iclusters, basketbytes)
        sumbytes = [sum(last.(g)) for g in groupby(first, pairs)]
        bytes .+= sumbytes
    end
    return bytes
end

Tables.columns(t::LazyTree) = Tables.columns(innertable(t))
Tables.partitions(t::LazyTree) = (t[r] for r in _clusterranges(t))
