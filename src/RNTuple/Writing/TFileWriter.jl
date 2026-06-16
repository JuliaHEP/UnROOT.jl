using StaticArrays
using UnROOT
using UnROOT: RNTupleFrame, ClusterSummary, PageDescription
using XXHashNative: xxh3_64
using Accessors
using Tables: istable, columntable, schema

function color_diff(ary1, ary2)
    if length(ary1) != length(ary2)
        printstyled("!!! Length mismatch !!!: length(ary1)=$(length(ary1)), length(ary2)=$(length(ary2))\n", color=:red)
    end
    print("[")
    x = 0
    for (i,j) in zip(ary1, ary2)
        if x % 8 == 0
            print("    ")
        end
        if x % 16 == 0
            println()
            x = 0
        end
        if i != j
            printstyled("$(repr(i))/$(repr(j)), ", color=:red)
        else
            printstyled("$(repr(i)), ", color=:green)
        end
        x += 1
    end
    println()
    println("]")
end

function rnt_write(io::IO, x::AbstractString; legacy=false)
    # byte count, not character count: we write codeunits below
    L = ncodeunits(x)
    if legacy
        if L > typemax(UInt8)
            error("String longer than 255 not implemented")
        end
        write(io, UInt8(L))
        write(io, codeunits(x))
    else
        write(io, UInt32(L))
        write(io, codeunits(x))
    end
end

function rnt_write(io::IO, x::AbstractVector)
    error("Ambiguous type: $(typeof(x)), use Write_RNTupleListFrame or similar wrapper")
end

function rnt_write(io::IO, x; legacy=false)
    if legacy
        write(io, bswap(x))
    else
        write(io, x)
    end
end

struct Page_write{T <: AbstractVector{UInt8}}
    data::T
    num_elements::Int32
end

function rnt_write(io::IO, x::Page_write; checksum=true)
    write(io, x.data)
    if checksum
        write(io, xxh3_64(x.data))
    end
end

function rnt_write(io::IO, x::AbstractVector{UInt8}; legacy=false)
    if legacy
        write(io, reverse(x))
    else
        write(io, x)
    end
end

function test_io(obj, expected; kw...)
    a = IOBuffer()
    rnt_write(a, obj; kw...)
    ours = take!(a)
    if ours != expected
        color_diff(ours, expected)
    end
end

function rnt_write(io::IO, x::UnROOT.FileHeader32)
    rnt_write(io, x.fBEGIN; legacy=true)
    rnt_write(io, x.fEND; legacy=true)
    rnt_write(io, x.fSeekFree; legacy=true)
    rnt_write(io, x.fNbytesFree; legacy=true)
    rnt_write(io, x.nfree; legacy=true)
    rnt_write(io, x.fNbytesName; legacy=true)
    rnt_write(io, x.fUnits; legacy=true)
    rnt_write(io, x.fCompress; legacy=true)
    rnt_write(io, x.fSeekInfo; legacy=true)
    rnt_write(io, x.fNbytesInfo; legacy=true)
    rnt_write(io, x.fUUID; legacy=true)
end

function rnt_write(io::IO, x::UnROOT.TKey32)
    p = position(io)
    rnt_write(io, x.fNbytes; legacy=true)
    rnt_write(io, x.fVersion; legacy=true)
    rnt_write(io, x.fObjlen; legacy=true)
    rnt_write(io, x.fDatime; legacy=true)
    rnt_write(io, x.fKeylen; legacy=true)
    rnt_write(io, x.fCycle; legacy=true)
    rnt_write(io, x.fSeekKey; legacy=true)
    rnt_write(io, x.fSeekPdir; legacy=true)
    rnt_write(io, x.fClassName; legacy=true)
    rnt_write(io, x.fName; legacy=true)
    rnt_write(io, x.fTitle; legacy=true)
    @assert position(io) - p == x.fKeylen
end

struct TFile_write
    filename::String
    unknown::String
end
function rnt_write(io::IO, x::TFile_write)
    rnt_write(io, x.filename; legacy=true)
    rnt_write(io, x.unknown; legacy=true)
end

function rnt_write(io::IO, x::UnROOT.ROOTDirectoryHeader32)
    rnt_write(io, x.fVersion; legacy=true)
    rnt_write(io, x.fDatimeC; legacy=true)
    rnt_write(io, x.fDatimeM; legacy=true)
    rnt_write(io, x.fNbytesKeys; legacy=true)
    rnt_write(io, x.fNbytesName; legacy=true)
    rnt_write(io, x.fSeekDir; legacy=true)
    rnt_write(io, x.fSeekParent; legacy=true)
    rnt_write(io, x.fSeekKeys; legacy=true)
end

Base.@kwdef struct RBlob
    fNbytes::Int32
    fVersion::Int16
    fObjLen::Int32
    fDatime::UInt32
    fKeyLen::Int16
    fCycle::Int16
    fSeekKey::Int32
    fSeekPdir::Int32
    fClassName::String
    fName::String
    fTitle::String
end
function rnt_write(io::IO, x::RBlob)
    rnt_write(io, x.fNbytes; legacy=true)
    rnt_write(io, x.fVersion; legacy=true)
    rnt_write(io, x.fObjLen; legacy=true)
    rnt_write(io, x.fDatime; legacy=true)
    rnt_write(io, x.fKeyLen; legacy=true)
    rnt_write(io, x.fCycle; legacy=true)
    rnt_write(io, x.fSeekKey; legacy=true)
    rnt_write(io, x.fSeekPdir; legacy=true)
    rnt_write(io, x.fClassName; legacy=true)
    rnt_write(io, x.fName; legacy=true)
    rnt_write(io, x.fTitle; legacy=true)
end

function rnt_write(io::IO, x::UnROOT.FieldRecord)
    rnt_write(io, x.field_version)
    rnt_write(io, x.type_version)
    rnt_write(io, x.parent_field_id)
    rnt_write(io, x.struct_role)
    rnt_write(io, x.flags)
    rnt_write(io, x.field_name)
    rnt_write(io, x.type_name)
    rnt_write(io, x.type_alias)
    rnt_write(io, x.field_desc)
    if !iszero(0x01 & x.flags)
        rnt_write(io, x.repetition)
    end
    if !iszero(0x02 & x.flags)
        rnt_write(io, x.source_field_id)
    end
    if !iszero(0x04 & x.flags)
        rnt_write(io, x.root_streamer_checksum)
    end
end

function rnt_write(io::IO, x::UnROOT.ColumnRecord)
    rnt_write(io, x.type)
    rnt_write(io, x.nbits)
    rnt_write(io, x.field_id)
    rnt_write(io, x.flags)
    # final (1.0) spec: representation index first, then the optional first
    # element index gated on the deferred-column flag 0x01
    rnt_write(io, x.representation_idx)
    if !iszero(x.first_ele_idx)
        if iszero(x.flags & 0x01)
            error("First element index is set but the deferred-column flag (0x01) is not")
        end
        rnt_write(io, x.first_ele_idx)
    end
end

function rnt_write(io::IO, x::RNTupleFrame{T}) where T
    temp_io = IOBuffer()
    rnt_write(temp_io, x.payload)
    size = temp_io.size + 8
    write(io, Int64(size))
    seekstart(temp_io)
    write(io, temp_io)
end

struct Write_RNTupleListFrame{T<:AbstractArray}
    payload::T
end
function rnt_write(io::IO, x::Write_RNTupleListFrame)
    ary = x.payload
    N = length(ary)
    temp_io = IOBuffer()
    for x in ary
        rnt_write(temp_io, RNTupleFrame(x))
    end
    size = temp_io.size + sizeof(Int64) + sizeof(Int32)
    write(io, Int64(-size))
    write(io, Int32(N))
    seekstart(temp_io)
    write(io, temp_io)
end

function _checksum(x::UnROOT.RNTupleHeader)
    temp_io = IOBuffer()
    rnt_write(temp_io, x.feature_flag)
    rnt_write(temp_io, x.name)
    rnt_write(temp_io, x.ntuple_description)
    rnt_write(temp_io, x.writer_identifier)
    rnt_write(temp_io, Write_RNTupleListFrame(x.field_records))
    rnt_write(temp_io, Write_RNTupleListFrame(x.column_records))
    rnt_write(temp_io, Write_RNTupleListFrame(x.alias_columns))
    rnt_write(temp_io, Write_RNTupleListFrame(x.extra_type_infos))

    # add id_length size and checksum size
    envelope_size = temp_io.size + sizeof(Int64) + sizeof(UInt64)
    id_type = 0x0001

    id_length = (UInt64(envelope_size) << 16) | id_type

    payload_ary = take!(temp_io)
    prepend!(payload_ary, reinterpret(UInt8, [id_length]))

    return xxh3_64(payload_ary)
end

function rnt_write(io::IO, x::UnROOT.RNTupleHeader; envelope=true)
    temp_io = IOBuffer()
    rnt_write(temp_io, x.feature_flag)
    rnt_write(temp_io, x.name)
    rnt_write(temp_io, x.ntuple_description)
    rnt_write(temp_io, x.writer_identifier)
    rnt_write(temp_io, Write_RNTupleListFrame(x.field_records))
    rnt_write(temp_io, Write_RNTupleListFrame(x.column_records))
    rnt_write(temp_io, Write_RNTupleListFrame(x.alias_columns))
    rnt_write(temp_io, Write_RNTupleListFrame(x.extra_type_infos))

    # add id_length size and checksum size
    envelope_size = temp_io.size + sizeof(Int64) + sizeof(UInt64)
    id_type = 0x0001

    id_length = (UInt64(envelope_size) << 16) | id_type

    payload_ary = take!(temp_io)

    if envelope
        prepend!(payload_ary, reinterpret(UInt8, [id_length]))
        checksum = xxh3_64(payload_ary)
        write(io, payload_ary)
        write(io, checksum)
    else
        write(io, payload_ary)
    end
end

function rnt_write(io::IO, x::ClusterSummary)
    rnt_write(io, x.first_entry_number)
    rnt_write(io, x.number_of_entries)
end

function rnt_write(io::IO, x::UnROOT.Locator)
    rnt_write(io, x.num_bytes)
    rnt_write(io, x.offset)
end

function rnt_write(io::IO, x::PageDescription)
    rnt_write(io, -x.num_elements)
    rnt_write(io, x.locator)
end

function rnt_write(io::IO, x::UnROOT.RNTuplePageTopList)
    ary = x.payload
    N = length(ary)
    temp_io = IOBuffer()
    for x in ary
        rnt_write(temp_io, x)
    end
    size = temp_io.size + sizeof(Int64) + sizeof(Int32)
    write(io, Int64(-size))
    write(io, Int32(N))
    seekstart(temp_io)
    write(io, temp_io)
end
function rnt_write(io::IO, x::UnROOT.RNTuplePageOuterList)
    ary = x.payload
    N = length(ary)
    temp_io = IOBuffer()
    for x in ary
        rnt_write(temp_io, x)
    end
    size = position(temp_io) + sizeof(Int64) + sizeof(Int32)
    write(io, Int64(-size))
    write(io, Int32(N))
    seekstart(temp_io)
    write(io, temp_io)
end
function rnt_write(io::IO, x::UnROOT.RNTuplePageInnerList)
    ary = x.payload
    N = length(ary)
    temp_io = IOBuffer()
    for x in ary
        rnt_write(temp_io, x)
    end
    offset = zero(UInt64)
    compression = zero(UInt32)
    write(temp_io, offset, compression)
    size = position(temp_io) + sizeof(offset) + sizeof(compression)
    write(io, Int64(-size))
    write(io, Int32(N))
    seekstart(temp_io)
    write(io, temp_io)
end

# Writer-only inner page list: carries the per-column element offset and 32-bit
# compression settings that trail the inner list frame (see the "Page Locations"
# section of the RNTuple spec). The reader's `RNTuplePageInnerList` skips this
# trailer, so it does not need these fields.
struct InnerPageListWrite
    pages::Vector{PageDescription}
    element_offset::Int64
    compression::UInt32
end

# Writer-only page-link envelope whose nested list carries `InnerPageListWrite`
# items (with element offset + compression settings). Field names match
# `UnROOT.PageLink` so the serialization below is shared.
struct PageLinkWrite
    header_checksum::UInt64
    cluster_summaries::Vector{ClusterSummary}
    nested_page_locations::RNTuplePageTopList{RNTuplePageOuterList{InnerPageListWrite}}
end

function rnt_write(io::IO, x::Union{UnROOT.PageLink,PageLinkWrite}; envelope=true)
    temp_io = IOBuffer()
    rnt_write(temp_io, x.header_checksum)
    rnt_write(temp_io, Write_RNTupleListFrame(x.cluster_summaries))
    rnt_write(temp_io, x.nested_page_locations)

    # add id_length size and checksum size
    envelope_size = temp_io.size + sizeof(Int64) + sizeof(UInt64)
    id_type = 0x0003

    id_length = (UInt64(envelope_size) << 16) | id_type

    payload_ary = take!(temp_io)

    if envelope
        prepend!(payload_ary, reinterpret(UInt8, [id_length]))
        checksum = xxh3_64(payload_ary)
        write(io, payload_ary)
        write(io, checksum)
    else
        write(io, payload_ary)
    end
end

function rnt_write(io::IO, x::UnROOT.EnvLink)
    rnt_write(io, x.uncomp_size)
    rnt_write(io, x.locator)
end

"""
@SimpleStruct struct ClusterGroupRecord
    minimum_entry_number::Int64
    entry_span::Int64
    num_clusters::Int32
    page_list_link::EnvLink
end
"""
function rnt_write(io::IO, x::UnROOT.ClusterGroupRecord)
    rnt_write(io, x.minimum_entry_number)
    rnt_write(io, x.entry_span)
    rnt_write(io, x.num_clusters)
    rnt_write(io, x.page_list_link)
end

function rnt_write(io::IO, x::UnROOT.RNTupleSchemaExtension)
    temp_io = IOBuffer()
    rnt_write(temp_io, Write_RNTupleListFrame(x.field_records))
    rnt_write(temp_io, Write_RNTupleListFrame(x.column_records))
    rnt_write(temp_io, Write_RNTupleListFrame(x.alias_records))
    rnt_write(temp_io, Write_RNTupleListFrame(x.extra_type_info))

    size = temp_io.size + sizeof(Int64)
    write(io, Int64(size))
    seekstart(temp_io)
    write(io, temp_io)
end

function rnt_write(io::IO, x::UnROOT.RNTupleFooter; envelope=true)
    temp_io = IOBuffer()
    rnt_write(temp_io, x.feature_flag)
    rnt_write(temp_io, x.header_checksum)
    rnt_write(temp_io, x.extension_header_links)
    rnt_write(temp_io, Write_RNTupleListFrame(x.cluster_group_records))

    # add id_length size and checksum size
    envelope_size = temp_io.size + sizeof(Int64) + sizeof(UInt64)
    id_type = 0x0002

    id_length = (UInt64(envelope_size) << 16) | id_type

    payload_ary = take!(temp_io)

    if envelope
        prepend!(payload_ary, reinterpret(UInt8, [id_length]))
        checksum = xxh3_64(payload_ary)
        write(io, payload_ary)
        write(io, checksum)
    else
        write(io, payload_ary)
    end
end

function rnt_write(io::IO, x::UnROOT.ROOT_3a3a_RNTuple)
    temp_io = IOBuffer()
    rnt_write(temp_io, x.fVersionEpoch; legacy=true)
    rnt_write(temp_io, x.fVersionMajor; legacy=true)
    rnt_write(temp_io, x.fVersionMinor; legacy=true)
    rnt_write(temp_io, x.fVersionPatch; legacy=true)
    rnt_write(temp_io, x.fSeekHeader; legacy=true)
    rnt_write(temp_io, x.fNBytesHeader; legacy=true)
    rnt_write(temp_io, x.fLenHeader; legacy=true)
    rnt_write(temp_io, x.fSeekFooter; legacy=true)
    rnt_write(temp_io, x.fNBytesFooter; legacy=true)
    rnt_write(temp_io, x.fLenFooter; legacy=true)
    rnt_write(temp_io, x.fMaxKeySize; legacy=true)
    payload_ary = take!(temp_io)
    checksum = xxh3_64(payload_ary)
    rnt_write(io, payload_ary)
    rnt_write(io, checksum; legacy=true)
end

mutable struct WriteObservable{O, T}
    io::O
    position::Int64
    len::Int64
    object::T
end

function Base.setindex!(io::WriteObservable, val, key::Symbol)
    new_obj = set(io.object, PropertyLens(key), val)
    io.object = new_obj
    return io
end

function Base.setindex!(io::WriteObservable, dict::Dict)
    for (key, val) in dict
        new_obj = set(io.object, PropertyLens(key), val)
        io.object = new_obj
    end
    return io
end

function flush!(o::WriteObservable) 
    io = o.io
    old_pos = position(io)

    seek(io, o.position)
    rnt_write(io, o.object)
    seek(io, old_pos)

    nothing
end

function rnt_write_observe(io::IO, x::T) where T
    pos = position(io)
    rnt_write(io, x)
    len = position(io) - pos
    WriteObservable(io, pos, len, x)
end

# primary case
function add_field_column_record!(field_records, column_records, input_T::Type{<:Real}, NAME; parent_field_id, col_field_id = parent_field_id)
    fr = UnROOT.FieldRecord(zero(UInt32), zero(UInt32), parent_field_id, zero(UInt16), zero(UInt16), string(NAME), RNT_WRITE_CPP_TYPE_NAME_DICT[input_T], "", "", 0, -1, -1)
    rnt_col_type = RNT_COL_TYPE_TABLE[RNT_WRITE_JL_TYPE_DICT[input_T] + 1]
    cr = UnROOT.ColumnRecord(rnt_col_type.type, rnt_col_type.nbits, col_field_id, 0x00, 0x00, 0)
    push!(field_records, fr)
    push!(column_records, cr)
    nothing
end

# string case
function add_field_column_record!(field_records, column_records, input_T::Type{<:AbstractString}, NAME; parent_field_id, col_field_id = parent_field_id)
    implicit_field_id = length(field_records)
    fr =  UnROOT.FieldRecord(; field_version=0x00000000, type_version=0x00000000, parent_field_id, struct_role=0x0000, flags=0x0000, repetition=0, source_field_id=-1, root_streamer_checksum=-1, field_name=string(NAME), type_name="std::string", type_alias="", field_desc="", )
    push!(field_records, fr)

    rnt_indexcol_type = RNT_COL_TYPE_TABLE[RNT_WRITE_JL_TYPE_DICT[Index64] + 1]
    cr_offset = UnROOT.ColumnRecord(rnt_indexcol_type.type, rnt_indexcol_type.nbits, col_field_id, 0x00, 0x00, 0)
    push!(column_records, cr_offset)
    rnt_charcol_type = RNT_COL_TYPE_TABLE[RNT_WRITE_JL_TYPE_DICT[Char] + 1]
    cr_chars = UnROOT.ColumnRecord(rnt_charcol_type.type, rnt_charcol_type.nbits, col_field_id, 0x00, 0x00, 0)
    push!(column_records, cr_chars)
    nothing
end

_rnt_cpp_typename(T::Type{<:Real}) = RNT_WRITE_CPP_TYPE_NAME_DICT[T]
_rnt_cpp_typename(::Type{<:AbstractString}) = "std::string"
_rnt_cpp_typename(T::Type{<:AbstractVector}) = "std::vector<" * _rnt_cpp_typename(eltype(T)) * ">"

# vector case
function add_field_column_record!(field_records, column_records, input_T::Type{<:AbstractVector}, NAME; parent_field_id, col_field_id = parent_field_id)
    implicit_field_id = length(field_records)
    fr =  UnROOT.FieldRecord(; field_version=0x00000000, type_version=0x00000000, parent_field_id, struct_role=0x0001, flags=0x0000, repetition=0, source_field_id=-1, root_streamer_checksum=-1, field_name=string(NAME), type_name=_rnt_cpp_typename(input_T), type_alias="", field_desc="", )
    push!(field_records, fr)
    rnt_col_type = RNT_COL_TYPE_TABLE[RNT_WRITE_JL_TYPE_DICT[Index64] + 1]
    cr_offset = UnROOT.ColumnRecord(rnt_col_type.type, rnt_col_type.nbits, col_field_id, 0x00, 0x00, 0)
    push!(column_records, cr_offset)

    # TODO: this feels like a hack, think about it more
    Element_T = eltype(input_T)
    content_parent_field_id = Element_T <: Real ? implicit_field_id : parent_field_id
    add_field_column_record!(field_records, column_records, Element_T, "_0"; parent_field_id = content_parent_field_id, col_field_id = length(field_records))
    nothing
end

function schema_to_field_column_records(table)
    input_schema = schema(table)
    input_Ts = input_schema.types
    input_names = input_schema.names
    field_records = UnROOT.FieldRecord[]
    column_records = UnROOT.ColumnRecord[]

    for (input_T, input_name) in zip(input_Ts, input_names)
        add_field_column_record!(field_records, column_records, input_T, input_name, parent_field_id=length(field_records))
    end
    return field_records, column_records
end

function rnt_write(io::IO, x::InnerPageListWrite)
    temp_io = IOBuffer()
    for p in x.pages
        rnt_write(temp_io, p)
    end
    write(temp_io, x.element_offset, x.compression)
    size = position(temp_io) + sizeof(Int64) + sizeof(Int32)
    write(io, Int64(-size))
    write(io, Int32(length(x.pages)))
    seekstart(temp_io)
    write(io, temp_io)
end

"""
    generate_page_links(page_locators, compression) -> RNTuplePageTopList

Build the nested page-location list for a single cluster. `page_locators` is a
vector of `(num_elements, nbytes, offset)` for each column's single page;
`compression` is the fCompress code recorded per column.
"""
function generate_page_links(page_locators, compression::Integer)
    outer_list = RNTuplePageOuterList{InnerPageListWrite}([])
    for (num_elements, nbytes, pos) in page_locators
        inner_list = InnerPageListWrite(
            [PageDescription(num_elements, Locator(nbytes, pos))],
            0, UInt32(compression))
        push!(outer_list, inner_list)
    end
    return RNTuplePageTopList([outer_list])
end

# serialized TKey32 header (26 bytes of fixed fields) + three length-prefixed strings
_tkey32_len(class, name, title) =
    Int16(26 + 3 + ncodeunits(class) + ncodeunits(name) + ncodeunits(title))

"""
    _write_rblob(file::IO, payload::AbstractVector{UInt8}, fdatime; compression=0) -> (pos, nbytes)

Write an RBlob TKey followed by `payload` with correctly computed key sizes,
optionally compressing the payload with ROOT's block framing for the given
`compression` (fCompress) code. The key's `fObjLen` records the uncompressed
size and `fNbytes` the on-disk size, so a reader can tell whether the blob is
compressed. Returns the file position where the (possibly compressed) payload
starts and its on-disk byte count (for locators).
"""
function _write_rblob(file::IO, payload::AbstractVector{UInt8}, fdatime; compression::Integer=0)
    ondisk = _root_compress(payload, compression)
    klen = _tkey32_len("RBlob", "", "")
    key = RBlob(; fNbytes = Int32(klen + length(ondisk)), fVersion = 4,
                  fObjLen = Int32(length(payload)), fDatime = fdatime,
                  fKeyLen = klen, fCycle = 1,
                  fSeekKey = Int32(position(file)), fSeekPdir = 100,
                  fClassName = "RBlob", fName = "", fTitle = "")
    rnt_write(file, key)
    pos = position(file)
    write(file, ondisk)
    return pos, length(ondisk)
end

_buffer_bytes(writer::Function) = (io = IOBuffer(); writer(io); take!(io))

"""
    _root_datime([t]) -> UInt32

Encode a wall-clock time as ROOT's `TDatime` (the `fDatime` field of every TKey):
a 32-bit packed `(year-1995):month:day:hour:min:sec`. Defaults to the current
local time, so written files carry a real timestamp instead of a frozen one.
"""
function _root_datime(t::Base.Libc.TmStruct = Base.Libc.TmStruct(time()))
    year = t.year + 1900
    return UInt32(year - 1995) << 26 | UInt32(t.month + 1) << 22 |
           UInt32(t.mday) << 17 | UInt32(t.hour) << 12 |
           UInt32(t.min) << 6 | UInt32(t.sec)
end

# Default on-disk compression: LZ4 (algorithm 4) at level 4, i.e. ROOT fCompress
# code 404 — matching ROOT's RNTuple default for the LZ4 algorithm.
const RNT_DEFAULT_COMPRESSION = 100 * Const.kLZ4 + 4

"""
    write_rntuple(file::IO, table; file_name="test_ntuple_minimal.root",
                  rntuple_name="myntuple", compression=$(100 * 4 + 4))

Write `table` (any Tables.jl-compatible table, e.g. a `NamedTuple` of vectors)
into `file` as an RNTuple inside a freshly created ROOT file structure. The
output is readable by UnROOT itself, uproot, and ROOT (≥ 6.34).

Supported column element types: `Bool` (bit column), `Int8`–`Int64`,
`UInt8`–`UInt64`, `Float16`/`Float32`/`Float64`, `String`, and (nested)
`Vector`s of these.

`compression` is a ROOT `fCompress` code (`algorithm*100 + level`); pass `0` for
no compression. Supported algorithms: `4` LZ4 (default, level 4), `1` ZLIB,
`5` ZSTD. Each page and the header/footer/page-list envelopes are compressed
independently, and any block that fails to shrink is stored uncompressed.

Current limitations: data is written as a single cluster with one page per
column; struct/union columns are not supported.

# Example
```julia
julia> open("out.root", "w") do io
           UnROOT.write_rntuple(io, (x=[1.0, 2.0], s=["a", "b"]); rntuple_name="t")
       end

julia> LazyTree("out.root", "t")
```
"""
function write_rntuple(file::IO, table; file_name="test_ntuple_minimal.root",
                       rntuple_name="myntuple", compression::Integer=RNT_DEFAULT_COMPRESSION)
    if !istable(table)
        error("RNTuple writing accepts object compatible with Tables.jl interface, got type $(typeof(table))")
    end

    input_cols = columntable(table)
    if !allequal(map(length, values(input_cols)))
        error("Top-level columns must have the same length")
    end
    input_length = length(input_cols[begin])

    fdatime = _root_datime()  # real timestamp on every key

    # The streamed ROOT::RNTuple anchor is wrapped in a 6-byte object preamble
    # (4-byte (kByteCountMask | byte count) + 2-byte class version, big-endian)
    # and followed by an 8-byte xxhash checksum.
    anchor_payload_nbytes = 64        # 4×UInt16 + 7×UInt64
    anchor_class_version = 2
    anchor_preamble_nbytes = 6
    anchor_objlen = Int32(anchor_preamble_nbytes + anchor_payload_nbytes + 8)

    # name-dependent sizes of the TFile container records
    klen_tfile = _tkey32_len("TFile", file_name, "")
    tnamed_len = 2 + ncodeunits(file_name)            # (1+name) + (1+empty title)
    fNbytesName = Int32(klen_tfile + tnamed_len)
    tfile_objlen = Int32(tnamed_len + 30 + 30)        # TNamed + directory header + padding
    klen_dir = _tkey32_len("", file_name, "")
    klen_anchor = _tkey32_len("ROOT::RNTuple", rntuple_name, "")
    fNbytesKeys = Int32(klen_dir + 4 + klen_anchor)
    klen_end = _tkey32_len("", file_name, "")
    fNbytesFree = Int32(klen_end + 10)
    fNbytesInfo = Int32(64 + length(Stubs.tsreamerinfo_compressed))  # constant streamer record

    # file format magic + on-disk format version (what readers check)
    write(file, b"root")
    rnt_write(file, Int32(63501); legacy=true)
    fileheader = UnROOT.FileHeader32(
        100,                  # fBEGIN
        0, 0,                 # fEND, fSeekFree (patched at the end)
        fNbytesFree, 1,       # fNbytesFree, nfree
        fNbytesName, 0x04,
        Int32(compression),   # fCompress
        0, fNbytesInfo,       # fSeekInfo (patched), fNbytesInfo
        zeros(SVector{18,UInt8}))
    fileheader_obs = rnt_write_observe(file, fileheader)
    write(file, zeros(UInt8, 100 - position(file)))   # zero-pad up to fBEGIN
    @assert position(file) == 100

    rnt_write(file, UnROOT.TKey32(klen_tfile + tfile_objlen, 4, tfile_objlen, fdatime,
                                  klen_tfile, 1, 100, 0, "TFile", file_name, ""))
    rnt_write(file, UnROOT.TFile_write(file_name, ""))
    tdirectory32 = UnROOT.ROOTDirectoryHeader32(5, fdatime, fdatime,
                                                fNbytesKeys, fNbytesName, 100, 0,
                                                0)  # fSeekKeys patched below
    tdirectory32_obs = rnt_write_observe(file, tdirectory32)
    # TUUID (version + 16 bytes) and reserved tail of the directory record; the
    # reader does not use these, so a zeroed UUID is sufficient.
    rnt_write(file, Stubs.dummy_padding2)

    # RNTuple header envelope. The writer identifier honestly reports UnROOT.jl
    # (not a ROOT version) per the ROOT team's request not to impersonate ROOT.
    field_records, col_records = schema_to_field_column_records(table)
    writer_identifier = "UnROOT.jl $(pkgversion(@__MODULE__))"
    rnt_header = UnROOT.RNTupleHeader(
        zero(UInt64), rntuple_name, "", writer_identifier,
        field_records, col_records,
        UnROOT.AliasRecord[], UnROOT.ExtraTypeInfo[])
    header_bytes = _buffer_bytes(io -> rnt_write(io, rnt_header))
    fSeekHeader, header_nbytes = _write_rblob(file, header_bytes, fdatime; compression)

    # pages (one page per column, one cluster), all in one RBlob. Each page is
    # compressed independently and carries an XxHash-3 checksum of its on-disk
    # (compressed) bytes, so the per-column locators can point inside the blob.
    pages_arys = mapreduce(rnt_col_to_ary, vcat, input_cols)
    @assert length(pages_arys) == length(col_records)
    pages = [rnt_ary_to_page(ary, cr) for (ary, cr) in zip(pages_arys, col_records)]
    page_ondisk = [_root_compress(p.data, compression) for p in pages]
    pages_payload = _buffer_bytes() do io
        for od in page_ondisk
            write(io, od)
            write(io, xxh3_64(od))   # checksum over the on-disk (compressed) bytes
        end
    end
    pages_begin, _ = _write_rblob(file, pages_payload, fdatime)  # container itself not re-compressed
    page_locators = Vector{Tuple{Int32,Int64,Int64}}(undef, length(pages))
    let pos = pages_begin
        for i in eachindex(pages)
            nbytes = length(page_ondisk[i])
            page_locators[i] = (pages[i].num_elements, nbytes, pos)
            pos += nbytes + 8  # on-disk data + xxh3 checksum
        end
    end

    # page list envelope
    header_checksum = _checksum(rnt_header)
    cluster_summary = Write_RNTupleListFrame([ClusterSummary(0, input_length)])
    nested_page_locations = generate_page_links(page_locators, compression)
    pagelink = PageLinkWrite(header_checksum, cluster_summary.payload, nested_page_locations)
    pagelink_bytes = _buffer_bytes(io -> rnt_write(io, pagelink))
    pagelink_pos, pagelink_nbytes = _write_rblob(file, pagelink_bytes, fdatime; compression)

    # footer envelope
    rnt_footer = UnROOT.RNTupleFooter(0, header_checksum, UnROOT.RNTupleSchemaExtension([], [], [], []), [
        UnROOT.ClusterGroupRecord(0, input_length, 1,
            UnROOT.EnvLink(length(pagelink_bytes), UnROOT.Locator(pagelink_nbytes, pagelink_pos))),
    ])
    footer_bytes = _buffer_bytes(io -> rnt_write(io, rnt_footer))
    fSeekFooter, footer_nbytes = _write_rblob(file, footer_bytes, fdatime; compression)

    # anchor: all locator values are known by now, no patching needed.
    # fNBytes* is the on-disk (compressed) size; fLen* is the uncompressed size.
    rnt_anchor = UnROOT.ROOT_3a3a_RNTuple(1, 0, 0, 0,
        fSeekHeader, header_nbytes, length(header_bytes),
        fSeekFooter, footer_nbytes, length(footer_bytes),
        0x0000000040000000, 0)  # checksum computed in rnt_write
    tkey32_anchor = UnROOT.TKey32(klen_anchor + anchor_objlen, 4, anchor_objlen, fdatime,
                                  klen_anchor, 1, position(file), 100, "ROOT::RNTuple", rntuple_name, "")
    rnt_write(file, tkey32_anchor)
    # object preamble for the streamed anchor: byte count (covering the version
    # word + payload, no checksum) | kByteCountMask, then the class version
    rnt_write(file, UInt32(Const.kByteCountMask | (2 + anchor_payload_nbytes)); legacy=true)
    rnt_write(file, UInt16(anchor_class_version); legacy=true)
    rnt_write(file, rnt_anchor)

    # directory key listing (1 key: the anchor)
    tdirectory32_obs[:fSeekKeys] = Int32(position(file))
    rnt_write(file, UnROOT.TKey32(fNbytesKeys, 4, Int32(4 + klen_anchor), fdatime,
                                  klen_dir, 1, position(file), 100, "", file_name, ""))
    rnt_write(file, Int32(1); legacy=true)  # number of keys in this directory
    rnt_write(file, tkey32_anchor)

    # streamer info (constant compressed TList blob describing ROOT::RNTuple;
    # name-independent, so kept verbatim)
    fileheader_obs[:fSeekInfo] = UInt32(position(file))
    rnt_write(file, UnROOT.TKey32(fNbytesInfo, 4, 1254, fdatime,
                                  64, 1, position(file), 100, "TList", "StreamerInfo", "Doubly linked list"))
    rnt_write(file, Stubs.tsreamerinfo_compressed)

    # free-segments record: one segment [fEND, 2000000000]
    fSeekFree = position(file)
    fileheader_obs[:fSeekFree] = UInt32(fSeekFree)
    fEND = fSeekFree + fNbytesFree
    rnt_write(file, UnROOT.TKey32(fNbytesFree, 4, 10, fdatime,
                                  klen_end, 1, fSeekFree, 100, "", file_name, ""))
    rnt_write(file, UInt16(1); legacy=true)        # TFree version
    rnt_write(file, UInt32(fEND); legacy=true)     # first free byte
    rnt_write(file, UInt32(2000000000); legacy=true)
    @assert position(file) == fEND
    fileheader_obs[:fEND] = UInt32(fEND)

    flush!(fileheader_obs)
    flush!(tdirectory32_obs)
end
