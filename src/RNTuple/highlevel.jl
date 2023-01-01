function _read_field_cluster(rn, field, event_id)
    #TODO handle cluster groups
    bytes = _read_envlink(rn.io, only(rn.footer.cluster_group_records).page_list_link);
    page_list = _rntuple_read(IOBuffer(bytes), RNTupleEnvelope{PageLink}).payload
    cluster_idx = _find_cluster_idx(rn, event_id)
    read_field(rn.io, field, page_list, cluster_idx)
end

"""
    mutable struct RNTupleField{R, F, O, E} <: AbstractVector{E}

Not a counterpart of RNTuple field in ROOT. This is a user-facing Julia-only
construct like `LazyBranch` that is meant to act like a lazy `AbstractVector`
backed with file IO source and a schema field from `RNTuple.schema`.

- `R` is the type of parent `RNTuple`
- `F` is the type of the field in the schema
- 'O' is the type of output when you read a cluster-worth of data
- 'E' is the element type of `O` (i.e. what you get for each event (row) in iteration)
"""
struct RNTupleField{R, F, O, E} <: AbstractVector{E}
    rn::R
    field::F
    buffers::Vector{Union{Nothing, O}}
    function RNTupleField(rn::R, field::F) where {R, F}
        O = _field_output_type(F)
        E = eltype(O)
        buffers = Union{Nothing, O}[nothing for _ = 1:Threads.nthreads()]
        new{R, F, O, E}(rn, field, buffers)
    end
end
Base.length(rf::RNTupleField) = _length(rf.rn)
Base.size(rf::RNTupleField) = (length(rf), )
Base.IndexStyle(::RNTupleField) = IndexLinear()
function Base.getindex(rf::RNTupleField, i::Int)
    tid = Threads.threadid()
    if isnothing(rf.buffers[tid])
        rf.buffers[tid] = _read_field_cluster(rf.rn, rf.field, i) # this gets the entire cluster
    end
    return rf.buffers[tid][i]
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
    function RNTuple(io::O, header, footer, schema::S) where {O, S}
        new{O, S}(
            io,
            header,
            footer,
            schema,
        )
    end
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
