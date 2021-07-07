using Test
using UnROOT
using StaticArrays
using MD5

@static if VERSION > v"1.3.0"
    using ThreadsX
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

    @test_skip 21 == sizeof(Foo)

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
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_histos.root"))
    @test 100 == rootfile.header.fBEGIN
    @test 1 == length(rootfile.directory.keys)
    @test "t1" ∈ keys(rootfile)
    for key in keys(rootfile)
        rootfile[key]
    end

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_custom_struct.root"))
    @test 100 == rootfile.header.fBEGIN
    @test 1 == length(rootfile.directory.keys)
    @test "T" ∈ keys(rootfile)
    for key in keys(rootfile)
        rootfile[key]
    end

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "histograms.root"))
    for branch in ["one", "two", "three"]
        @test branch in keys(rootfile)
    end

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
end

@testset "readbasketsraw()" begin
    array_md5 = [0xb4, 0xe9, 0x32, 0xe8, 0xfb, 0xff, 0xcf, 0xa0, 0xda, 0x75, 0xe0, 0x25, 0x34, 0x9b, 0xcd, 0xdf]
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "km3net_online.root"))
    data, offsets = array(rootfile, "KM3NET_EVENT/KM3NET_EVENT/snapshotHits"; raw=true)
    reco = UnROOT.splitup(data, offsets, UnROOT.KM3NETDAQHit)
    @test reco[1][1].tdc == 9
    @test reco[end-1][1].tdc == 58729296
    @test array_md5 == md5(data)

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array.root"))
    data, offsets = array(rootfile, "t1/int32_array"; raw=true)

    @test data isa Vector{UInt8}
    @test offsets isa Vector{Int32}
    @test data[1:3] == UInt8[0x40, 0x00, 0x00]
end

@testset "No (basket) compression" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "uncomressed_lz4_int32.root"))
    arr = array(rootfile, "t1/int32_array")
    @test length(arr) == 3
    @test all(arr .== [[1,2], [], [3]])
end

@testset "Compressions" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_large_array_lzma.root"))
    @test rootfile isa ROOTFile
    arr = array(rootfile, "t1/float_array")
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_large_array_lz4.root"))
    arr = array(rootfile, "t1/float_array")
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
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
end


@testset "array()" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_histos.root"))
    arr = array(rootfile, "t1/mynum")
    @test 25 == length(arr)
    @test [0, 1, 2, 3, 4] ≈ arr[1:5] atol=0.1
    @test [10, 10, 10, 10, 10, 10] ≈ arr[20:end] atol=0.1

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_large_array.root"))
    arr = array(rootfile, "t1/int32_array")
    @test 100000 == length(arr)
    @test [0, 1, 2, 3, 4] == arr[1:5]
    @test 99999-4:99999 == arr[end-4:end]
    arr = array(rootfile, "t1/float_array")
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    @test 105881.296875 ≈ last(arr)
end

@testset "TNtupel" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "TNtuple.root"))
    arrs = [array(rootfile, "n1/$c") for c in "xyz"]
    @test length.(arrs) == fill(100, 3)
    @test arrs[1] ≈ 0:99
    @test arrs[2] ≈ arrs[1] .+ arrs[1] ./ 13
    @test arrs[3] ≈ arrs[1] .+ arrs[1] ./ 17
end

@testset "Jagged branches" begin
    # 32bits T
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array.root"))
    data = array(rootfile, "t1/int32_array")
    @test data isa Vector{Vector{Int32}}
    @test data[1] == Int32[]
    @test data[1:2] == [Int32[], Int32[0]]
    @test data[end] == Int32[90, 91, 92, 93, 94, 95, 96, 97, 98]

    # 64bits T
    T = Float64
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_jagged_array_double.root"))
    data = array(rootfile, "t1/double_array")
    @test data isa Vector{Vector{T}}
    @test data[1] == T[]
    @test data[1:2] == [T[], T[0]]
    @test data[end] == T[90, 91, 92, 93, 94, 95, 96, 97, 98]
end

@testset "NanoAOD" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "NanoAODv5_sample.root"))
    event = array(rootfile, "Events/event")
    @test event[1:3] == UInt64[12423832, 12423821, 12423834]
    Electron_dxy = array(rootfile, "Events/Electron_dxy")
    @test eltype(Electron_dxy) == Vector{Float32}
    @test Electron_dxy[1:3] ≈ [Float32[0.0003705], Float32[-0.00981903], Float32[]]
    HLT_Mu3_PFJet40 = array(rootfile, "Events/HLT_Mu3_PFJet40")
    @test eltype(HLT_Mu3_PFJet40) == Bool
    @test HLT_Mu3_PFJet40[1:3] == [false, true, false]


    if VERSION > v"1.3.0"
        branch_names = keys(rootfile["Events"])
        # thread-safety test
        @test all(
           map(bn->array(rootfile, "Events/$bn"; raw=true), branch_names) .== 
           ThreadsX.map(bn->array(rootfile, "Events/$bn"; raw=true), branch_names)
           )
    end

end



# Issues

@testset "issues" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "issue7.root"))
    @test 2 == length(keys(rootfile))
    @test [1.0, 2.0, 3.0] == array(rootfile, "TreeD/nums")
    @test [1.0, 2.0, 3.0] == array(rootfile, "TreeF/nums")
end
