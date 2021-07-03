using DataFrames: DataFrame

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


UUID(f::ROOTFile) = f.header.fUUID


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

Base.keys(t::TTree) = [b.fName for b in t.fBranches.elements]

function Base.getindex(t::T, s::AbstractString) where {T<:Union{TTree, TBranchElement}}
    if '/' ∈ s
        @debug "Splitting path '$s' and getting branches recursively"
        paths = split(s, '/')
        return t[first(paths)][join(paths[2:end], "/")]
    end
    @debug "Searching for branch '$s' in $(length(t.fBranches.elements)) branches."
    for branch in t.fBranches.elements
        @debug branch.fName
        if branch.fName == s
            return branch
        end
    end
    missing
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


"""
    function DataFrame(f::ROOTFile, path)

Reads a tree into a dataframe
"""
function DataFrame(f::ROOTFile, path)
    names = keys(f[path])
    cols = [array(f, path * "/" * n) for n in names]
    for each in cols
        eltype(each) <: Number || error("Jagged array cannot be put into a dataframe")
    end
    DataFrame(cols, names, copycols=false) #avoid double allocation
end

function splitup(data::Vector{UInt8}, offsets, T::Type; skipbytes=0, primitive=false)
    elsize = packedsizeof(T)
    out = sizehint!(Vector{Vector{T}}(), length(offsets))
    lengths = diff(offsets)
    push!(lengths, length(data) - offsets[end] + offsets[1])  # yay ;)
    io = IOBuffer(data)
    for (idx, l) in enumerate(lengths)
        # println("$idx / $(length(lengths))")
        if primitive
            error("primitive interpretation is buggy")
            push!(out, reinterpret(T, data[skipbytes+1:skipbytes+Int32((l - skipbytes))]))
        else
            skip(io, skipbytes)
            n = (l - skipbytes) / elsize
            push!(out, [readtype(io, T) for _ in 1:n])
        end
    end
    out
end


function readbaskets(io, branch, ::Type{T}) where {T}
    seeks = branch.fBasketSeek
    entries = branch.fBasketEntry

    out = sizehint!(Vector{T}(), branch.fEntries)


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
    # Just to check if we have a jagged structure
    # streamer = streamerfor()

    # FIXME This UInt8 is wrong, the final data depends on branch info
    max_len = sum(bytes)
    data = sizehint!(Vector{UInt8}(), max_len)
    offsets = sizehint!(Vector{Int32}(), total_entries+1) # this is always Int32
    idx = 1
    _res = sizehint!(Vector{Int32}(), max_len)
    for (basket_seek, n_bytes) in zip(seeks, bytes)
        @debug "Reading raw basket data" basket_seek n_bytes
        basket_seek == 0 && break
        seek(io, basket_seek)
        idx += readbasketbytes!(data, offsets, io, idx, _res)
    end
    _res, offsets
end


# Thanks Jim and Philippe
# https://groups.google.com/forum/#!topic/polyglot-root-io/yeC0mAizQcA
# The offsets start at fKeylen - fLast + 4. A singe basket of data looks like this:
#                                           4 bytes          4 bytes
# ┌─────────┬────────────────────────────────┬───┬────────────┬───┐
# │ TKey    │ content                        │ X │ offsets    │ x │
# └─────────┴────────────────────────────────┴───┴────────────┴───┘
#           │←        fLast - fKeylen       →│                    │
#           │                                                     │
#           │←                       fObjlen                     →│
#
function readbasketbytes!(data, offsets, io, idx, _res::Vector{T}) where T
    basketkey = unpack(io, TBasketKey)

    # @show basketkey
    s = datastream(io, basketkey)  # position(s) == 0, but offsets start at -basketkey.fKeylen
    start = position(s)
    # @show start
    contentsize = basketkey.fLast - basketkey.fKeylen
    offsetbytesize = basketkey.fObjlen - contentsize - 8
    offset_len = offsetbytesize ÷ 4 # these are always Int32

    if offsetbytesize > 0
        @debug "Offset data present" offsetlength
        skip(s, contentsize)
        skip(s, 4) # a flag that indicates the type of data that follows
        readoffsets!(offsets, s, offset_len, length(data), length(data))
        skip(s, 4)  # "Pointer-to/location-of last used byte in basket"
        seek(s, start)
    end
    push!(offsets, basketkey.fLast)
    offsets .-= basketkey.fKeylen 

    @debug "Reading $(contentsize) bytes"
    readbytes!(s, data, idx, contentsize)

    # FIXME wtf is going on here please make this non-allocating
    # https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/interp/jagged.py#L78-L87
    #
    # FIXME the +10 is for a bunch of jagged stuff, not sure what's the speial case
    bytestarts = offsets[begin:offset_len] .+ 10
    bytestops = offsets[begin+1:offset_len+1]

    # fuck 0/1 index
    mask = OffsetArray(zeros(Int8, contentsize), -1)
    mask[@view bytestarts[bytestarts .< contentsize]] .=  1
    mask[@view bytestops[bytestops .< contentsize]]   .-= 1
    mask = OffsetArrays.no_offset_view(cumsum(mask))

    #FIXME figureout what to interpret to outside
    append!(_res, ntoh.(reinterpret(T, data[mask .== 1])))

    # ======= end of magic =======
    contentsize
end

function readoffsets!(out, s, contentsize, global_offset, local_offset)
    for _ in 1:contentsize
        offset = readtype(s, Int32) + global_offset
        push!(out, offset)
    end
end

"""
    function readbytes!(io, b, offset, nr)

Efficient read of bytes into an existing array at a given offset
"""
function readbytes!(io, b, offset, nr)
    resize!(b, offset + nr - 1)
    nb = UInt(nr)
    # GC.@preserve b unsafe_read(io, pointer(b, offset), nb)
    unsafe_read(io, pointer(b, offset), nb)
    nothing
end
