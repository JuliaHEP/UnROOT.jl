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
    summary1 = footer1.cluster_summaries[1]
    @test summary1.num_first_entry == 0
    @test summary1.num_entries == 5e4

    f2 = UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")
    rn2 = f2["ntuple"]

    header2 = rn2.header
    @test length(header2.field_records) == 25
    [f.field_name for f in header2.field_records[1:9]] == 
    ["string", "vector_int32", "vector_float_int32", "vector_string", 
     "vector_vector_string", "variant_int32_string", "vector_variant_int64_string", "tuple_int32_string", "vector_tuple_int32_string"]
    @test length(header2.column_records) == 30
    @test rn2.footer.header_crc32 == 0x075071b9
end

@testset "RNTuple Schema Parsing" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    schema1 = f1["ntuple"].schema
    @test length(schema1) == 1
    @test schema1.one_integers isa UnROOT.LeafField{Int32}
    @test schema1.one_integers.content_col_idx == 1 # we use this to index directly, so it's 1-based

    f2 = UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")
    schema2 = f2["ntuple"].schema
    a = IOBuffer()
    show(a, schema2)
    @test length(take!(a)) < 1500 # make sure schema is reasonably compact
    @test length(schema2) == 9

    #this is:
    #VectorField(offset=Leaf{Int32}(col=9), content=StructField{(:_0=Leaf{Int32}(col=28), :_1=String(offset=29, char=30))))
    sample = schema2.vector_tuple_int32_string
    @test sample isa UnROOT.VectorField
    @test sample.offset_col isa UnROOT.LeafField{Int32}
    @test sample.offset_col.content_col_idx == 9

    @test sample.content_col isa UnROOT.StructField
    @test length(sample.content_col.content_cols) == 2
    @test sample.content_col.content_cols[1] isa UnROOT.LeafField{Int32}
    @test sample.content_col.content_cols[1].content_col_idx == 28
    @test sample.content_col.content_cols[2] isa UnROOT.StringField
    @test sample.content_col.content_cols[2].offset_col.content_col_idx == 29
    @test sample.content_col.content_cols[2].content_col.content_col_idx == 30
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

@testset "RNTuple struct reading" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_vfloat_tlv_vtlv.root")
    df = LazyTree(f1, "ntuple")
    @test df.two_v_floats == Vector{Float32}[Float32[9.0, 8.0, 7.0, 6.0], Float32[5.0, 4.0, 3.0], Float32[2.0, 1.0], Float32[0.0, -1.0], Float32[-2.0]]
    @test df.three_LV[1] === (pt = 19.0f0, eta = 19.0f0, phi = 19.0f0, mass = 19.0f0)
    @test df.three_LV[end] === df.three_LV[5] === (pt = 16.0f0, eta = 16.0f0, phi = 16.0f0, mass = 16.0f0)
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

    @test df.vector_variant_int64_string == Vector{Union{Int64, String}}[Union{Int64, String}["one"], Union{Int64, String}["one", 2], Union{Int64, String}["one", 2, 3], Union{Int64, String}["one", 2, 3, 4], Union{Int64, String}["one", 2, 3, 4, 5]]
end

nthreads == 1 && @warn "Running on a single thread. Please re-run the test suite with at least two threads (`julia --threads 2 ...`)"

@testset "RNTuple Multi-threading" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    df = LazyTree(f1, "ntuple")

    field = df.one_integers
    accumulator = zeros(Int, nthreads)
    Threads.@threads for i in eachindex(field)
        @inbounds accumulator[Threads.threadid()] += field[i]
    end
    # test we've hit each thread's buffer
    @test all(!isempty, field.buffers)
    @test sum(accumulator) == sum(1:5e4)

    accumulator .= 0
    Threads.@threads for evt in df
        @inbounds accumulator[Threads.threadid()] += evt.one_integers
    end
    @test sum(accumulator) == sum(1:5e4)
end

