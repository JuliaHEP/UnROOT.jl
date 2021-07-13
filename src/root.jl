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
    lk::ReentrantLock
end
lock(f::ROOTFile) = lock(f.lk)
unlock(f::ROOTFile) = unlock(f.lk)


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

    ROOTFile(filename, format_version, header, fobj, tkey, streamers, directory, ReentrantLock())
end

function Base.show(io::IO, f::ROOTFile)
    n_entries = length(f.directory.keys)
    entries_suffix = n_entries == 1 ? "entry" : "entries"
    n_streamers = length(f.streamers)
    streamers_suffix = n_streamers == 1 ? "streamer" : "streamers"
    print(io, typeof(f))
    print(io, " with $n_entries $entries_suffix ")
    println(io, "and $n_streamers $streamers_suffix.")
    print_tree(f)
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
    S = _getindex(f, s)
    if S isa Union{TBranch, TBranchElement}
        try # if we can't construct LazyBranch, just give up (maybe due to custom class)
            return LazyBranch(f, S)
        catch
            @warn "Can't automatically create LazyBranch for branch $s. Returning a branch object"
        end
    end
    S
end

@memoize LRU(maxsize = 2000) function _getindex(f::ROOTFile, s)
# function _getindex(f::ROOTFile, s)
    if '/' ∈ s
        @debug "Splitting path '$s' and getting items recursively"
        paths = split(s, '/')
        return f[first(paths)][join(paths[2:end], "/")]
    end
    tkey = f.directory.keys[findfirst(isequal(s), keys(f))]
    @debug "Retrieving $s ('$(tkey.fClassName)')"
    streamer = getfield(@__MODULE__, Symbol(tkey.fClassName))
    lock(f)
    try
        S = streamer(f.fobj, tkey, f.streamers.refs)
        return S
    catch
    finally
        unlock(f)
    end
end

function Base.keys(f::ROOTFile)
    keys(f.directory)
end

function Base.keys(d::ROOTDirectory)
    [key.fName for key in d.keys]
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
        if branch.fName == s
            return branch
        end
    end
    missing
end
function Base.getindex(t::TTree, s::Vector{T}) where {T<:AbstractString}
    [t[n] for n in s]
end

function interped_data(rawdata, rawoffsets, ::Type{J}, ::Type{T}) where {J<:JaggType, T}
    # there are two possibility, one is the leaf is just normal leaf but the title has "[...]" in it
    # magic offsets, seems to be common for a lot of types, see auto.py in uproot3
    # only needs when the jaggedness comes from TLeafElements, not needed when
    # the jaggedness comes from having "[]" in TLeaf's title
    # the other is where we need to auto detector T bsaed on class name
    # we want the fundamental type as `reinterpret` will create vector
    elT = eltype(T)
    if J !== Nojagg
        jagg_offset = J===Offsetjagg ? 10 : 0

        # for each "event", the index range is `offsets[i] + jagg_offset + 1` to `offsets[i+1]`
        # this is why we need to append `rawoffsets` in the `readbranchraw()` call
        # when you use this range to index `rawdata`, you will get raw bytes belong to each event
        # Say your real data is Int32 and you see 8 bytes after indexing, then this event has [num1, num2] as real data
        @views [
                ntoh.(reinterpret(
                                  elT, rawdata[ (rawoffsets[i]+jagg_offset+1):rawoffsets[i+1] ]
                                 )) for i in 1:(length(rawoffsets) - 1)
               ]
    else # the branch is not jagged
        return ntoh.(reinterpret(T, rawdata))
    end

end

function _normalize_ftype(fType)
    # Taken from uproot4; thanks Jim ;)
    if Const.kOffsetL < fType < Const.kOffsetP
        fType - kOffsetP
    else
        fType
    end
end

@memoize LRU(;maxsize=10^3) function interp_jaggT(branch, leaf)
    if hasproperty(branch, :fClassName)
        classname = branch.fClassName # the C++ class name, such as "vector<int>"
        m = match(r"vector<(.*)>", classname)
        if m!==nothing
            elname = m[1]
            elname = endswith(elname, "_t") ? lowercase(chop(elname; tail=2)) : elname  # Double_t -> double
            try
                elname == "bool" && return Bool #Cbool doesn't exist
                elname == "unsigned int" && return UInt32 #Cunsigned doesn't exist
                elname == "unsigned char" && return Char #Cunsigned doesn't exist
                getfield(Base, Symbol(:C, elname))
            catch
                error("Cannot convert element of $elname to a native Julia type")
            end
        # Try to interpret by leaf type
        else
            leaftype = _normalize_ftype(leaf.fType)
            leaftype == Const.kBool && return Bool
            leaftype == Const.kChar && return Int8
            leaftype == Const.kUChar && return UInt8
            leaftype == Const.kShort && return Int16
            leaftype == Const.kUShort && return UInt16
            leaftype == Const.kInt && return Int32
            (leaftype in [Const.kBits, Const.kUInt, Const.kCounter]) && return UInt32
            (leaftype in [Const.kLong, Const.kLong64]) && return Int64
            (leaftype in [Const.kULong, Const.kULong64]) && return UInt64
            leaftype == Const.kDouble32 && return Float32
            leaftype == Const.kDouble && return Float64
            error("Cannot interpret type.")
        end
    else
        primitivetype(leaf)
    end
end


# read all bytes of DATA and OFFSET from a branch
function readbranchraw(f::ROOTFile, branch)
    nbytes = branch.fBasketBytes
    datas = sizehint!(Vector{UInt8}(), sum(nbytes)) # maximum length if all data are UInt8
    offsets = sizehint!(zeros(Int32, 1), branch.fEntries+1) # this is always Int32
    position = 0
    foreach(branch.fBasketSeek) do seek
        seek==0 && return
        data, offset = readbasketseek(f, branch, seek)
        append!(datas, data)
        # FIXME: assuming offset has always 0 or at least 2 elements ;)
        append!(offsets, (@view offset[2:end]) .+ position)
        if length(offset) > 0
            position = offset[end]
        end
    end
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
# 3GB cache for baskets
readbasket(f::ROOTFile, branch, ith) = readbasketseek(f, branch, branch.fBasketSeek[ith])

@memoize LRU(; maxsize=3 * 1024^3, by=x -> sum(length, x)) function readbasketseek(
    f::ROOTFile, branch, seek_pos
)::Tuple{Vector{UInt8},Vector{Int32},Int32}  # just being extra careful
    lock(f)
    seek(f.fobj, seek_pos)
    basketkey = unpack(f.fobj, TBasketKey)
    compressedbytes = compressed_datastream(f.fobj, basketkey)
    unlock(f)

    basketrawbytes = decompress_datastreambytes(compressedbytes, basketkey)

    @debug begin
        ibasket = findfirst(==(seek_pos), branch.fBasketSeek)
        mbcompressed = length(compressedbytes)/1024^2
        mbuncompressed = length(basketrawbytes)/1024^2
        "Read branch $(branch.fName), basket $(ibasket), $(mbcompressed) MB compressed, $(mbuncompressed) MB uncompressed"
    end

    Keylen = basketkey.fKeylen
    contentsize = Int32(basketkey.fLast - Keylen)

    offsetbytesize = basketkey.fObjlen - contentsize - 8

    data = @view basketrawbytes[1:contentsize]
    if offsetbytesize > 0

        #indexing is inclusive on both ends
        offbytes = @view basketrawbytes[(contentsize + 4 + 1):(end - 4)]

        # offsets starts at -fKeylen, same as the `local_offset` we pass in in the loop
        offset = ntoh.(reinterpret(Int32, offbytes)) .- Keylen
        push!(offset, contentsize)
        data, offset, contentsize
    else
        data, Int32[], contentsize
    end
end
