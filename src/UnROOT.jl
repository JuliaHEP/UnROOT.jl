module UnROOT

export ROOTFile, array

import Base: keys, get, getindex, show, length, iterate, position

using CodecZlib, CodecLz4, CodecXz
using Mixers
using Parameters
using StaticArrays

include("constants.jl")
include("io.jl")
include("types.jl")
include("utils.jl")
include("streamers.jl")
include("bootstrap.jl")
include("root.jl")
include("custom.jl")

end # module
