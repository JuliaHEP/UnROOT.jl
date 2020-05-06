module ROOTIO

export ROOTFile, array

import Base: keys, get, getindex, show, length, iterate, sizeof

using CodecZlib
using Mixers
using Parameters
using StaticArrays
using ArraysOfArrays

include("constants.jl")
include("utils.jl")
include("io.jl")
include("types.jl")
include("streamers.jl")
include("root.jl")
include("custom.jl")

end # module
