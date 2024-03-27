using Test
using UnROOT

SAMPLES_DIR = joinpath(@__DIR__, "samples")


@testset "Displaying files" begin
    files = filter(x->endswith(x, ".root"), readdir(SAMPLES_DIR))
    _io = IOBuffer()
    for f in files
        # https://github.com/JuliaHEP/UnROOT.jl/issues/268
        contains(f, "km3net_") && continue
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
