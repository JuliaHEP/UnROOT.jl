@SimpleStruct struct Locator
    num_bytes::Int32
    offset::UInt64
end

@SimpleStruct struct EnvLink
    uncomp_size::UInt64
    locator::Locator
end

@SimpleStruct struct ClusterGroupRecord
    minimum_entry_number::Int64
    entry_span::Int64
    num_clusters::Int32
    page_list_link::EnvLink
end

struct RNTupleSchemaExtension
    field_records::Vector{FieldRecord}
    column_records::Vector{ColumnRecord}
    alias_records::Vector{AliasRecord}
    extra_type_info::Vector{ExtraTypeInfo}
end

function _rntuple_read(io, ::Type{RNTupleSchemaExtension})
    pos = position(io)
    Size = read(io, Int64)
    end_pos = pos + Size
    @assert Size >= 0
    field_records = _rntuple_read(io, Vector{FieldRecord})
    column_records = _rntuple_read(io, Vector{ColumnRecord})
    alias_records = _rntuple_read(io, Vector{AliasRecord})
    extra_type_info = _rntuple_read(io, Vector{ExtraTypeInfo})
    seek(io, end_pos)

    return RNTupleSchemaExtension(field_records, column_records, alias_records, extra_type_info)
end

struct RNTupleFooter
    feature_flag::UInt64
    header_checksum::UInt64
    extension_header_links::RNTupleSchemaExtension
    cluster_group_records::Vector{ClusterGroupRecord}
    # whatever follows the cluster group list in the footer payload (spec 1.0.1
    # added a list frame of linked attribute sets there), kept verbatim so that
    # the writer can reproduce a footer it appends cluster groups to
    trailing_bytes::Vector{UInt8}
end
RNTupleFooter(feature_flag, header_checksum, extension_header_links, cluster_group_records) =
    RNTupleFooter(feature_flag, header_checksum, extension_header_links, cluster_group_records, UInt8[])

function _rntuple_read(io, ::Type{RNTupleFooter})
    feature_flag = read(io, UInt64)
    header_checksum = read(io, UInt64)
    extension_header_links = _rntuple_read(io, RNTupleSchemaExtension)
    cluster_group_records = _rntuple_read(io, Vector{ClusterGroupRecord})
    # `io` holds the whole envelope: its first 8 bytes encode the envelope
    # length, and the payload ends 8 bytes (checksum) before that
    here = position(io)
    seek(io, 0)
    envelope_length = Int(read(io, UInt64) >> 16)
    seek(io, here)
    trailing_bytes = read(io, max(envelope_length - 8 - here, 0))
    RNTupleFooter(feature_flag, header_checksum, extension_header_links, cluster_group_records, trailing_bytes)
end

function _read_locator(io, locator, uncomp_size::Integer)
    decompress_bytes(read_seek_nb(io, locator.offset, locator.num_bytes), uncomp_size)
end

function _read_locator!(dst::Vector{UInt8}, io, locator, uncomp_size::Integer)
    decompress_bytes!(dst, read_seek_nb(io, locator.offset, locator.num_bytes), uncomp_size)
end

# The parsed page lists are cached per RNTuple (`RNTuple.pagelinks`), so the
# raw envelope bytes are not cached here.
_read_envlink(io, link::EnvLink) = _read_locator(io, link.locator, link.uncomp_size)

@SimpleStruct struct PageDescription
    num_elements::Int32
    locator::Locator
end

# https://discourse.julialang.org/t/simd-gather-result-in-slow-down/95161/2
function split2_reinterpret!(dst, src::AbstractVector{UInt8})
    count = length(src) ÷ 2
    res = reinterpret(UInt16, dst)
    @inbounds for i = 1:count
        Base.Cartesian.@nexprs 2 j -> b_j = UInt16(src[(j-1)*count + i]) << (8*(j-1))
        res[i] = (b_2 | b_1)
    end
    return dst
end
function split4_reinterpret!(dst, src::AbstractVector{UInt8})
    count = length(src) ÷ 4
    res = reinterpret(UInt32, dst)
    @inbounds for i = 1:count
        Base.Cartesian.@nexprs 4 j -> b_j = UInt32(src[(j-1)*count + i]) << (8*(j-1))
        res[i] = (b_1 | b_2) | (b_3 | b_4)
    end
    return dst
end
function split8_reinterpret!(dst, src::AbstractVector{UInt8})
    count = length(src) ÷ 8
    res = reinterpret(UInt64, dst)
    @inbounds for i = 1:count
        Base.Cartesian.@nexprs 8 j -> b_j = UInt64(src[(j-1)*count + i]) << (8*(j-1))
        res[i] = (b_1 | b_2) | (b_3 | b_4) | (b_5 | b_6) | (b_7 | b_8)
    end
    return dst
end

# TODO: handle flags for shared cluster
@SimpleStruct struct ClusterSummary
    first_entry_number::Int64
    number_of_entries::Int64
end

for x in (:RNTuplePageTopList, :RNTuplePageOuterList, :RNTuplePageInnerList)
    @eval begin
        struct ($x){T} <: AbstractVector{T}
            payload::Vector{T}
        end

        function _rntuple_read(io, ::Type{$x{T}}) where T
            pos = position(io)
            Size = read(io, Int64)
            @assert Size < 0
            NumItems = read(io, Int32)
            end_pos = pos - Size
            res = T[_rntuple_read(io, T) for _=1:NumItems]
            seek(io, end_pos)
            return $x(res)
        end

        Base.size(r::$x) = size(r.payload)
        Base.getindex(r::$x, i) = r.payload[i]
        Base.setindex!(r::$x, v, i) = (r.payload[i] = v)
        Base.push!(r::$x, v) = push!(r.payload, v)
        Base.append!(r::$x, v) = append!(r.payload, v)
        
    end
end

@SimpleStruct struct PageLink
    header_checksum::UInt64
    cluster_summaries::Vector{ClusterSummary}
    nested_page_locations::RNTuplePageTopList{RNTuplePageOuterList{RNTuplePageInnerList{PageDescription}}}
end
