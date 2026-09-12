# Writable ROOT files: create or re-open a file, add RNTuples to it and append
# clusters to RNTuples that are already in it.
#
# The top-level shape follows uproot's writing interface (`recreate`/`update`
# return a directory-like handle, `f[name] = table` creates a filled RNTuple,
# `f[name]` hands back a writable RNTuple that can be extended), spelled the
# Julia way: `append!(f[name], table)`.
#
# File layout strategy: the three records every ROOT reader locates through the
# file header -- the directory key list, the streamer record and the free-segment
# record -- form a "tail" that floats at the end of the file. Every mutating
# operation seeks to the tail, writes its new blobs there, rewrites the tail
# behind them and patches the file/directory headers. The file is therefore
# valid after every operation, and only the superseded RNTuple footer (a few
# hundred bytes per append) is left behind as an unreferenced gap.

# streamed ROOT::RNTuple anchor: 6-byte object preamble, 64-byte payload
# (4×UInt16 + 7×UInt64) and an 8-byte XxHash-3 checksum
const _ANCHOR_PAYLOAD_NBYTES = 64
const _ANCHOR_PREAMBLE_NBYTES = 6
const _ANCHOR_CLASS_VERSION = 2
const _ANCHOR_OBJLEN = _ANCHOR_PREAMBLE_NBYTES + _ANCHOR_PAYLOAD_NBYTES + 8

"""
    WritableRNTuple

Handle to an RNTuple inside a [`WritableROOTFile`](@ref), obtained with
`f[name]` or [`mkrntuple`](@ref). Data is added with `append!(rnt, table)`;
`length(rnt)` is the number of entries written so far.
"""
mutable struct WritableRNTuple{F}
    file::F
    name::String
    anchor_pos::Int64            # file offset of the anchor payload, 0 until first written
    anchor::ROOT_3a3a_RNTuple
    header_checksum::UInt64
    footer::RNTupleFooter
    field_records::Vector{FieldRecord}    # full schema: header + extension records
    column_records::Vector{ColumnRecord}
    column_offsets::Vector{Int64}         # elements written so far, per column
    num_entries::Int64
    compression::Int
end

"""
    WritableROOTFile

A ROOT file opened for writing by [`create`](@ref), [`recreate`](@ref) or
[`update`](@ref). Behaves like a dictionary of the objects in the file's top
directory: `keys(f)`, `haskey(f, name)`, `f[name]` (a [`WritableRNTuple`](@ref))
and `f[name] = table` (create a new RNTuple holding `table`). Close it with
`close(f)`; the file on disk is valid after every operation, so closing only
flushes and releases the handle.
"""
mutable struct WritableROOTFile{IOT<:IO}
    io::IOT
    path::String
    file_name::String            # the name recorded in the TFile/TDirectory records
    compression::Int             # fCompress for new data
    header::FileHeader32
    dir_header_pos::Int64
    dir_header::ROOTDirectoryHeader32
    keys::Vector{TKey}           # top-directory key list (32- or 64-bit keys, as found)
    keylist_key::TKey            # class/name/title template of the key-list record
    streamer_key::TKey
    streamer_payload::Vector{UInt8}
    tail_start::Int64            # where the floating tail currently begins
    ntuples::Dict{String, WritableRNTuple}
    unavailable::Dict{String, String}   # RNTuples of an updated file we cannot extend, with the reason
    owns_io::Bool
    closed::Bool
end

# ---------------------------------------------------------------------------
# opening

"""
    create(path; compression=$(RNT_DEFAULT_COMPRESSION)) -> WritableROOTFile
    create(f::Function, path; compression)

Create a new ROOT file at `path` for writing RNTuples; errors if the file
already exists (like ROOT's `"CREATE"` option). `compression` is the ROOT
`fCompress` code (`algorithm*100 + level`, `0` for none) used for the data.
The do-block form closes the file when `f` returns.

See [`recreate`](@ref), [`update`](@ref), [`mkrntuple`](@ref).
"""
function create(path::AbstractString; compression::Integer=RNT_DEFAULT_COMPRESSION)
    isfile(path) && throw(ArgumentError("$path already exists; use `recreate` to overwrite it or `update` to add to it"))
    recreate(path; compression)
end

"""
    recreate(path; compression=$(RNT_DEFAULT_COMPRESSION)) -> WritableROOTFile
    recreate(f::Function, path; compression)

Create a new ROOT file at `path`, overwriting any existing file (like ROOT's
`"RECREATE"` option). See [`create`](@ref) for the arguments.

# Example
```julia
UnROOT.recreate("out.root") do f
    f["events"] = (x = [1.0, 2.0], s = ["a", "b"])       # first cluster
    append!(f["events"], (x = [3.0], s = ["c"]))          # second cluster
end
```
"""
function recreate(path::AbstractString; compression::Integer=RNT_DEFAULT_COMPRESSION)
    io = open(path, "w+")
    return WritableROOTFile(io, String(path); compression, path=String(path), owns_io=true)
end

"""
    update(path; compression=nothing) -> WritableROOTFile
    update(f::Function, path; compression)

Open the existing ROOT file at `path` so RNTuples can be added to it and
existing RNTuples extended (like ROOT's `"UPDATE"` option). New data uses the
file's own compression setting unless `compression` is given.

Only files with the 32-bit layout (smaller than 2 GiB) are supported. An
RNTuple written by another program can be extended when UnROOT can reproduce
its schema exactly: fields of the supported types (numbers, `Bool`, strings and
nested vectors of these), one column representation per field, and a footer
UnROOT's writer serializes byte for byte.

# Example
```julia
UnROOT.update("out.root") do f
    append!(f["events"], (x = [4.0, 5.0], s = ["d", "e"]))
end
```
"""
function update(path::AbstractString; compression::Union{Nothing, Integer}=nothing)
    isfile(path) || throw(SystemError("opening file $path", 2))
    return _open_existing(String(path), compression)
end

for fn in (:create, :recreate, :update)
    @eval function $fn(f::Function, path::AbstractString; kw...)
        wf = $fn(path; kw...)
        try
            f(wf)
        finally
            close(wf)
        end
    end
end

"""
    WritableROOTFile(io::IO, file_name; compression, path="", owns_io=false)

Write a fresh ROOT file container (magic, file header, `TFile` and top
directory records) into the empty, seekable `io` and return the handle.
`file_name` is the name recorded inside the file. Used by [`write_rntuple`](@ref)
to write into any `IO`; prefer [`recreate`](@ref) for files on disk.
"""
function WritableROOTFile(io::IO, file_name::AbstractString; compression::Integer=RNT_DEFAULT_COMPRESSION,
                          path::AbstractString="", owns_io::Bool=false)
    fdatime = _root_datime()
    file_name = String(file_name)
    fBEGIN = Int32(100)
    klen_tfile = _tkey32_len("TFile", file_name, "")
    tnamed_len = 2 + ncodeunits(file_name)          # (1+name) + (1+empty title)
    fNbytesName = Int32(klen_tfile + tnamed_len)
    tfile_objlen = Int32(tnamed_len + 30 + 30)      # TNamed + directory header + UUID/padding

    seekstart(io)
    write(io, b"root")
    rnt_write(io, Int32(63501); legacy=true)        # on-disk format version
    header = FileHeader32(fBEGIN, 0, 0, 0, 1, fNbytesName, 0x04, Int32(compression),
                          0, 0, zeros(SVector{18, UInt8}))
    rnt_write(io, header)
    write(io, zeros(UInt8, fBEGIN - position(io)))   # zero-pad up to fBEGIN
    rnt_write(io, TKey32(klen_tfile + tfile_objlen, 4, tfile_objlen, fdatime,
                         klen_tfile, 1, fBEGIN, 0, "TFile", file_name, ""))
    rnt_write(io, TFile_write(file_name, ""))
    dir_header_pos = position(io)
    dir_header = ROOTDirectoryHeader32(5, fdatime, fdatime, 0, fNbytesName, fBEGIN, 0, 0)
    rnt_write(io, dir_header)
    # TUUID (version + 16 bytes) and reserved tail of the directory record
    rnt_write(io, Stubs.dummy_padding2)

    # constant compressed TList blob describing ROOT::RNTuple (name-independent)
    streamer_payload = Vector{UInt8}(Stubs.tsreamerinfo_compressed)
    klen_info = _tkey32_len("TList", "StreamerInfo", "Doubly linked list")
    streamer_key = TKey32(klen_info + length(streamer_payload), 4, 1254, fdatime, klen_info, 1,
                          0, fBEGIN, "TList", "StreamerInfo", "Doubly linked list")
    keylist_key = TKey32(0, 4, 0, fdatime, 0, 1, 0, fBEGIN, "", file_name, "")

    f = WritableROOTFile{typeof(io)}(io, String(path), file_name, Int(compression), header,
                                     dir_header_pos, dir_header, TKey[], keylist_key,
                                     streamer_key, streamer_payload, position(io),
                                     Dict{String, WritableRNTuple}(), Dict{String, String}(),
                                     owns_io, false)
    _write_tail!(f)     # an empty but valid ROOT file
    return f
end

# Where the floating tail can start in an existing file: directly at the first
# of the three tail records when they tile the end of the file exactly (as in
# files written by UnROOT), otherwise at the current end of file.
function _tail_start(header::FileHeader32, dir::ROOTDirectoryHeader32)
    segs = sort!([(Int64(dir.fSeekKeys), Int64(dir.fNbytesKeys)),
                  (Int64(header.fSeekInfo), Int64(header.fNbytesInfo)),
                  (Int64(header.fSeekFree), Int64(header.fNbytesFree))])
    tiles = segs[1][1] + segs[1][2] == segs[2][1] &&
            segs[2][1] + segs[2][2] == segs[3][1] &&
            segs[3][1] + segs[3][2] == Int64(header.fEND)
    return tiles ? segs[1][1] : Int64(header.fEND)
end

function _open_existing(path::String, compression)
    rf = ROOTFile(path)
    local f
    try
        header = rf.header
        header isa FileHeader32 || error("$path uses the 64-bit ROOT file layout, which UnROOT cannot write to")
        dir_header = rf.directory.header
        dir_header isa ROOTDirectoryHeader32 || error("$path has a 64-bit top directory, which UnROOT cannot write to")
        keys = TKey[k for k in rf.directory.keys]
        fobj = rf.fobj

        # recent ROOT versions write 64-bit keys (fVersion > 1000) even into
        # small files; both key flavours are kept and re-serialized as found
        keylist_key = unpack(IOBuffer(read_seek_nb(fobj, dir_header.fSeekKeys, dir_header.fNbytesKeys)), TKey)
        streamer_raw = Vector{UInt8}(read_seek_nb(fobj, header.fSeekInfo, header.fNbytesInfo))
        streamer_key = unpack(IOBuffer(streamer_raw), TKey)
        streamer_payload = streamer_raw[streamer_key.fKeylen+1:end]

        comp = compression === nothing ? Int(header.fCompress) : Int(compression)
        f = WritableROOTFile{IOStream}(open(path, "r+"), path, String(rf.tkey.fName), comp, header,
                                       Int64(header.fBEGIN + header.fNbytesName), dir_header, keys,
                                       keylist_key, streamer_key, streamer_payload,
                                       _tail_start(header, dir_header),
                                       Dict{String, WritableRNTuple}(), Dict{String, String}(),
                                       true, false)
        # the reader is only available now, so load every RNTuple's state up front;
        # ones we cannot extend are reported when (and if) they are asked for
        for key in keys
            key.fClassName == "ROOT::RNTuple" || continue
            try
                f.ntuples[key.fName] = _load_rntuple(f, rf, key)
            catch e
                f.unavailable[key.fName] = sprint(showerror, e)
            end
        end
    finally
        close(rf)
    end
    return f
end

# reconstruct the writer-side state of an RNTuple that is already in the file
function _load_rntuple(f::WritableROOTFile, rf::ROOTFile, key::TKey)
    key.fObjlen == _ANCHOR_OBJLEN || error("unsupported RNTuple anchor of $(key.fObjlen) bytes (expected $_ANCHOR_OBJLEN)")
    key.fNbytes - key.fKeylen == key.fObjlen || error("compressed RNTuple anchors are not supported")
    rn = ROOT_3a3a_RNTuple(rf.fobj, key, rf.streamers.refs)
    anchor = rn.anchor

    # the footer is rewritten on every append: refuse if our serializer does
    # not reproduce the existing one byte for byte (unknown flags, records, ...)
    footer_bytes = decompress_bytes(read_seek_nb(rf.fobj, anchor.fSeekFooter, anchor.fNBytesFooter), anchor.fLenFooter)
    _buffer_bytes(io -> rnt_write(io, rn.footer)) == footer_bytes ||
        error("the footer of RNTuple \"$(key.fName)\" uses features UnROOT's writer cannot reproduce")

    # elements already written per column (physical column order), summed over
    # every cluster of every cluster group; columns absent from early clusters
    # (extension columns) simply contribute nothing there
    column_offsets = zeros(Int64, length(rn.header.column_records))
    for gi in eachindex(rn.footer.cluster_group_records)
        for cluster in _read_page_list(rn, gi).nested_page_locations
            for (ci, pages) in enumerate(cluster)
                column_offsets[ci] += sum(p -> abs(Int64(p.num_elements)), pages; init=Int64(0))
            end
        end
    end

    return WritableRNTuple(f, String(key.fName), Int64(key.fSeekKey + key.fKeylen + _ANCHOR_PREAMBLE_NBYTES),
                           anchor, rn.footer.header_checksum, rn.footer,
                           rn.header.field_records, rn.header.column_records,
                           column_offsets, Int64(_length(rn)), f.compression)
end

# ---------------------------------------------------------------------------
# the floating tail

function _check_open(f::WritableROOTFile)
    f.closed && error("the ROOT file $(f.path) has been closed")
    nothing
end

# the same key at another position
_relocate_key(k::TKey32, seek) = TKey32(k.fNbytes, k.fVersion, k.fObjlen, k.fDatime, k.fKeylen, k.fCycle,
                                        Int32(seek), k.fSeekPdir, k.fClassName, k.fName, k.fTitle)
_relocate_key(k::TKey64, seek) = TKey64(k.fNbytes, k.fVersion, k.fObjlen, k.fDatime, k.fKeylen, k.fCycle,
                                        Int64(seek), k.fSeekPdir, k.fClassName, k.fName, k.fTitle)

# (re)write key list, streamer record and free-segment record at `f.tail_start`
# and patch the file header and directory header accordingly
function _write_tail!(f::WritableROOTFile)
    io = f.io
    fdatime = _root_datime()
    fBEGIN = f.header.fBEGIN

    # directory key list (always written as a 32-bit key; the listed keys keep their own flavour)
    kk = f.keylist_key
    klen_dir = _tkey32_len(kk.fClassName, kk.fName, kk.fTitle)
    keys_objlen = Int32(4 + sum(k -> Int(k.fKeylen), f.keys; init=0))
    fNbytesKeys = Int32(klen_dir + keys_objlen)
    sk = f.streamer_key
    klen_end = _tkey32_len("", f.file_name, "")
    fNbytesFree = Int32(klen_end + 10)
    f.tail_start + fNbytesKeys + sk.fNbytes + fNbytesFree <= typemax(Int32) ||
        error("RNTuple writing only supports files smaller than 2 GiB (32-bit file layout)")

    seek(io, f.tail_start)
    fSeekKeys = Int32(position(io))
    rnt_write(io, TKey32(fNbytesKeys, 4, keys_objlen, fdatime, klen_dir, 1, fSeekKeys, fBEGIN,
                         kk.fClassName, kk.fName, kk.fTitle))
    rnt_write(io, Int32(length(f.keys)); legacy=true)
    for k in f.keys
        rnt_write(io, k)
    end

    # streamer record (payload copied verbatim, key relocated)
    fSeekInfo = Int32(position(io))
    rnt_write(io, _relocate_key(sk, fSeekInfo))
    write(io, f.streamer_payload)

    # free-segments record: one segment [fEND, 2000000000]
    fSeekFree = Int32(position(io))
    fEND = fSeekFree + fNbytesFree
    rnt_write(io, TKey32(fNbytesFree, 4, 10, fdatime, klen_end, 1, fSeekFree, fBEGIN, "", f.file_name, ""))
    rnt_write(io, UInt16(1); legacy=true)          # TFree version
    rnt_write(io, UInt32(fEND); legacy=true)       # first free byte
    rnt_write(io, UInt32(2000000000); legacy=true)
    @assert position(io) == fEND

    h = f.header
    f.header = FileHeader32(h.fBEGIN, UInt32(fEND), UInt32(fSeekFree), fNbytesFree, 1, h.fNbytesName,
                            h.fUnits, Int32(f.compression), UInt32(fSeekInfo), sk.fNbytes, h.fUUID)
    seek(io, 8)                                    # right after "root" + version
    rnt_write(io, f.header)

    d = f.dir_header
    f.dir_header = ROOTDirectoryHeader32(d.fVersion, d.fDatimeC, fdatime, fNbytesKeys, d.fNbytesName,
                                         d.fSeekDir, d.fSeekParent, fSeekKeys)
    seek(io, f.dir_header_pos)
    rnt_write(io, f.dir_header)
    flush(io)
    return f
end

function Base.close(f::WritableROOTFile)
    f.closed && return nothing
    flush(f.io)
    f.owns_io && close(f.io)
    f.closed = true
    return nothing
end
Base.isopen(f::WritableROOTFile) = !f.closed

Base.keys(f::WritableROOTFile) = [String(k.fName) for k in f.keys]
Base.haskey(f::WritableROOTFile, name::AbstractString) = any(k -> k.fName == name, f.keys)

function Base.getindex(f::WritableROOTFile, name::AbstractString)
    _check_open(f)
    rnt = get(f.ntuples, name, nothing)
    rnt === nothing || return rnt
    if haskey(f.unavailable, name)
        throw(ArgumentError("RNTuple \"$name\" cannot be extended by UnROOT: " * f.unavailable[name]))
    end
    i = findfirst(k -> k.fName == name, f.keys)
    i === nothing && throw(KeyError(name))
    throw(ArgumentError("\"$name\" is a $(f.keys[i].fClassName); only RNTuples can be written by UnROOT"))
end

function Base.setindex!(f::WritableROOTFile, table, name::AbstractString)
    mkrntuple(f, name, table)
    return f
end

function Base.show(io::IO, f::WritableROOTFile)
    print(io, "WritableROOTFile(", repr(f.path), ", ", length(f.keys), " key", length(f.keys) == 1 ? "" : "s")
    isempty(f.keys) || print(io, ": ", join(keys(f), ", "))
    print(io, f.closed ? ", closed)" : ")")
end

# ---------------------------------------------------------------------------
# RNTuples

_top_level_field_names(frs::Vector{FieldRecord}) =
    [fr.field_name for (i, fr) in enumerate(frs) if fr.parent_field_id == i - 1]

Base.length(rnt::WritableRNTuple) = Int(rnt.num_entries)
function Base.show(io::IO, rnt::WritableRNTuple)
    print(io, "WritableRNTuple(", repr(rnt.name), ", ", rnt.num_entries, " entries, fields: ",
          join(_top_level_field_names(rnt.field_records), ", "), ")")
end

# the schema of `spec`, plus its data when `spec` is a table
function _rntuple_spec(spec)
    if spec isa Tables.Schema
        return spec, nothing
    elseif spec isa NamedTuple && !isempty(spec) && all(v -> v isa Type, values(spec))
        return Tables.Schema(keys(spec), values(spec)), nothing
    elseif istable(spec)
        cols = columntable(spec)
        return schema(cols), cols
    else
        error("an RNTuple is specified by a Tables.jl table, a `Tables.Schema` or a NamedTuple of " *
              "element types like `(x = Float64, v = Vector{Int32})`, got type $(typeof(spec))")
    end
end

"""
    mkrntuple(f::WritableROOTFile, name, spec) -> WritableRNTuple

Add an RNTuple called `name` to `f`. `spec` is either a Tables.jl table, whose
contents become the first cluster (this is what `f[name] = table` does), or a
type specification for an initially empty RNTuple: a `Tables.Schema` or a
`NamedTuple` of element types such as `(x = Float64, v = Vector{Int32})`.
Fill it afterwards with `append!`.

Supported element types: `Bool`, `Int8`–`Int64`, `UInt8`–`UInt64`,
`Float16`/`Float32`/`Float64`, `String`, and (nested) `Vector`s of these.
"""
function mkrntuple(f::WritableROOTFile, name::AbstractString, spec)
    _check_open(f)
    name = String(name)
    haskey(f, name) && throw(ArgumentError("an object named \"$name\" already exists in the file"))
    sch, cols = _rntuple_spec(spec)
    isempty(sch.names) && throw(ArgumentError("an RNTuple needs at least one field"))
    cols === nothing || _check_equal_lengths(cols)
    field_records, column_records = schema_to_field_column_records(sch)

    io = f.io
    fdatime = _root_datime()
    seek(io, f.tail_start)

    # header envelope; the writer identifier honestly reports UnROOT.jl (not a
    # ROOT version) per the ROOT team's request not to impersonate ROOT
    header = RNTupleHeader(zero(UInt64), name, "", "UnROOT.jl $(pkgversion(@__MODULE__))",
                           field_records, column_records, AliasRecord[], ExtraTypeInfo[])
    header_bytes = _buffer_bytes(io -> rnt_write(io, header))
    fSeekHeader, header_nbytes = _write_rblob(io, header_bytes, fdatime; compression=f.compression)
    header_checksum = only(reinterpret(UInt64, @view header_bytes[end-7:end]))

    footer = RNTupleFooter(0, header_checksum, RNTupleSchemaExtension([], [], [], []), ClusterGroupRecord[])
    anchor = ROOT_3a3a_RNTuple(1, 0, 0, 0, fSeekHeader, header_nbytes, length(header_bytes),
                               0, 0, 0, 0x0000000040000000, 0)
    rnt = WritableRNTuple(f, name, Int64(0), anchor, header_checksum, footer, field_records, column_records,
                          zeros(Int64, length(column_records)), Int64(0), f.compression)
    cols === nothing || isempty(first(cols)) || _write_cluster!(rnt, cols, fdatime)
    _commit_footer!(rnt, fdatime)
    f.ntuples[name] = rnt
    f.tail_start = position(io)
    _write_tail!(f)
    return rnt
end

function _check_equal_lengths(cols)
    allequal(map(length, values(cols))) || throw(ArgumentError("top-level columns must have the same length"))
    nothing
end

"""
    append!(rnt::WritableRNTuple, table) -> rnt

Append the rows of `table` (any Tables.jl table) to `rnt` as one new cluster.
The table must have exactly the RNTuple's top-level fields (in any order) with
matching element types. Since every call writes a cluster of its own, prefer
few large appends over many small ones.
"""
function Base.append!(rnt::WritableRNTuple, table)
    f = rnt.file
    _check_open(f)
    cols = _columns_in_field_order(rnt, table)
    _check_equal_lengths(cols)
    isempty(first(cols)) && return rnt
    fdatime = _root_datime()
    seek(f.io, f.tail_start)
    _write_cluster!(rnt, cols, fdatime)
    _commit_footer!(rnt, fdatime)
    f.tail_start = position(f.io)
    _write_tail!(f)
    return rnt
end

# reorder the table's columns to the RNTuple's field order and check that the
# schema they imply matches the one in the file
function _columns_in_field_order(rnt::WritableRNTuple, table)
    istable(table) || error("RNTuple writing accepts object compatible with Tables.jl interface, got type $(typeof(table))")
    cols = columntable(table)
    have = Set(String.(keys(cols)))
    want = _top_level_field_names(rnt.field_records)
    missing_names = setdiff(want, have)
    extra_names = setdiff(have, want)
    if !isempty(missing_names) || !isempty(extra_names)
        throw(ArgumentError("table columns do not match the fields of RNTuple \"$(rnt.name)\"" *
                            (isempty(missing_names) ? "" : "; missing: $(join(missing_names, ", "))") *
                            (isempty(extra_names) ? "" : "; unexpected: $(join(extra_names, ", "))")))
    end
    ordered = NamedTuple{Tuple(Symbol.(want))}(Tuple(cols[Symbol(n)] for n in want))
    _check_schema_compatible(rnt, schema(ordered))
    return ordered
end

function _check_schema_compatible(rnt::WritableRNTuple, sch::Tables.Schema)
    frs, crs = schema_to_field_column_records(sch)
    mismatch(what) = throw(ArgumentError("table schema is not compatible with RNTuple \"$(rnt.name)\": $what"))
    length(frs) == length(rnt.field_records) || mismatch("the RNTuple has $(length(rnt.field_records)) field records, the table implies $(length(frs))")
    for (ours, theirs) in zip(frs, rnt.field_records)
        ours.field_name == theirs.field_name || mismatch("field \"$(theirs.field_name)\" vs \"$(ours.field_name)\"")
        ours.parent_field_id == theirs.parent_field_id && ours.struct_role == theirs.struct_role && ours.flags == theirs.flags ||
            mismatch("field \"$(theirs.field_name)\" has a structure UnROOT cannot write")
        ours.type_name == theirs.type_name || mismatch("field \"$(theirs.field_name)\" is a $(theirs.type_name), the table column is a $(ours.type_name)")
    end
    length(crs) == length(rnt.column_records) || mismatch("the RNTuple has $(length(rnt.column_records)) columns, the table implies $(length(crs))")
    for (ours, theirs) in zip(crs, rnt.column_records)
        theirs.representation_idx == 0 || mismatch("fields with several column representations are not supported")
        ours.field_id == theirs.field_id || mismatch("column layout differs")
        _column_storage_type(theirs) === _column_storage_type(ours) ||
            mismatch("column $(RNT_COL_TYPE_TABLE[theirs.type+1].name) of field \"$(rnt.field_records[theirs.field_id+1].field_name)\" cannot hold the table data")
    end
    nothing
end

# write one cluster (one page per column) and its page list, and record the
# resulting cluster group in the footer
function _write_cluster!(rnt::WritableRNTuple, cols, fdatime)
    io = rnt.file.io
    compression = rnt.compression
    n_entries = length(first(cols))
    pages_arys = mapreduce(rnt_col_to_ary, vcat, values(cols); init=Any[])
    length(pages_arys) == length(rnt.column_records) ||
        error("internal error: $(length(pages_arys)) column arrays for $(length(rnt.column_records)) columns")
    pages = [rnt_ary_to_page(ary, cr) for (ary, cr) in zip(pages_arys, rnt.column_records)]

    # each page is compressed independently and followed by an XxHash-3 checksum
    # of its on-disk bytes; the page locators point inside one RBlob
    page_ondisk = [_root_compress(p.data, compression) for p in pages]
    pages_payload = _buffer_bytes() do buf
        for od in page_ondisk
            write(buf, od)
            write(buf, xxh3_64(od))
        end
    end
    pages_begin, _ = _write_rblob(io, pages_payload, fdatime)   # container itself not re-compressed
    page_locators = Vector{Tuple{Int32, Int64, Int64}}(undef, length(pages))
    pos = pages_begin
    for i in eachindex(pages)
        nbytes = length(page_ondisk[i])
        page_locators[i] = (pages[i].num_elements, nbytes, pos)
        pos += nbytes + 8
    end

    first_entry = rnt.num_entries
    cluster_summaries = [ClusterSummary(first_entry, n_entries)]
    nested = generate_page_links(page_locators, compression, rnt.column_offsets)
    pagelink_bytes = _buffer_bytes(io -> rnt_write(io, PageLinkWrite(rnt.header_checksum, cluster_summaries, nested)))
    pagelink_pos, pagelink_nbytes = _write_rblob(io, pagelink_bytes, fdatime; compression)

    push!(rnt.footer.cluster_group_records,
          ClusterGroupRecord(first_entry, n_entries, 1,
                             EnvLink(length(pagelink_bytes), Locator(pagelink_nbytes, pagelink_pos))))
    for i in eachindex(pages)
        rnt.column_offsets[i] += pages[i].num_elements
    end
    rnt.num_entries += n_entries
    return rnt
end

# write the current footer and point the anchor at it (creating the anchor key
# on the first call, overwriting the anchor payload in place afterwards)
function _commit_footer!(rnt::WritableRNTuple, fdatime)
    f = rnt.file
    io = f.io
    footer_bytes = _buffer_bytes(io -> rnt_write(io, rnt.footer))
    fSeekFooter, footer_nbytes = _write_rblob(io, footer_bytes, fdatime; compression=rnt.compression)
    a = rnt.anchor
    rnt.anchor = ROOT_3a3a_RNTuple(a.fVersionEpoch, a.fVersionMajor, a.fVersionMinor, a.fVersionPatch,
                                   a.fSeekHeader, a.fNBytesHeader, a.fLenHeader,
                                   fSeekFooter, footer_nbytes, length(footer_bytes), a.fMaxKeySize, 0)
    if rnt.anchor_pos == 0
        klen = _tkey32_len("ROOT::RNTuple", rnt.name, "")
        key = TKey32(klen + _ANCHOR_OBJLEN, 4, _ANCHOR_OBJLEN, fdatime, klen, 1,
                     Int32(position(io)), f.header.fBEGIN, "ROOT::RNTuple", rnt.name, "")
        rnt_write(io, key)
        # object preamble: (kByteCountMask | byte count of version word + payload), class version
        rnt_write(io, UInt32(Const.kByteCountMask | (2 + _ANCHOR_PAYLOAD_NBYTES)); legacy=true)
        rnt_write(io, UInt16(_ANCHOR_CLASS_VERSION); legacy=true)
        rnt.anchor_pos = position(io)
        rnt_write(io, rnt.anchor)
        push!(f.keys, key)
    else
        here = position(io)
        seek(io, rnt.anchor_pos)
        rnt_write(io, rnt.anchor)
        seek(io, here)
    end
    return rnt
end
