using Test
using UnROOT, LorentzVectors
using StaticArrays
using InteractiveUtils
using MD5

@static if VERSION > v"1.5.0"
    import Pkg
    Pkg.add("Polyester")
    using ThreadsX, Polyester
end

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
    ROOTFile(joinpath(SAMPLES_DIR, "tree_with_histos.root")) do rootfile
        @test 100 == rootfile.header.fBEGIN
        @test 1 == length(rootfile.directory.keys)
        @test "t1" ∈ keys(rootfile)
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
    @test rootfile isa ROOTFile
    arr = UnROOT.array(rootfile, "t1/float_array")
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    close(rootfile)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_large_array_lz4.root"))
    arr = collect(rootfile["t1/float_array"])
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    close(rootfile)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_int_array_zstd.root"))
    arr = collect(rootfile["t1/a"])
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
    close(rootfile)
end

@testset "TLorentzVector" begin
    # 64bits T
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "TLorentzVector.root"))
    branch = rootfile["t1/LV"]
    tree = LazyTree(rootfile, "t1")

    @test branch[1].x == 1.0
    @test branch[1].t == 4.0
    @test eltype(branch) === LorentzVectors.LorentzVector{Float64}
    @test tree[1].LV.x == 1.0
    @test tree[1].LV.t == 4.0
    close(rootfile)


    # jagged LVs
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "Jagged_TLorentzVector.root"))
    branch = rootfile["t1/LVs"]
    tree = LazyTree(rootfile, "t1")

    @test eltype(branch) <: AbstractVector{LorentzVectors.LorentzVector{Float64}}
    @test eltype(branch) <: SubArray
    @test length.(branch[1:10]) == 0:9
    close(rootfile)
end

@testset "TNtuple" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "TNtuple.root"))
    arrs = [collect(rootfile["n1/$c"]) for c in "xyz"]
    @test length.(arrs) == fill(100, 3)
    @test arrs[1] ≈ 0:99
    @test arrs[2] ≈ arrs[1] .+ arrs[1] ./ 13
    @test arrs[3] ≈ arrs[1] .+ arrs[1] ./ 17
    close(rootfile)
end

@testset "Singly jagged branches" begin
    # 32bits T
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array.root"))
    data = rootfile["t1/int32_array"]
    @test data[1] == Int32[]
    @test data[1:2] == [Int32[], Int32[0]]
    @test data[end] == Int32[90, 91, 92, 93, 94, 95, 96, 97, 98]
    close(rootfile)

    # 64bits T
    T = Float64
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array_double.root"))
    data = rootfile["t1/double_array"]
    @test data isa AbstractVector
    @test eltype(data) <: AbstractVector{T}
    @test data[1] == T[]
    @test data[1:2] == [T[], T[0]]
    @test data[end] == T[90, 91, 92, 93, 94, 95, 96, 97, 98]
    close(rootfile)
end

@testset "Doubly jagged branches" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_doubly_jagged.root"))
    vvi = [[[2], [3, 5]], [[7, 9, 11], [13]], [[17], [19], []], [], [[]]]
    vvf = [[[2.5], [3.5, 5.5]], [[7.5, 9.5, 11.5], [13.5]], [[17.5], [19.5], []], [], [[]]]
    @test UnROOT.array(rootfile, "t1/bi") == vvi
    @test rootfile["t1/bi"] == vvi
    @test eltype(eltype(eltype(rootfile["t1/bi"]))) === Int32
    @test UnROOT.array(rootfile, "t1/bf") == vvf
    @test rootfile["t1/bf"] == vvf
    @test eltype(eltype(eltype(rootfile["t1/bf"]))) === Float32
    close(rootfile)
end

@testset "NanoAOD" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root"))
    event = UnROOT.array(rootfile, "Events/event")
    @test event[1:3] == UInt64[12423832, 12423821, 12423834]
    Electron_dxy = rootfile["Events/Electron_dxy"]
    @test eltype(Electron_dxy) == SubArray{Float32, 1, Vector{Float32}, Tuple{UnitRange{Int64}}, true}
    @test Electron_dxy[1:3] ≈ [Float32[0.0003705], Float32[-0.00981903], Float32[]]
    HLT_Mu3_PFJet40 = UnROOT.array(rootfile, "Events/HLT_Mu3_PFJet40")
    @test eltype(HLT_Mu3_PFJet40) == Bool
    @test HLT_Mu3_PFJet40[1:3] == [false, true, false]
    tree = LazyTree(rootfile, "Events", [r"Muon_(pt|eta|phi)$", "Muon_charge", "Muon_pt"])
    @test sort(propertynames(tree) |> collect) == sort([:Muon_pt, :Muon_eta, :Muon_phi, :Muon_charge])
    tree = LazyTree(rootfile, "Events", r"Muon_(pt|eta)$")
    @test sort(propertynames(tree) |> collect) == sort([:Muon_pt, :Muon_eta])
    @test occursin("LazyEvent", repr(first(iterate(tree))))
    @test sum(rootfile["Events/HLT_Mu3_PFJet40"]) == 443
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
    headers_auto = f_auto["KM3NET_EVENT/KM3NET_EVENT/KM3NETDAQ::JDAQEventHeader"]
    event_hits_auto = f_auto["KM3NET_EVENT/KM3NET_EVENT/snapshotHits"]
    event_thits_auto = f_auto["KM3NET_EVENT/KM3NET_EVENT/triggeredHits"]

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

    f = ROOTFile(joinpath(SAMPLES_DIR, "cms_ntuple_wjet.root"))
    binlabels = ["Root", "Weight", "Preselection", "SelectGenPart", "GoodRunsList", "EventFilters", "SelectLeptons", "SelectJets", "Trigger", "ObjectsSelection", "SSPreselection", "NjetGeq4", "AK4CategTagHiggsJets", "AK4CategTagVBSJets", "AK4CategChannels", "AK4CategPresel"]
    @test f["AK4CategPresel_cutflow"][:fXaxis_fModLabs].objects == binlabels
    close(f)
end


# Issues

@testset "issues" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue7.root"))
    @test 2 == length(keys(rootfile))
    @test [1.0, 2.0, 3.0] == UnROOT.array(rootfile, "TreeD/nums")
    @test [1.0, 2.0, 3.0] == UnROOT.array(rootfile, "TreeF/nums")
    close(rootfile)

    # issue 55
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "cms_ntuple_wjet.root"))
    pts1 = UnROOT.array(rootfile, "variable/met_p4/fCoordinates/fCoordinates.fPt"; raw=false)
    pts2 = LazyTree(rootfile, "variable", [r"met_p4/fCoordinates/.*", "mll"])[!, Symbol("met_p4/fCoordinates/fCoordinates.fPt")]
    pts3 = rootfile["variable/good_jets_p4/good_jets_p4.fCoordinates.fPt"]
    @test 24 == length(pts1)
    @test Float32[69.96958, 25.149912, 131.66693, 150.56802] == pts1[1:4]
    @test pts1 == pts2
    @test pts3[1:2] == [[454.0, 217.5, 89.5, 30.640625], [184.375, 33.28125, 32.28125, 28.46875]]
    close(rootfile)

    # issue 61
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue61.root"))
    @test rootfile["Events/Jet_pt"][:] == Vector{Float32}[[], [27.324587, 24.889547, 20.853024], [], [20.33066], [], []]
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
    @test rootfile["tree/trk_algoMask"][2] == [0x0000000000004000, 0x0000000000004000, 0x0000000000004000, 0x0000000000004000]
    @test rootfile["tree/pix_ladder"][3][1:5] == UInt16[0x0001, 0x0001, 0x0001, 0x0001, 0x0003]
    close(rootfile)

    # issue 116
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue116.root"))
    @test length(rootfile["fTree"].fBranches.elements) == 112
    close(rootfile)
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
    function isfullystable(func)
        io = IOBuffer()
        print(io, (@code_typed func()).first);
        typed = String(take!(io))
        return !occursin("::Any", typed)
    end

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

    @test isfullystable(f1)
    @test isfullystable(f2)

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
        @test Threads.nthreads() > 1
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

@static if VERSION > v"1.5.1"
    t = LazyTree(ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root")), "Events", ["Muon_pt"])
    @testset "Multi threading" begin
        nmus = zeros(Int, Threads.nthreads())
        Threads.@threads for (i, evt) in enumerate(t)
            nmus[Threads.threadid()] += length(t.Muon_pt[i])
        end
        @test sum(nmus) == 878

        nmus .= 0
        Threads.@threads for evt in t
            nmus[Threads.threadid()] += length(evt.Muon_pt)
        end
        @test count(>(0), nmus) > 1 # test @threads is actually threading
        @test sum(nmus) == 878

        nmus .= 0
        @batch for (i, evt) in enumerate(t)
            nmus[Threads.threadid()] += length(evt.Muon_pt)
        end
        @test count(>(0), nmus) > 1 # test @batch is actually threading
        @test sum(nmus) == 878

        event_nums = zeros(Int, Threads.nthreads())
        @batch for (i, evt) in enumerate(t)
            event_nums[Threads.threadid()] += 1
        end
        @test count(>(0), event_nums) > 1 # test @batch is actually threading
        @test sum(event_nums) == length(t)

        nmus .= 0
        @batch for evt in t
            nmus[Threads.threadid()] += length(evt.Muon_pt)
        end
        @test count(>(0), nmus) > 1 # test @batch is actually threading
        @test sum(nmus) == 878
        for j in 1:3
            inds = [Vector{Int}() for _ in 1:Threads.nthreads()]
            @batch for (i, evt) in enumerate(t)
                push!(inds[Threads.threadid()], i)
            end
            @test sum([length(inds[i] ∩ inds[j]) for i=1:length(inds), j=1:length(inds) if j>i]) == 0
        end
    end
end

@testset "TDirectory" begin
    f = UnROOT.samplefile("tdir_complicated.root")
    @test length(keys(f["mydir"])) == 4
    @test sort(keys(f["mydir"])) == ["Events", "c", "d", "mysubdir"]
    @test sort(keys(f["mydir/mysubdir"])) == ["e", "f"]
    @test sum(length.(LazyTree(f, "mydir/Events").Jet_pt)) == 4
    @test sum(length.(f["mydir/Events/Jet_pt"])) == 4

    f = UnROOT.samplefile("issue11_tdirectory.root")
    @test sum(f["Data/mytree/Particle0_E"]) ≈ 1012.0
end

@testset "Basic C++ types" begin
    f = UnROOT.samplefile("tree_basictypes.root")
    onesrow = LazyTree(f,"t")[2] |> collect |> values .|> first .|> Int
    @test all(onesrow .== 1)
end

@testset "basketarray_iter()" begin
    f = UnROOT.samplefile("tree_with_vector_multiple_baskets.root")
    t = LazyTree(f,"t1")
    @test (UnROOT.basketarray_iter(f, f["t1"]["b1"]) .|> length) == [1228, 1228, 44]
    @test (UnROOT.basketarray_iter(t.b1) .|> length) == [1228, 1228, 44]
    @test length(UnROOT.basketarray(t.b1, 1)) == 1228
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


@static if VERSION > v"1.5.0"
    @testset "Broadcast fusion" begin
        rootfile = ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root"))
        t = LazyTree(rootfile, "Events", "nMuon")
        testf(evt) = evt.nMuon == 4
        testf2(evt) = evt.nMuon == 4
        alloc1 = @allocated a1 = testf.(t)
        alloc1 += @allocated a2 = testf2.(t)
        alloc1 += @allocated idx1 = findall(a1 .& a2)
        alloc2 = @allocated idx2 = findall(@. testf(t) & testf2(t))
        @assert !isempty(idx1)
        @test idx1 == idx2
        # compiler optimization is good on 1.8
        @test alloc1 > 1.4*alloc2
    end
end
