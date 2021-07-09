module UnROOT

export ROOTFile, LazyBranch, Table

import Base: keys, get, getindex, show, length, iterate, position, ntoh, lock, unlock
using Base.Threads: SpinLock
ntoh(b::Bool) = b

using CodecZlib, CodecLz4, CodecXz, CodecZstd, StaticArrays
using Mixers, Parameters, Memoization, LRUCache 
import Tables, TypedTables

@static if VERSION < v"1.1"
    fieldtypes(T::Type) = [fieldtype(T, f) for f in fieldnames(T)]
end

@static if VERSION < v"1.2"
    hasproperty(x, s::Symbol) = s in fieldnames(typeof(x))
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
include("precompile.jl")


end # module
