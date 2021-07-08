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
    interped_data(rawdata, rawoffsets, branch, JaggType(leaf), T)
end

"""
    basketarray(f::ROOTFile, path, ith; raw=false)
Reads an array from ith basket of a branch. Set `raw=true` to return raw data and correct offsets.
"""
basketarray(f::ROOTFile, path::AbstractString, ithbasket; raw=false) = basketarray(f, f[path], ithbasket; raw=raw)

function basketarray(f::ROOTFile, branch, ithbasket; raw=false)
    ismissing(branch) && error("No branch found at $path")
    (!raw && length(branch.fLeaves.elements) > 1) && error(
            "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.")

    rawdata, rawoffsets = readbasket(f, branch, ithbasket)
    if raw
        return rawdata, rawoffsets
    end
    leaf = first(branch.fLeaves.elements)
    jagt = JaggType(leaf)
    T = eltype(branch) 
    interped_data(rawdata, rawoffsets, branch, JaggType(leaf), T)
end


# TODO restructure it into proper `Base.getindex()`
function getentry(f::ROOTFile, branch, ithentry)
    fEntry = branch.fBasketEntry
    seek_pos = searchsortedlast(fEntry, ithentry-1)
    entries = basketarray(f, branch, seek_pos)
    localidx = ithentry - fEntry[seek_pos]
    entries[localidx]
end
