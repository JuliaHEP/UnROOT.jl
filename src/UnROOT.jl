module UnROOT

using LazyArrays
export ROOTFile, LazyBranch, LazyTree

import Base: close, keys, get, getindex, getproperty, show, length, iterate, position, ntoh, lock, unlock, reinterpret
ntoh(b::Bool) = b

import AbstractTrees: children, printnode, print_tree

using CodecLz4, CodecXz, CodecZstd, StaticArrays, LorentzVectors, ArraysOfArrays
using Mixers, Parameters, Memoization, LRUCache
import IterTools: groupby

import LibDeflate: zlib_decompress!, Decompressor

import Tables, TypedTables, PrettyTables

@static if VERSION < v"1.6"
    Base.first(a::AbstractVector{S}, n::Integer) where S<: AbstractString = a[1:(length(a) > n ? n : end)]
    Base.first(a::S, n::Integer) where S<: AbstractString = a[1:(length(a) > n ? n : end)]
end

function unsafe_arraycast(::Type{D}, ary::Vector{S}) where {S, D}
    l = sizeof(S)*length(ary)÷sizeof(D)
    ccall(:jl_reshape_array, Vector{D}, (Any, Any, Any), Vector{D}, ary, (l,))
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
