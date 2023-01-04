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
    buffers::Vector{O}
    buffer_ranges::Vector{UnitRange{Int64}}
    function RNTupleField(rn::R, field::F) where {R, F}
        O = _field_output_type(F)
        E = eltype(O)
        buffers = Vector{O}(undef, Threads.nthreads())
        buffer_ranges = [0:-1 for _ in 1:Threads.nthreads()]
        new{R, F, O, E}(rn, field, buffers, buffer_ranges)
    end
end
Base.length(rf::RNTupleField) = _length(rf.rn)
Base.size(rf::RNTupleField) = (length(rf), )
Base.IndexStyle(::RNTupleField) = IndexLinear()

function Base.getindex(rf::RNTupleField, idx::Int)
    tid = Threads.threadid()
    br = @inbounds rf.buffer_ranges[tid]
    localidx = if idx ∉ br
        _localindex_newcluster!(rf, idx, tid)
    else
        idx - br.start + 1
    end
    return rf.buffers[tid][localidx]
end

function _read_page_list(rn, nth_cluster_group=1)
    #TODO add multiple cluster group support
    bytes = _read_envlink(rn.io, only(rn.footer.cluster_group_records).page_list_link);
    return _rntuple_read(IOBuffer(bytes), RNTupleEnvelope{PageLink}).payload
end

function _localindex_newcluster!(rf::RNTupleField, idx::Int, tid::Int)
    page_list = _read_page_list(rf.rn, 1)
    summaries = rf.rn.footer.cluster_summaries

    for (cluster_idx, cluster) in enumerate(summaries)
        first_entry = cluster.num_first_entry 
        n_entries = cluster.num_entries
        if first_entry + n_entries >= idx
            br = first_entry+1:(first_entry+n_entries)
            rf.buffers[tid] = read_field(rf.rn.io, rf.field, page_list[cluster_idx])
            rf.buffer_ranges[tid] = br
            return idx - br.start + 1
        end
    end
    error("$idx-th event not found in cluster summaries")
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

function Base.keys(rn::RNTuple)
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

function LazyTree(rn::RNTuple, selection)
    field_names = keys(rn)
    _m(r::Regex) = Base.Fix1(occursin, r)
    filtered_names = mapreduce(∪, selection) do b
        if b isa Regex
            filter(_m(b), field_names)
        elseif b isa String
            [b]
        else
            error("branch selection must be string or regex")
        end
    end

    N = Tuple(Symbol.(filtered_names))
    T = Tuple(RNTupleField(rn, getproperty(rn.schema, Symbol(k))) for k in filtered_names)

    return LazyTree(NamedTuple{N}(T))
end
