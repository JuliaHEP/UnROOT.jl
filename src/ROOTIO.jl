module ROOTIO

export ROOTFile

import Base: keys, get, getindex
using StaticArrays

include("io.jl")
include("types.jl")
include("root.jl")

end # module
