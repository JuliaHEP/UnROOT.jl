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
    thread_locks::Vector{ReentrantLock}
    buffer_ranges::Vector{UnitRange{Int64}}
    function RNTupleField(rn::R, field::F) where {R, F}
        O = _field_output_type(F)
        E = eltype(O)
        Nthreads = _maxthreadid()
        buffers = Vector{O}(undef, Nthreads)
        thread_locks = [ReentrantLock() for _ in 1:Nthreads]
        buffer_ranges = [0:-1 for _ in 1:Nthreads]
        new{R, F, O, E}(rn, field, buffers, thread_locks, buffer_ranges)
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
    cluster_summaries = _read_page_list(rn, 1).cluster_summaries
    ranges = map(_rntuple_clusterrange, cluster_summaries)
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

function Base.getindex(rf::RNTupleField, idx::Int)
    tid = Threads.threadid()
    tlock = @inbounds rf.thread_locks[tid]
    Base.@lock tlock begin 
        br = @inbounds rf.buffer_ranges[tid]
        localidx = if idx ∉ br
            _localindex_newcluster!(rf, idx, tid)
        else
            idx - br.start + 1
        end
        return @inbounds rf.buffers[tid][localidx]
    end
end

function _read_page_list(rn, nth=1)
    get!(rn.pagelinks, nth) do
        #TODO add multiple cluster group support
        bytes = _read_envlink(rn.io, rn.footer.cluster_group_records[nth].page_list_link);
        _rntuple_read(IOBuffer(bytes), RNTupleEnvelope{PageLink}).payload
    end
end

function _localindex_newcluster!(rf::RNTupleField, idx::Int, tid::Int)
    page_list =_read_page_list(rf.rn, 1)
    cluster_summaries, nested_page_locations = page_list.cluster_summaries, page_list.nested_page_locations

    for (cluster_idx, cluster) in enumerate(cluster_summaries)
        first_entry = cluster.first_entry_number 
        n_entries = cluster.number_of_entries
        if first_entry + n_entries >= idx
            br = first_entry+1:(first_entry+n_entries)
            @inbounds rf.buffers[tid] = read_field(rf.rn.io, rf.field, nested_page_locations[cluster_idx])
            @inbounds rf.buffer_ranges[tid] = br
            return idx - br.start + 1
        end
    end
    error("$idx-th event not found in cluster summaries")
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
    schema::RNTupleSchema
    function RNTuple(io::O, anchor, header, footer, schema) where {O}
        new{O}(
            io,
            anchor,
            header,
            footer,
            Dict{Int, PageLink}(),
            RNTupleSchema(schema),
        )
    end
end

function _length(rn::RNTuple)::Int
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
    _m(r::Regex) = Base.Fix1(occursin, r)
    filtered_names = mapreduce(∪, selection) do b
        if b isa Regex
            filter(_m(b), field_names)
        elseif b isa String
            [b]
        else
            error("branch selection must be String or Regex")
        end
    end

    N = Tuple(Symbol.(filtered_names))
    skim_schema = getfield(rn.schema, :namedtuple)[N]
    new_rn =  RNTuple(rn.io, rn.anchor, rn.header, rn.footer, skim_schema)
    T = Tuple(RNTupleField(new_rn, getproperty(new_rn.schema, k)) for k in N)

    return LazyTree(NamedTuple{N}(T))
end
