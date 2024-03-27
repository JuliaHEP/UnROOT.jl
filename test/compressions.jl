using Test
using UnROOT


@testset "Compressions" begin
    rootfile = UnROOT.samplefile("tree_with_large_array_lzma.root")
    arr = UnROOT.array(rootfile, "t1/float_array")
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    close(rootfile)

    rootfile = UnROOT.samplefile("tree_with_large_array_lz4.root")
    arr = collect(LazyBranch(rootfile, rootfile["t1/float_array"]))
    @test 100000 == length(arr)
    @test [0.0, 1.0588236, 2.1176472, 3.1764705, 4.2352943] ≈ arr[1:5] atol=1e-7
    close(rootfile)

    rootfile = UnROOT.samplefile("tree_with_int_array_zstd.root")
    arr = collect(LazyBranch(rootfile, "t1/a"))
    @test arr == 0:99
    close(rootfile)
end

@testset "No (basket) compression" begin
    rootfile = UnROOT.samplefile("uncomressed_lz4_int32.root")
    arr = UnROOT.array(rootfile, "t1/int32_array")
    @test length(arr) == 3
    @test all(arr .== [[1,2], [], [3]])
    close(rootfile)
end

@testset "Uncompressed trees" begin
    rootfile = UnROOT.samplefile("issue87_uncompressed_a.root")
    @test LazyTree(rootfile,"Events").Jet_pt ≈ [[27.3245, 24.8896, 20.8534],Float32[],[5.3306]]

    rootfile = UnROOT.samplefile("issue87_uncompressed_b.root")
    @test LazyTree(rootfile,"Events").myval[2:5] ≈ [[0.1], [0.2, 1.2], [0.3, 1.3, 2.3], [0.4, 1.4, 2.4, 3.4]]
end
