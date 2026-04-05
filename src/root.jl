struct ROOTDirectory
    name::AbstractString
    header::ROOTDirectoryHeader
    keys::Vector{TKey}
    fobj::AbstractSourceStream
    refs::Dict{Int32, Any}
end
function Base.show(io::IO, d::ROOTDirectory)
    println(io, "ROOTDirectory ($(length(d.keys)) keys, $(length(keys(d.refs))) refs)")
end

struct ROOTFile
    filename::String
    format_version::Int32
    header::FileHeader
    fobj::AbstractSourceStream
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
to interpret them, see [`interped_data`](@ref).

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
        httpstreamer(filename)
    elseif startswith(filename, "root://")
        xrootdstreamer(filename)
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
    idx = findfirst(isequal(s), keys(f))
    isnothing(idx) && throw(KeyError(s))
    tkey = f.directory.keys[idx]
    typename = safename(tkey.fClassName)
    @debug "Retrieving $s ('$(typename)')"
    if isdefined(@__MODULE__, Symbol(typename))
        streamer = getfield(@__MODULE__, Symbol(typename))
        # TODO: this needs to be generalised at some point ;)
        # TNamed is essentially just a string->string,
        # so we return her fTitle since the user made the
        # request with its fName
        if streamer === TNamed
            return tkey.fTitle
        end
        S = streamer(f.fobj, tkey, f.streamers.refs)
        return S
    end

    @debug "Could not get streamer for $(typename), trying custom streamer."
    # last resort, try direct parsing
    parsetobject(f, tkey, streamerfor(f, tkey.fClassName))
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
function interped_data(rawdata, rawoffsets, ::Type{String}, ::Type{Nojagg})
    rawoffsets .= rawoffsets .+ 1
    vov_bytes = VectorOfVectors(rawdata, rawoffsets)
    return [readtype(IOBuffer(v), String) for v in vov_bytes]
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

# Maps ROOT k-type constants to Julia types, used for TBranchElement leaf-type fallback.
const _leaftypeconstlookup = Dict{Int, Type}(
    Const.kChar       => Int8,
    Const.kShort      => Int16,
    Const.kInt        => Int32,
    Const.kLong       => Int64,
    Const.kFloat      => Float32,
    Const.kCounter    => UInt32,
    Const.kCharStar   => String,
    Const.kDouble     => Float64,
    Const.kDouble32   => Float32,
    Const.kLegacyChar => Int8,
    Const.kUChar      => UInt8,
    Const.kUShort     => UInt16,
    Const.kUInt       => UInt32,
    Const.kULong      => UInt64,
    Const.kBits       => UInt32,
    Const.kLong64     => Int64,
    Const.kULong64    => UInt64,
    Const.kBool       => Bool,
    Const.kFloat16    => Float16,
    Const.kTString    => String,
)

# Maps C++ scalar type spellings (fundamental types, ROOT typedefs, C++11 fixed-width)
# to Julia types. Used to resolve element types of vector<T> branches.
const _cpp_to_julia = Dict{String, Type}(
    # C++ fundamental types — all spellings ROOT is known to emit
    "bool"                   => Bool,
    "char"                   => Int8,
    "signed char"            => Int8,
    "unsigned char"          => UInt8,
    "short"                  => Int16,
    "short int"              => Int16,
    "signed short"           => Int16,
    "signed short int"       => Int16,
    "unsigned short"         => UInt16,
    "unsigned short int"     => UInt16,
    "int"                    => Int32,
    "signed"                 => Int32,
    "signed int"             => Int32,
    "unsigned"               => UInt32,
    "unsigned int"           => UInt32,
    "long"                   => Int64,   # ROOT always serialises 64-bit on 64-bit platforms
    "long int"               => Int64,
    "signed long"            => Int64,
    "signed long int"        => Int64,
    "unsigned long"          => UInt64,
    "unsigned long int"      => UInt64,
    "long long"              => Int64,
    "long long int"          => Int64,
    "signed long long"       => Int64,
    "signed long long int"   => Int64,
    "unsigned long long"     => UInt64,
    "unsigned long long int" => UInt64,
    "float"                  => Float32,
    "double"                 => Float64,
    "string"                 => String,
    "std::string"            => String,
    # ROOT typedefs (from Rtypes.h)
    "Char_t"                 => Int8,
    "UChar_t"                => UInt8,
    "Short_t"                => Int16,
    "UShort_t"               => UInt16,
    "Int_t"                  => Int32,
    "UInt_t"                 => UInt32,
    "Long_t"                 => Int64,
    "ULong_t"                => UInt64,
    "Long64_t"               => Int64,
    "ULong64_t"              => UInt64,
    "Float_t"                => Float32,
    "Double_t"               => Float64,
    "Float16_t"              => Float16,
    "Double32_t"             => Float32,
    "Bool_t"                 => Bool,
    # C++11 fixed-width (also used in ROOT macros)
    "int8_t"                 => Int8,
    "uint8_t"                => UInt8,
    "int16_t"                => Int16,
    "uint16_t"               => UInt16,
    "int32_t"                => Int32,
    "uint32_t"               => UInt32,
    "int64_t"                => Int64,
    "uint64_t"               => UInt64,
)

# Resolve a C++ type spelling of the form "vector<T>" or "vector<vector<T>>" to
# a (JuliaType, JaggType) pair.  Returns `nothing` if `typename` does not match
# the vector<...> pattern or if the inner element type is unknown.
#
# `_jaggtype` is the jaggedness already determined by JaggType(); it is used for
# singly-nested vectors so that the caller's offset information is preserved.
# For doubly-nested vectors we always force Offsetjaggjagg regardless.
#
# `customstructs` is checked before `_cpp_to_julia` so user-registered types win.
function _resolve_vector_type(typename, _jaggtype; customstructs=Dict{String,Type}())
    m = match(r"^vector<(.+)>$", strip(typename))
    m === nothing && return nothing
    inner = strip(m[1])

    # Doubly-nested: vector<vector<T>>
    mm = match(r"^vector<(.+)>$", inner)
    if mm !== nothing
        inner2 = strip(mm[1])
        jtype = get(customstructs, inner2, get(_cpp_to_julia, inner2, nothing))
        jtype === nothing && return nothing
        jagg = _jaggtype ∈ (Offsetjaggjagg, Offset6jaggjagg) ? _jaggtype : Offsetjaggjagg
        return Vector{Vector{jtype}}, jagg
    end

    # Singly-nested: vector<T>
    jtype = get(customstructs, inner, get(_cpp_to_julia, inner, nothing))
    jtype === nothing && return nothing
    # JaggType() may already say doubly-jagged for a branch that stores vector<T>
    # per entry (the streamer records the inner type, not the outer wrapper).
    if _jaggtype ∈ (Offsetjaggjagg, Offset6jaggjagg)
        return Vector{Vector{jtype}}, _jaggtype
    end
    return Vector{jtype}, _jaggtype
end

"""
    auto_T_JaggT(f::ROOTFile, branch; customstructs::Dict{String, Type})

Given a file and branch, automatically return (eltype, JaggType). This function is aware of
custom structs carried with the parent `ROOTFile`.

See also: [`ROOTFile`](@ref), [`interped_data`](@ref)
"""
function auto_T_JaggT(f::ROOTFile, branch; customstructs::Dict{String, Type})
    leaf = first(branch.fLeaves.elements)
    _jaggtype = JaggType(f, branch, leaf)

    if !hasproperty(branch, :fClassName)
        # TBranch (no class info): determine type entirely from the leaf
        return leaf_jaggtype(leaf, _jaggtype)
    end

    classname = branch.fClassName
    parentname = branch.fParentName

    # Custom struct lookup.
    # When classname == parentname the branch is a field of its own class, so we
    # use "ClassName.fieldTitle" as the identifier (KM3NeT-style dot notation).
    identifier = classname == parentname ? join([classname, branch.fTitle], '.') : classname
    if haskey(customstructs, identifier)
        return customstructs[identifier], Nojagg
    end

    # Streamer-based resolution: use fTypeName from the TStreamerElement.
    streamer = streamerfor(f, branch)
    if !ismissing(streamer)
        tn = streamer.fTypeName
        # Plain std::string field — 6-byte-offset encoding (issue #377)
        if tn ∈ ("string", "std::string")
            return Vector{String}, Offset6jagg
        end
        result = _resolve_vector_type(tn, _jaggtype; customstructs)
        result !== nothing && return result
    end

    # Classname-based resolution: parse vector<T> / vector<vector<T>> directly.
    result = _resolve_vector_type(classname, _jaggtype; customstructs)
    result !== nothing && return result

    if startswith(classname, "vector<")
        error("Cannot determine Julia type for C++ type '$classname'")
    end

    # Last resort: interpret the leaf's fType constant directly.
    leaftype = _normalize_ftype(leaf.fType)
    _type = get(_leaftypeconstlookup, leaftype, Nothing)
    if branch.fType == Const.kSubbranchSTLCollection
        _type = Vector{_type}
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
            _vtype = FixLenVector{Int(leafLen), _type}
            if isnothing(m)
                if leaf isa TLeafC
                    return String, Nojagg
                else
                    return _vtype, Nojagg
                end
            else
                #FIXME this only handles [var][fix] case
                return Vector{_vtype}, Nooffsetjagg
            end
        end
        _type = _jaggtype === Nojagg ? _type : Vector{_type}

        return _type, _jaggtype
end


# read all bytes of DATA and OFFSET from a branch
function readbranchraw(f::ROOTFile, branch)
    nbytes = branch.fBasketBytes
    res = sizehint!(Vector{UInt8}(), sum(nbytes)) # maximum length if all data are UInt8
    offsets = sizehint!(zeros(Int32, 1), branch.fEntries+1) # this is always Int32
    position = 0
    for (seek, nb) in zip(branch.fBasketSeek, nbytes)
        seek==0 && break
        data, offset = readbasketseek(f, branch, seek, nb)
        append!(res, data)
        # FIXME: assuming offset has always 0 or at least 2 elements ;)
        append!(offsets, (@view offset[2:end]) .+ position)
        if length(offset) > 0
            position = offsets[end]
        end
    end
    res, offsets
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

The fundamental building block of reading read data from a .root file. Read one
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
        # Notice: need to delay `resize!` to not destroy this @view
        offbytes = @view basketrawbytes[(contentsize + 4 + 1):(end - 4)]

        # offsets starts at -fKeylen, same as the `local_offset` we pass in in the loop
        offset = ntoh.(reinterpret(Int32, offbytes)) .- Keylen
        push!(offset, contentsize)
        return resize!(basketrawbytes, contentsize), offset
    else
        return resize!(basketrawbytes, contentsize), Int32[]
    end
end
