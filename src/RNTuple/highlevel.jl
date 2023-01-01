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

function Base.length(rn::RNTuple)::Int
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
