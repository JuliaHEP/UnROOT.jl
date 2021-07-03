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

    if !raw && length(branch.fLeaves.elements) > 1
        error(
            "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.",
        )
    end

    leaf = first(branch.fLeaves.elements)
    rawdata, rawoffsets = readbasketsraw(f.fobj, branch)
    if raw
        return rawdata, rawoffsets
    else
        if leaf isa TLeafElement # non-primitive jagged leaf
            classname = branch.fClassName # the C++ class name, such as "vector<int>"
            m = match(r"vector<(.*)>", classname)
            isnothing(m) && error("Cannot understand fClassName: $classname.")
            elname = m[1]
            elname = endswith(elname, "_t") ? lowercase(chop(elname; tail=2)) : elname  # Double_t -> double
            T = try
                getfield(Base, Symbol(:C, elname))
            catch
                error("Cannot convert element of $elname to a native Julia type")
            end

            jagg_offset = 10 # magic offsets, seems to be common for a lot of types, see auto.py in uproot3

            # for each "event", the index range is `offsets[i] + jagg_offset + 1` to `offsets[i+1]`
            # this is why we need to append `rawoffsets` in the `readbasketsraw()` call
            # when you use this range to index `rawdata`, you will get raw bytes belong to each event
            # Say your real data is Int32 and you see 8 bytes after indexing, then this event has [num1, num2] as real data
            @views [
                ntoh.(reinterpret(
                        T, rawdata[ (rawoffsets[i]+jagg_offset+1):rawoffsets[i+1] ]
                    )) for i in 1:(length(rawoffsets) - 1)
            ]
        else # the branch is not jagged
            return ntoh.(reinterpret(primitivetype(leaf), rawdata))
        end
    end
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

"""
    splitup(data::Vector{UInt8}, offsets, T::Type; skipbytes=0, primitive=false)

Given the `offsets` and `data` return by `array(...; raw = true)`, reconstructed the actual
array (can be jagged, or with custome struct).
"""
function splitup(data::Vector{UInt8}, offsets, T::Type; skipbytes=0, primitive=false)
    elsize = sizeof(T)
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



function readbasketsraw(io, branch)
    seeks = branch.fBasketSeek
    bytes = branch.fBasketBytes

    total_entries = branch.fEntries
    # Just to check if we have a jagged structure
    # streamer = streamerfor()

    max_len = sum(bytes)
    data = sizehint!(Vector{UInt8}(), max_len)
    offsets = sizehint!(Vector{Int32}(), total_entries+1) # this is always Int32
    idx = 1
    for (basket_seek, n_bytes) in zip(seeks, bytes)
        @debug "Reading raw basket data" basket_seek n_bytes
        basket_seek == 0 && break
        seek(io, basket_seek)
        idx += readbasketbytes!(data, offsets, io, idx)
    end
    data, offsets
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
function readbasketbytes!(data, offsets, io, idx)
    basketkey = unpack(io, TBasketKey)

    s = datastream(io, basketkey)  # position(s) == 0, but offsets start at -basketkey.fKeylen
    start = position(s)
    contentsize = basketkey.fLast - basketkey.fKeylen
    offsetbytesize = basketkey.fObjlen - contentsize - 8
    offset_len = offsetbytesize ÷ 4 # these are always Int32

    if offsetbytesize > 0
        @debug "Offset data present" offsetbytesize
        skip(s, contentsize)
        skip(s, 4) # a flag that indicates the type of data that follows
        readoffsets!(offsets, s, offset_len, length(data), length(data))
        skip(s, 4)  # "Pointer-to/location-of last used byte in basket"
        seek(s, start)
    end

    @debug "Reading $(contentsize) bytes"
    readbytes!(s, data, idx, contentsize)
    push!(offsets, basketkey.fLast)
    offsets .-= basketkey.fKeylen 

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
