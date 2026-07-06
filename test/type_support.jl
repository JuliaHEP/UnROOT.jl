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

@testset "runlength_string long-string (0xFF) marker" begin
    # ROOT stores strings >= 255 bytes with a 0xFF marker byte followed by
    # a 4-byte big-endian length; shorter strings use a single length byte.
    function encode(s)
        b = UInt8[]
        n = ncodeunits(s)
        if n < 255
            push!(b, UInt8(n))
        else
            push!(b, 0xff)
            push!(b, UInt8((n >> 24) & 0xff), UInt8((n >> 16) & 0xff),
                     UInt8((n >>  8) & 0xff), UInt8( n        & 0xff))
        end
        append!(b, codeunits(s))
        b
    end
    offset = 6
    short1 = "abc"
    long   = repeat("x", 397)   # >= 255 bytes, triggers the escape
    short2 = "de"
    data = vcat(zeros(UInt8, offset), encode(short1), encode(long), encode(short2))

    out = UnROOT.runlength_string(String, data; offset=offset)
    @test out == [short1, long, short2]
    @test ncodeunits(out[2]) == 397

    # A truncated buffer must not throw: parsing stops at the last complete string.
    @test UnROOT.runlength_string(String, data[1:end-1]; offset=offset) == [short1, long]
end
