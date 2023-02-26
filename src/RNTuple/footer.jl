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

# https://discourse.julialang.org/t/simd-gather-result-in-slow-down/95161/2
function split4_reinterpret(src::Vector{UInt8})
    dst = similar(src)
    count = length(src) ÷ 4
    res = reinterpret(UInt32, dst)
    @inbounds for i = 1:count
        Base.Cartesian.@nexprs 4 j -> b_j = UInt32(src[(j-1)*count + i]) << (8*(j-1))
        res[i] = (b_1 | b_2) | (b_3 | b_4)
    end
    return dst
end
function split8_reinterpret(src::Vector{UInt8})
    dst = similar(src)
    count = length(src) ÷ 8
    res = reinterpret(UInt64, dst)
    @inbounds for i = 1:count
        Base.Cartesian.@nexprs 8 j -> b_j = UInt64(src[(j-1)*count + i]) << (8*(j-1))
        res[i] = (b_1 | b_2) | (b_3 | b_4) | (b_5 | b_6) | (b_7 | b_8)
    end
    return dst
end

"""
    read_pagedesc(io, pagedesc::Vector{PageDescription}, nbits::Integer)

Read the decompressed raw bytes given a Page Description. The
`nbits` need to be provided according to the element type of the
column since `pagedesc` only contains `num_elements` information.

!!! note
    Boolean values are always stored as bit in RNTuple, so `nbits = 1`.
    
"""
function read_pagedesc(io, pagedescs::Vector{PageDescription}, nbits::Integer; split=false)
    res = mapreduce(vcat, pagedescs) do pagedesc
        # when nbits == 1 for bits, need RoundUp
        uncomp_size = div(pagedesc.num_elements * nbits, 8, RoundUp)
        tmp = _read_locator(io, pagedesc.locator, uncomp_size)
        if split && nbits == 32
            split4_reinterpret(tmp)
        elseif split && nbits == 64
            split8_reinterpret(tmp)
        else
            tmp
        end
    end

    return res
end

struct PageLink end
function _rntuple_read(io, ::Type{PageLink})::Vector{Vector{Vector{PageDescription}}}
    _rntuple_read(io, RNTupleListNoFrame{RNTupleListNoFrame{RNTupleListNoFrame{PageDescription}}})
end

