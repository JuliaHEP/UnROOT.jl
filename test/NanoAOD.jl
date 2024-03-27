using Test
using UnROOT

@testset "NanoAOD" begin
    rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
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
