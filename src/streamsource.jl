using xrootdgo_jll
import HTTP

mutable struct XRDStream
    gofile_id::Cstring # used as key to a global `map` on the Go side
    seekloc::Int
    size::Int
end

mutable struct MmapStream # Mmap based
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

function Base.close(fobj::MmapStream) # no-op
    nothing
end

# SciToken discovery https://zenodo.org/record/3937438
function _find_scitoken()
    op1 = get(ENV, "BEARER_TOKEN", "")
    op2 = get(ENV, "BEARER_TOKEN_FILE", "")
    op3 = get(ENV, "XDG_RUNTIME_DIR", "")
    uid = @static if Sys.iswindows() 
            "julia"
        else
            strip(read(`id -u`, String))
        end
    op3_file = joinpath(op3, "bt_u$uid")
    op4_file = "/tmp/bt_u$uid"
    token = if !isempty(op1)
        op1
    elseif !isempty(op2)
        read(op2, String)
    elseif !isempty(op3) && isfile(op3_file)
        read(op3_file, String)
    elseif isfile(op4_file)
        read(op4_file, String)
    else
        ""
    end
    return strip(token)
end

mutable struct HTTPStream
    uri::HTTP.URI
    seekloc::Int
    size::Int
    multipart::Bool
    scitoken::String
    function HTTPStream(uri::AbstractString; scitoken = _find_scitoken())
        #TODO: determin multipart support
        test = HTTP.request("GET", uri, 
        ("Range" => "bytes=0-3", "User-Agent" => "UnROOTjl", "Authorization" => "Bearer $scitoken")
        )
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
        new(HTTP.URI(uri), 0, size, multipart, scitoken)
    end
end

const SourceStream = Union{MmapStream, HTTPStream, XRDStream}

function Base.read(fobj::SourceStream, ::Type{T}) where T
    return only(reinterpret(T, read(fobj, sizeof(T))))

function Base.position(fobj::SourceStream)
    fobj.seekloc
end

function Base.seek(fobj::SourceStream, loc)
    fobj.seekloc = loc
    return fobj
end

function Base.skip(fobj::SourceStream, stride)
    fobj.seekloc += stride
    return fobj
end

function Base.seekstart(fobj::SourceStream)
    fobj.seekloc = 0
    return fobj
end

function Base.close(fobj::HTTPStream) # no-op
    nothing
end

function Base.read(fobj::HTTPStream, nb::Integer)
    @debug nb
    b = read_seek_nb(fobj, fobj.seekloc, nb)
    fobj.seekloc += nb
    return b
end

function read_seek_nb(fobj::HTTPStream, seek, nb)
    stop = seek+nb-1
    hd = ("Range" => "bytes=$(seek)-$stop", "Authorization" => "Bearer $(fobj.scitoken)")
    b = HTTP.request(HTTP.stack(), "GET", fobj.uri, hd, UInt8[]).body
    return b
end

function Base.read(fobj::SourceStream)
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

function read_seek_nb(fobj::XRDStream, seek, nb)
    buffer = Vector{UInt8}(undef, nb)
    @threadcall((:ReadAt, xrootdgo), Cvoid, (Ptr{UInt8}, Cstring, Clong, Clong), buffer, fobj.gofile_id, nb, seek)
    # @ccall xrootdgo.ReadAt(buffer::Ptr{UInt8}, 
    #                   fobj.gofile_id::Cstring, nb::Clong, seek::Clong)::Cvoid
    return buffer
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
