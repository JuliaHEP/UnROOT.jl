module ROOTIO

export ROOTFile

import Base: keys, get, getindex, show, length
using StaticArrays
using CodecZlib
using Mixers
using Parameters

include("constants.jl")
include("io.jl")
include("types.jl")
include("streamers.jl")
include("root.jl")

end # module
