module UnROOT

export ROOTFile, LazyBranch, LazyTree

import Base: keys, get, getindex, getproperty, show, length, iterate, position, ntoh, lock, unlock
ntoh(b::Bool) = b

import AbstractTrees: children, printnode, print_tree
using Base.Threads: SpinLock

using CodecZlib, CodecLz4, CodecXz, CodecZstd, StaticArrays
using Mixers, Parameters, Memoization, LRUCache

import Tables, TypedTables, PrettyTables, DataFrames

@static if VERSION < v"1.4"
    Base.first(a::AbstractVector{S}, n::Integer) where S<: AbstractString = a[1:(length(a) > n ? n : end)]
end

include("constants.jl")
include("io.jl")
include("types.jl")
include("utils.jl")
include("streamers.jl")
include("bootstrap.jl")
include("root.jl")
include("iteration.jl")
include("custom.jl")
include("displays.jl")

end # module
