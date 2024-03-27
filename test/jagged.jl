using Test
using UnROOT


@testset "Singly jagged branches" begin
    # 32bits T
    rootfile = UnROOT.samplefile("tree_with_jagged_array.root")
    data = LazyBranch(rootfile, "t1/int32_array")
    @test data[1] == Int32[]
    @test data[1:2] == [Int32[], Int32[0]]
    @test data[end] == Int32[90, 91, 92, 93, 94, 95, 96, 97, 98]
    close(rootfile)

    # 64bits T
    T = Float64
    rootfile = UnROOT.samplefile("tree_with_jagged_array_double.root")
    data = LazyBranch(rootfile, "t1/double_array")
    @test data isa AbstractVector
    @test eltype(data) <: AbstractVector{T}
    @test data[1] == T[]
    @test data[1:2] == [T[], T[0]]
    @test data[end] == T[90, 91, 92, 93, 94, 95, 96, 97, 98]
    close(rootfile)
end

@testset "Doubly jagged [var][var] branches" begin
    # this is vector<vector<blah>>
    rootfile = UnROOT.samplefile("tree_with_doubly_jagged.root")
    vvi = [[[2], [3, 5]], [[7, 9, 11], [13]], [[17], [19], []], [], [[]]]
    vvf = [[[2.5], [3.5, 5.5]], [[7.5, 9.5, 11.5], [13.5]], [[17.5], [19.5], []], [], [[]]]
    @test UnROOT.array(rootfile, "t1/bi") == vvi
    @test LazyBranch(rootfile, "t1/bi") == vvi
    @test eltype(eltype(eltype(LazyBranch(rootfile, "t1/bi")))) === Int32
    @test UnROOT.array(rootfile, "t1/bf") == vvf
    @test LazyBranch(rootfile, "t1/bf") == vvf
    @test eltype(eltype(eltype(LazyBranch(rootfile, "t1/bf")))) === Float32
    close(rootfile)
end

@testset "Doubly jagged [var][fix] branches" begin
    # issue #187
    # this is vector<Int[N]>
    f = UnROOT.samplefile("tree_with_varfix_doubly_jagged.root")
    tree = LazyTree(f, "outtree")
    @test tree.nparticles == [4,3,2]
    @test length.(tree.P) == [4,3,2]
    @test eltype(tree.P[1]) <: AbstractVector
    # also compared to uproot
    @test tree[1].P == [
                        [0.9411764705882353, 0.8888888888888888, 0.8421052631578947, 0.8],
                        [1.0, 0.9285714285714286, 0.8666666666666667, 0.8125],
                        [1.1111111111111112, 1.0, 0.9090909090909091, 0.8333333333333334],
                        [1.4, 1.1666666666666667, 1.0, 0.875]
                       ]
    @test tree[3].P == [
                        [0.8222222222222222,
                         0.8043478260869565,
                         0.7872340425531915,
                         0.7708333333333334],
                        [0.8292682926829268,
                         0.8095238095238095,
                         0.7906976744186046,
                         0.7727272727272727]
                       ]
end

@testset "Doubly jagged via custom class" begin
    f = UnROOT.samplefile("triply_jagged_via_custom_class.root")
    b = LazyBranch(f, "E/Evt/w")
    @test 3 == length(b)
    @test [3.3329158e6, 3.6047424e22, 3.1181261e8] ≈ b[1]
    @test [3.3329158e6, 2.4039883e23, 4.5337845e6] ≈ b[2]
    @test [3.3329158e6, 4.9458148e24, 42805.383] ≈ b[3]
    close(f)
end

@testset "Triply jagged stuff via custom class" begin
    f = UnROOT.samplefile("triply_jagged_via_custom_class.root")
    b = LazyBranch(f, "E/Evt/trks/trks.rec_stages")
    @test 3 == length(b)
    @test 38 == length(b[3])
    @test 5 == length(b[3][1])
    @test [1, 2, 3, 4, 5] == b[2][1]
    b = LazyBranch(f, "E/Evt/trks/trks.fitinf")
    @test 3 == length(b)
    @test 38 == length(b[3])
    @test 17 == length(b[3][1])
    @test b[3][1] ≈ [
        0.02175229704756278, 0.013640169301181978, -27.59387722710992, 45.0,
        90072.00780343144, 52.67760965729974, 3.9927948910593525, 10.0,
        0.3693832125931179, 0.3693832125931179, 72.02530060292972, 0.0, 0.0,
        13461.937901498717, -Inf, 1518.0, 56.0,
    ]
    close(f)
end

@testset "jagged subbranch type by leaf" begin
    rootfile = UnROOT.samplefile("km3net_offline.root")
    times = UnROOT.array(rootfile, "E/Evt/trks/trks.t")
    @test times[1][1] ≈ 7.0311446e7
    @test times[10][11] ≈ 5.4956456e7

    ids_jagged = UnROOT.array(rootfile, "E/Evt/trks/trks.id")
    @test all(ids_jagged[1] .== collect(1:56))
    @test all(ids_jagged[9] .== collect(1:54))

    close(rootfile)
end
