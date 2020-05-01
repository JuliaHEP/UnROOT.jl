module ROOTIO

export ROOTFile, array

import Base: keys, get, getindex, show, length, iterate
using StaticArrays
using CodecZlib
using Mixers
using Parameters

include("constants.jl")
include("utils.jl")
include("io.jl")
include("types.jl")
include("streamers.jl")
include("root.jl")

end # module
