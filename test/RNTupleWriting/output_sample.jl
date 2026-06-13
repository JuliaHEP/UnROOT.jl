using UnROOT

# Generate a sample RNTuple file together with a JSON sidecar describing the
# exact values written, so an external reader (C++ ROOT, see
# `validate_rntuple.py`) can check both readability and correctness.
#
# Usage:
#   julia output_sample.jl <outfile.root> [compression]
#
# `compression` is a ROOT fCompress code (algorithm*100 + level); it defaults to
# UnROOT's writer default (LZ4). Pass 0 for no compression. The sidecar is
# written next to the output as `<outfile.root>.expected.json`.

const OUTFILE = ARGS[1]
const COMPRESSION = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : UnROOT.RNT_DEFAULT_COMPRESSION

const N = 100   # entries; deliberately repetitive so compression engages

# deterministic, exactly-representable value patterns
sval(i) = ((i - 1) % 21) - 10           # -10 .. 10   (signed ints, floats)
uval(i) = (i - 1) % 11                   #   0 .. 10   (unsigned ints)
veclen(i) = (i - 1) % 6                   #    0 .. 5   (vector lengths)

const SIGNED_PRIMS   = [Float64, Float32, Float16, Int8, Int16, Int32, Int64]
const UNSIGNED_PRIMS = [UInt8, UInt16, UInt32, UInt64]

# ---- build the table (column name => Julia vector) -------------------------
names = String[]
cols  = Any[]
addcol!(name, v) = (push!(names, name); push!(cols, v))

for T in SIGNED_PRIMS
    addcol!("x_$T", T[T(sval(i)) for i in 1:N])
end
for T in UNSIGNED_PRIMS
    addcol!("x_$T", T[T(uval(i)) for i in 1:N])
end
addcol!("x_Bool", Bool[isodd(i) for i in 1:N])
addcol!("x_String", String["s$(uval(i))" for i in 1:N])

for T in SIGNED_PRIMS
    addcol!("x_vec_$T", [T[T(sval(j)) for j in 1:veclen(i)] for i in 1:N])
end
for T in UNSIGNED_PRIMS
    addcol!("x_vec_$T", [T[T(uval(j)) for j in 1:veclen(i)] for i in 1:N])
end

# nested vector to exercise vector<vector<...>>
addcol!("x_vecvec_Int32",
    [[Int32[Int32(k) for k in 1:inner] for inner in 1:((i - 1) % 3)] for i in 1:N])

const RNTUPLE_NAME = "myntuple"
table = NamedTuple{Tuple(Symbol.(names))}(Tuple(cols))

open(OUTFILE, "w") do io
    UnROOT.write_rntuple(io, table; rntuple_name=RNTUPLE_NAME, compression=COMPRESSION)
end

# ---- write the JSON sidecar (hand-rolled, no extra dependency) --------------
leaftype(::Type{T}) where {T} = T
leaftype(::Type{<:AbstractString}) = String
leaftype(::Type{<:AbstractVector{T}}) where {T} = leaftype(T)
isfloatcol(v) = leaftype(eltype(v)) <: AbstractFloat

json_escape(s::AbstractString) = replace(string(s), '\\' => "\\\\", '"' => "\\\"",
                                         '\n' => "\\n", '\t' => "\\t", '\r' => "\\r")

jval(x::Bool) = x ? "true" : "false"
jval(x::Integer) = string(x)
jval(x::AbstractFloat) = string(Float64(x))     # shortest round-trippable form
jval(x::AbstractString) = "\"" * json_escape(x) * "\""
jval(x::AbstractVector) = "[" * join((jval(e) for e in x), ",") * "]"

io = IOBuffer()
print(io, "{\n")
print(io, "  \"ntuple_name\": \"", RNTUPLE_NAME, "\",\n")
print(io, "  \"n_entries\": ", N, ",\n")
print(io, "  \"compression\": ", COMPRESSION, ",\n")
print(io, "  \"columns\": [\n")
for (idx, (name, v)) in enumerate(zip(names, cols))
    print(io, "    {\"name\": \"", name, "\", \"float\": ", isfloatcol(v) ? "true" : "false",
          ", \"values\": ", jval(v), idx == length(names) ? "}\n" : "},\n")
end
print(io, "  ]\n}\n")
write(OUTFILE * ".expected.json", take!(io))

println("wrote $OUTFILE (compression=$COMPRESSION, $(length(names)) columns, $N entries)")
println("wrote $OUTFILE.expected.json")
