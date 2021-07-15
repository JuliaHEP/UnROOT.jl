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
    T, J = auto_T_JaggT(branch; customstructs = f.customstructs)
    interped_data(rawdata, rawoffsets, T, J)
end

"""
    basketarray(f::ROOTFile, path, ith; raw=false)
Reads an array from ith basket of a branch. Set `raw=true` to return raw data and correct offsets.
"""

basketarray(f::ROOTFile, path::AbstractString, ithbasket) = basketarray(f, f[path], ithbasket)
@memoize LRU(; maxsize=1 * 1024^3, by=x->sum(sizeof, x)) function basketarray(f::ROOTFile, branch, ithbasket)
# function basketarray(f::ROOTFile, branch, ithbasket)
    ismissing(branch) && error("No branch found at $path")
    length(branch.fLeaves.elements) > 1 && error(
            "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.")

    rawdata, rawoffsets = readbasket(f, branch, ithbasket)
    T, J = auto_T_JaggT(branch; customstructs = f.customstructs)
    interped_data(rawdata, rawoffsets, T, J)
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
    buffer::Vector{T}
    buffer_range::UnitRange{Int64}

    function LazyBranch(f::ROOTFile, b::Union{TBranch, TBranchElement})
        T, J = auto_T_JaggT(b; customstructs = f.customstructs)
        new{T, J}(f, b, length(b), b.fBasketEntry, T[], 0:0)
    end
end

function Base.hash(lb::LazyBranch, h::UInt)
    h = hash(lb.f, h)
    h = hash(lb.b.fClassName, h)
    h = hash(lb.L, h)
    h = hash(lb.buffer_range, h)
    h
end
Base.size(ba::LazyBranch) = (ba.L,)
Base.length(ba::LazyBranch) = ba.L
Base.firstindex(ba::LazyBranch) = 1
Base.lastindex(ba::LazyBranch) = ba.L
Base.eltype(ba::LazyBranch{T,J}) where {T,J} = T

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
    br = ba.buffer_range
    if idx ∉ br
        seek_idx = findfirst(x -> x>(idx-1), ba.fEntry) - 1 #support 1.0 syntax
        ba.buffer = basketarray(ba.f, ba.b, seek_idx)
        br = ba.fEntry[seek_idx] + 1 : ba.fEntry[seek_idx+1] - 1 
        ba.buffer_range = br
    end
    localidx = idx - br.start + 1
    return ba.buffer[localidx]
end

function Base.iterate(ba::LazyBranch{T, J}, idx=1) where {T, J}
    idx>ba.L && return nothing
    return (ba[idx], idx+1)
end

const _LazyTreeType = TypedTables.Table{<:NamedTuple, 1, NamedTuple{S, N}} where {S, N <: Tuple{Vararg{LazyBranch}}}

struct LazyTree{T} <: DataFrames.AbstractDataFrame
    treetable::T
    colidx::DataFrames.Index
end
@inline innertable(t::LazyTree) = Core.getfield(t, :treetable)

# a specific branch
Base.getindex(lt::LazyTree, row::Int) = innertable(lt)[row]
Base.getindex(lt::LazyTree, rang::UnitRange) = LazyTree(innertable(lt)[rang], Core.getfield(lt, :colidx))
Base.getindex(lt::LazyTree, ::typeof(!), s::Symbol) = lt[:, s]
Base.getindex(lt::LazyTree, ::Colon, i::Int) = lt[:, propertynames(lt)[i]]
Base.getindex(lt::LazyTree, ::typeof(!), i::Int) = lt[:, propertynames(lt)[i]]
Base.getindex(lt::LazyTree, ::Colon, s::Symbol) = getproperty(innertable(lt), s) # the real deal

# a specific event
Base.getindex(lt::LazyTree, row::Int, col::Int) = lt[:, col][row]
Base.getindex(lt::LazyTree, row::Int, col::Symbol) = lt[:, col][row]
Base.getindex(lt::LazyTree, rows::UnitRange, col::Symbol) = lt[:, col][rows]
Base.getindex(lt::LazyTree, ::Colon) = lt[1:end]
Base.firstindex(lt::LazyTree) = 1
Base.lastindex(lt::LazyTree) = length(lt)

# interfacing AbstractDataFrame
DataFrames._check_consistency(lt::LazyTree) = nothing #we're read-only
Base.names(lt::LazyTree) = collect(String.(propertynames(innertable(lt))))
DataFrames.index(lt::LazyTree) = Core.getfield(lt, :colidx)
DataFrames.ncol(lt::LazyTree) = length(DataFrames.index(lt))
Base.length(lt::LazyTree) = length(innertable(lt))
DataFrames.nrow(lt::LazyTree) = length(lt)

function LazyTree(f::ROOTFile, s::AbstractString, branches)
    tree = f[s]
    tree isa TTree || error("$s is not a tree name.")
    d = Dict{Symbol, LazyBranch}()
    d_colidx = Dict{Symbol, Int}()
    _m(s::AbstractString) = isequal(s)
    _m(r::Regex) = contains(r)
    branches = mapreduce(b->filter(_m(b), keys(f[s])), ∪, branches)
    SB = Symbol.(branches)
    for (i,b) in enumerate(SB)
        d[b] = f["$s/$b"]
        d_colidx[b] = i
    end
    if length(branches) > 30
        @warn "Your tree is pretty wide $(length(branches)), this will take compiler a moment."
    end
    LazyTree( TypedTables.Table(d), DataFrames.Index(d_colidx, SB) )
end

function LazyTree(f::ROOTFile, s::AbstractString)
    LazyTree(f, s, keys(f[s]))
end

struct LazyEvent{T<:LazyTree}
    tree::T
    idx::Int64
end
Base.show(io::IO, evt::LazyEvent) = show(io, "LazyEvent with: $(propertynames(evt))")
Base.getproperty(evt::LazyEvent, s::Symbol) = Core.getfield(evt, :tree)[Core.getfield(evt, :idx), s]
Base.collect(evt::LazyEvent) = Core.getfield(evt, :tree)[Core.getfield(evt, :idx)]

function Base.iterate(tree::T, idx=1) where T <: LazyTree
    idx > length(tree) && return nothing
    LazyEvent{T}(tree, idx), idx+1
end

# TODO this is not terribly slow, but we can get faster implementation still ;)
function Base.getindex(ba::LazyBranch{T, J}, rang::UnitRange) where {T, J}
    [ba[i] for i in rang]
end
