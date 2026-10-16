# Cross-check UnROOT's RNTuple reading against uproot.
#
# This is a development tool, not part of the test suite. It needs `uproot`,
# `awkward` and (optionally) `scikit-hep-testdata` on the Python side and the
# `JSON` package in the Julia environment.
#
#   python dump_uproot.py file.root file.json 300      # first 300 entries of every field
#   julia --project=<env with UnROOT and JSON> compare_uproot.jl file.root file.json 300
#
# Every field is compared entry by entry (floats with a relative tolerance);
# a field whose dotted name is a sub-field of a struct that UnROOT exposes as a
# whole (e.g. `my_struct.i`) is skipped.
# Compare UnROOT's RNTuple reading against a uproot JSON dump produced by dump_uproot.py
using UnROOT, JSON, StaticArrays, StructArrays
norm(x::AbstractString) = String(x)
norm(x::Bool) = x
norm(x::Integer) = Int64(x)   # may overflow for UInt64 > typemax(Int64); handled below
norm(x::UInt64) = x > typemax(Int64) ? Float64(x) : Int64(x)
norm(x::AbstractFloat) = Float64(x)
norm(x::AbstractVector) = [norm(e) for e in x]
norm(x::NamedTuple) = Dict{String,Any}(String(k) => norm(v) for (k, v) in pairs(x))
norm(x::Char) = string(x)
norm(x::Missing) = nothing
norm(x::Nothing) = nothing
norm(x) = x

jnorm(x::Vector) = [jnorm(e) for e in x]
jnorm(x::AbstractDict) = Dict{String,Any}(k => jnorm(v) for (k, v) in x)
jnorm(x::Integer) = Int64(x)
jnorm(x::AbstractFloat) = Float64(x)
jnorm(x::Bool) = x
jnorm(x) = x

# tolerant equality: floats compared with isequal (NaN==NaN) and approx, nested recursively
same(a::Float64, b::Float64) = isequal(a, b) || (isfinite(a) && isfinite(b) && isapprox(a, b; rtol=1e-6, atol=1e-30))
same(a::Float64, b::Integer) = same(a, Float64(b))
same(a::Integer, b::Float64) = same(Float64(a), b)
same(a::Bool, b::Bool) = a == b
same(a::Bool, b::Integer) = Int(a) == b
same(a::Integer, b::Bool) = a == Int(b)
same(a::Vector, b::Vector) = length(a) == length(b) && all(same(x, y) for (x, y) in zip(a, b))
same(a::Dict, b::Dict) = keys(a) == keys(b) && all(same(a[k], b[k]) for k in keys(a))
same(a::Dict, b::Vector) = same(collect(values(a)), b)  # tuple-like
same(a, b) = isequal(a, b)

function compare(path, jsonpath, N)
    up = JSON.parsefile(jsonpath; allownan=true)
    f = ROOTFile(path)
    nbad = 0
    for (tname, d) in up
        rn = f[tname]
        t = LazyTree(f, tname)
        ne = d["num_entries"]
        if length(t) != ne
            println("  [$tname] LENGTH MISMATCH: unroot=$(length(t)) uproot=$ne"); nbad += 1
        end
        for (fname, uval) in d["fields"]
            sym = Symbol(fname)
            if !(sym in propertynames(t)) && occursin('.', fname) && Symbol(first(split(fname, '.'))) in propertynames(t)
                continue  # sub-field of a struct we expose whole
            end
            if !(sym in propertynames(t))
                println("  [$tname] field '$fname' missing in UnROOT (have $(propertynames(t)))"); nbad += 1
                continue
            end
            col = getproperty(t, sym)
            n = Int(min(N, ne))
            ours = try
                norm(collect(col[1:n]))
            catch e
                println("  [$tname] '$fname' UnROOT ERROR: ", sprint(showerror, e)[1:min(end, 300)]); nbad += 1
                continue
            end
            theirs = jnorm(uval)
            if !same(ours, theirs)
                nbad += 1
                println("  [$tname] '$fname' MISMATCH")
                for i in 1:min(n, length(theirs))
                    if i > length(ours) || !same(ours[i], theirs[i])
                        println("     first diff at entry $i: ours=", repr(i <= length(ours) ? ours[i] : "<missing>")[1:min(end,200)], " theirs=", repr(theirs[i])[1:min(end,200)])
                        break
                    end
                end
            end
        end
        for (fname, err) in d["errors"]
            println("  [$tname] uproot itself failed on '$fname': $err")
        end
    end
    return nbad
end

if abspath(PROGRAM_FILE) == @__FILE__
    path, jsonpath, N = ARGS[1], ARGS[2], parse(Int, get(ARGS, 3, "300"))
    println("== ", basename(path))
    nbad = compare(path, jsonpath, N)
    println(nbad == 0 ? "  ALL OK" : "  $nbad problems")
    exit(nbad == 0 ? 0 : 1)
end
