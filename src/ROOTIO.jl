module ROOTIO

export ROOTFile

import Base: keys, get, getindex
using StaticArrays
using CodecZlib

include("constants.jl")
include("io.jl")
include("types.jl")
include("root.jl")

end # module
