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
    L = length(x)
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
    if !iszero(x.first_ele_idx)
        if x.flags != 0x08
            error("First element index is set but flags is not 0x08")
        end
        rnt_write(io, x.first_ele_idx)
    end
    rnt_write(io, x.representation_idx)
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

function rnt_write(io::IO, x::UnROOT.PageLink; envelope=true)
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
    fr = UnROOT.FieldRecord(zero(UInt32), zero(UInt32), parent_field_id, zero(UInt16), zero(UInt16), string(NAME), RNTUPLE_WRITE_TYPE_CPPNAME_DICT[input_T], "", "", 0, -1, -1)
    cr = UnROOT.ColumnRecord(RNTUPLE_WRITE_TYPE_IDX_DICT[input_T]..., col_field_id, 0x00, 0x00, 0)
    push!(field_records, fr)
    push!(column_records, cr)
    nothing
end

# string case
function add_field_column_record!(field_records, column_records, input_T::Type{<:AbstractString}, NAME; parent_field_id, col_field_id = parent_field_id)
    implicit_field_id = length(field_records)
    fr =  UnROOT.FieldRecord(; field_version=0x00000000, type_version=0x00000000, parent_field_id, struct_role=0x0000, flags=0x0000, repetition=0, source_field_id=-1, root_streamer_checksum=-1, field_name=string(NAME), type_name="std::string", type_alias="", field_desc="", )
    push!(field_records, fr)

    cr_offset = UnROOT.ColumnRecord(RNTUPLE_WRITE_TYPE_IDX_DICT[Index64]..., col_field_id, 0x00, 0x00, 0)
    push!(column_records, cr_offset)
    cr_chars = UnROOT.ColumnRecord(RNTUPLE_WRITE_TYPE_IDX_DICT[Char]..., col_field_id, 0x00, 0x00, 0)
    push!(column_records, cr_chars)
    nothing
end

# vector case
function add_field_column_record!(field_records, column_records, input_T::Type{<:AbstractVector}, NAME; parent_field_id, col_field_id = parent_field_id)
    implicit_field_id = length(field_records)
    fr =  UnROOT.FieldRecord(; field_version=0x00000000, type_version=0x00000000, parent_field_id, struct_role=0x0001, flags=0x0000, repetition=0, source_field_id=-1, root_streamer_checksum=-1, field_name=string(NAME), type_name="", type_alias="", field_desc="", )
    push!(field_records, fr)
    cr_offset = UnROOT.ColumnRecord(RNTUPLE_WRITE_TYPE_IDX_DICT[Index64]..., col_field_id, 0x00, 0x00, 0)
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

function generate_page_links(column_records, pages_obses)
    outer_list = RNTuplePageOuterList{RNTuplePageInnerList{PageDescription}}([])
    for (cr, page_obs) in zip(column_records, pages_obses)
        Nbytes = length(page_obs.object.data)
        Nitems = Nbytes * 8 ÷ cr.nbits
        inner_list = RNTuplePageInnerList([
                PageDescription(Nitems, Locator(Nbytes, page_obs.position))
            ])
            push!(outer_list, inner_list)
    end
    return RNTuplePageTopList([outer_list])
end

function write_rntuple(file::IO, table; file_name="test_ntuple_minimal.root", rntuple_name="myntuple")
    if !istable(table)
        error("RNTuple writing accepts object compatible with Tables.jl interface, got type $(typeof(table))")
    end

    input_cols = columntable(table)
    if !allequal(length, input_cols)
        error("Top-level columns must have the same length")
    end
    input_length = length(input_cols[begin])

    rntAnchor_update = Dict{Symbol, Any}()

    file_preamble_obs = rnt_write_observe(file, Stubs.file_preamble)
    fileheader_obs = rnt_write_observe(file, Stubs.fileheader)
    dummy_padding1_obs = rnt_write_observe(file, Stubs.dummy_padding1)

    fileheader_obs[:fBEGIN] = UInt32(position(file))

    tkey32_tfile_obs = rnt_write_observe(file, Stubs.tkey32_tfile)
    tkey32_tfile_obs[:fName] = file_name
    tfile_obs = rnt_write_observe(file, Stubs.tfile)

    tdirectory32_obs = rnt_write_observe(file, Stubs.tdirectory32)
    dummy_padding2_obs = rnt_write_observe(file, Stubs.dummy_padding2)

    RBlob1 = UnROOT.RBlob(; fNbytes = 0x00DC, fVersion = 0x0004, fObjLen = 0x000000BA, fDatime = Stubs.WRITE_TIME, fKeyLen = 34,
    fCycle = 0x0001, fSeekKey = position(file), fSeekPdir = 100, fClassName = "RBlob", fName = "", fTitle = "")
    RBlob1_update = Dict{Symbol, Any}()
    RBlob1_obs = rnt_write_observe(file, RBlob1)
    field_records, col_records = schema_to_field_column_records(table)
    rnt_header = UnROOT.RNTupleHeader(
    zero(UInt64), rntuple_name, "", "ROOT v6.35.001",
    field_records, col_records,
    UnROOT.AliasRecord[], UnROOT.ExtraTypeInfo[]
    )

    rntAnchor_update[:fSeekHeader] = UInt32(position(file))
    rnt_header_obs = rnt_write_observe(file, rnt_header)
    rntAnchor_update[:fNBytesHeader] = rnt_header_obs.len
    rntAnchor_update[:fLenHeader] = rnt_header_obs.len
    RBlob1_update[:fObjLen] = rnt_header_obs.len
    RBlob1_update[:fNbytes] = rnt_header_obs.len + 34

    Base.setindex!(RBlob1_obs, RBlob1_update)

    RBlob2_obs = rnt_write_observe(file, Stubs.RBlob2)
    pages_arys = mapreduce(rnt_col_to_ary, vcat, input_cols)
    @assert length(pages_arys) == length(col_records)
    pages = [rnt_ary_to_page(ary, cr) for (ary, cr) in zip(pages_arys, col_records)]
    pages_obses = [rnt_write_observe(file, page) for page in pages]

    RBlob3_obs = rnt_write_observe(file, Stubs.RBlob3)
    cluster_summary = Write_RNTupleListFrame([ClusterSummary(0, input_length)])
    nested_page_locations = generate_page_links(col_records, pages_obses)

    pagelink = UnROOT.PageLink(_checksum(rnt_header_obs.object), cluster_summary.payload, nested_page_locations)
    pagelink_obs = rnt_write_observe(file, pagelink)

    RBlob4_obs = rnt_write_observe(file, Stubs.RBlob4)
    rntAnchor_update[:fSeekFooter] = UInt32(position(file))
    rnt_footer = UnROOT.RNTupleFooter(0, _checksum(rnt_header_obs.object), UnROOT.RNTupleSchemaExtension([], [], [], []), [
        UnROOT.ClusterGroupRecord(0, input_length, 1, UnROOT.EnvLink(pagelink_obs.len, UnROOT.Locator(pagelink_obs.len, pagelink_obs.position, ))),
    ])
    rnt_footer_obs = rnt_write_observe(file, rnt_footer)
    rntAnchor_update[:fNBytesFooter] = rnt_footer_obs.len
    rntAnchor_update[:fLenFooter] = rnt_footer_obs.len

    tkey32_anchor_position = position(file)
    tkey32_anchor = UnROOT.TKey32(0x0000008E, 4, typemin(Int32), Stubs.WRITE_TIME, 50, 1, tkey32_anchor_position, 100, "ROOT::RNTuple", rntuple_name, "")
    tkey32_anchor_obs1 = rnt_write_observe(file, tkey32_anchor)
    tkey32_anchor_update = Dict{Symbol, Any}()
    magic_6bytes_obs = rnt_write_observe(file, Stubs.magic_6bytes)
    rnt_anchor_obs = rnt_write_observe(file, Stubs.rnt_anchor)
    Base.setindex!(rnt_anchor_obs, rntAnchor_update)
    tkey32_anchor_update[:fObjlen] = rnt_anchor_obs.len + magic_6bytes_obs.len
    Base.setindex!(tkey32_anchor_obs1, tkey32_anchor_update)

    tdirectory32_obs[:fSeekKeys] = UInt32(position(file))
    tkey32_TDirectory_obs = rnt_write_observe(file, Stubs.tkey32_TDirectory)
    n_keys_obs = rnt_write_observe(file, Stubs.n_keys)
    tkey32_anchor_obs2 = rnt_write_observe(file, tkey32_anchor)
    Base.setindex!(tkey32_anchor_obs2, tkey32_anchor_update)

    fileheader_obs[:fSeekInfo] = UInt32(position(file))
    tkey32_TStreamerInfo_obs = rnt_write_observe(file, Stubs.tkey32_TStreamerInfo)
    tsreamerinfo_compressed_obs = rnt_write_observe(file, Stubs.tsreamerinfo_compressed)
    fileheader_obs[:fSeekFree] = UInt32(position(file))
    tfile_end_obs = rnt_write_observe(file, Stubs.tfile_end)
    fileheader_obs[:fEND] = UInt32(position(file))

    flush!(RBlob1_obs)
    flush!(tkey32_anchor_obs1)
    flush!(tkey32_anchor_obs2)
    flush!(tkey32_tfile_obs)
    flush!(tdirectory32_obs)
    flush!(fileheader_obs)
    flush!(rnt_anchor_obs)
end
