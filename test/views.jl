using UnROOT
using Test

SAMPLES_DIR = joinpath(@__DIR__, "samples")


@testset "View" begin
    data = LazyTree(joinpath(SAMPLES_DIR, "tree_with_jagged_array.root"), "t1")
    data[1:2]
    @view data[1:2]
    alloc1 = @allocated v = data[3:90]
    alloc2 = @allocated v = @view data[3:90]
    v = @view data[3:80]
    @test alloc2 < alloc1/100
    @test all(v.int32_array .== data.int32_array[3:80])

    v2 = @view data[[1,3,5]]
    @test v2[1].int32_array == data[1].int32_array
    @test v2[2].int32_array == data[3].int32_array
end
