using UnROOT
using Test
import Tables
using Tables: columntable

const APPEND_SAMPLES = joinpath(@__DIR__, "..", "samples", "RNTuple")

# every column of a (lazy) table as a plain Vector
_columns(t) = map(collect, columntable(t))
# number of cluster groups of the RNTuple behind a LazyTree
_ngroups(t) = length(first(columntable(t)).rn.footer.cluster_group_records)

@testset "RNTuple appending - recreate / append! / update round trip" begin
    dir = mktempdir()
    p = joinpath(dir, "append.root")
    t1 = (x = Int64[1, 2, 3], y = Float32[1.5, 2.5, 3.5], v = [Int32[1, 2], Int32[3], Int32[]],
          s = ["a", "bb", ""], b = [true, false, true],
          vv = [[Float64[1.0]], Vector{Float64}[], [Float64[], Float64[2.0, 3.0]]])
    t2 = (x = Int64[4, 5], y = Float32[4.5, 5.5], v = [Int32[4, 5, 6], Int32[7]], s = ["dddd", "e"],
          b = [false, false], vv = [[Float64[4.0, 5.0]], [Float64[6.0]]])
    # columns may come in any order
    t3 = (s = ["f"], b = [true], vv = [Vector{Float64}[]], x = Int64[6], v = [Int32[]], y = Float32[6.5])

    f = UnROOT.recreate(p)
    @test isempty(keys(f))
    @test isopen(f)
    f["t"] = t1
    @test keys(f) == ["t"]
    @test haskey(f, "t") && !haskey(f, "u")
    @test f["t"] isa UnROOT.WritableRNTuple
    @test length(f["t"]) == 3
    @test append!(f["t"], t2) === f["t"]
    @test length(f["t"]) == 5
    @test occursin("5 entries", sprint(show, f["t"]))
    @test occursin("1 key: t", sprint(show, f))
    close(f)
    @test !isopen(f)
    @test_throws ErrorException f["t"]      # closed

    lt = LazyTree(p, "t")
    @test length(lt) == 5
    for k in keys(t1)
        @test collect(getproperty(lt, k)) == vcat(t1[k], t2[k])
    end
    # one cluster (and one cluster group) per append
    @test length(lt.x.rn.footer.cluster_group_records) == 2
    @test UnROOT._clusterranges([lt.x]) == [1:3, 4:5]

    UnROOT.update(p) do f
        @test keys(f) == ["t"]
        @test length(f["t"]) == 5
        append!(f["t"], t3)
        @test length(f["t"]) == 6
    end
    lt = LazyTree(p, "t")
    @test length(lt) == 6
    for k in keys(t1)
        @test collect(getproperty(lt, k)) == vcat(t1[k], t2[k], t3[k])
    end
    @test UnROOT._clusterranges([lt.x]) == [1:3, 4:5, 6:6]
    # element access across cluster boundaries and row iteration
    @test lt.s[3] == "" && lt.s[5] == "e" && lt.s[6] == "f"
    @test lt.vv[3] == [Float64[], Float64[2.0, 3.0]] && lt.vv[6] == Vector{Float64}[]
    @test [row.x for row in lt] == 1:6
    # the file header still describes a valid file: one free segment at fEND
    rf = ROOTFile(p)
    @test rf.header.fEND == filesize(p)
    @test rf.header.nfree == 1
    close(rf)
end

@testset "RNTuple appending - several RNTuples, empty RNTuple, mkrntuple" begin
    dir = mktempdir()
    p = joinpath(dir, "multi.root")
    UnROOT.recreate(p; compression=0) do f
        r = UnROOT.mkrntuple(f, "empty", (a = Float64, w = Vector{String}))
        @test r isa UnROOT.WritableRNTuple && length(r) == 0
        f["u"] = (k = UInt8[1, 2, 3],)
        @test keys(f) == ["empty", "u"]
    end
    rf = ROOTFile(p)
    @test sort(keys(rf)) == ["empty", "u"]
    @test length(LazyTree(rf, "empty")) == 0
    @test isempty(collect(LazyTree(rf, "empty").a))
    @test collect(LazyTree(rf, "u").k) == UInt8[1, 2, 3]
    @test rf.header.fCompress == 0
    close(rf)

    UnROOT.update(p) do f
        append!(f["empty"], (a = [1.0, 2.0], w = [["x"], String[]]))
        append!(f["u"], (k = UInt8[4],))
        # a Tables.Schema specification, filled afterwards
        r = UnROOT.mkrntuple(f, "sch", Tables.Schema((:i, :s), (Int16, String)))
        append!(r, (i = Int16[7], s = ["seven"]))
        @test length(r) == 1
    end
    rf = ROOTFile(p)
    @test sort(keys(rf)) == ["empty", "sch", "u"]
    @test collect(LazyTree(rf, "empty").a) == [1.0, 2.0]
    @test collect(LazyTree(rf, "empty").w) == [["x"], String[]]
    @test collect(LazyTree(rf, "u").k) == UInt8[1, 2, 3, 4]
    @test collect(LazyTree(rf, "sch").s) == ["seven"]
    close(rf)
end

@testset "RNTuple appending - errors leave the file intact" begin
    dir = mktempdir()
    p = joinpath(dir, "err.root")
    UnROOT.recreate(p) do f
        f["t"] = (x = Int32[1], s = ["a"])
        @test_throws ArgumentError f["t"] = (x = Int32[2],)                            # name taken
        @test_throws KeyError f["nope"]
        @test_throws ArgumentError append!(f["t"], (x = Int32[1],))                    # missing column
        @test_throws ArgumentError append!(f["t"], (x = Int32[1], s = ["a"], z = [1]))  # extra column
        @test_throws ArgumentError append!(f["t"], (x = Int64[1], s = ["a"]))          # wrong type
        @test_throws ArgumentError append!(f["t"], (x = Int32[1, 2], s = ["a"]))       # ragged
        @test_throws ArgumentError UnROOT.mkrntuple(f, "e", Tables.Schema((), ()))     # no fields
        @test_throws ErrorException UnROOT.mkrntuple(f, "e", 1)                        # not a table
        append!(f["t"], (x = Int32[], s = String[]))                                   # no rows: no-op
        @test length(f["t"]) == 1
    end
    @test_throws ArgumentError UnROOT.create(p)                     # exists already
    @test_throws SystemError UnROOT.update(joinpath(dir, "missing.root"))
    lt = LazyTree(p, "t")
    @test collect(lt.x) == Int32[1] && collect(lt.s) == ["a"]
    @test length(lt.x.rn.footer.cluster_group_records) == 1
end

@testset "RNTuple appending - add an RNTuple to a TTree file" begin
    src = joinpath(@__DIR__, "..", "samples", "tree_with_jagged_array.root")
    p = joinpath(mktempdir(), "tree_plus_rntuple.root")
    cp(src, p)
    before = _columns(LazyTree(src, "t1"))
    UnROOT.update(p) do f
        @test keys(f) == ["t1"]
        @test_throws ArgumentError f["t1"]          # a TTree cannot be written to
        f["rnt"] = (x = [1, 2, 3],)
    end
    rf = ROOTFile(p)
    @test sort(keys(rf)) == ["rnt", "t1"]
    @test collect(LazyTree(rf, "rnt").x) == [1, 2, 3]
    after = _columns(LazyTree(rf, "t1"))
    @test keys(after) == keys(before)
    @test all(k -> after[k] == before[k], keys(before))
    close(rf)
end

@testset "RNTuple appending - files written by ROOT and uproot" begin
    # ROOT-written files use split/zigzag/delta column encodings and, for recent
    # ROOT versions, 64-bit TKeys and a spec 1.0.1 footer
    cases = [
        ("test_ntuple_minimal.root", "myntuple"),                          # ROOT, 32-bit keys
        ("test_ntuple_split_3e4.root", "ntuple"),                          # split columns, 30000 rows
        ("test_ntuple_bit.root", "ntuple"),                                # bit column
        ("test_int_float_rntuple_v1-0-0-0.root", "ntuple"),               # SplitInt32 / SplitReal32
        ("test_index_multicluster_rntuple_v1-0-0-0.root", "ntuple"),      # SplitIndex64 vectors, several clusters
        ("test_multiple_cluster_groups_rntuple_v1-0-0-0.root", "ntuple"),  # 64-bit keys, several cluster groups
        ("test_extension_columns_rntuple_v1-0-0-0.root", "ntuple"),       # deferred (extension) columns
        ("test_splitint_rntuple_v1-0-1-0.root", "ntuple"),                # spec 1.0.1 footer (linked attribute sets)
        ("uproot_written_rntuple_v1-0-0-0.root", "t"),                    # uproot 5.7.6, two cluster groups
    ]
    for (fname, name) in cases
        src = joinpath(APPEND_SAMPLES, fname)
        dst = joinpath(mktempdir(), fname)
        cp(src, dst)
        orig = _columns(LazyTree(src, name))
        n = min(5, length(first(orig)))
        head = map(c -> c[1:n], orig)
        groups_before = _ngroups(LazyTree(src, name))
        UnROOT.update(dst) do f
            append!(f[name], head)
            @test length(f[name]) == length(first(orig)) + n
        end
        back_tree = LazyTree(dst, name)
        @test _ngroups(back_tree) == groups_before + 1
        back = _columns(back_tree)
        for k in keys(orig)
            @test isequal(back[k], vcat(orig[k], head[k]))
        end
    end

    # schemas UnROOT cannot write (struct fields, low-precision floats) are
    # refused before anything is written
    for (fname, name) in [("test_ntuple_stl_containers.root", "ntuple"),
                          ("test_float_types_rntuple_v1-0-0-0.root", "ntuple")]
        src = joinpath(APPEND_SAMPLES, fname)
        dst = joinpath(mktempdir(), fname)
        cp(src, dst)
        orig = _columns(LazyTree(src, name))
        UnROOT.update(dst) do f
            @test_throws Exception append!(f[name], map(c -> c[1:1], orig))
        end
        @test read(dst) == read(src)
    end
end
