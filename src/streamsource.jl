using XRootD.XrdCl
import HTTP

mutable struct XRDStream
    file::File     # encapsulates a XRootD.XrdCl!File object
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
        #TODO: determine multipart support
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
end

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
    stop = min(fobj.size-1, stop) 
    hd = ("Range" => "bytes=$(seek)-$stop", "Authorization" => "Bearer $(fobj.scitoken)")
    b = HTTP.request(HTTP.stack(), "GET", fobj.uri, hd, UInt8[]).body
    return b
end

function Base.read(fobj::SourceStream)
    read(fobj, fobj.size - fobj.seekloc + 1)
end

function XRDStream(url::AbstractString)
    file = File()
    st, _ = open(file, url, OpenFlags.Read)
    isError(st) && error("XRootD file open error: $st")
    st, statinfo = stat(file)
    isError(st) && error("XRootD file stat error: $st")
    XRDStream(file, 0, statinfo.size)
end

function Base.close(fobj::XRDStream)
    close(fobj.file)
end

function read_seek_nb(fobj::XRDStream, seek, nb)
    st, buffer = read(fobj.file, nb, seek)
    isError(st) && error("XRootD file read error: $st")
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
    isError(st) && error("XRootD file read error: $st")
    fobj.seekloc += nb
    return buffer
end
