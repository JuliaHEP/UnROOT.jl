using xrootdgo_jll

mutable struct XRDStream
    gofile_id::Cstring # used as key to a global `map` on the Go side
    seekloc::Int
    size::Int
end

function XRDStream(urlbase::AbstractString, filepath::AbstractString, username::AbstractString)
    file_id = @ccall xrootdgo.Open(urlbase::Cstring, filepath::Cstring, username::Cstring)::Cstring
    # file_id = @threadcall((:Open, xrootdgo), Cstring, (Cstring, Cstring, Cstring), urlbase, filepath, username)
    size = @ccall xrootdgo.Size(file_id::Cstring)::Int
    XRDStream(file_id, 0, size)
end

function Base.position(fobj::XRDStream)
    fobj.seekloc
end

function Base.seek(fobj::XRDStream, loc)
    fobj.seekloc = loc
    return fobj
end

function Base.skip(fobj::XRDStream, stride)
    fobj.seekloc += stride
    return fobj
end

function Base.seekstart(fobj::XRDStream)
    fobj.seekloc = 0
    return fobj
end

function Base.close(fobj::XRDStream)
    xrootdgo.Close(fobj.gofile_id)
end

function _read!(ptr, fobj, nb, seekloc)
    @ccall xrootdgo.ReadAt(ptr::Ptr{UInt8}, 
                      fobj.gofile_id::Cstring, nb::Clong, seekloc::Clong)::Cvoid
end

function _read!(ptr, fobj, nb)
    _read!(ptr, fobj, nb, fobj.seekloc)
end

function Base.read(fobj::XRDStream, ::Type{T}) where T
    @debug @show T, sizeof(T)
    nb = sizeof(T)
    output = Ref{T}()
    tko = Base.@_gc_preserve_begin output
    po = Ptr{UInt8}(pointer_from_objref(output))
    _read!(po, fobj, nb, fobj.seekloc)
    Base.@_gc_preserve_end tko
    fobj.seekloc += nb
    return output[]
end

function Base.read(fobj::XRDStream, nb::Integer)
    buffer = Vector{UInt8}(undef, nb)
    GC.@preserve buffer _read!(buffer, fobj, nb, fobj.seekloc)
    fobj.seekloc += nb
    return buffer
end

function Base.read(fobj::XRDStream)
    read(fobj, fobj.size - fobj.seekloc + 1)
end
