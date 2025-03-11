using Test
using UnROOT

SAMPLES_DIR = joinpath(@__DIR__, "samples")


@testset "Issues" begin
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
    rootfile = UnROOT.samplefile("issue61.root")
    arr = LazyTree(rootfile,"Events").Jet_pt;
    _ = length.(arr);
    @test length.(arr.buffer) == length.(arr.buffer_range)
    close(rootfile)

    # issue 108
    # unsigned short -> Int16, ulong64 -> UInt64
    # file minified with `rooteventselector --recreate -l 2 "trackntuple.root:trackingNtuple/tree" issue108_small.root`
    rootfile = UnROOT.samplefile("issue108_small.root")
    @test LazyBranch(rootfile, "tree/trk_algoMask")[2] == [0x0000000000004000, 0x0000000000004000, 0x0000000000004000, 0x0000000000004000]
    @test LazyBranch(rootfile, "tree/pix_ladder")[3][1:5] == UInt16[0x0001, 0x0001, 0x0001, 0x0001, 0x0003]
    close(rootfile)

    # issue 116
    rootfile = UnROOT.samplefile("issue116.root")
    @test length(rootfile["fTree"].fBranches.elements) == 112
    close(rootfile)

    # issue 246
    arr = LazyTree(joinpath(SAMPLES_DIR, "issue246.root"), "tree_NOMINAL").v_mcGenWgt
    @test all(reduce(vcat, arr) .== 1.0)

    # issue 323
    f = UnROOT.samplefile("issue323.root")
    t = LazyTree(f, "sim", [r"ghost/ghost\.(.*)" => s"\1"])
    @test 1200 == length(t)
    @test t[1].time[2] ≈ 36.396744f0
    @test t[end].xpos[end] ≈ 788.35144f0

    # issue 377
    f = UnROOT.samplefile("issue377.root")
    arr = UnROOT.array(f, "podio_metadata/events___CollectionTypeInfo/events___CollectionTypeInfo.dataType")
    t = LazyTree(f, "podio_metadata", ["events___CollectionTypeInfo"])
    @test 1 == length(t.events___CollectionTypeInfo_dataType)
    @test 26 == length(t.events___CollectionTypeInfo_dataType[1])
    @test "edm4hep::CaloHitContributionCollection" == t.events___CollectionTypeInfo_dataType[1][1]
    @test "podio::LinkCollection<edm4hep::Vertex,edm4hep::ReconstructedParticle>" == t.events___CollectionTypeInfo_dataType[1][end]
    @test arr == t.events___CollectionTypeInfo_datatype
end

function _test_clean_GC(fname)
    for i in 1:5
        f = UnROOT.samplefile(fname)
        t = LazyTree(f, "t1")
        f = t = nothing
    end
end

@testset "Clean GC issue #260" begin
    fname = "tree_with_large_array_lzma.root"

    _test_clean_GC(fname)
    GC.gc()
    GC.gc()
    sleep(2)
    GC.gc()
    sleep(2)

    pid = getpid()
    @static if Sys.islinux()
        @test isempty(filter(contains(fname), readlines("/proc/$pid/smaps")))
    elseif Sys.isapple()
        @test isempty(filter(contains(fname), readlines(`vmmap $(getpid())`)))
    elseif Sys.iswindows()
        # TODO: add test for windows
    end
end

@testset "PR 266" begin
    f = UnROOT.samplefile("edm4hep_266.root")
    tree = LazyTree(f, "events", r"PandoraPFOs/PandoraPFOs.[(a-z)(A-Z))]")

    @test length(tree.PandoraPFOs_energy[1]) == 79
    @test length(tree.var"PandoraPFOs_covMatrix[10]"[1]) == 790
end

@testset "PR 342 TLeafC" begin
    df = LazyTree(UnROOT.samplefile("TLeafC_pr342.root"), "G4Sim")
    @test all(df.Process[1:10] .== ["Radioactivation", "msc", "eIoni", "Transportation", "ionIoni", "Radioactivation", "msc", "eIoni", "ionIoni", "Radioactivation"])
end
