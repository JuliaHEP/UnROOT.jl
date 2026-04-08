abstract type AbstractSourceStream end

"""
Placeholder function which is extended with HTTP is loaded.
"""
function httpstreamer(url)
    error("Opening HTTP streamed ROOT files requires to install and load the 'HTTP' module.")
end

"""
Placeholder function which is extended with XRootD is loaded.
"""
function xrootdstreamer(url)
    error("Opening XRootD streamed ROOT files requires to install and load the 'XRootD' module.")
end

mutable struct MmapStream <: AbstractSourceStream# Mmap based
    mmap_ary::Vector{UInt8}
    seekloc::Int
    size::Int
    function MmapStream(filepath::AbstractString) 
        size = filesize(filepath)
        new(mmap(filepath), 0, size)
     end
end

read_seek_nb(fobj::MmapStream, seek, nb) = fobj.mmap_ary[seek+1:seek+nb]

function Base.read(fobj::MmapStream, nb::Integer)
    stop = min(fobj.seekloc + nb, fobj.size)
    b = fobj.mmap_ary[fobj.seekloc+1 : stop]
    fobj.seekloc += nb
    return b
end

function Base.close(::MmapStream) # no-op
    nothing
end

function Base.read(fobj::AbstractSourceStream, ::Type{T}) where T
    return only(reinterpret(T, read(fobj, sizeof(T))))
end

function Base.position(fobj::AbstractSourceStream)
    fobj.seekloc
end

function Base.seek(fobj::AbstractSourceStream, loc)
    fobj.seekloc = loc
    return fobj
end

function Base.skip(fobj::AbstractSourceStream, stride)
    fobj.seekloc += stride
    return fobj
end

function Base.seekstart(fobj::AbstractSourceStream)
    fobj.seekloc = 0
    return fobj
end

function Base.read(fobj::AbstractSourceStream)
    read(fobj, fobj.size - fobj.seekloc + 1)
end
