using ROOTIO
using StaticArrays
using Test

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
@ROOTIO.stack D A B C
expected_fieldnames = (:n, :m, :o, :p, :q, :r, :s, :t, :u)
expected_fieldtypes = [Int32, Int64, Float16, Any, Bool, Any, Any, Any, Any]

@testset "utils" begin
    @test fieldnames(D) == expected_fieldnames
    @test [fieldtype(D, f) for f in fieldnames(D)] == expected_fieldtypes
end

# io.jl
ROOTIO.@io struct Foo
    a::Int32
    b::Int64
    c::Float32
    d::SVector{5, UInt8}
end

@testset "io" begin

    d = SA{UInt8}[1, 2, 3, 4, 5]

    foo = Foo(1, 2, 3, d)

    @test foo.a == 1
    @test foo.b == 2
    @test foo.c ≈ 3
    @test d == foo.d

    @test_skip 21 == sizeof(Foo)

    buf = IOBuffer(Vector{UInt8}(1:sizeof(Foo)))
    foo = ROOTIO.unpack(buf, Foo)

    @test foo.a == 16909060
    @test foo.b == 361984551142689548
    @test foo.c ≈ 4.377526f-31
    @test foo.d == UInt8[0x11, 0x12, 0x13, 0x14, 0x15]
end


@testset "Header and Preamble" begin
    fobj = open(joinpath(SAMPLES_DIR, "km3net_online.root"))
    file_preamble = ROOTIO.unpack(fobj, ROOTIO.FilePreamble)
    @test "root" == String(file_preamble.identifier)

    file_header = ROOTIO.unpack(fobj, ROOTIO.FileHeader32)
    @test 100 == file_header.fBEGIN
end


@testset "ROOTFile" begin
    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "tree_with_histos.root"))
    show(rootfile)
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
    for key in keys(rootfile)
        rootfile[key]
    end
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

    rootfile = ROOTFile(joinpath(SAMPLES_DIR, "km3net_online.root"))
    header = rootfile.directory.header
    @test 5 == header.fVersion
    @test 1658540644 == header.fDatimeC
    @test 1658540645 == header.fDatimeM
    @test 629 == header.fNbytesKeys
    @test 68 == header.fNbytesName
    @test 100 == header.fSeekDir
    @test 0 == header.fSeekParent
    @test 1619244 == header.fSeekKeys
end
