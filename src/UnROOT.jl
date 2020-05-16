module UnROOT

export ROOTFile, array

import Base: keys, get, getindex, show, length, iterate, sizeof, position

using CodecZlib
using Mixers
using Parameters
using StaticArrays

include("constants.jl")
include("utils.jl")
include("io.jl")
include("types.jl")
include("streamers.jl")
include("bootstrap.jl")
include("root.jl")
include("custom.jl")

end # module
