using Test
using UnROOT


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

@testset "vector<string>" begin
    rootfile = UnROOT.samplefile("usr-sample.root")
    names = LazyBranch(rootfile, "E/Evt/AAObject/usr_names")
    for n in names
        @test all(n .== ["RecoQuality", "RecoNDF", "CoC", "ToT", "ChargeAbove", "ChargeBelow", "ChargeRatio", "DeltaPosZ", "FirstPartPosZ", "LastPartPosZ", "NSnapHits", "NTrigHits", "NTrigDOMs", "NTrigLines", "NSpeedVetoHits", "NGeometryVetoHits", "ClassficationScore"])
    end
    close(rootfile)
end
