using xrootdgo_jll
import HTTP

mutable struct XRDStream
    gofile_id::Cstring # used as key to a global `map` on the Go side
    seekloc::Int
    size::Int
end

mutable struct HTTPStream
    uri::HTTP.URI
    seekloc::Int
    size::Int
    multipart::Bool
    function HTTPStream(uri::AbstractString)
        #TODO: determin multipart support
        test = HTTP.request("GET", uri, ("Range" => "bytes=0-3", "User-Agent" => "UnROOT.jl"))
        @assert test.status==206 "bad network or wrong server"
        @assert String(test.body)=="root" "not a root file"
        multipart = false
        local v
        for pair in test.headers
            if lowercase(pair[1]) == "content-range"
                v = pair[2]
                break
            end
        end
        size = parse(Int, match(r"/(\d+)", v).captures[1])
        new(HTTP.URI(uri), 0, size, multipart)
    end
end
const RemoteStream = Union{HTTPStream, XRDStream}


function Base.position(fobj::RemoteStream)
    fobj.seekloc
end

function Base.seek(fobj::RemoteStream, loc)
    fobj.seekloc = loc
    return fobj
end

function Base.skip(fobj::RemoteStream, stride)
    fobj.seekloc += stride
    return fobj
end

function Base.seekstart(fobj::RemoteStream)
    fobj.seekloc = 0
    return fobj
end

function Base.close(fobj::HTTPStream) # no-op
    nothing
end

function Base.read(fobj::HTTPStream, nb::Integer)
    stop = fobj.seekloc + nb - 1
    hd = ["Range" => "bytes=$(fobj.seekloc)-$stop"]
    b = HTTP.request(HTTP.stack(), "GET", fobj.uri, hd, UInt8[]).body
    fobj.seekloc += nb
    return b
end

function Base.read(fobj::RemoteStream)
    read(fobj, fobj.size - fobj.seekloc + 1)
end

function XRDStream(urlbase::AbstractString, filepath::AbstractString, username::AbstractString)
    file_id = @ccall xrootdgo.Open(urlbase::Cstring, filepath::Cstring, username::Cstring)::Cstring
    # file_id = @threadcall((:Open, xrootdgo), Cstring, (Cstring, Cstring, Cstring), urlbase, filepath, username)
    size = @ccall xrootdgo.Size(file_id::Cstring)::Int
    XRDStream(file_id, 0, size)
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

# TODO: should never get used, if things go well
# function Base.read(fobj::XRDStream, ::Type{T}) where T
#     @debug @show T, sizeof(T)
#     nb = sizeof(T)
#     output = Ref{T}()
#     tko = Base.@_gc_preserve_begin output
#     po = Ptr{UInt8}(pointer_from_objref(output))
#     _read!(po, fobj, nb, fobj.seekloc)
#     Base.@_gc_preserve_end tko
#     fobj.seekloc += nb
#     return output[]
# end

function Base.read(fobj::XRDStream, nb::Integer)
    buffer = Vector{UInt8}(undef, nb)
    GC.@preserve buffer _read!(buffer, fobj, nb, fobj.seekloc)
    fobj.seekloc += nb
    return buffer
end
