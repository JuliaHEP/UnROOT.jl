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
array(f::ROOTFile, path::AbstractString; raw=false) = array(f::ROOTFile, f[path]; raw=raw)

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

# function barrior to make getting individual index faster
# TODO upstream some types into parametric types for Branch/BranchElement
#
"""
    BranchAccess(f::ROOTFile, branch)

Construct an accessor for a given branch such that `BA[idx]` and or `BA[1:20]` is almost
type-stable. And memory footprint is a single basket (<20MB usually).

# Example
```julia
julia> rf = ROOTFile("./test/samples/tree_with_large_array.root");

julia> b = rf["t1/int32_array"];

julia> ab = UnROOT.BranchAccess(rf, b);

julia> ab[1]
0

julia> ab[begin:end]
0
1
...
```
"""
mutable struct BranchAccess{T, J}
    f::ROOTFile
    b::Union{TBranch, TBranchElement}
    fEntry::Vector{Int64}
    buffer_seek::Int64
    buffer::Vector{T}

    function BranchAccess(f::ROOTFile, b::Union{TBranch, TBranchElement})
        T = eltype(b)
        J = JaggType(only(b.fLeaves.elements))
        max_len = maximum(diff(b.fBasketEntry))
        # we don't know how to deal with multiple leaves yet
        new{T, J}(f, b, b.fBasketEntry, -1, T[])
    end
end
Base.firstindex(ba::BranchAccess) = 1
Base.lastindex(ba::BranchAccess) = length(ba.b)
Base.length(ba::BranchAccess) = length(ba.b)
Base.eltype(ba::BranchAccess{T,J}) where {T,J} = T

function Base.getindex(ba::BranchAccess{T, J}, idx::Integer) where {T, J}
    seek_idx = searchsortedlast(ba.fEntry, idx-1)
    localidx = idx - ba.fEntry[seek_idx]
    if seek_idx != ba.buffer_seek # update buffer
        ba.buffer_seek = seek_idx
        ba.buffer = basketarray(ba.f, ba.b, seek_idx)
    end
    return ba.buffer[localidx]
end

# TODO this is not terribly slow, but we can get faster implementation still ;)
function Base.getindex(ba::BranchAccess{T, J}, rang::UnitRange) where {T, J}
    [ba[i] for i in rang]
end
