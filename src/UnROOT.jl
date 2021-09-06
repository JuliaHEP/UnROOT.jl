module UnROOT

export ROOTFile, LazyBranch, LazyTree, @batch

import Base: close, keys, get, getindex, getproperty, show, length, iterate, position, ntoh, lock, unlock, reinterpret
ntoh(b::Bool) = b

import AbstractTrees: children, printnode, print_tree

using CodecZlib, CodecLz4, CodecXz, CodecZstd, StaticArrays, LorentzVectors, ArraysOfArrays
using Mixers, Parameters, Memoization, LRUCache, Polyester

import Tables, TypedTables, PrettyTables, DataFrames

@static if VERSION < v"1.6"
    Base.first(a::AbstractVector{S}, n::Integer) where S<: AbstractString = a[1:(length(a) > n ? n : end)]
    Base.first(a::S, n::Integer) where S<: AbstractString = a[1:(length(a) > n ? n : end)]
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
include("polyester.jl")
include("displays.jl")

end # module
