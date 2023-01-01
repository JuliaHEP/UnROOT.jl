@with_kw struct Locator
    num_bytes::Int32
    offset::UInt64
end
function _rntuple_read(io, ::Type{Locator})
    num_bytes = read(io, Int32)
    offset = read(io, UInt64)
    Locator(; num_bytes, offset)
end

"""
    EnvLink

Envelope Link

"""
@with_kw struct EnvLink
    uncomp_size::UInt32
    locator::Locator
end
function _rntuple_read(io, ::Type{EnvLink})
    uncomp_size = read(io, UInt32)
    locator = _rntuple_read(io, Locator)
    EnvLink(; uncomp_size, locator)
end

@with_kw struct ColumnGroupRecord
    column_ids::Vector{UInt32}
end
function _rntuple_read(io, ::Type{ColumnGroupRecord})
    column_ids = _rntuple_read(io, RNTupleListFrame{UInt32})
    ColumnGroupRecord(; column_ids)
end


@with_kw struct ClusterSummary
    num_first_entry::UInt64
    num_entries::UInt64
end
function _rntuple_read(io, ::Type{ClusterSummary})
    num_first_entry = read(io, UInt64)
    num_entries = read(io, UInt64)
    ClusterSummary(; num_first_entry, num_entries)
end

@with_kw struct ClusterGroupRecord
    num_clusters::UInt32
    page_list_link::EnvLink
end
function _rntuple_read(io, ::Type{ClusterGroupRecord})
    num_clusters = read(io, UInt32)
    page_list_link = _rntuple_read(io, EnvLink)
    ClusterGroupRecord(; num_clusters, page_list_link)
end

@with_kw struct RNTupleFooter
    feature_flag::UInt64
    header_crc32::UInt32
    extension_header_links::Vector{EnvLink} # this is a bare list frame for some reason
    column_group_records::Vector{ColumnGroupRecord}
    cluster_summaries::Vector{ClusterSummary}
    cluster_group_records::Vector{ClusterGroupRecord}
    meta_data_links::Vector{EnvLink}
end
function _rntuple_read(io, ::Type{RNTupleFooter})
    feature_flag = read(io, UInt64)
    header_crc32 = read(io, UInt32)
    extension_header_links = _rntuple_read(io, RNTupleListNoFrame{FieldRecord})
    column_group_records = _rntuple_read(io, RNTupleListFrame{ColumnGroupRecord})
    cluster_summaries = _rntuple_read(io, RNTupleListFrame{ClusterSummary})
    cluster_group_records = _rntuple_read(io, RNTupleListFrame{ClusterGroupRecord})
    meta_data_links = _rntuple_read(io, RNTupleListFrame{EnvLink})
    RNTupleFooter(; feature_flag, header_crc32, extension_header_links, column_group_records,
                 cluster_summaries, cluster_group_records, meta_data_links)
end

function _read_locator(io, locator, uncomp_size)
    decompress_bytes(read_seek_nb(io, locator.offset, locator.num_bytes), uncomp_size)
end

function _read_envlink(io, link::EnvLink)
    _read_locator(io, link.locator, link.uncomp_size)
end

@with_kw struct PageDescription
    num_elements::UInt32
    locator::Locator
end
function _rntuple_read(io, ::Type{PageDescription})
    num_elements = _rntuple_read(io, UInt32)
    locator = _rntuple_read(io, Locator)
    return PageDescription(; num_elements, locator)
end

"""
    read_pagedesc(io, pagedesc::PageDescription, nbits::Int)

Read the decompressed raw bytes given a Page Description. The
`nbits` need to be provided according to the element type of the
column since `pagedesc` only contains `num_elements` information.

!!! note
    Boolean values are always stored as bit in RNTuple, so `nbits = 1`.
    
"""
function read_pagedesc(io, pagedesc::PageDescription, nbits::Integer)
    uncomp_size = div(pagedesc.num_elements * nbits, 8, RoundUp) # when nbits == 1 for bits, need RoundUp
    return _read_locator(io, pagedesc.locator, uncomp_size)
end
function read_pagedesc(io, pagedescs::Vector, nbits::Integer)
    res = read_pagedesc.(Ref(io), pagedescs, nbits)
    return reduce(vcat, res)
end

struct PageLink end
function _rntuple_read(io, ::Type{PageLink})::Vector{Vector{Vector{PageDescription}}}
    _rntuple_read(io, RNTupleListNoFrame{RNTupleListNoFrame{RNTupleListNoFrame{PageDescription}}})
end

