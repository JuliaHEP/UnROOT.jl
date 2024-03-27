using Test
using UnROOT


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

@testset "Chaining/vcat" begin
    rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
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
    alloc1 = @allocated length.(t.Muon_pt)
    alloc2 = @allocated length.(tt.Muon_pt)
    @test alloc2 < 2.1 * alloc1
    close(rootfile)
end

@testset "Broadcast fusion" begin
    rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
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
