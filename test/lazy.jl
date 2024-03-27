using Test
using UnROOT


@testset "LazyBranch and LazyTree" begin
    rootfile = UnROOT.samplefile("tree_with_large_array.root")
    branch = rootfile["t1"]["int32_array"]
    arr = UnROOT.array(rootfile, branch)
    arr2 = UnROOT.arrays(rootfile, "t1")[1]

    @test hash(branch) == hash(rootfile["t1"]["int32_array"])
    @test hash(branch) != hash(rootfile["t1"]["float_array"])
    @test arr == arr2

    table = LazyTree(rootfile, "t1")
    BA = LazyBranch(rootfile, branch)
    @test length(arr) == length(BA)
    @test BA[1] == arr[1]
    @test BA[end] == arr[end]
    @test BA[20:30] == arr[20:30]
    @test BA[1:end] == arr
    @test table.int32_array[20:30] == BA[20:30]
    @test table[:, :int32_array][20:30] == BA[20:30]
    @test table[23, :int32_array] == BA[23]
    @test table[20:30, :int32_array] == BA[20:30]
    @test table[:].int32_array[20:30] == BA[20:30]
    @test [row.int32_array for row in table[20:30]] == BA[20:30]
    @test sum(table.int32_array) == sum(row.int32_array for row in table)
    @test [row.int32_array for row in table] == BA

    # do some hardcoded value checks
    bunches = Float32[]
    for i in 1:10
        start = 1 + 1000*(i-1)
        stop = 1000*i
        push!(bunches, sum(table.float_array[start:stop]))
    end
    testvalues = Vector{Float32}([528882.3f0, 1.5877059f6, 2.6465295f6, 3.705353f6, 4.764177f6, 5.823f6, 6.881823f6, 7.9406475f6, 8.999469f6, 1.0058294f7])
    @test bunches ≈ testvalues

    close(rootfile)

    rootfile = UnROOT.samplefile("km3net_offline.root")
    t = LazyTree(rootfile, "E", ["Evt/trks/trks.id", r"Evt/trks/trks.(dir|pos).([xyz])" => s"\1_\2"])
    @test 10 == length(t.Evt_trks_trks_id)
    @test 10 == length(t.dir_x)
    @test 10 == length(t.dir_y)
    @test 10 == length(t.dir_z)
    @test 10 == length(t.pos_x)
    @test 10 == length(t.pos_y)
    @test 10 == length(t.pos_z)
    @test 56 == length(t.pos_z[1])
    @test 68.42717410489223 ≈ t.pos_z[1][5]
    close(rootfile)
end

@testset "Alternative sink for LazyTree" begin
    rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
    t = LazyTree(rootfile, "Events", ["nMuon", "Muon_pt"])
    df = LazyTree(rootfile, "Events", ["nMuon", "Muon_pt"]; sink=DataFrame)
    @test df == DataFrame(t)
end
