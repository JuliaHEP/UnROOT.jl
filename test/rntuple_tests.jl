using Arrow, DataFrames

@testset "RNTuple Anchodr/Header/Footer" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    @test haskey(f1, "ntuple")
    rn1 = f1["ntuple"]
    header1 = rn1.header
    @test header1.name == "ntuple"
    @test length(header1.field_records) == 1
    @test header1.field_records[1].field_name == "one_integers"
    @test header1.field_records[1].parent_field_id == 0 # it's 0-based sigh

    footer1 = rn1.footer
    @test isempty(footer1.meta_data_links)
    @test length(footer1.cluster_group_records) == 1
    summary1 = UnROOT._read_page_list(rn1).cluster_summaries[1]
    @test summary1.first_entry_number == 0
    @test summary1.number_of_entries == 5e4

    f2 = UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")
    rn2 = f2["ntuple"]

    header2 = rn2.header
    @test length(header2.field_records) == 41
    [f.field_name for f in header2.field_records[1:9]] == 
    ["string", "vector_int32", "vector_float_int32", "vector_string", 
     "vector_vector_string", "variant_int32_string", "vector_variant_int64_string", "tuple_int32_string", "vector_tuple_int32_string"]
    @test length(header2.column_records) == 42
end

@testset "RNTuple Schema Parsing" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    schema1 = f1["ntuple"].schema
    @test length(schema1) == 1
    @test schema1.one_integers isa UnROOT.LeafField{Int32}
    @test schema1.one_integers.content_col_idx == 1 # we use this to index directly, so it's 1-based

    f2 = UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")
    schema2 = f2["ntuple"].schema
    @test length(schema2) == 13

    sample = schema2.vector_tuple_int32_string
    @test sample isa UnROOT.VectorField
    @test sample.offset_col isa UnROOT.LeafField{UnROOT.Index64}

    @test sample.content_col isa UnROOT.StructField
    @test length(sample.content_col.content_cols) == 2
end

@testset "RNTuple Int32 reading" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    df = LazyTree(f1, "ntuple")
    @test length(df) == 5e4
    @test length(df.one_integers) == 5e4
    @test all(df.one_integers .== 5*10^4:-1:1)
end

@testset "RNTuple bit(bool) reading" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_bit.root")
    df = LazyTree(f1, "ntuple")
    @test df.one_bit == Bool[1, 0, 0, 1, 0, 0, 1, 0, 0, 1]
end

@testset "RNTuple multicluster" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_multicluster.root")
    df = LazyTree(f1, "ntuple")
    @test unique(df.one_integers[1:end÷2]) == [2]
    @test unique(df.one_integers[end÷2+1:end]) == [1]
    @test df.one_integers[1] == 2
    @test df.one_integers[end] == 1
    @test length(df.one_integers) == 50000000 * 2
end

@testset "RNTuple std:: container types" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")
    df = LazyTree(f1, "ntuple")

    @test eltype(df.string) == String
    @test df.string == ["one", "two", "three", "four", "five"]

    @test eltype(df.vector_int32) == Vector{Int32}
    @test df.vector_int32 == [Int32[1], Int32[1,2], Int32[1,2,3], Int32[1,2,3,4], Int32[1,2,3,4,5]]

    @test eltype(df.variant_int32_string) == Union{Int32, String}
    @test length(df.variant_int32_string) == 5
    @test df.variant_int32_string == Union{Int32, String}[Int32(1), "two", "three", Int32(4), Int32(5)]

    @test df.vector_string == [["one"], ["one", "two"], ["one", "two", "three"], ["one", "two", "three", "four"], ["one", "two", "three", "four", "five"]]

    @test values(df.tuple_int32_string[1]) == (Int32(1), "one")
    @test values(df.tuple_int32_string[5]) == (Int32(5), "five")
    @test values(df.pair_int32_string[1]) == (Int32(1), "one")
    @test values(df.pair_int32_string[5]) == (Int32(5), "five")

    @test df.vector_variant_int64_string == Vector{Union{Int64, String}}[Union{Int64, String}["one"], Union{Int64, String}["one", 2], Union{Int64, String}["one", 2, 3], Union{Int64, String}["one", 2, 3, 4], Union{Int64, String}["one", 2, 3, 4, 5]]

    @test df.lorentz_vector[1] === (pt = 1.0f0, eta = 1.0f0, phi = 1.0f0, mass = 1.0f0)
    @test df.lorentz_vector[end] === df.lorentz_vector[5] === (pt = 5.0f0, eta = 5.0f0, phi = 5.0f0, mass = 5.0f0)

    @test length(df.array_lv) == 5
    @test all(length.(df.array_lv) .== 3)
    @test df.array_lv[1] == fill((pt=1.0, eta=1.0, phi=1.0, mass=1.0), 3)
    @test df.array_lv[5] == fill((pt=5.0, eta=5.0, phi=5.0, mass=5.0), 3)
end

@testset "RNTupleCardinality" begin
    f1 = UnROOT.samplefile("RNTuple/Run2012BC_DoubleMuParked_Muons_rntuple_1000evts.root")
    t = LazyTree(f1, "Events")
    @test t.nMuon == 
        length.(t.Muon_pt) ==
        length.(t.Muon_eta) ==
        length.(t.Muon_mass) == 
        length.(t.Muon_charge)
end

# Covered by other tests already
# @testset "RNTuple Split Encoding" begin
#     f1 = UnROOT.samplefile("RNTuple/test_ntuple_split_3e4.root")
#     t = LazyTree(f1, "ntuple")
#     @test all(==(Int32(0x04030201)), t.one_int32)
#     @test all(==(0xffeeddcc), reinterpret(UInt32, t.two_uint32))

#     @test eltype(t.one_int32) == Int32
#     @test eltype(t.two_uint32) == UInt32

#     # 0.099967316
#     @test reinterpret(UInt32, t.three_vfloat32[2]) == [0x3dccbbaa]
#     @test all(reduce(vcat, t.three_vfloat32) .=== 0.099967316f0)
#     @test length.(t.three_float32) == repeat(0:9, 3000)

#     @test all(==(578437695752307201), t.four_int64)
# end

@testset "RNTuple Type stability" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    t = LazyTree(f1, "ntuple")

    function f()
        s = 0.0f0
        for evt in t
            s += evt.one_integers
        end
        s
    end
    g() = sum(t.one_integers)

    @inferred f()
    @inferred g()
end

@testset "RNTuple Multi-threading" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    df = LazyTree(f1, "ntuple")

    field = df.one_integers
    accumulator = zeros(Int, nthreads)
    Threads.@threads for i in eachindex(field)
        @inbounds accumulator[Threads.threadid()] += field[i]
    end

    # test we've hit each thread's buffer
    @test all(
        map(eachindex(field.buffers)) do b
            if !isassigned(field.buffers, b)
                return true
            else
                return  !isempty(field.buffers[b])
            end

    end)
    @test sum(accumulator) == sum(1:5e4)

    accumulator .= 0
    Threads.@threads for evt in df
        @inbounds accumulator[Threads.threadid()] += evt.one_integers
    end
    @test sum(accumulator) == sum(1:5e4)
end

@testset "RNTuple Tables.jl and Arrow integration " begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")
    rnt = LazyTree(f1, "ntuple")
    df_direct = DataFrame(rnt)
    df_col = DataFrame(UnROOT.Tables.columntable(UnROOT.Tables.columns(rnt)))
    df_row = DataFrame(UnROOT.Tables.dictrowtable(UnROOT.Tables.rows(rnt)))
    # row table and col table should arrive at the same result
    @test df_col == df_row == df_direct

    path = tempname()
    Arrow.write(path, rnt)
    df_arrow = DataFrame(Arrow.Table(path))
    # RNTuple -> Arrow -> DataFrame should be same as RNTuple -> DataFrame
    @test df_arrow == df_direct
end
