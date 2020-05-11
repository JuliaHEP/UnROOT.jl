struct ROOTDirectory
    name::AbstractString
    header::ROOTDirectoryHeader
    keys::Vector{TKey}
end

struct ROOTFile
    filename::AbstractString
    format_version::Int32
    header::FileHeader
    fobj::IOStream
    tkey::TKey
    streamers::Streamers
    directory::ROOTDirectory
    branch_cache::Dict{String, TBranch}
end


function ROOTFile(filename::AbstractString)
    fobj = Base.open(filename)
    preamble = unpack(fobj, FilePreamble)
    String(preamble.identifier) == "root" || error("Not a ROOT file!")
    format_version = preamble.fVersion

    if format_version < 1000000
        @debug "32bit ROOT file"
        header = unpack(fobj, FileHeader32)
    else
        @debug "64bit ROOT file"
        header = unpack(fobj, FileHeader64)
    end

    # Streamers
    if header.fSeekInfo != 0
        @debug "Reading streamer info."
        seek(fobj, header.fSeekInfo)
        streamers = Streamers(fobj)
        define_streamers(streamers)
    else
        @debug "No streamer info present, skipping."
    end

    seek(fobj, header.fBEGIN)
    tkey = unpack(fobj, TKey)

    # Reading the header key for the top ROOT directory
    seek(fobj, header.fBEGIN + header.fNbytesName)
    dir_header = unpack(fobj, ROOTDirectoryHeader)
    if dir_header.fSeekKeys == 0
        ROOTFile(format_version, header, fobj, tkey, [])
    end

    seek(fobj, dir_header.fSeekKeys)
    header_key = unpack(fobj, TKey)

    n_keys = readtype(fobj, Int32)
    keys = [unpack(fobj, TKey) for _ in 1:n_keys]

    directory = ROOTDirectory(tkey.fName, dir_header, keys)

    ROOTFile(filename, format_version, header, fobj, tkey, streamers, directory, Dict())
end

function Base.show(io::IO, f::ROOTFile)
    n_entries = length(f.directory.keys)
    entries_suffix = n_entries == 1 ? "entry" : "entries"
    n_streamers = length(f.streamers)
    streamers_suffix = n_streamers == 1 ? "streamer" : "streamers"
    print(io, typeof(f))
    print(io, "(\"$(f.filename)\") with $n_entries $entries_suffix ")
    print(io, "and $n_streamers $streamers_suffix.")
end


function streamerfor(f::ROOTFile, name::AbstractString)
    for e in f.streamers.elements
        if e.streamer.fName == name
            return e
        end
    end
    error("No streamer found for $name.")
end


function Base.getindex(f::ROOTFile, s::AbstractString)
    if '/' ∈ s
        @debug "Splitting path '$s' and getting items recursively"
        paths = split(s, '/')
        return f[first(paths)][join(paths[2:end], "/")]
    end
    tkey = f.directory.keys[findfirst(isequal(s), keys(f))]
    @debug "Retrieving $s ('$(tkey.fClassName)')"
    streamer = getfield(@__MODULE__, Symbol(tkey.fClassName))
    streamer(f.fobj, tkey, f.streamers.refs)
end

function Base.keys(f::ROOTFile)
    keys(f.directory)
end

function Base.keys(d::ROOTDirectory)
    [key.fName for key in d.keys]
end

function Base.keys(b::TBranchElement)
    [branch.fName for branch in b.fBranches.elements]
end

function Base.get(f::ROOTFile, k::TKey)
end

"""
    function array(f::ROOTFile, path)

Reads an array from a branch. Currently hardcoded to Int32
"""
function array(f::ROOTFile, path; raw=false)
    if path ∈ keys(f.branch_cache)
        branch = f.branch_cache[path]
    else
        branch = f[path]
        if ismissing(branch)
            error("No branch found at $path")
        end
    end

    if raw
        return readbasketsraw(f.fobj, branch)
    end

    if length(branch.fLeaves.elements) > 1
        error("Branches with multiple leaves are not supported yet.")
    end

    leaf = first(branch.fLeaves.elements)

    readbaskets(f.fobj, branch, primitivetype(leaf))
end


function readbaskets(io, branch, ::Type{T}) where {T}
    seeks = branch.fBasketSeek
    entries = branch.fBasketEntry

    out = Vector{T}()
    sizehint!(out, branch.fEntries)


    for (idx, basket_seek) in enumerate(seeks)
        @debug "Reading basket" idx basket_seek
        if basket_seek == 0
            break
        end
        seek(io, basket_seek)
        basketkey = unpack(io, TBasketKey)
        s = datastream(io, basketkey)

        for _ in entries[idx]:(entries[idx + 1] - 1)
            push!(out, readtype(s, T))
        end
    end
    out
end

function readbasketsraw(io, branch)
    seeks = branch.fBasketSeek
    bytes = branch.fBasketBytes

    total_entries = branch.fEntries
    @show branch
    @show total_entries
    @show seeks bytes

    @show branch.fType

    out = Vector{UInt8}()
    offsets = Vector{Int32}()
    sizehint!(out, sum(bytes))
    for (basket_seek, n_bytes) in zip(seeks, bytes)
        @debug "Reading raw basket data" basket_seek n_bytes
        if basket_seek == 0
            break
        end
        seek(io, basket_seek)
        basketkey = unpack(io, TBasketKey)
        @show basketkey
        s = datastream(io, basketkey)  # position(s) == 0, but offsets start at -basketkey.fKeylen
        start = position(s)
        @show start
        contentsize = basketkey.fLast - basketkey.fKeylen
        offsetlength = basketkey.fObjlen - contentsize

        if offsetlength > 0
            @debug "Offset data present" offsetlength
            skip(s, contentsize)
            skip(s, 4)
            for _ in 1:((offsetlength - 8)/4)
                push!(offsets, readtype(s, Int32))
            end
            # https://groups.google.com/forum/#!topic/polyglot-root-io/yeC0mAizQcA
            skip(s, 4)  # "Pointer-to/location-of last used byte in basket"
            seek(s, start)
        end

        for _ in 1:contentsize
            push!(out, readtype(s, UInt8))
        end
    end
    out, offsets
end
