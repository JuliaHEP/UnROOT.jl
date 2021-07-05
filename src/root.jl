using DataFrames: DataFrame

struct ROOTDirectory
    name::AbstractString
    header::ROOTDirectoryHeader
    keys::Vector{TKey}
end

struct ROOTFile
    filename::AbstractString
    filepath::AbstractString
    format_version::Int32
    header::FileHeader
    fobj::IOStream
    tkey::TKey
    streamers::Streamers
    directory::ROOTDirectory
end
Base.open(f::ROOTFile) = open(f.filepath)


function ROOTFile(filename::AbstractString)
    fobj = Base.open(filename)
    filepath = abspath(filename)
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

    ROOTFile(filename, filepath, format_version, header, fobj, tkey, streamers, directory)
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


@memoize LRU(maxsize = 2000) function Base.getindex(f::ROOTFile, s::AbstractString)
    if '/' ∈ s
        @debug "Splitting path '$s' and getting items recursively"
        paths = split(s, '/')
        return f[first(paths)][join(paths[2:end], "/")]
    end
    tkey = f.directory.keys[findfirst(isequal(s), keys(f))]
    @debug "Retrieving $s ('$(tkey.fClassName)')"
    streamer = getfield(@__MODULE__, Symbol(tkey.fClassName))
    S = open(f) do local_io
        streamer(local_io, tkey, f.streamers.refs)
    end
    return S
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

Reads an array from a branch.
"""
function array(f::ROOTFile, path; raw=false)
    branch = f[path]
    if ismissing(branch)
        error("No branch found at $path")
    end

    if !raw && length(branch.fLeaves.elements) > 1
        error(
            "Branches with multiple leaves are not supported yet. Try reading with `array(...; raw=true)`.",
        )
    end

    leaf = first(branch.fLeaves.elements)
    rawdata, rawoffsets = readbranchraw(f, branch)
    # https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/interp/auto.py#L144
    isjagged = (match(r"\[.*\]", leaf.fTitle) !== nothing)

    # there are two possibility, one is the leaf is just normal leaf but the title has "[...]" in it
    # magic offsets, seems to be common for a lot of types, see auto.py in uproot3
    # only needs when the jaggedness comes from TLeafElements, not needed when
    # the jaggedness comes from having "[]" in TLeaf's title
    jagg_offset = leaf isa TLeafElement ? 10 : 0
    if raw
        return rawdata, rawoffsets
    end
    # the other is where we need to auto detector T bsaed on class name
    if isjagged || !iszero(jagg_offset) # non-primitive jagged leaf
        T = autointerp_T(branch, leaf)

        # for each "event", the index range is `offsets[i] + jagg_offset + 1` to `offsets[i+1]`
        # this is why we need to append `rawoffsets` in the `readbranchraw()` call
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

"""
    arrays(f::ROOTFile, treename)

Reads all branches from a tree.
"""
function arrays(f::ROOTFile, treename)
    names = keys(f[treename])
    res = Vector{Any}(undef, length(names))
    Threads.@threads for i in eachindex(names)
        res[i] = array(f, "$treename/$(names[i])")
    end
    res
end

function autointerp_T(branch, leaf)
    if hasproperty(branch, :fClassName)
        classname = branch.fClassName # the C++ class name, such as "vector<int>"
        m = match(r"vector<(.*)>", classname)
        m===nothing && error("Cannot understand fClassName: $classname.")
        elname = m[1]
        elname = endswith(elname, "_t") ? lowercase(chop(elname; tail=2)) : elname  # Double_t -> double
        try
            elname == "bool" && return Bool #Cbool doesn't exist
            getfield(Base, Symbol(:C, elname))
        catch
            error("Cannot convert element of $elname to a native Julia type")
        end
    else
        primitivetype(leaf)
    end

end


"""
    function DataFrame(f::ROOTFile, path)

Reads a tree into a dataframe
"""
function DataFrame(f::ROOTFile, path)
    names = keys(f[path])
    cols = [array(f, path * "/" * n) for n in names]
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


# read all bytes of DATA and OFFSET from a branch
function readbranchraw(f::ROOTFile, branch)
    io = open(f)
    seeks = branch.fBasketSeek
    nbytes = branch.fBasketBytes

    total_entries = branch.fEntries
    # Just to check if we have a jagged structure
    # streamer = streamerfor()

    max_len = sum(nbytes)
    datas = sizehint!(Vector{UInt8}(), max_len)
    offsets = sizehint!(Vector{Int32}(), total_entries+1) # this is always Int32
    total_idx = 1
    for i in eachindex(seeks)
        @debug "Reading raw basket data" seeks[i] nbytes[i]
        seek_pos, numofbytes = seeks[i], nbytes[i]
        seek_pos == 0 && break
        data, offset, idx = readbasketbytes!(f, seek_pos, total_idx)
        total_idx += idx
        append!(datas, data)
        append!(offsets, offset)
    end
    close(io)
    datas, offsets
end


# Thanks Jim and Philippe
# https://groups.google.com/forum/#!topic/polyglot-root-io/yeC0mAizQcA
# The offsets start at fKeylen - fLast + 4. A singe basket of data looks like this:
#                                           4 bytes          4 bytes
# ┌─────────┬────────────────────────────────┬───┬────────────┬───┐
# │ TKey    │ content                        │ X │ offsets    │ x │
# └─────────┴────────────────────────────────┴───┴────────────┴───┘
#           │←        fLast - fKeylen       →│(l1)                │
#           │                                                     │
#           │←                       fObjlen                     →│
#
@memoize LRU(;maxsize=2000) function readbasketbytes!(f::ROOTFile, seek_pos, idx)
    local_io = open(f)
    seek(local_io, seek_pos)

    basketkey = unpack(local_io, TBasketKey)
    basketrawbytes = read(datastream(local_io, basketkey))

    close(local_io)

    contentsize = basketkey.fLast - basketkey.fKeylen
    Keylen = basketkey.fKeylen

    offsetbytesize = basketkey.fObjlen - contentsize - 8
    offsetnumints = offsetbytesize ÷ 4 # these are always Int32
    l1 = contentsize + 4 # see the graph above

    data = @view basketrawbytes[1:contentsize]
    if offsetbytesize > 0

        #indexing is inclusive on both ends
        offbytes = @view basketrawbytes[l1+1:l1+4*offsetnumints]
        global_offset = 0

        # offsets starts at -fKeylen, same as the `local_offset` we pass in in the loop
        offset = ntoh.(reinterpret(Int32, offbytes)) .+ global_offset .- Keylen
        push!(offset, basketkey.fLast - basketkey.fKeylen)
        # in the naive case idx==1, contentsize == length(data)
        # resize!(data, idx + contentsize - 1) 
        data, offset, contentsize
    else
        data, Int32[], contentsize
    end

end
