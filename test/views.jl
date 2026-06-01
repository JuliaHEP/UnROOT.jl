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

    # a view must have the same element type as the tree it views (issue #427), so
    # that a concrete `LazyEvent{T}` can be used for dispatch on both
    @test eltype(data) === eltype(@view data[1:1])
    @test eltype(data) === eltype(v)
    @test eltype(data) === eltype(v2)
    @test v[1] === data[3]                      # v == @view data[3:80], so v[1] is data[3]
    # nested views and lazy sub-slicing keep the element type stable
    @test eltype(data) === eltype((@view data[1:10])[2:4])
    @test eltype(data) === eltype(@view (@view data[1:10])[2:4])
end
