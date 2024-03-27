using Test
using UnROOT


@testset "TLorentzVector" begin
    # 64bits T
    rootfile = UnROOT.samplefile("TLorentzVector.root")
    branch = LazyBranch(rootfile, "t1/LV")
    tree = LazyTree(rootfile, "t1")

    @test branch[1].x == 1.0
    @test branch[1].t == 4.0
    @test eltype(branch) === LorentzVectors.LorentzVector{Float64}
    @test tree[1].LV.x == 1.0
    @test tree[1].LV.t == 4.0
    close(rootfile)


    # jagged LVs
    rootfile = UnROOT.samplefile("Jagged_TLorentzVector.root")
    branch = LazyBranch(rootfile, "t1/LVs")
    tree = LazyTree(rootfile, "t1")

    @test eltype(branch) <: AbstractVector{LorentzVectors.LorentzVector{Float64}}
    @test eltype(branch) <: SubArray
    @test length.(branch[1:10]) == 0:9
    close(rootfile)
end
