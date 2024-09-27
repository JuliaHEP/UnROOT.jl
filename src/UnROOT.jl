module UnROOT

import SentinelArrays: ChainedVector
import Mmap: mmap
export ROOTFile, LazyBranch, LazyTree

import Base: close, keys, get, getindex, getproperty, show, length, iterate, position
ntoh(b) = Base.ntoh(b)
ntoh(b::Bool) = b
reinterpret(a,b) = Base.reinterpret(a,b)

import AbstractTrees: children, printnode, print_tree

using CodecLz4, CodecXz, CodecZstd, StaticArrays, LorentzVectors, ArraysOfArrays, FHist
using Mixers, Parameters, Memoization, LRUCache
import IterTools: groupby

using LibDeflate: zlib_decompress!, Decompressor, crc32
using BitIntegers: @define_integers

import Tables, PrettyTables

if VERSION < v"1.9"
  using TOML
  pkgversion(m::Module) = TOML.parsefile(joinpath(pkgdir(m), "Project.toml"))["version"] |> VersionNumber
end

"""
    OffsetBuffer

Works with seek, position of the original file. Think of it as a view of IOStream that can be
indexed with original positions.
"""
struct OffsetBuffer{T}
    io::T
    offset::Int
end
Base.read(io::OffsetBuffer, nb) = Base.read(io.io, nb)
Base.seek(io::OffsetBuffer, i) = Base.seek(io.io, i - io.offset)
Base.skip(io::OffsetBuffer, i) = Base.skip(io.io, i)
Base.position(io::OffsetBuffer) = position(io.io) + io.offset

include("constants.jl")
include("streamsource.jl")
include("io.jl")
include("types.jl")
include("utils.jl")
include("streamers.jl")
include("bootstrap.jl")
include("root.jl")
include("iteration.jl")
include("custom.jl")
include("displays.jl")

using StructArrays: StructArray
using XXHashNative: xxh3_64
# using OhMyThreads: tmap

include("RNTuple/bootstrap.jl")
include("RNTuple/constants.jl")
include("RNTuple/header.jl")
include("RNTuple/footer.jl")
include("RNTuple/fieldcolumn_schema.jl")
include("RNTuple/highlevel.jl")
include("RNTuple/fieldcolumn_reading.jl")
include("RNTuple/displays.jl")

include("RNTuple/Writing/constants.jl")
include("RNTuple/Writing/TFileWriter.jl")
include("RNTuple/Writing/Stubs.jl")

_maxthreadid() = @static if VERSION < v"1.9"
    Threads.nthreads()
else
    Threads.maxthreadid()
end

using PrecompileTools: @compile_workload

if VERSION >= v"1.9"
    @compile_workload begin
        t = LazyTree(UnROOT.samplefile("tree_with_jagged_array.root"), "t1")
        show(devnull, t)
        show(devnull, t[1])
        # UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")["ntuple"]
    end
end

end # module
