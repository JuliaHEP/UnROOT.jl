module UnROOTXRootDExt

import UnROOT: AbstractSourceStream, xrootdstreamer, read_seek_nb
import XRootD


xrootdstreamer(url::AbstractString) = XRDStream(url)

mutable struct XRDStream <: AbstractSourceStream
    file::XRootD.XrdCl.File
    seekloc::Int
    size::Int
end

function XRDStream(url::AbstractString)
    file = XRootD.XrdCl.File()
    st, _ = open(file, url, XRootD.XrdCl.OpenFlags.Read)
    XRootD.XrdCl.isError(st) && error("XRootD file open error: $st")
    st, statinfo = stat(file)
    XRootD.XrdCl.isError(st) && error("XRootD file stat error: $st")
    XRDStream(file, 0, statinfo.size)
end

function Base.close(fobj::XRDStream)
    close(fobj.file)
end

function read_seek_nb(fobj::XRDStream, seek, nb)
    st, buffer = read(fobj.file, nb, seek)
    XRootD.XrdCl.isError(st) && error("XRootD file read error: $st")
    return buffer
end

function Base.read(fobj::XRDStream, ::Type{T}) where T
    @debug @show T, sizeof(T)
    nb = sizeof(T)
    output = Ref{T}()
    tko = Base.@_gc_preserve_begin output
    po = pointer_from_objref(output)
    unsafe_read(fobj.file, po, nb, fobj.seekloc)
    Base.@_gc_preserve_end tko
    fobj.seekloc += nb
    return output[]
end

function Base.read(fobj::XRDStream, nb::Integer)
    st, buffer = read(fobj.file, nb, fobj.seekloc)
    XRootD.XrdCl.isError(st) && error("XRootD file read error: $st")
    fobj.seekloc += nb
    return buffer
end

end
