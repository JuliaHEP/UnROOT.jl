using Test
using SHA
using UnROOT
using StaticArrays

SAMPLES_DIR = joinpath(@__DIR__, "samples")

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

    rootfile = UnROOT.samplefile("tree_with_custom_struct.root")
    @test 100 == rootfile.header.fBEGIN
    @test 1 == length(rootfile.directory.keys)
    @test "T" ∈ keys(rootfile)
    for key in keys(rootfile)
        rootfile[key]
    end
    close(rootfile)

    rootfile = UnROOT.samplefile("histograms.root")
    for branch in ["one", "two", "three"]
        @test branch in keys(rootfile)
    end
    close(rootfile)

    rootfile = UnROOT.samplefile("km3net_online.root")
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
    close(rootfile)
end

@testset "readbasketsraw()" begin
    array_sha1 = [0x45, 0xab, 0x2c, 0x2a, 0x68, 0x17, 0x1d, 0x32, 0x3b, 0x25, 0x1f, 0x39, 0x01, 0xbe, 0xb7, 0xf3, 0xc9, 0xbf, 0xd3, 0xd6]
    rootfile = UnROOT.samplefile("km3net_online.root")
    data, offsets = UnROOT.array(rootfile, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
    @test array_sha1 == sha1(data)
    close(rootfile)

    rootfile = UnROOT.samplefile("tree_with_jagged_array.root")
    data, offsets = UnROOT.array(rootfile, "t1/int32_array"; raw=true)

    @test data isa Vector{UInt8}
    @test offsets isa Vector{Int32}
    @test data[1:3] == UInt8[0x40, 0x00, 0x00]

    rootfile = UnROOT.samplefile("tree_with_vector_multiple_baskets.root")
    data, offsets = UnROOT.array(rootfile, "t1/b1"; raw=true)
    @test unique(diff(offsets)) == [18]
    close(rootfile)
end

@testset "ROOTDirectoryHeader" begin
    rootfile = UnROOT.samplefile("tree_with_histos.root")
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

@testset "TNtuple" begin
    rootfile = UnROOT.samplefile("TNtuple.root")
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

@testset "basketarray_iter()" begin
    f = UnROOT.samplefile("tree_with_vector_multiple_baskets.root")
    t = LazyTree(f,"t1")
    @test (UnROOT.basketarray_iter(f, f["t1"]["b1"]) .|> length) == [1228, 1228, 44]
    @test (UnROOT.basketarray_iter(t.b1) .|> length) == [1228, 1228, 44]
    @test length(UnROOT.basketarray(t.b1, 1)) == 1228
end
