struct ROOTDirectory
    name::AbstractString
    header::ROOTDirectoryHeader
    keys::Vector{TKey}
    fobj::SourceStream
    refs::Dict{Int32, Any}
end
function Base.show(io::IO, d::ROOTDirectory)
    println(io, "ROOTDirectory ($(length(d.keys)) keys, $(length(keys(d.refs))) refs)")
end

struct ROOTFile
    filename::String
    format_version::Int32
    header::FileHeader
    fobj::SourceStream
    tkey::TKey
    streamers::Streamers
    directory::ROOTDirectory
    customstructs::Dict{String, Type}
    cache::Dict{Any, Any}
end
function close(f::ROOTFile)
    close(f.fobj)
end
function ROOTFile(f::Function, args...; pv...)
    rootfile = ROOTFile(args...; pv...)
    try
        f(rootfile)
    finally
        close(rootfile)
    end
end

function Base.hash(rf::ROOTFile, h::UInt)
    h = hash(rf.filename, h)
    h = hash(rf.header, h)
    return hash(rf.fobj, h)
end

const HEAD_BUFFER_SIZE = 2048
"""
    ROOTFile(filename::AbstractString; customstructs = Dict("TLorentzVector" => LorentzVector{Float64}))

`ROOTFile`'s constructor from a file. The `customstructs` dictionary can be used to pass user-defined
struct as value and its corresponding `fClassName` (in Branch) as key such that `UnROOT` will know
to intepret them, see [`interped_data`](@ref).

See also: [`LazyTree`](@ref), [`LazyBranch`](@ref)

# Example
```julia
julia> f = ROOTFile("test/samples/NanoAODv5_sample.root")
ROOTFile with 2 entries and 21 streamers.
test/samples/NanoAODv5_sample.root
└─ Events
   ├─ "run"
   ├─ "luminosityBlock"
   ├─ "event"
   ├─ "HTXS_Higgs_pt"
   ├─ "HTXS_Higgs_y"
   └─ "⋮"
```
"""
function ROOTFile(filename::AbstractString; customstructs = Dict("TLorentzVector" => LorentzVector{Float64}))
    fobj = if startswith(filename, r"https?://")
        HTTPStream(filename)
    elseif startswith(filename, "root://")
        sep_idx = findlast("//", filename)
        baseurl = filename[8:first(sep_idx)-1]
        filepath = filename[last(sep_idx):end]
        XRDStream(baseurl, filepath, "go")
    else
        !isfile(filename) && throw(SystemError("opening file $filename", 2))
        MmapStream(filename)
    end
    header_bytes = read(fobj, HEAD_BUFFER_SIZE)
    if header_bytes[1:4] != [0x72, 0x6f, 0x6f, 0x74]
        error("$filename is not a ROOT file.")
    end
    head_buffer = IOBuffer(header_bytes)
    preamble = unpack(head_buffer, FilePreamble)
    format_version = preamble.fVersion

    header = if format_version < 1000000
        @debug "32bit ROOT file"
        unpack(head_buffer, FileHeader32)
    else
        @debug "64bit ROOT file"
        unpack(head_buffer, FileHeader64)
    end

    # Streamers
    seek(fobj, header.fSeekInfo)
    stream_buffer = OffsetBuffer(IOBuffer(read(fobj, 10^5)), Int(header.fSeekInfo))
    streamers = Streamers(stream_buffer)

    seek(head_buffer, header.fBEGIN + header.fNbytesName)
    dir_header = unpack(head_buffer, ROOTDirectoryHeader)
    dirkey = dir_header.fSeekKeys
    seek(fobj, dirkey)
    tail_buffer = @async IOBuffer(read(fobj, 10^7))

    seek(head_buffer, header.fBEGIN)
    tkey = unpack(head_buffer, TKey)

    wait(tail_buffer)
    unpack(tail_buffer.result, TKey)

    n_keys = readtype(tail_buffer.result, Int32)
    keys = [unpack(tail_buffer.result, TKey) for _ in 1:n_keys]

    directory = ROOTDirectory(tkey.fName, dir_header, keys, fobj, streamers.refs)

    ROOTFile(filename, format_version, header, fobj, tkey, streamers, directory, customstructs, Dict())
end

function Base.show(io::IO, f::ROOTFile)
    n_entries = length(f.directory.keys)
    entries_suffix = n_entries == 1 ? "entry" : "entries"
    n_streamers = length(f.streamers)
    streamers_suffix = n_streamers == 1 ? "streamer" : "streamers"
    print(io, typeof(f))
    print(io, " with $n_entries $entries_suffix ")
    println(io, "and $n_streamers $streamers_suffix.")
    print_tree(io, f)
end


UUID(f::ROOTFile) = f.header.fUUID


function streamerfor(f::ROOTFile, name::AbstractString)
    for e in f.streamers.elements
        if e.streamer.fName == name
            return e
        end
    end
    missing
end

streamerfor(f::ROOTFile, branch::TBranch) = missing
function streamerfor(f::ROOTFile, branch::TBranchElement)
    fID = branch.fID
    # According to ChatGPt: When fID is equal to -1, it means that the
    # TBranch object has not been registered yet in the TTree's list of
    # branches. This can happen, for example, when a TBranch object has been
    # created, but has not been added to a TTree with the TTree::Branch()
    # method.
    #
    # TODO: For now, we force it to be 0 in this case, until someone complains.
    if fID == -1
        fID = 0
    end
    next_streamer = streamerfor(f, branch.fClassName)
    if ismissing(next_streamer)
        return missing
    else
        return next_streamer.streamer.fElements.elements[fID + 1]  # one-based indexing in Julia
    end
end


function Base.getindex(f::ROOTFile, s::AbstractString)
    get!(f.cache, s) do 
        _getindex(f, s)
    end
end

function _getindex(f::ROOTFile, s)
    if '/' ∈ s
        @debug "Splitting path '$s' and getting items recursively"
        paths = split(s, '/')
        return f[first(paths)][join(paths[2:end], "/")]
    end
    tkey = f.directory.keys[findfirst(isequal(s), keys(f))]
    typename = safename(tkey.fClassName)
    @debug "Retrieving $s ('$(typename)')"
    if isdefined(@__MODULE__, Symbol(typename))
        streamer = getfield(@__MODULE__, Symbol(typename))
        S = streamer(f.fobj, tkey, f.streamers.refs)
        return S
    end

    @debug "Could not get streamer for $(typename), trying custom streamer."
    # last resort, try direct parsing
    parsetobject(f.fobj, tkey, streamerfor(f, typename))
end

function getindex(d::ROOTDirectory, s)
    if '/' ∈ s
        @debug "Splitting path '$s' and getting items recursively"
        paths = split(s, '/')
        return d[first(paths)][join(paths[2:end], "/")]
    end
    tkey = d.keys[findfirst(isequal(s), keys(d))]
    streamer = getfield(@__MODULE__, Symbol(tkey.fClassName))
    S = streamer(d.fobj, tkey, d.refs)
    return S
end

function Base.keys(f::ROOTFile)
    keys(f.directory)
end

function Base.haskey(f::ROOTFile, k)
    haskey(f.directory, k)
end

function Base.keys(d::ROOTDirectory)
    [key.fName for key in d.keys]
end

function Base.haskey(d::ROOTDirectory, k)
    any(==(k), (key.fName for key in d.keys))
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

reinterpret(vt::Type{Vector{T}}, data::Vector{UInt8}) where T <: Union{AbstractFloat, Integer} = reinterpret(T, data)

"""
    interped_data(rawdata, rawoffsets, ::Type{T}, ::Type{J}) where {T, J<:JaggType}

The function thats interpret raw bytes (from a basket) into corresponding Julia data, based
on type `T` and jagg type `J`.

In order to retrieve data from custom branches, user should defined more speialized
method of this function with specific `T` and `J`. See `TLorentzVector` example.
"""
function interped_data(rawdata, rawoffsets, ::Type{Bool}, ::Type{Nojagg})
    # specialized case to get Vector{Bool} instead of BitVector
    return map(ntoh,reinterpret(Bool, rawdata))
end
function interped_data(rawdata, rawoffsets, ::Type{T}, ::Type{J}) where {T, J<:JaggType}
    # there are two possibility, one is the leaf is just normal leaf but the title has "[...]" in it
    # magic offsets, seems to be common for a lot of types, see auto.py in uproot3
    # only needs when the jaggedness comes from TLeafElements, not needed when
    # the jaggedness comes from having "[]" in TLeaf's title
    # the other is where we need to auto detector T bsaed on class name
    # we want the fundamental type as `reinterpret` will create vector
    if J === Nojagg
        return ntoh.(reinterpret(T, rawdata))
    elseif J === Offsetjaggjagg || J === Offset6jaggjagg # the branch is doubly jagged
        if J === Offset6jaggjagg
            jagg_offset = 6
        else
            jagg_offset = 10
        end
        subT = eltype(eltype(T))
        out = VectorOfVectors(T(), Int32[1])
        @views for i in 1:(length(rawoffsets)-1)
            flat = rawdata[(rawoffsets[i]+1+jagg_offset:rawoffsets[i+1])]
            row = VectorOfVectors{subT}()
            cursor = 1
            while cursor < length(flat)
                n = ntoh(reinterpret(Int32, flat[cursor:cursor+sizeof(Int32)-1])[1])
                cursor += sizeof(Int32)
                b = ntoh.(reinterpret(subT, flat[cursor:cursor+n*sizeof(subT)-1]))
                cursor += n*sizeof(subT)
                push!(row, b)
            end
            push!(out, row)
        end
        return out
    else # the branch is singly jagged
        # for each "event", the index range is `offsets[i] + jagg_offset + 1` to `offsets[i+1]`
        # this is why we need to append `rawoffsets` in the `readbranchraw()` call
        # when you use this range to index `rawdata`, you will get raw bytes belong to each event
        # Say your real data is Int32 and you see 8 bytes after indexing, then this event has [num1, num2] as real data
        _size = sizeof(eltype(T))
        if J === Offsetjagg
            jagg_offset = 10
            dp = 0 # book keeping for copy_to!
            lr = length(rawoffsets)
            offset = Vector{Int32}(undef, lr)
            offset[1] = 0
            @views @inbounds for i in 1:lr-1
                start = rawoffsets[i]+jagg_offset+1
                stop = rawoffsets[i+1]
                l = stop-start+1
                if l > 0
                    unsafe_copyto!(rawdata, dp+1, rawdata, start, l)
                    dp += l
                    offset[i+1] = offset[i] + l
                else
                    # when we have an empty [] in jagged basket
                    offset[i+1] = offset[i]
                end
            end
            resize!(rawdata, dp)
        else
            offset = rawoffsets
        end
        real_data = ntoh.(reinterpret(T, rawdata))
        offset .= (offset .÷ _size) .+ 1
        return VectorOfVectors(real_data, offset, ArraysOfArrays.no_consistency_checks)
    end
end

function _normalize_ftype(fType)
    # Taken from uproot4; thanks Jim ;)
    if Const.kOffsetL < fType < Const.kOffsetP
        fType - Const.kOffsetL
    else
        fType
    end
end

const _leaftypeconstlookup = Dict(
                             Const.kBool   => Bool  ,
                             Const.kChar   => Int8  ,
                             Const.kUChar  => UInt8 ,
                             Const.kShort  => Int16 ,
                             Const.kUShort => UInt16,
                             Const.kInt    => Int32 ,
                             Const.kBits   => UInt32,
                             Const.kUInt   => UInt32,
                             Const.kCounter=>UInt32 ,
                             Const.kLong => Int64   ,
                             Const.kLong64 =>  Int64,
                             Const.kULong =>  UInt64,
                             Const.kULong64 =>UInt64,
                             Const.kDouble32 => Float32,
                             Const.kDouble =>   Float64,
                             Const.kFloat => Float32,
                            )

"""
    auto_T_JaggT(f::ROOTFile, branch; customstructs::Dict{String, Type})

Given a file and branch, automatically return (eltype, Jaggtype). This function is aware of custom structs that
are carried with the parent `ROOTFile`.

This is also where you may want to "redirect" classname -> Julia struct name,
for example `"TLorentzVector" => LorentzVector` here and you can focus on `LorentzVectors.LorentzVector`
methods from here on.

See also: [`ROOTFile`](@ref), [`interped_data`](@ref)
"""
function auto_T_JaggT(f::ROOTFile, branch; customstructs::Dict{String, Type})
# TODO Why is this broken on 1.8?
# @memoize LRU(;maxsize=10^3) function auto_T_JaggT(f::ROOTFile, branch; customstructs::Dict{String, Type})
    leaf = first(branch.fLeaves.elements)
    _type = Nothing
    _jaggtype = JaggType(f, branch, leaf)
    if hasproperty(branch, :fClassName)
        classname = branch.fClassName # the C++ class name, such as "vector<int>"
        parentname = branch.fParentName  # assuming it has a parent ;)
        try
            # this will call a customize routine if defined by user
            # see custom.jl
            #
            # TODO to be verified: fields of custom classes have the same classname and parentname,
            # the fieldname is the fTitle. Here, we use the dot-separator, so that the
            # user can provide e.g. `KM3NETDAQ::JDAQEvent.snapshotHits`, where `KM3NETDAQ::JDAQEvent`
            # is the class name and `snapshotHits` the field name. The provided type will be used
            # to parse the data
            if classname == parentname
                identifier = join([classname, branch.fTitle], '.')
            else
                identifier = classname
            end
            _custom = customstructs[identifier]
            return _custom, Nojagg
        catch
        end

        # check if we have an actual streamer
        streamer = streamerfor(f, branch)
        if !ismissing(streamer)
            # TODO unify this with the "switch" block below and expand for more types!
            if _jaggtype == Offsetjagg
                streamer.fTypeName == "vector<string>" && return Vector{String}, _jaggtype
                streamer.fTypeName == "vector<double>" && return Vector{Float64}, _jaggtype
                streamer.fTypeName == "vector<int>" && return Vector{Int32}, _jaggtype
            elseif _jaggtype == Offsetjaggjagg || _jaggtype == Offset6jaggjagg
                streamer.fTypeName == "vector<string>" && return Vector{Vector{String}}, _jaggtype
                streamer.fTypeName == "vector<double>" && return Vector{Vector{Float64}}, _jaggtype
                streamer.fTypeName == "vector<int>" && return Vector{Vector{Int32}}, _jaggtype
            end

        end

        # some standard cases
        m = match(r"vector<(.*)>", classname)
        if m!==nothing
            elname = m[1]

            minner = match(r"vector<(.*)>", elname)
            if minner != nothing
                elname = minner[1]
                _jaggtype = Offsetjaggjagg
            end

            if haskey(customstructs, elname)
                _custom = customstructs[elname]
                return Vector{_custom}, _jaggtype
            end
            elname = endswith(elname, "_t") ? lowercase(chop(elname; tail=2)) : elname  # Double_t -> double
            try
                _type = if elname == "bool" 
                    Bool 
                elseif elname == "unsigned int" 
                    UInt32
                elseif elname == "signed char"
                    Int8
                elseif elname == "unsigned char" 
                    UInt8
                elseif elname == "unsigned short"
                    UInt16
                elseif elname == "unsigned long"
                    UInt64
                elseif elname == "long64"
                    Int64
                elseif elname == "ulong64"
                    UInt64
                elseif elname == "string"
                    String #length encoded, NOT null terminated
                else
                    _type = getfield(Base, Symbol(:C, elname))
                end

                # we know it's a vector because we saw vector<>
                _type = Vector{_type}
            catch
                error("Cannot convert element of $elname to a native Julia type")
            end
            _type = _jaggtype === Offsetjaggjagg ? Vector{_type} : _type
        # Try to interpret by leaf type
        else
            leaftype = _normalize_ftype(leaf.fType)
            _type = get(_leaftypeconstlookup, leaftype, nothing)
            if branch.fType == Const.kSubbranchSTLCollection
                _type = Vector{_type}
            end
        end
    else
        # since no classname were found, we now try to determine
        # type based on leaf information
        _type, _jaggtype = leaf_jaggtype(leaf, _jaggtype)
    end
    return _type, _jaggtype
end

function leaf_jaggtype(leaf, _jaggtype)
        _type = primitivetype(leaf)
        leafLen = leaf.fLen
        if leafLen > 1 # treat NTuple as Nojagg since size is static
            _fTitle = replace(leaf.fTitle, "[$(leafLen)]" => "")
            # looking for more `[var]`
            m = match(r"\[\D+\]", _fTitle)
            _type = FixLenVector{Int(leafLen), _type}
            if isnothing(m)
                return _type, Nojagg
            else
                #FIXME this only handles [var][fix] case
                return Vector{_type}, Nooffsetjagg
            end
        end
        _type = _jaggtype === Nojagg ? _type : Vector{_type}

        return _type, _jaggtype
end


# read all bytes of DATA and OFFSET from a branch
function readbranchraw(f::ROOTFile, branch)
    nbytes = branch.fBasketBytes
    datas = sizehint!(Vector{UInt8}(), sum(nbytes)) # maximum length if all data are UInt8
    offsets = sizehint!(zeros(Int32, 1), branch.fEntries+1) # this is always Int32
    position = 0
    for (seek, nb) in zip(branch.fBasketSeek, nbytes)
        seek==0 && break
        data, offset = readbasketseek(f, branch, seek, nb)
        append!(datas, data)
        # FIXME: assuming offset has always 0 or at least 2 elements ;)
        append!(offsets, (@view offset[2:end]) .+ position)
        if length(offset) > 0
            position = offsets[end]
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
"""
    readbasket(f::ROOTFile, branch, ith)
    readbasketseek(f::ROOTFile, branch::Union{TBranch, TBranchElement}, seek_pos::Int, nbytes)

The fundamental building block of reading read data from a .root file. Read read one
basket's raw bytes and offsets at a time. These raw bytes and offsets then (potentially) get
processed by [`interped_data`](@ref).

See also: [`auto_T_JaggT`](@ref), [`basketarray`](@ref)
"""
function readbasket(f::ROOTFile, branch, ith) 
    readbasketseek(f, branch, branch.fBasketSeek[ith], branch.fBasketBytes[ith])
end

function readbasketseek(f::ROOTFile, branch::Union{TBranch, TBranchElement}, seek_pos::Int, nb)
    local rawbuffer
    rawbuffer = OffsetBuffer(IOBuffer(read_seek_nb(f.fobj, seek_pos, nb)), seek_pos)
    basketkey = unpack(rawbuffer, TBasketKey)
    compressedbytes = compressed_datastream(rawbuffer, basketkey)

    @debug "Seek position: $seek_pos"
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

    if offsetbytesize > 0

        # indexing is inclusive on both ends
        # Notice: need to delay `resize!` to not destory this @view
        offbytes = @view basketrawbytes[(contentsize + 4 + 1):(end - 4)]

        # offsets starts at -fKeylen, same as the `local_offset` we pass in in the loop
        offset = ntoh.(reinterpret(Int32, offbytes)) .- Keylen
        push!(offset, contentsize)
        return resize!(basketrawbytes, contentsize), offset
    else
        return resize!(basketrawbytes, contentsize), Int32[]
    end
end
