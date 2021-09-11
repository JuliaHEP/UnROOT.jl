"""
    arrays(f::ROOTFile, treename)

Reads all branches from a tree.
"""
function arrays(f::ROOTFile, treename)
    names = keys(f[treename])
    res = Vector{Any}(undef, length(names))
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
        _buffer = J === Nojagg ? T[] : VectorOfVectors(T(), Int32[1])
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

function Base.show(io::IO, lb::LazyBranch)
    summary(io, lb)
    println(":")
    println("  File: $(lb.f.filename)")
    println("  Branch: $(lb.b.fName)")
    println("  Description: $(lb.b.fTitle)")
    println("  NumEntry: $(lb.L)")
    print("  Entry Type: $(eltype(lb))")
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
    br = ba.buffer_range[tid]
    if idx ∉ br
        seek_idx = findfirst(x -> x > (idx - 1), ba.fEntry) - 1 #support 1.0 syntax
        bb = basketarray(ba.f, ba.b, seek_idx)
        if typeof(bb) !== B
            error("Expected type of interpreted data: $(B), got: $(typeof(bb))")
        end
        ba.buffer[tid] = bb
        br = (ba.fEntry[seek_idx] + 1):(ba.fEntry[seek_idx + 1])
        ba.buffer_range[tid] = br
    end
    localidx = idx - br.start + 1
    return @inbounds ba.buffer[tid][localidx]
end

function Base.iterate(ba::LazyBranch{T,J,B}, idx=1) where {T,J,B}
    idx > ba.L && return nothing
    return (ba[idx], idx + 1)
end

struct LazyTree{T}
    treetable::T
end

@inline innertable(t::LazyTree) = Core.getfield(t, :treetable)

Base.propertynames(lt::LazyTree) = propertynames(innertable(lt))
Base.getproperty(lt::LazyTree, s::Symbol) = getproperty(innertable(lt), s)

# a specific branch
Base.getindex(lt::LazyTree, row::Int) = innertable(lt)[row]
function Base.getindex(lt::LazyTree, rang::UnitRange)
    return LazyTree(innertable(lt)[rang])
end
Base.getindex(lt::LazyTree, ::typeof(!), s::Symbol) = lt[:, s]
Base.getindex(lt::LazyTree, ::Colon, s::Symbol) = getproperty(innertable(lt), s) # the real deal

# a specific event
Base.getindex(lt::LazyTree, row::Int, col::Symbol) = lt[:, col][row]
Base.getindex(lt::LazyTree, rows::UnitRange, col::Symbol) = lt[:, col][rows]
Base.getindex(lt::LazyTree, ::Colon) = lt[1:end]
Base.firstindex(lt::LazyTree) = 1
Base.lastindex(lt::LazyTree) = length(lt)
Base.eachindex(lt::LazyTree) = 1:lastindex(lt)

# allow enumerate() to be chunkable (eg with Threads.@threads)
Base.firstindex(e::Iterators.Enumerate{LazyTree{T}}) where T = firstindex(e.itr)
Base.lastindex(e::Iterators.Enumerate{LazyTree{T}}) where T = lastindex(e.itr)
Base.eachindex(e::Iterators.Enumerate{LazyTree{T}}) where T = eachindex(e.itr)
Base.getindex(e::Iterators.Enumerate{LazyTree{T}}, row::Int) where T = (row, first(iterate(e.itr, row)))

# interfacing Table
Base.names(lt::LazyTree) = collect(String.(propertynames(innertable(lt))))
Base.length(lt::LazyTree) = length(innertable(lt))

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

struct LazyEvent{T<:TypedTables.Table}
    tree::T
    idx::Int64
end
function Base.show(io::IO, evt::LazyEvent)
    idx = Core.getfield(evt, :idx)
    fields = propertynames(Core.getfield(evt, :tree))
    nfields = length(fields)
    sfields = nfields < 20 ? ": $(fields)" : ""
    show(io, "LazyEvent $(idx) with $(nfields) fields$(sfields)")
end
function Base.getproperty(evt::LazyEvent, s::Symbol)
    @inbounds getproperty(Core.getfield(evt, :tree), s)[Core.getfield(evt, :idx)]
end
Base.collect(evt::LazyEvent) = @inbounds Core.getfield(evt, :tree)[Core.getfield(evt, :idx)]

function Base.iterate(tree::T, idx=1) where {T<:LazyTree}
    idx > length(tree) && return nothing
    return LazyEvent(innertable(tree), idx), idx + 1
end

# TODO this is not terribly slow, but we can get faster implementation still ;)
function Base.getindex(ba::LazyBranch{T,J,B}, rang::UnitRange) where {T,J,B}
    return [ba[i] for i in rang]
end
