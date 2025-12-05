abstract type AbstractSourceStream end

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
