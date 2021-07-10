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
    res
end


"""
    array(f::ROOTFile, path; raw=false)

Reads an array from a branch. Set `raw=true` to return raw data and correct offsets.
"""
array(f::ROOTFile, path::AbstractString; raw=false) = array(f::ROOTFile, _getindex(f, path); raw=raw)

function array(f::ROOTFile, branch; raw=false)
    ismissing(branch) && error("No branch found at $path")
    (!raw && length(branch.fLeaves.elements) > 1) && error(
            "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.")

    rawdata, rawoffsets = readbranchraw(f, branch)
    if raw
        return rawdata, rawoffsets
    end
    leaf = first(branch.fLeaves.elements)
    jagt = JaggType(leaf)
    T = eltype(branch) 
    interped_data(rawdata, rawoffsets, branch, jagt, T)
end

"""
    basketarray(f::ROOTFile, path, ith; raw=false)
Reads an array from ith basket of a branch. Set `raw=true` to return raw data and correct offsets.
"""
basketarray(f::ROOTFile, path::AbstractString, ithbasket) = basketarray(f, f[path], ithbasket)

function basketarray(f::ROOTFile, branch, ithbasket)
    ismissing(branch) && error("No branch found at $path")
    length(branch.fLeaves.elements) > 1 && error(
            "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.")

    rawdata, rawoffsets = readbasket(f, branch, ithbasket)
    leaf = first(branch.fLeaves.elements)
    jagt = JaggType(leaf)
    T = eltype(branch)
    interped_data(rawdata, rawoffsets, branch, jagt, T)
end

function LazyTree(f::ROOTFile, s::AbstractString, branches)
    tree = f[s]
    tree isa TTree || error("$s is not a tree name.")
    d = Dict{Symbol, LazyBranch}()
    for (i,b) in enumerate(branches)
        d[Symbol(b)] = f["$s/$b"]
    end
    if length(branches) > 30
        @warn "Your tree is pretty wide $(length(branches)), this will take compiler a moment."
    end
    TypedTables.Table(d)
end

function LazyTree(f::ROOTFile, s::AbstractString)
    LazyTree(f, s, keys(f[s]))
end

# function barrior to make getting individual index faster
# TODO upstream some types into parametric types for Branch/BranchElement
"""
    LazyBranch(f::ROOTFile, branch)

Construct an accessor for a given branch such that `BA[idx]` and or `BA[1:20]` is almost
type-stable. And memory footprint is a single basket (<20MB usually).

# Example
```julia
julia> rf = ROOTFile("./test/samples/tree_with_large_array.root");

julia> b = rf["t1/int32_array"];

julia> ab = UnROOT.LazyBranch(rf, b);

julia> ab[1]
0

julia> ab[begin:end]
0
1
...
```
"""
mutable struct LazyBranch{T, J} <: AbstractVector{T}
    f::ROOTFile
    b::Union{TBranch, TBranchElement}
    L::Int64
    fEntry::Vector{Int64}
    buffer_seek::Int64
    buffer::Vector{T}

    function LazyBranch(f::ROOTFile, b::Union{TBranch, TBranchElement})
        T = eltype(b)
        J = JaggType(first(b.fLeaves.elements))
        max_len = maximum(diff(b.fBasketEntry))
        # we don't know how to deal with multiple leaves yet
        new{T, J}(f, b, length(b), b.fBasketEntry, -1, T[])
    end
end
Base.size(ba::LazyBranch) = (ba.L,)
Base.length(ba::LazyBranch) = ba.L
Base.firstindex(ba::LazyBranch) = 1
Base.lastindex(ba::LazyBranch) = ba.L
Base.eltype(ba::LazyBranch{T,J}) where {T,J} = T

Base.show(io::IO,m::MIME"text/plain", lb::LazyBranch) = Base.show(io, lb)
function Base.show(io::IO, lb::LazyBranch)
    summary(io, lb)
    println(":")
    println("  File: $(lb.f.filename)")
    println("  Branch: $(lb.b.fName)")
    println("  Description: $(lb.b.fTitle)")
    println("  NumEntry: $(lb.L)")
    print("  Entry Type: $(eltype(lb))")
end

function Base.getindex(ba::LazyBranch{T, J}, idx::Integer) where {T, J}
    # I hate 1-based indexing
    seek_idx = findfirst(x -> x>(idx-1), ba.fEntry) - 1 #support 1.0 syntax
    localidx = idx - ba.fEntry[seek_idx]
    if seek_idx != ba.buffer_seek # update buffer if index in a new basket
        ba.buffer = basketarray(ba.f, ba.b, seek_idx)
        ba.buffer_seek = seek_idx
    end
    return ba.buffer[localidx]
end

function Base.iterate(ba::LazyBranch{T, J}, idx=1) where {T, J}
    idx>ba.L && return nothing
    return (ba[idx], idx+1)
end

const _LazyTreeType = TypedTables.Table{<:NamedTuple, 1, NamedTuple{S, N}} where {S, N <: Tuple{Vararg{LazyBranch}}}

struct LazyEvent{T<:_LazyTreeType}
    tree::T
    idx::Int64
end
Base.getproperty(evt::LazyEvent{T}, s::Symbol) where T = getindex(getproperty(getfield(evt, :tree), s), getfield(evt, :idx))

function Base.iterate(tree::T, idx=1) where T<: _LazyTreeType
    idx > length(tree) && return nothing
    LazyEvent{T}(tree, idx), idx+1
end

# TODO this is not terribly slow, but we can get faster implementation still ;)
function Base.getindex(ba::LazyBranch{T, J}, rang::UnitRange) where {T, J}
    [ba[i] for i in rang]
end
