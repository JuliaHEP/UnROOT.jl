using Test
using UnROOT, LorentzVectors
using StaticArrays
using InteractiveUtils
using MD5

const nthreads = Threads.nthreads()
nthreads == 1 && @warn "Running on a single thread. Please re-run the test suite with at least two threads (`julia --threads 2 ...`)"

const SAMPLES_DIR = joinpath(@__DIR__, "samples")


# @stack
struct A
    n::Int32
    m::Int64
end
struct B
    o::Float16
    p
    q::Bool
end
struct C
    r
    s
    t
    u
end
@UnROOT.stack D A B C
expected_fieldnames = (:n, :m, :o, :p, :q, :r, :s, :t, :u)
expected_fieldtypes = [Int32, Int64, Float16, Any, Bool, Any, Any, Any, Any]

@testset "utils" begin
    @test fieldnames(D) == expected_fieldnames
    @test [fieldtype(D, f) for f in fieldnames(D)] == expected_fieldtypes
end

# io.jl
UnROOT.@io struct Foo
    a::Int32
    b::Int64
    c::Float32
    d::SVector{5, UInt8}
end

@testset "@io" begin

    d = SA{UInt8}[1, 2, 3, 4, 5]

    foo = Foo(1, 2, 3, d)

    @test foo.a == 1
    @test foo.b == 2
    @test foo.c ≈ 3
    @test d == foo.d

    @test 32 == sizeof(Foo)
    @test 21 == UnROOT.packedsizeof(Foo)

    buf = IOBuffer(Vector{UInt8}(1:sizeof(Foo)))
    foo = UnROOT.unpack(buf, Foo)

    @test foo.a == 16909060
    @test foo.b == 361984551142689548
    @test foo.c ≈ 4.377526f-31
    @test foo.d == UInt8[0x11, 0x12, 0x13, 0x14, 0x15]
end

struct Bar
    x::Int8
    y::UInt16
end

@testset "io functions" begin
    @test 21 == UnROOT.packedsizeof(Foo)
    @test 3 == UnROOT.packedsizeof(Bar)
end


@testset "Header and Preamble" begin
    fobj = open(joinpath(SAMPLES_DIR, "km3net_online.root"))
    file_preamble = UnROOT.unpack(fobj, UnROOT.FilePreamble)
    @test "root" == String(file_preamble.identifier)

    file_header = UnROOT.unpack(fobj, UnROOT.FileHeader32)
    @test 100 == file_header.fBEGIN
end


@testset "ROOTFile" begin
    @test_throws SystemError ROOTFile("non_existent_fname.root")

    ROOTFile(joinpath(SAMPLES_DIR, "tree_with_histos.root")) do rootfile
        @test 100 == rootfile.header.fBEGIN
        @test 1 == length(rootfile.directory.keys)
        @test "t1" ∈ keys(rootfile)
        @test haskey(rootfile, "t1")
        @test haskey(rootfile.directory, "t1")
        for key in keys(rootfile)
            rootfile[key]
        end
    end

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_custom_struct.root"))
    @test 100 == rootfile.header.fBEGIN
    @test 1 == length(rootfile.directory.keys)
    @test "T" ∈ keys(rootfile)
    for key in keys(rootfile)
        rootfile[key]
    end
    close(rootfile)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "histograms.root"))
    for branch in ["one", "two", "three"]
        @test branch in keys(rootfile)
    end
    close(rootfile)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "km3net_online.root"))
    @test 100 == rootfile.header.fBEGIN
    @test 10 == length(rootfile.directory.keys)
    @test "E" ∈ keys(rootfile)
    @test "META" ∈ keys(rootfile)
    @test "JTRIGGER::JTriggerParameters" ∈ keys(rootfile)
    @test "KM3NET_TIMESLICE" ∈ keys(rootfile)
    @test "KM3NET_TIMESLICE_L0" ∈ keys(rootfile)
    @test "KM3NET_TIMESLICE_L1" ∈ keys(rootfile)
    @test "KM3NET_TIMESLICE_L2" ∈ keys(rootfile)
    @test "KM3NET_TIMESLICE_SN" ∈ keys(rootfile)
    @test "KM3NET_EVENT" ∈ keys(rootfile)
    @test "KM3NET_SUMMARYSLICE" ∈ keys(rootfile)
    # for key in keys(rootfile)
    #     @test !ismissing(rootfile[key])
    # end
    close(rootfile)
end

@testset "readbasketsraw()" begin
    array_md5 = [0xb4, 0xe9, 0x32, 0xe8, 0xfb, 0xff, 0xcf, 0xa0, 0xda, 0x75, 0xe0, 0x25, 0x34, 0x9b, 0xcd, 0xdf]
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "km3net_online.root"))
    data, offsets = UnROOT.array(rootfile, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
    @test array_md5 == md5(data)
    close(rootfile)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array.root"))
    data, offsets = UnROOT.array(rootfile, "t1/int32_array"; raw=true)

    @test data isa Vector{UInt8}
    @test offsets isa Vector{Int32}
    @test data[1:3] == UInt8[0x40, 0x00, 0x00]

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_vector_multiple_baskets.root"))
    data, offsets = UnROOT.array(rootfile, "t1/b1"; raw=true)
    @test unique(diff(offsets)) == [18]
    close(rootfile)
end

@testset "No (basket) compression" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "uncomressed_lz4_int32.root"))
    arr = UnROOT.array(rootfile, "t1/int32_array")
    @test length(arr) == 3
    @test all(arr .== [[1,2], [], [3]])
    close(rootfile)
end

@testset "Uncompressed trees" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue87_uncompressed_a.root"))
    @test LazyTree(rootfile,"Events").Jet_pt ≈ [[27.3245, 24.8896, 20.8534],Float32[],[5.3306]]

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue87_uncompressed_b.root"))
    @test LazyTree(rootfile,"Events").myval[2:5] ≈ [[0.1], [0.2, 1.2], [0.3, 1.3, 2.3], [0.4, 1.4, 2.4, 3.4]]
end

@testset "Compressions" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_large_array_lzma.root"))
    arr = UnROOT.array(rootfile, "t1/float_array")
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    close(rootfile)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_large_array_lz4.root"))
    arr = collect(LazyBranch(rootfile, rootfile["t1/float_array"]))
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    close(rootfile)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_int_array_zstd.root"))
    arr = collect(LazyBranch(rootfile, "t1/a"))
    @test arr == 0:99
    close(rootfile)
end

@testset "ROOTDirectoryHeader" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_histos.root"))
    header = rootfile.directory.header
    @test 5 == header.fVersion
    @test 1697049339 == header.fDatimeC
    @test 1697049339  == header.fDatimeM
    @test 111 == header.fNbytesKeys
    @test 78 == header.fNbytesName
    @test 100 == header.fSeekDir
    @test 0 == header.fSeekParent
    @test 1398 == header.fSeekKeys
    close(rootfile)

    # rootfile = ROOTFile(joinpath(SAMPLES_DIR, "km3net_online.root"))
    # header = rootfile.directory.header
    # @test 5 == header.fVersion
    # @test 1658540644 == header.fDatimeC
    # @test 1658540645 == header.fDatimeM
    # @test 629 == header.fNbytesKeys
    # @test 68 == header.fNbytesName
    # @test 100 == header.fSeekDir
    # @test 0 == header.fSeekParent
    # @test 1619244 == header.fSeekKeys
    # close(rootfile)
end

@testset "Single TObject subclasses" begin
    f = UnROOT.samplefile("triply_jagged_via_custom_class.root")
    # map<string,string>
    head = f["Head"]
    @test 27 == length(f["Head"])
    @test " 3.3" == head["DAQ"]
    @test " CORSIKA 7.640 181111 1211" == head["physics"]
    @test "MUSIC seawater 02-03  190204  1643" == head["propag"]
    close(f)
end

@testset "LazyBranch and LazyTree" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_large_array.root"))
    branch = rootfile["t1"]["int32_array"]
    arr = UnROOT.array(rootfile, branch)
    arr2 = UnROOT.arrays(rootfile, "t1")[1]
    
    @test hash(branch) == hash(rootfile["t1"]["int32_array"])
    @test hash(branch) != hash(rootfile["t1"]["float_array"])
    @test arr == arr2

    table = LazyTree(rootfile, "t1")
    BA = LazyBranch(rootfile, branch)
    @test length(arr) == length(BA)
    @test BA[1] == arr[1]
    @test BA[end] == arr[end]
    @test BA[20:30] == arr[20:30]
    @test BA[1:end] == arr
    @test table.int32_array[20:30] == BA[20:30]
    @test table[:, :int32_array][20:30] == BA[20:30]
    @test table[23, :int32_array] == BA[23]
    @test table[20:30, :int32_array] == BA[20:30]
    @test table[:].int32_array[20:30] == BA[20:30]
    @test [row.int32_array for row in table[20:30]] == BA[20:30]
    @test sum(table.int32_array) == sum(row.int32_array for row in table)
    @test [row.int32_array for row in table] == BA
    
    # do some hardcoded value checks
    bunches = Float32[]
    for i in 1:10
        start = 1 + 1000*(i-1)
        stop = 1000*i
        push!(bunches, sum(table.float_array[start:stop]))
    end
    testvalues = Vector{Float32}([528882.3f0, 1.5877059f6, 2.6465295f6, 3.705353f6, 4.764177f6, 5.823f6, 6.881823f6, 7.9406475f6, 8.999469f6, 1.0058294f7])
    @test bunches ≈ testvalues

    close(rootfile)

    rootfile = UnROOT.samplefile("km3net_offline.root")
    t = LazyTree(rootfile, "E", ["Evt/trks/trks.id", r"Evt/trks/trks.(dir|pos).([xyz])" => s"\1_\2"])
    @test 10 == length(t.Evt_trks_trks_id)
    @test 10 == length(t.dir_x)
    @test 10 == length(t.dir_y)
    @test 10 == length(t.dir_z)
    @test 10 == length(t.pos_x)
    @test 10 == length(t.pos_y)
    @test 10 == length(t.pos_z)
    @test 56 == length(t.pos_z[1])
    @test 68.42717410489223 ≈ t.pos_z[1][5]
    close(rootfile)
end

@testset "TLorentzVector" begin
    # 64bits T
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "TLorentzVector.root"))
    branch = LazyBranch(rootfile, "t1/LV")
    tree = LazyTree(rootfile, "t1")

    @test branch[1].x == 1.0
    @test branch[1].t == 4.0
    @test eltype(branch) === LorentzVectors.LorentzVector{Float64}
    @test tree[1].LV.x == 1.0
    @test tree[1].LV.t == 4.0
    close(rootfile)


    # jagged LVs
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "Jagged_TLorentzVector.root"))
    branch = LazyBranch(rootfile, "t1/LVs")
    tree = LazyTree(rootfile, "t1")

    @test eltype(branch) <: AbstractVector{LorentzVectors.LorentzVector{Float64}}
    @test eltype(branch) <: SubArray
    @test length.(branch[1:10]) == 0:9
    close(rootfile)
end

@testset "TNtuple" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "TNtuple.root"))
    arrs = [collect(LazyBranch(rootfile, "n1/$c")) for c in "xyz"]
    @test length.(arrs) == fill(100, 3)
    @test arrs[1] ≈ 0:99
    @test arrs[2] ≈ arrs[1] .+ arrs[1] ./ 13
    @test arrs[3] ≈ arrs[1] .+ arrs[1] ./ 17
    close(rootfile)
end

@testset "TNtupleD" begin
    ntupled = LazyTree(joinpath(SAMPLES_DIR, "TNtupleD.root"), "n1")
    @test ntupled.x == [0.0, 1.0]
    @test ntupled.y == [0.0, 1.0]
end

@testset "Singly jagged branches" begin
    # 32bits T
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array.root"))
    data = LazyBranch(rootfile, "t1/int32_array")
    @test data[1] == Int32[]
    @test data[1:2] == [Int32[], Int32[0]]
    @test data[end] == Int32[90, 91, 92, 93, 94, 95, 96, 97, 98]
    close(rootfile)

    # 64bits T
    T = Float64
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array_double.root"))
    data = LazyBranch(rootfile, "t1/double_array")
    @test data isa AbstractVector
    @test eltype(data) <: AbstractVector{T}
    @test data[1] == T[]
    @test data[1:2] == [T[], T[0]]
    @test data[end] == T[90, 91, 92, 93, 94, 95, 96, 97, 98]
    close(rootfile)
end

@testset "View" begin
    data = LazyTree(joinpath(SAMPLES_DIR, "tree_with_jagged_array.root"), "t1")
    data[1:2]
    @view data[1:2]
    alloc1 = @allocated v = data[3:90]
    alloc2 = @allocated v = @view data[3:90]
    v = @view data[3:80]
    @test alloc2 < alloc1/100
    @static if VERSION >= v"1.8"
        @test alloc2 < 50
    end
    @test all(v.int32_array .== data.int32_array[3:80])

    v2 = @view data[[1,3,5]]
    @test v2[1].int32_array == data[1].int32_array
    @test v2[2].int32_array == data[3].int32_array
end

@testset "Doubly jagged [var][var] branches" begin
    # this is vector<vector<blah>>
    rootfile = UnROOT.samplefile("tree_with_doubly_jagged.root")
    vvi = [[[2], [3, 5]], [[7, 9, 11], [13]], [[17], [19], []], [], [[]]]
    vvf = [[[2.5], [3.5, 5.5]], [[7.5, 9.5, 11.5], [13.5]], [[17.5], [19.5], []], [], [[]]]
    @test UnROOT.array(rootfile, "t1/bi") == vvi
    @test LazyBranch(rootfile, "t1/bi") == vvi
    @test eltype(eltype(eltype(LazyBranch(rootfile, "t1/bi")))) === Int32
    @test UnROOT.array(rootfile, "t1/bf") == vvf
    @test LazyBranch(rootfile, "t1/bf") == vvf
    @test eltype(eltype(eltype(LazyBranch(rootfile, "t1/bf")))) === Float32
    close(rootfile)
end

@testset "Doubly jagged [var][fix] branches" begin
    # issue #187
    # this is vector<Int[N]>
    f = UnROOT.samplefile("tree_with_varfix_doubly_jagged.root")
    tree = LazyTree(f, "outtree")
    @test tree.nparticles == [4,3,2]
    @test length.(tree.P) == [4,3,2]
    @test eltype(tree.P[1]) <: AbstractVector
    # also compared to uproot
    @test tree[1].P == [
                        [0.9411764705882353, 0.8888888888888888, 0.8421052631578947, 0.8],
                        [1.0, 0.9285714285714286, 0.8666666666666667, 0.8125],
                        [1.1111111111111112, 1.0, 0.9090909090909091, 0.8333333333333334],
                        [1.4, 1.1666666666666667, 1.0, 0.875]
                       ]
    @test tree[3].P == [
                        [0.8222222222222222,
                         0.8043478260869565,
                         0.7872340425531915,
                         0.7708333333333334],
                        [0.8292682926829268,
                         0.8095238095238095,
                         0.7906976744186046,
                         0.7727272727272727]
                       ]
end

@testset "Doubly jagged via custom class" begin
    f = UnROOT.samplefile("triply_jagged_via_custom_class.root")
    b = LazyBranch(f, "E/Evt/w")
    @test 3 == length(b)
    @test [3.3329158e6, 3.6047424e22, 3.1181261e8] ≈ b[1]
    @test [3.3329158e6, 2.4039883e23, 4.5337845e6] ≈ b[2]
    @test [3.3329158e6, 4.9458148e24, 42805.383] ≈ b[3]
    close(f)
end

@testset "Triply jagged stuff via custom class" begin
    f = UnROOT.samplefile("triply_jagged_via_custom_class.root")
    b = LazyBranch(f, "E/Evt/trks/trks.rec_stages")
    @test 3 == length(b)
    @test 38 == length(b[3])
    @test 5 == length(b[3][1])
    @test [1, 2, 3, 4, 5] == b[2][1]
    b = LazyBranch(f, "E/Evt/trks/trks.fitinf")
    @test 3 == length(b)
    @test 38 == length(b[3])
    @test 17 == length(b[3][1])
    @test b[3][1] ≈ [
        0.02175229704756278, 0.013640169301181978, -27.59387722710992, 45.0,
        90072.00780343144, 52.67760965729974, 3.9927948910593525, 10.0,
        0.3693832125931179, 0.3693832125931179, 72.02530060292972, 0.0, 0.0,
        13461.937901498717, -Inf, 1518.0, 56.0,
    ]
    close(f)
end

@testset "NanoAOD" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root"))
    event = UnROOT.array(rootfile, "Events/event")
    @test event[1:3] == UInt64[12423832, 12423821, 12423834]
    Electron_dxy = LazyBranch(rootfile, "Events/Electron_dxy")
    @test eltype(Electron_dxy) == SubArray{Float32, 1, Vector{Float32}, Tuple{UnitRange{Int64}}, true}
    @test Electron_dxy[1:3] ≈ [Float32[0.0003705], Float32[-0.00981903], Float32[]]
    HLT_Mu3_PFJet40 = UnROOT.array(rootfile, "Events/HLT_Mu3_PFJet40")
    @test eltype(HLT_Mu3_PFJet40) == Bool
    @test HLT_Mu3_PFJet40[1:3] == [false, true, false]
    tree = LazyTree(rootfile, "Events", [r"Muon_(pt|eta|phi)$", "Muon_charge", "Muon_pt"])
    @test sort(propertynames(tree) |> collect) == sort([:Muon_pt, :Muon_eta, :Muon_phi, :Muon_charge])
    @test sort(names(tree)) == [String(x) for x in sort([:Muon_pt, :Muon_eta, :Muon_phi, :Muon_charge])]
    tree = LazyTree(rootfile, "Events", r"Muon_(pt|eta)$")
    @test sort(propertynames(tree) |> collect) == sort([:Muon_pt, :Muon_eta])
    @test occursin("LazyEvent", repr(first(iterate(tree))))
    @test sum(LazyBranch(rootfile, "Events/HLT_Mu3_PFJet40")) == 443
    close(rootfile)
end

@testset "Branch filtering" begin
    # Branch selection behavior: if not regex, require exact name match
    treebranches = ["Muon_pt", "Muon_eta", "Muon_phi", "Muon_charge", "Muon_ptErr",
                   "Muon_", "_pt", "Muon.pt"]
    _m(s::AbstractString) = isequal(s)
    _m(r::Regex) = Base.Fix1(occursin, r)
    filter_branches(selected) = Set(mapreduce(b->filter(_m(b), treebranches), ∪, selected))
    @test (filter_branches([r"Muon_(pt|eta|phi)$", "Muon_charge", "Muon_pt"]) ==
           Set(["Muon_pt", "Muon_eta", "Muon_phi", "Muon_charge"]))
    @test filter_branches(["Muon_pt"]) == Set(["Muon_pt"])
    @test filter_branches(["Muon.pt"]) == Set(["Muon.pt"])
end

@testset "Displaying files" begin
    files = filter(x->endswith(x, ".root"), readdir(SAMPLES_DIR))
    _io = IOBuffer()
    for f in files
        r = ROOTFile(joinpath(SAMPLES_DIR, f))
        show(_io, r)
        close(r)
    end

    # test that duplicate trees (but different cycle numbers)
    # are only displayed once, and that histograms show up
    f = UnROOT.samplefile("tree_cycles_hist.root")
    @test length(collect(eachmatch(r"Events", repr(f)))) == 1
    @test length(collect(eachmatch(r"myTH2F", repr(f)))) == 1
    close(f)
end

@testset "Displaying trees" begin
    f = UnROOT.samplefile("NanoAODv5_sample.root")
    t = LazyTree(f, "Events", ["nMuon","MET_pt","Muon_pt"])
    _io = IOBuffer()
    show(_io, t)
    show(_io, t[1:10])
    show(_io, t.Muon_pt)
    show(_io, t.Muon_pt[1:10])
    s = repr(t[1:10])
    @test length(collect(eachmatch(r"Float32\[", s))) == 0
    _io = IOBuffer()
    show(_io, t)
    _iostring = String(take!(_io))
    @test length(split(_iostring,'\n')) > length(t)
    @test occursin("───────", _iostring)
    @test !occursin("NamedTuple", _iostring)
    show(_io, t; crop=:both)
    @test length(split(String(take!(_io)),'\n')) <= Base.displaysize()[1]
    _io = IOBuffer()
    show(_io, MIME"text/html"(), t)
    _iostring = String(take!(_io))
    @test occursin("</table>", _iostring)

    # test show a single LazyBranch
    _io = IOBuffer()
    show(_io, MIME"text/plain"(), t.nMuon)
    _iostring = String(take!(_io))
    @test occursin("LazyBranch{", _iostring)
    @test occursin("0x00000000", _iostring)
    close(f)
end

# Custom bootstrap things

@testset "custom boostrapping" begin
    # manual interpretation (splitting)
    f_manual = ROOTFile(joinpath(SAMPLES_DIR, "km3net_online.root"))

    data, offsets = UnROOT.array(f_manual, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"; raw=true)
    headers_manual = UnROOT.splitup(data, offsets, UnROOT._KM3NETDAQEventHeader; jagged=false)

    data, offsets = UnROOT.array(f_manual, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
    event_hits_manual = UnROOT.splitup(data, offsets, UnROOT._KM3NETDAQHit; skipbytes=10)

    data, offsets = UnROOT.array(f_manual, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits"; raw=true)
    event_thits_manual = UnROOT.splitup(data, offsets, UnROOT._KM3NETDAQTriggeredHit; skipbytes=10)

    close(f_manual)  # we can close, everything is in memory

    # automatic interpretation
    customstructs = Dict(
            "KM3NETDAQ::JDAQEvent.snapshotHits" => Vector{UnROOT._KM3NETDAQHit},
            "KM3NETDAQ::JDAQEvent.triggeredHits" => Vector{UnROOT._KM3NETDAQTriggeredHit},
            "KM3NETDAQ::JDAQEvent.KM3NETDAQ::JDAQEventHeader" => UnROOT._KM3NETDAQEventHeader
    )
    f_auto = UnROOT.ROOTFile(joinpath(SAMPLES_DIR, "km3net_online.root"), customstructs=customstructs)
    headers_auto = LazyBranch(f_auto, "KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader")
    event_hits_auto = LazyBranch(f_auto, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits")
    event_thits_auto = LazyBranch(f_auto, "KM3NET_EVENT/KM3NET_EVENT/triggeredHits")

    for event_hits ∈ [event_hits_manual, event_hits_auto]
        @test length(event_hits) == 3
        @test length(event_hits[1]) == 96
        @test length(event_hits[2]) == 124
        @test length(event_hits[3]) == 78
        @test event_hits[1][1].dom_id == 806451572
        @test event_hits[1][1].tdc == 30733918
        @test event_hits[1][end].dom_id == 809544061
        @test event_hits[1][end].tdc == 30735112
        @test event_hits[3][1].dom_id == 806451572
        @test event_hits[3][1].tdc == 63512204
        @test event_hits[3][end].dom_id == 809544061
        @test event_hits[3][end].tdc == 63512892
    end
    for event_thits ∈ [event_thits_manual, event_thits_auto]
        @test length(event_thits) == 3
        @test length(event_thits[1]) == 18
        @test length(event_thits[2]) == 53
        @test length(event_thits[3]) == 9
        @test event_thits[1][1].dom_id == 806451572
        @test event_thits[1][1].tdc == 30733918
        @test event_thits[1][end].dom_id == 808972598
        @test event_thits[1][end].tdc == 30733192
        @test event_thits[3][1].dom_id == 808447186
        @test event_thits[3][1].tdc == 63511558
        @test event_thits[3][end].dom_id == 809526097
        @test event_thits[3][end].tdc == 63511708
    end

    for headers ∈ [headers_manual, headers_auto]
        @test length(headers) == 3
        for header in headers
            @test header.run == 6633
            @test header.detector_id == 44
            @test header.UTC_seconds == 0x5dc6018c
        end
        @test headers[1].frame_index == 127
        @test headers[2].frame_index == 127
        @test headers[3].frame_index == 129
        @test headers[1].UTC_16nanosecondcycles == 0x029b9270
        @test headers[2].UTC_16nanosecondcycles == 0x029b9270
        @test headers[3].UTC_16nanosecondcycles == 0x035a4e90
        @test headers[1].trigger_counter == 0
        @test headers[2].trigger_counter == 1
        @test headers[3].trigger_counter == 0
        @test headers[1].trigger_mask == 22
        @test headers[2].trigger_mask == 22
        @test headers[3].trigger_mask == 4
        @test headers[1].overlays == 6
        @test headers[2].overlays == 21
        @test headers[3].overlays == 0
    end

    close(f_auto)
end

# Histograms
@testset "histograms" begin
    f = ROOTFile(joinpath(SAMPLES_DIR, "histograms1d2d.root"))
    for k in ["myTH1F", "myTH1D"]
        @test f[k][:fName] == k
        @test f[k][:fEntries] == 4.0
        @test f[k][:fSumw2] == [0.0, 800.0, 2.0, 0.0]
        @test f[k][:fXaxis_fXmin] == -2.0
        @test f[k][:fXaxis_fXmax] == 2.0
        @test f[k][:fXaxis_fXbins] == []
        @test f[k][:fXaxis_fNbins] == 2
        @test f[k][:fN] == [0.0, 40.0, 2.0, 0.0]
    end

    k = "myTH1D_nonuniform"
    @test f[k][:fName] == k
    @test f[k][:fEntries] == 4.0
    @test f[k][:fSumw2] == [0.0, 800.0, 2.0, 0.0]
    @test f[k][:fXaxis_fXmin] == -2.0
    @test f[k][:fXaxis_fXmax] == 2.0
    @test f[k][:fXaxis_fXbins] == [-2, 1, 2]
    @test f[k][:fXaxis_fNbins] == 2
    @test f[k][:fN] == [0.0, 40.0, 2.0, 0.0]

    for k in ["myTH2F", "myTH2D"]
        @test f[k][:fName] == k
        @test f[k][:fEntries] == 4.0
        @test f[k][:fSumw2] == [0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test f[k][:fXaxis_fXmin] == -2.0
        @test f[k][:fXaxis_fXmax] == 2.0
        @test f[k][:fXaxis_fXbins] == []
        @test f[k][:fXaxis_fNbins] == 2
        @test f[k][:fYaxis_fXmin] == -2.0
        @test f[k][:fYaxis_fXmax] == 2.0
        @test f[k][:fYaxis_fXbins] == []
        @test f[k][:fYaxis_fNbins] == 4
        @test f[k][:fN] == [0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    end

    @test UnROOT.parseTH(f["myTH1F"]) == ([40.0, 2.0], (-2.0:2.0:2.0,), [800.0, 2.0])
    @test UnROOT.parseTH(f["myTH2D"]) == ([20.0 0.0 0.0 20.0; 1.0 0.0 0.0 1.0], (-2.0:2.0:2.0, -2.0:1.0:2.0), [400.0 0.0 0.0 400.0; 1.0 0.0 0.0 1.0])
    @test UnROOT.parseTH(f["myTH1D_nonuniform"]) == ([40.0, 2.0], ([-2.0, 1.0, 2.0],), [800.0, 2.0])

    close(f)

    f = ROOTFile(joinpath(SAMPLES_DIR, "TH2_5.root"))
    h = UnROOT.TH2F(f.fobj, f.directory.keys[1], f.streamers.refs)
        @test h[:fName] == "myTH2F"
        @test h[:fEntries] == 4.0
        @test h[:fSumw2] == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test h[:fXaxis_fXmin] == -2.0
        @test h[:fXaxis_fXmax] == 2.0
        @test h[:fXaxis_fXbins] == []
        @test h[:fXaxis_fNbins] == 4
        @test h[:fYaxis_fXmin] == -2.0
        @test h[:fYaxis_fXmax] == 2.0
        @test h[:fYaxis_fXbins] == []
        @test h[:fYaxis_fNbins] == 4
        @test h[:fN] == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    close(f)

    f = ROOTFile(joinpath(SAMPLES_DIR, "cms_ntuple_wjet.root"))
    binlabels = ["Root", "Weight", "Preselection", "SelectGenPart", "GoodRunsList", "EventFilters", "SelectLeptons", "SelectJets", "Trigger", "ObjectsSelection", "SSPreselection", "NjetGeq4", "AK4CategTagHiggsJets", "AK4CategTagVBSJets", "AK4CategChannels", "AK4CategPresel"]
    @test f["AK4CategPresel_cutflow"][:fXaxis_fModLabs].objects == binlabels
    close(f)
end


# Issues

@testset "issues" begin
    rootfile = UnROOT.samplefile("issue7.root")
    @test 2 == length(keys(rootfile))
    @test [1.0, 2.0, 3.0] == UnROOT.array(rootfile, "TreeD/nums")
    @test [1.0, 2.0, 3.0] == UnROOT.array(rootfile, "TreeF/nums")
    close(rootfile)

    # issue #55 and #156
    rootfile = UnROOT.samplefile("cms_ntuple_wjet.root")
    pts1 = UnROOT.array(rootfile, "variable/met_p4/fCoordinates/fCoordinates.fPt"; raw=false)
    pts2 = LazyTree(rootfile, "variable", [r"met_p4/fCoordinates/.*", "mll"])[!, Symbol("met_p4_fPt")]
    pts3 = LazyBranch(rootfile, "variable/good_jets_p4/good_jets_p4.fCoordinates.fPt")
    @test 24 == length(pts1)
    @test Float32[69.96958, 25.149912, 131.66693, 150.56802] == pts1[1:4]
    @test pts1 == pts2
    @test pts3[1:2] == [[454.0, 217.5, 89.5, 30.640625], [184.375, 33.28125, 32.28125, 28.46875]]
    close(rootfile)

    # issue 61
    rootfile = UnROOT.samplefile("issue61.root")
    @test LazyBranch(rootfile, "Events/Jet_pt")[:] == Vector{Float32}[[], [27.324587, 24.889547, 20.853024], [], [20.33066], [], []]
    close(rootfile)

    # issue 78
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue61.root"))
    arr = LazyTree(rootfile,"Events").Jet_pt;
    _ = length.(arr);
    @test length.(arr.buffer) == length.(arr.buffer_range)
    close(rootfile)

    # issue 108
    # unsigned short -> Int16, ulong64 -> UInt64
    # file minified with `rooteventselector --recreate -l 2 "trackntuple.root:trackingNtuple/tree" issue108_small.root`
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue108_small.root"))
    @test LazyBranch(rootfile, "tree/trk_algoMask")[2] == [0x0000000000004000, 0x0000000000004000, 0x0000000000004000, 0x0000000000004000]
    @test LazyBranch(rootfile, "tree/pix_ladder")[3][1:5] == UInt16[0x0001, 0x0001, 0x0001, 0x0001, 0x0003]
    close(rootfile)

    # issue 116
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue116.root"))
    @test length(rootfile["fTree"].fBranches.elements) == 112
    close(rootfile)

    # issue 246
    arr = LazyTree(joinpath(SAMPLES_DIR, "issue246.root"), "tree_NOMINAL").v_mcGenWgt
    @test all(reduce(vcat, arr) .== 1.0)
end

@testset "jagged subbranch type by leaf" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "km3net_offline.root"))
    times = UnROOT.array(rootfile, "E/Evt/trks/trks.t")
    @test times[1][1] ≈ 7.0311446e7
    @test times[10][11] ≈ 5.4956456e7

    ids_jagged = UnROOT.array(rootfile, "E/Evt/trks/trks.id")
    @test all(ids_jagged[1] .== collect(1:56))
    @test all(ids_jagged[9] .== collect(1:54))

    close(rootfile)
end

@testset "Type stability" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root"))
    t = LazyTree(rootfile, "Events", ["MET_pt"])[1:10]

    function f1()
        s = 0.0f0
        for evt in t
            s += evt.MET_pt
        end
        s
    end
    f2() = sum(t.MET_pt)

    @inferred f1()
    @inferred f2()

    close(rootfile)
end


@testset "Parallel and enumerate interface" begin
    t = LazyTree(ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root")), "Events", ["Muon_pt"])
    @test eachindex(enumerate(t)) == eachindex(t)
    nmu = 0
    for evt in t
        nmu += length(evt.Muon_pt)
    end
    @test nmu == 878

    nmu = 0
    for (i,evt) in enumerate(t)
        nmu += length(evt.Muon_pt)
    end
    @test nmu == 878


    if get(ENV, "CI", "false") == "true"
        if nthreads >= 1
            @test Threads.nthreads()>1 
        else
            @warn "CI wasn't run with multi thread"
        end
    end
    nmus = zeros(Int, Threads.nthreads())
    Threads.@threads for i in 1:length(t)
        nmus[Threads.threadid()] += length(t.Muon_pt[i])
    end
    @test sum(nmus) == 878

    et = enumerate(t)
    @test firstindex(et) == firstindex(t)
    @test lastindex(et) == lastindex(t)
    test_i, test_evt = et[2]
    @test test_i == 2
    @test test_evt isa UnROOT.LazyEvent
    @test !isempty(hash(t.Muon_pt.b))
end

t = LazyTree(ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root")), "Events", ["Muon_pt"])
@testset "Multi threading" begin
    nmus = zeros(Int, nthreads)
    Threads.@threads for (i, evt) in enumerate(t)
        nmus[Threads.threadid()] += length(t.Muon_pt[i])
    end
    @test sum(nmus) == 878

    nmus .= 0
    Threads.@threads for evt in t
        nmus[Threads.threadid()] += length(evt.Muon_pt)
    end
    if nthreads > 1
        @test count(>(0), nmus) > 1# test @threads is actually threading
    end
    @test sum(nmus) == 878


    nmus .= 0
    Threads.@threads for evt in t
        nmus[Threads.threadid()] += length(evt.Muon_pt)
    end
    if nthreads > 1
        @test count(>(0), nmus) > 1
    end
    @test sum(nmus) == 878

    nmus .= 0
    t_dummy = LazyTree(ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root")), "Events", ["Muon_pt"])
    chained_tree = vcat(t,t_dummy)
    Threads.@threads for evt in chained_tree # avoid using the same underlying file handler
        nmus[Threads.threadid()] += length(evt.Muon_pt)
    end
    @test sum(nmus) == 2*878
    @test mapreduce(length, +, [t,t_dummy]) == length(t) + length(t_dummy)

    for j in 1:3
        inds = [Vector{Int}() for _ in 1:nthreads]
        Threads.@threads for (i, evt) in enumerate(t)
            push!(inds[Threads.threadid()], i)
        end
        @test sum([length(inds[i] ∩ inds[j]) for i=1:length(inds), j=1:length(inds) if j>i]) == 0
    end
end

@testset "TDirectory" begin
    f = UnROOT.samplefile("tdir_complicated.root")
    @test length(keys(f["mydir"])) == 4
    @test sort(keys(f["mydir"])) == ["Events", "c", "d", "mysubdir"]
    @test sort(keys(f["mydir/mysubdir"])) == ["e", "f"]
    @test sum(length.(LazyTree(f, "mydir/Events").Jet_pt)) == 4
    @test sum(length.(LazyBranch(f, "mydir/Events/Jet_pt"))) == 4

    f = UnROOT.samplefile("issue11_tdirectory.root")
    @test sum(LazyBranch(f, "Data/mytree/Particle0_E")) ≈ 1012.0
end

@testset "TBaskets in TTree" begin
    f = UnROOT.samplefile("tree_with_tbaskets_from_uproot-issue327.root")
    close(f)
end

@testset "Basic C++ types" begin
    f = UnROOT.samplefile("tree_basictypes.root")
    onesrow = LazyTree(f,"t")[2] |> collect |> values .|> first .|> Int
    @test all(onesrow .== 1)
end

@testset "C-array types" begin
    tree = LazyTree(UnROOT.samplefile("issue165_multiple_baskets.root"), "arrays")
    ele = tree.carr[3]
    @test length(tree.carr) == 3
    @test length(ele) == 9
    @test eltype(ele) == Float64
    @test length(typeof(ele)) == 9
    @test all(ele .≈ 
            [0.7775048011809144, 0.8664217530127716, 0.4918492038230641, 
             0.24464299401484568, 0.38991686533667, 0.15690925771226608, 
             0.3850047958013624, 0.9268160513261408, 0.9298329730191421])
    @test all(ele .== [ele...])
end

@testset "C vector{string}" begin
    tree = LazyTree(UnROOT.samplefile("tree_with_vector_string.root"), "t1")
    @test length(tree.vs) == 3
    @test tree.vs[1] == ["ab"]
    @test tree.vs[2] == ["bcc", "cdd"]
    @test tree.vs[3] == ["Weight", "MEWeight", "WeightNormalisation", "NTrials", "UserHook", "MUR0.5_MUF0.5_PDF303200_PSMUR0.5_PSMUF0.5", "ME_ONLY_MUR0.5_MUF0.5_PDF303200_PSMUR0.5_PSMUF0.5", "MUR0.5_MUF1_PDF303200_PSMUR0.5_PSMUF1", "ME_ONLY_MUR0.5_MUF1_PDF303200_PSMUR0.5_PSMUF1", "MUR1_MUF0.5_PDF303200_PSMUR1_PSMUF0.5"]
end

@testset "basketarray_iter()" begin
    f = UnROOT.samplefile("tree_with_vector_multiple_baskets.root")
    t = LazyTree(f,"t1")
    @test (UnROOT.basketarray_iter(f, f["t1"]["b1"]) .|> length) == [1228, 1228, 44]
    @test (UnROOT.basketarray_iter(t.b1) .|> length) == [1228, 1228, 44]
    @test length(UnROOT.basketarray(t.b1, 1)) == 1228
end

@testset "SourceStream remote" begin
    r = ROOTFile("root://eospublic.cern.ch//eos/root-eos/cms_opendata_2012_nanoaod/Run2012B_DoubleMuParked.root")
    @test r["Events"].fEntries == 29308627
    show(devnull, r) # test display

    t = LazyTree("https://scikit-hep.org/uproot3/examples/Zmumu.root", "events")
    @test t.eta1[1] ≈ -1.21769
    @test t.eta1[end] ≈ -1.57044
    show(devnull, t) # test display
end

@testset "Cluster ranges" begin
    t = LazyTree(UnROOT.samplefile("tree_with_clusters.root"),"t1");
    @test all(UnROOT._clusterbytes(t; compressed=true) .< 10000)
    @test all(UnROOT._clusterbytes(t; compressed=false) .< 10000)
    @test UnROOT._clusterbytes([t.b1,t.b2]) == UnROOT._clusterbytes(t)
    @test length(UnROOT._clusterranges([t.b1])) == 157
    @test length(UnROOT._clusterranges([t.b2])) == 70
    @test length(UnROOT._clusterranges(t)) == 18 # same as uproot4
    @test sum(UnROOT._clusterbytes([t.b1]; compressed=true)) == 33493.0 # same as uproot4
    @test sum(UnROOT._clusterbytes([t.b2]; compressed=true)) == 23710.0 # same as uproot4
end

@testset "vcat/chaining" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root"))
    t = LazyTree(rootfile, "Events", ["nMuon", "Muon_pt"])
    tt = UnROOT.chaintrees([t,t])
    @test all(vcat(t, t).Muon_pt .== tt.Muon_pt)
    @static if VERSION >= v"1.7"
        @test (@allocated UnROOT.chaintrees([t,t])) < 1000
    end
    @test length(tt) == 2*length(t)
    s1 = sum(t.nMuon)
    s2 = sum(tt.nMuon)
    @test s2 == 2*s1
    alloc1 = @allocated sum(length, t.Muon_pt)
    alloc2 = @allocated sum(evt->length(evt.Muon_pt), tt)
    @test alloc2 < 2.1 * alloc1
    close(rootfile)
end

@testset "Broadcast fusion" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root"))
    t = LazyTree(rootfile, "Events", "nMuon")
    @test t[2] == t[CartesianIndex(2)]
    testf(evt) = evt.nMuon == 4
    testf2(evt) = evt.nMuon == 4
    # precompile
    testf.(t)
    testf2.(t)
    findall(@. testf(t) & testf2(t))
    ##########
    alloc1 = @allocated a1 = testf.(t)
    alloc1 += @allocated a2 = testf2.(t)
    alloc1 += @allocated idx1 = findall(a1 .& a2)
    alloc2 = @allocated idx2 = findall(@. testf(t) & testf2(t))
    @assert !isempty(idx1)
    @test idx1 == idx2
    @test alloc1 > 1.9*alloc2
end

@testset "Objects on top level" begin
    rootfile = UnROOT.samplefile("TVectorT-double_on_top_level.root")
    @test [1.1, 2.2, 3.3] == rootfile["vector_double"]
end

@testset "Test vector<string>" begin
    rootfile = UnROOT.samplefile("usr-sample.root")
    names = LazyBranch(rootfile, "E/Evt/AAObject/usr_names")
    for n in names
        @test all(n .== ["RecoQuality", "RecoNDF", "CoC", "ToT", "ChargeAbove", "ChargeBelow", "ChargeRatio", "DeltaPosZ", "FirstPartPosZ", "LastPartPosZ", "NSnapHits", "NTrigHits", "NTrigDOMs", "NTrigLines", "NSpeedVetoHits", "NGeometryVetoHits", "ClassficationScore"])
    end
end

function _test_clean_GC()
    fname = joinpath(SAMPLES_DIR, "tree_with_large_array_lzma.root")

    for i in 1:5
        f = ROOTFile(fname)
        t = LazyTree(f, "t1")
        f = t = nothing
    end
end

@testset "Clean GC issue #260" begin
    _test_clean_GC()
    GC.gc()
    GC.gc()
    sleep(2)
    GC.gc()
    sleep(2)

    pid = last(readlines(`pgrep julia`))
    @test isempty(filter(contains("_lzma"), readlines("/proc/$pid/smaps")))
end

include("rntuple_tests.jl")
