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
    # per-thread cache of the last cluster read, see `_BufferSlot`; the locks
    # only serialize the (slow) refill of a slot
    slots::Vector{_SlotBox{O}}
    thread_locks::Vector{ReentrantLock}
    function RNTupleField(rn::R, field::F) where {R, F}
        O = _field_output_type(F)
        E = eltype(O)
        Nthreads = _maxthreadid()
        slots = [_SlotBox{O}() for _ in 1:Nthreads]
        thread_locks = [ReentrantLock() for _ in 1:Nthreads]
        new{R, F, O, E}(rn, field, slots, thread_locks)
    end
end
Base.length(rf::RNTupleField) = _length(rf.rn)
Base.size(rf::RNTupleField) = (length(rf), )
Base.IndexStyle(::RNTupleField) = IndexLinear()

# this is used for Table.partition()
"""
The event number range a given cluster covers, in Julia's index
"""
function _rntuple_clusterrange(cs)
    first_entry = cs.first_entry_number
    n_entries = cs.number_of_entries
    return first_entry+1:(first_entry+n_entries)
end

function _clusterranges(lbs::AbstractVector{<:RNTupleField})
    rn = first(lbs).rn
    ranges = UnitRange{Int64}[]
    for gi in eachindex(rn.footer.cluster_group_records)
        append!(ranges, map(_rntuple_clusterrange, _read_page_list(rn, gi).cluster_summaries))
    end
    return ranges
end

"""
    struct RNTupleSchema

A wrapper struct for `print_tree` implementation of the schema display.

# Example
```julia
julia> f = ROOTFile("./test/samples/RNTuple/test_ntuple_stl_containers.root");

julia> f["ntuple"].schema
RNTupleSchema with 13 top fields
├─ :lorentz_vector ⇒ Struct
│                    ├─ :pt ⇒ Leaf{Float32}(col=26)
│                    ├─ :eta ⇒ Leaf{Float32}(col=27)
│                    ├─ :phi ⇒ Leaf{Float32}(col=28)
│                    └─ :mass ⇒ Leaf{Float32}(col=29)
├─ :vector_tuple_int32_string ⇒ Vector
│                               ├─ :offset ⇒ Leaf{Int32}(col=9)
│                               └─ :content ⇒ Struct
│                                             ├─ :_1 ⇒ String
│                                             │        ├─ :offset ⇒ Leaf{Int32}(col=37)
│                                             │        └─ :content ⇒ Leaf{Char}(col=38)
│                                             └─ :_0 ⇒ Leaf{Int32}(col=36)
├─ :string ⇒ String
│            ├─ :offset ⇒ Leaf{Int32}(col=1)
│            └─ :content ⇒ Leaf{Char}(col=2)
├─ :vector_string ⇒ Vector
│                   ├─ :offset ⇒ Leaf{Int32}(col=5)
│                   └─ :content ⇒ String
│                                 ├─ :offset ⇒ Leaf{Int32}(col=13)
│                                 └─ :content ⇒ Leaf{Char}(col=14)
...
..
.
```
"""
struct RNTupleSchema
    namedtuple::NamedTuple
end
Base.propertynames(s::RNTupleSchema) = propertynames(getfield(s, :namedtuple))
Base.getproperty(s::RNTupleSchema, sym::Symbol) = getproperty(getfield(s, :namedtuple), sym)
Base.length(s::RNTupleSchema) = length(getfield(s, :namedtuple))
function Base.getindex(s::RNTupleSchema, idx)
    RNTupleSchema(getfield(s, :namedtuple)[idx])
end

function Base.getindex(rf::RNTupleField{R, F, O, E}, idx::Int) where {R, F, O, E}
    # deliberately bounds-checked: `maxthreadid()` can grow after construction
    # (adopted threads), and an out-of-range `tid` must not corrupt memory
    tid = Threads.threadid()
    slot = _load_slot(rf.slots[tid])
    if slot === nothing || idx ∉ slot.range
        slot = _refill_slot!(rf, tid, idx)
    end
    return @inbounds slot.buffer[idx - first(slot.range) + 1]
end

"""
    _read_page_list(rn, nth=1)

The (cached) page list of the `nth` cluster group of `rn`.
"""
function _read_page_list(rn, nth=1)
    Base.@lock rn.pagelinks_lock begin
        get!(rn.pagelinks, nth) do
            bytes = _read_envlink(rn.io, rn.footer.cluster_group_records[nth].page_list_link);
            _rntuple_read(IOBuffer(bytes), RNTupleEnvelope{PageLink}).payload
        end
    end
end

# the (1-based) index of the cluster group that contains the 0-based `entry`
function _cluster_group_index(rn, entry::Integer)
    records = rn.footer.cluster_group_records
    for (gi, cg) in enumerate(records)
        if cg.minimum_entry_number <= entry < cg.minimum_entry_number + cg.entry_span
            return gi
        end
    end
    # the group records should cover every entry; scan the summaries as a fallback
    for gi in eachindex(records)
        for cs in _read_page_list(rn, gi).cluster_summaries
            if cs.first_entry_number <= entry < cs.first_entry_number + cs.number_of_entries
                return gi
            end
        end
    end
    error("entry $entry not found in any cluster group")
end

# read the cluster holding `idx` into the slot of thread `tid` and return it
@noinline function _refill_slot!(rf::RNTupleField{R, F, O, E}, tid::Int, idx::Int) where {R, F, O, E}
    1 <= idx <= length(rf) || throw(BoundsError(rf, idx))
    Base.@lock rf.thread_locks[tid] begin
        page_list = _read_page_list(rf.rn, _cluster_group_index(rf.rn, idx - 1))
        cluster_summaries, nested_page_locations = page_list.cluster_summaries, page_list.nested_page_locations
        for (cluster_idx, cluster) in enumerate(cluster_summaries)
            first_entry = cluster.first_entry_number
            n_entries = cluster.number_of_entries
            if first_entry < idx <= first_entry + n_entries
                br = first_entry+1:(first_entry+n_entries)
                cluster_info = ClusterInfo(nested_page_locations[cluster_idx], first_entry, n_entries)
                slot = _BufferSlot{O}(br, read_field(rf.rn.io, rf.field, cluster_info))
                _store_slot!(rf.slots[tid], slot)
                return slot
            end
        end
        error("$idx-th event not found in cluster summaries")
    end
end

"""
    RNTuple

This is the struct for holding all metadata (schema) needed to completely describe
and RNTuple from ROOT, just like `TTree`, to obtain a table-like data object, you need
to use `LazyTree` explicitly:


# Example
```julia
julia> f = ROOTFile("./test/samples/RNTuple/test_ntuple_stl_containers.root");

julia> f["ntuple"]
UnROOT.RNTuple:
  header:
    name: "ntuple"
    ntuple_description: ""
    writer_identifier: "ROOT v6.29/01"
    schema:
      RNTupleSchema with 13 top fields
      ├─ :lorentz_vector ⇒ Struct
      ├─ :vector_tuple_int32_string ⇒ Vector
      ├─ :string ⇒ String
      ├─ :vector_string ⇒ Vector
...
..
.

julia> LazyTree(f, "ntuple")
 Row │ string  vector_int32     array_float      vector_vector_i     vector_string       vector_vector_s     variant_int32_s  vector_variant_     ⋯
     │ String  Vector{Int32}    StaticArraysCor  Vector{Vector{I     Vector{String}      Vector{Vector{S     Union{Int32, St  Vector{Union{In     ⋯
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 1   │ one     [1]              [1.0, 1.0, 1.0]  Vector{Int32}[Int3  ["one"]             [["one"]]           1                Union{Int64, Strin  ⋯
 2   │ two     [1, 2]           [2.0, 2.0, 2.0]  Vector{Int32}[Int3  ["one", "two"]      [["one"], ["two"]]  two              Union{Int64, Strin  ⋯
 3   │ three   [1, 2, 3]        [3.0, 3.0, 3.0]  Vector{Int32}[Int3  ["one", "two", "th  [["one"], ["two"],  three            Union{Int64, Strin  ⋯
 4   │ four    [1, 2, 3, 4]     [4.0, 4.0, 4.0]  Vector{Int32}[Int3  ["one", "two", "th  [["one"], ["two"],  4                Union{Int64, Strin  ⋯
 5   │ five    [1, 2, 3, 4, 5]  [5.0, 5.0, 5.0]  Vector{Int32}[Int3  ["one", "two", "th  [["one"], ["two"],  5                Union{Int64, Strin  ⋯
                                                                                                                                  5 columns omitted
```
"""
struct RNTuple{O}
    io::O
    anchor::ROOT_3a3a_RNTuple
    header::RNTupleHeader
    footer::RNTupleFooter
    pagelinks::Dict{Int, PageLink}
    # protects `pagelinks`: fields read in parallel only hold their own
    # per-thread lock, so the shared page-list cache needs its own
    pagelinks_lock::ReentrantLock
    schema::RNTupleSchema
    function RNTuple(io::O, anchor, header, footer, schema) where {O}
        new{O}(
            io,
            anchor,
            header,
            footer,
            Dict{Int, PageLink}(),
            ReentrantLock(),
            RNTupleSchema(schema),
        )
    end
end

function _length(rn::RNTuple)::Int
    isempty(rn.footer.cluster_group_records) && return 0   # no cluster written yet
    last_record_idx = lastindex(rn.footer.cluster_group_records)
    page_list = _read_page_list(rn, last_record_idx)
    last_cs = page_list.cluster_summaries[end]
    range = _rntuple_clusterrange(last_cs)
    return last(range)
end

function Base.keys(rn::RNTuple)
    String.(propertynames(rn.schema))
end

LazyTree(rn::RNTuple, selection::Union{AbstractString, Regex}) = LazyTree(rn, [selection])
function LazyTree(rn::RNTuple, selection)
    field_names = keys(rn)
    field_names_set = Set(field_names)
    _m(r::Regex) = Base.Fix1(occursin, r)
    filtered_names = String[]
    for b in selection
        if b isa Regex
            append!(filtered_names, filter(_m(b), field_names))
        elseif b isa AbstractString
            b ∈ field_names_set || throw(KeyError("$b is not a field of RNTuple $(rn.header.name), available fields: $(join(field_names, ", "))"))
            push!(filtered_names, String(b))
        else
            error("branch selection must be String or Regex")
        end
    end
    unique!(filtered_names)

    N = Tuple(Symbol.(filtered_names))
    skim_schema = getfield(rn.schema, :namedtuple)[N]
    new_rn =  RNTuple(rn.io, rn.anchor, rn.header, rn.footer, skim_schema)
    T = Tuple(RNTupleField(new_rn, getproperty(new_rn.schema, k)) for k in N)

    return LazyTree(NamedTuple{N}(T))
end
