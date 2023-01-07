@SimpleStruct struct Locator
    num_bytes::Int32
    offset::UInt64
end

@SimpleStruct struct EnvLink
    uncomp_size::UInt32
    locator::Locator
end

@SimpleStruct struct ColumnGroupRecord
    column_ids::Vector{UInt32}
end


@SimpleStruct struct ClusterSummary
    num_first_entry::UInt64
    num_entries::UInt64
end

@SimpleStruct struct ClusterGroupRecord
    num_clusters::UInt32
    page_list_link::EnvLink
end

@SimpleStruct struct RNTupleFooter
    feature_flag::UInt64
    header_crc32::UInt32
    extension_header_links::Vector{EnvLink}
    column_group_records::Vector{ColumnGroupRecord}
    cluster_summaries::Vector{ClusterSummary}
    cluster_group_records::Vector{ClusterGroupRecord}
    meta_data_links::Vector{EnvLink}
end

function _read_locator(io, locator, uncomp_size)
    decompress_bytes(read_seek_nb(io, locator.offset, locator.num_bytes), uncomp_size)
end

@memoize LRU(maxsize = 200) function _read_envlink(io, link::EnvLink)
    _read_locator(io, link.locator, link.uncomp_size)
end

@SimpleStruct struct PageDescription
    num_elements::UInt32
    locator::Locator
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

