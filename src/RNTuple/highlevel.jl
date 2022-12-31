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
    uncomp_size = pagedesc.num_elements * nbits ÷ 8
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

"""
    RNTuple

This is the struct for holding all metadata (schema) needed to completely describe
and RNTuple from ROOT, just like `TTree`, to obtain a table-like data object, you need
to use `LazyTree` explicitly.
"""
struct RNTuple{O, S}
    io::O
    header::RNTupleHeader
    footer::RNTupleFooter
    schema::S
end


function ROOT_3a3a_Experimental_3a3a_RNTuple(io, tkey::TKey, refs)
    local_io = datastream(io, tkey)
    skip(local_io, 6)
    anchor = ROOT_3a3a_Experimental_3a3a_RNTuple(
                    fCheckSum = readtype(local_io, Int32),
                    fVersion = readtype(local_io, UInt32),
                    fSize = readtype(local_io, UInt32),
                    fSeekHeader = readtype(local_io, UInt64),
                    fNBytesHeader = readtype(local_io, UInt32),
                    fLenHeader = readtype(local_io, UInt32),
                    fSeekFooter = readtype(local_io, UInt64),
                    fNBytesFooter = readtype(local_io, UInt32),
                    fLenFooter = readtype(local_io, UInt32),
                    fReserved = readtype(local_io, UInt64),
                                       )
    header_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekHeader, anchor.fNBytesHeader), anchor.fLenHeader)
    header_io = IOBuffer(header_bytes)
    header = _rntuple_read(header_io, RNTupleEnvelope{RNTupleHeader})

    footer_bytes = decompress_bytes(read_seek_nb(io, anchor.fSeekFooter, anchor.fNBytesFooter), anchor.fLenFooter)
    footer_io = IOBuffer(footer_bytes)
    footer = _rntuple_read(footer_io, RNTupleEnvelope{RNTupleFooter})
    @assert header.crc32 == footer.payload.header_crc32 "header and footer don't go together"

    schema = parse_fields(header.payload)

    rnt = RNTuple(io, header.payload, footer.payload, schema)
    return rnt
end

function _length(rn::RNTuple)::Int
    last_cluster = rn.footer.cluster_summaries[end]
    return last_cluster.num_first_entry + last_cluster.num_entries
end

function _keys(rn::RNTuple)
    keys = String[]
    fn = rn.header.field_records
    for (idx,f) in enumerate(fn)
        # 0-index logic
        if idx-1 == f.parent_field_id
            push!(keys, f.field_name)
        end
    end
    return keys
end

function _find_cluster_idx(rn::RNTuple, event_id::Integer)
    idx = findfirst(rn.footer.cluster_summaries) do cluster
        cluster.num_first_entry + cluster.num_entries > event_id
    end
    return idx
end

function read_field(io, field::LeafField{T}, page_list, cluster_idx) where T
    nbits = field.nbits
    pages = page_list[cluster_idx][field.content_col_idx]
    bytes = read_pagedesc(io, pages, nbits)
    reinterpret(T, bytes)
end

function read_field(io, field::VectorField{O, T}, page_list, cluster_idx) where {O, T}
    offset = read_field(io, field.offset_col, page_list, cluster_idx)
    content = read_field(io, field.content_col, page_list, cluster_idx)

    o = one(eltype(offset))
    jloffset = pushfirst!(offset .+ o, o) #change to 1-indexed, and add a 1 at the beginning
    return VectorOfVectors(content, jloffset, ArraysOfArrays.no_consistency_checks)
end

function _read_field_cluster(rn, field_name, event_id)
    #TODO handle cluster groups
    bytes = _read_envlink(rn.io, only(rn.footer.cluster_group_records).page_list_link);
    page_list = _rntuple_read(IOBuffer(bytes), RNTupleEnvelope{PageLink}).payload
    cluster_idx = _find_cluster_idx(rn, event_id)
    read_field(rn.io, getproperty(rn.schema, field_name), page_list, cluster_idx)
end
