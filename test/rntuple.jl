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

@testset "RNTuple Display" begin
    f = UnROOT.samplefile("RNTuple/test_ntuple_stl_containers.root")
    _io1 = IOBuffer()
    show(_io1, f)
    _io2 = IOBuffer()
    show(_io2, f.header)

    s1 = String(take!(_io1))
    s2 = String(take!(_io2))
    # displaying just the header shows more details
    @test length(s2) > length(s1)
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

    @test eltype(df.vector_int32) <: AbstractVector{Int32}
    @test df.vector_int32 == [Int32[1], Int32[1,2], Int32[1,2,3], Int32[1,2,3,4], Int32[1,2,3,4,5]]

    # a variant without value (`valueless_by_exception`, tag 0) reads as `missing`
    @test eltype(df.variant_int32_string) == Union{Missing, Int32, String}
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

@testset "RNTuple Type stability" begin
    f1 = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
    t = LazyTree(f1, "ntuple")

    function func1()
        s = 0.0f0
        for evt in t
            s += evt.one_integers
        end
        s
    end
    g() = sum(t.one_integers)

    @test (@inferred func1() > 0)
    @test (@inferred g() > 0)
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
        map(field.slots) do box
            s = UnROOT._load_slot(box)
            return s === nothing || !isempty(s.buffer)
        end)
    @test sum(accumulator) == sum(1:5e4)

    accumulator .= 0
    Threads.@threads for evt in df
        @inbounds accumulator[Threads.threadid()] += evt.one_integers
    end
    @test sum(accumulator) == sum(1:5e4)
end

# @testset "String and Regex Selection" begin
#     f1 = UnROOT.samplefile("RNTuple/DAOD_TRUTH3_RC2.root")
#     df = LazyTree(f1, "EventData", r"AntiKt4TruthDressedWZ")
#     @test "AntiKt4TruthDressedWZJetsAux:" ∈ names(df)
#     df2 = LazyTree(joinpath(@__DIR__, "./samples/RNTuple/DAOD_TRUTH3_RC2.root"),
#         "EventData", r"AntiKt4TruthDressedWZ")
#     names(df) == names(df2)
#     df3 = LazyTree(joinpath(@__DIR__, "./samples/RNTuple/DAOD_TRUTH3_RC2.root"),
#         "EventData",
#         ["AntiKt4TruthDressedWZJetsAux:",
#             "AntiKt4TruthDressedWZJetsAux::PartonTruthLabelID"]
#     )
#     @test length(names(df3)) == 2
#     df4 = LazyTree(joinpath(@__DIR__, "./samples/RNTuple/DAOD_TRUTH3_RC2.root"),
#         "EventData",
#         "AntiKt4TruthDressedWZJetsAux::PartonTruthLabelID"
#     )
#     @test length(names(df4)) == 1
# end

# @testset "Skim the schema" begin
#     f1 = UnROOT.samplefile("RNTuple/DAOD_TRUTH3_RC2.root")
#     df_full = LazyTree(f1, "EventData")
#     df1 = LazyTree(f1, "EventData", r"AntiKt4TruthDressedWZ")
#     @test 0 < length(names(df1)) < length(names(df_full))
#     @test "AntiKt4TruthDressedWZJetsAux:" ∈ names(df1)
#     @test length(df1[!, 1].rn.schema) < length(df_full[!, 1].rn.schema)
# end

# @testset "Skip Recursively Empty Structs" begin
#     f1 = UnROOT.samplefile("RNTuple/DAOD_TRUTH3_RC2.root")
#     df = LazyTree(f1, "EventData", r"AntiKt4TruthDressedWZ")
#     truth_jets_one_event = df.var"AntiKt4TruthDressedWZJetsAux:"[1]
#     @test :pt ∈ propertynames(truth_jets_one_event)
#     @test length(truth_jets_one_event.pt) == 5
# end

# @testset "Footer extension header links backfill" begin
#     f1 = UnROOT.samplefile("RNTuple/test_ntuple_extension_columns.root")
#     df = LazyTree(f1, "EventData")
#     pbs = collect(df.var"HLT_AntiKt4EMPFlowJets_subresjesgscIS_ftf_TLAAux::fastDIPS20211215_pb")
#     @test length(pbs) == 40
#     @test findfirst(!isempty, pbs) == 37
#     jets = collect(df.var"HLT_AntiKt4EMPFlowJets_subresjesgscIS_ftf_TLAAux:")

#     @test length.(pbs) == length.(getproperty.(jets, :pt))

#     # backfilled booleans
#     xTrigDecisionAux = collect(df.var"xTrigDecisionAux:")
#     @test length(xTrigDecisionAux) == length(pbs)
# end

@testset "RNTuple Tables.jl and Arrow integration" begin
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

# Test files from scikit-hep-testdata (same source as uproot's test suite),
# all written with the final RNTuple spec (anchor version 1.0.x.x).
# Expected values cross-checked against uproot 5.7.4.
@testset "RNTuple v1.0 spec files (scikit-hep-testdata)" begin
    @testset "int + float" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_int_float_rntuple_v1-0-0-0.root"), "ntuple")
        @test collect(t.one_integers) == Int32.(9:-1:0)
        @test collect(t.two_floats) == Float32[9.9, 8.8, 7.7, 6.6, 5.5, 4.4, 3.3, 2.2, 1.1, 0.0]
    end

    @testset "bit column" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_bit_rntuple_v1-0-0-0.root"), "ntuple")
        @test collect(t.one_bit) == Bool[1, 0, 0, 1, 0, 0, 1, 0, 0, 1]
    end

    @testset "split-int zigzag (large magnitudes)" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_splitint_rntuple_v1-0-1-0.root"), "ntuple")
        @test collect(t.int16)[1:6] == Int16[0, 1, -1, 16384, -16384, 32767]
        @test collect(t.int32)[1:6] == Int32[0, 1, -1, 1073741824, -1073741824, 2147483647]
        @test collect(t.int64)[1:6] == Int64[0, 1, -1, 4611686018427387904, -4611686018427387904, 9223372036854775807]
    end

    @testset "multicluster index" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_index_multicluster_rntuple_v1-0-0-0.root"), "ntuple")
        v = collect(t.int_vector)
        # two clusters of 100 entries: [i, i] then [i, i+1]
        @test v == [[Int16[i, i] for i in 0:99]; [Int16[i, i+1] for i in 0:99]]
    end

    @testset "deferred (extension) columns" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_extension_columns_rntuple_v1-0-0-0.root"), "ntuple")
        ff = collect(t.float_field)
        iv = collect(t.intvec_field)
        @test length(ff) == length(iv) == 600
        # float_field deferred from entry 200: zeros before (values cross-checked with uproot)
        @test all(iszero, ff[1:200])
        @test ff[201:206] == Float32[0.5, 1.5, 2.5, 3.5, 4.5, 5.5]
        @test ff[end-2:end] == Float32[197.5, 198.5, 199.5]
        # intvec_field deferred from entry 400: empty before
        @test all(isempty, iv[1:400])
        @test iv[401] == Int32[0, 1]
        @test iv[600] == Int32[199, 200]
    end

    @testset "nested structs" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_nested_structs_rntuple_v1-0-0-0.root"), "ntuple")
        s = collect(t.my_struct)
        @test length(s) == 10
        @test s[1].i == 0
        @test s[1].sub_struct.i == 1
        @test s[1].sub_struct.sub_sub_struct.i == 2
        @test s[1].sub_struct.sub_sub_struct.v == Int32[0, 1]
        @test s[10].sub_struct.sub_sub_struct.v == Int32[9, 10]
    end

    @testset "stl containers (v1.0)" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_stl_containers_rntuple_v1-0-0-0.root"), "ntuple")
        @test collect(t.string) == ["one", "two", "three", "four", "five"]
        @test collect(t.vector_int32) == [Int32.(1:n) for n in 1:5]
        @test collect(t.vector_string) == [["one", "two", "three", "four", "five"][1:n] for n in 1:5]
    end

    @testset "truncated and quantized floats" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_float_types_rntuple_v1-0-0-0.root"), "ntuple")
        # values cross-checked against uproot
        @test collect(t.trunc10)[1:3] ≈ Float32[1.0, 1.319414f13, -4.2351647f-22]
        @test collect(t.trunc16)[1:3] ≈ Float32[1.234375, 1.4637249f13, -6.2865727f-22]
        @test collect(t.trunc24)[1:3] ≈ Float32[1.2345581, 1.4660066f13, -6.2874774f-22]
        @test collect(t.trunc31)[1:3] ≈ Float32[1.2345679, 1.4660154f13, -6.2875986f-22]
        @test collect(t.quant1)[1:3] == Float32[3.0, 3.0, -2.0]
        @test collect(t.quant8)[1:3] ≈ Float32[1.2352941, 1.6666666, 0.0]
        @test collect(t.quant16)[1:3] ≈ Float32[1.2345312, 1.6666666, 0.0]
        @test collect(t.quant20)[1:3] ≈ Float32[1.234566, 1.6666666, 0.0]
        @test collect(t.quant24)[1:3] ≈ Float32[1.2345679, 1.6666666, 0.0]
        @test collect(t.quant25)[1:3] ≈ Float32[1.2345679, 1.6666665, -5.9604645f-8]
        @test collect(t.quant32)[1:3] ≈ Float32[1.2345679, 1.6666666, 0.0]
    end

    @testset "real-world staff ntuple" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/ntpl001_staff_rntuple_v1-0-0-0.root"), "Staff")
        @test length(t) == 3354
        @test collect(t.Category)[1:4] == Int32[202, 530, 316, 361]
        @test collect(t.Division)[1:4] == ["PS", "EP", "PS", "PS"]
        @test collect(t.Nation)[end] == "ZZ"
        @test collect(t.Cost)[end] == 12716
    end
end

# More files from scikit-hep-testdata; every value below was cross-checked
# against uproot 5.7.6 (all fields of all these files agree with uproot).
@testset "RNTuple v1.0 spec files, part 2" begin
    @testset "multiple cluster groups" begin
        f = UnROOT.samplefile("RNTuple/test_multiple_cluster_groups_rntuple_v1-0-0-0.root")
        rn = f["ntuple"]
        @test length(rn.footer.cluster_group_records) == 3
        t = LazyTree(f, "ntuple")
        @test length(t) == 1000
        # entries beyond the first cluster group live in the 2nd and 3rd group
        @test collect(t.one) == Int32.(0:999)
        @test t.one[1000] == 999
        @test t.int_vector[1] == Int16[0, 1]
        @test t.int_vector[500] == Int16[499, 500]
        @test t.int_vector[1000] == Int16[999, 1000]
        # 5 + 4 + 3 clusters
        @test length(UnROOT._clusterranges(t)) == 12
        @test sum(length, Tables.partitions(t)) == 1000
        @test sum(p -> sum(p.one), Tables.partitions(t)) == sum(0:999)
    end

    @testset "multiple column representations (suppressed columns)" begin
        # one `float` field stored as Real32 in some clusters and Real16 in others
        f = UnROOT.samplefile("RNTuple/test_multiple_representations_rntuple_v1-0-0-0.root")
        rn = f["ntuple"]
        @test length(rn.header.column_records) == 2
        leaf = rn.schema.real
        @test leaf isa UnROOT.LeafField{Float32}
        @test length(leaf.alt_col_idx) == 1
        t = LazyTree(f, "ntuple")
        @test eltype(t.real) == Float32
        @test collect(t.real) == Float32[1.0, 2.0, 3.0]
    end

    @testset "std::atomic and std::bitset" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_atomic_bitset_rntuple_v1-0-0-0.root"), "ntuple")
        @test collect(t.atomic_int) == Int32[1, 2, 3]
        @test eltype(t.atomic_int) == Int32
        @test length(t.bitset[1]) == 42
        @test eltype(t.bitset[1]) == Bool
        @test findall(t.bitset[1]) == [2, 4, 6]
        @test findall(t.bitset[2]) == [2, 4, 6, 8, 10, 12, 14, 16]
        @test findall(t.bitset[3]) == [4, 8, 12, 16]
    end

    @testset "empty struct and valueless variant" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_emptystruct_invalidvar_rntuple_v1-0-0-0.root"), "ntuple")
        @test length(t) == 3
        @test collect(t.empty_struct) == [(;), (;), (;)]
        v = collect(t.variant)
        @test eltype(t.variant) == Union{Missing, Int32, @NamedTuple{i::Int32}}
        @test v[1] === Int32(1)
        @test ismissing(v[2])   # tag 0: variant without value
        @test v[3] == (i = Int32(2),)
    end

    @testset "class inheritance is flattened" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_class_inheritance_rntuple_v1-0-0-1.root"), "rntpl")
        @test length(t) == 10
        c = t.child[2]
        # base class members appear as direct members, like in ROOT and uproot
        @test Set(propertynames(c)) == Set([:child_1, :child_2, :base_a1, :base_a2, :base_a3])
        @test c.child_1 == 2 && c.child_2 == 20.0 && c.base_a1 == 1 && c.base_a2 ≈ 0.1 && c.base_a3 == [0, 1, 2]
        g = t.grandchild[10]
        @test g.grandchild_1 == 27 && g.child_1 == 18 && g.base_a3 == [0, 9, 18]
        # the same base class inherited via two paths is disambiguated by the class name
        m = t.multi_grandparent[2]
        @test Set(propertynames(m)) == Set([:multi_grand_parent1, :multi_grand_parent2, :multi_parent_1, :multi_parent_2, :base_b,
                                            Symbol("MultiParent::base_a1"), Symbol("MultiParent::base_a2"), Symbol("MultiParent::base_a3"),
                                            :child_1, :child_2, Symbol("Child::base_a1"), Symbol("Child::base_a2"), Symbol("Child::base_a3")])
        @test m.multi_grand_parent1 == 5 && m.base_b == 10.0 && m.child_1 == 2
        @test getproperty(m, Symbol("MultiParent::base_a3")) == [0, 1, 2]
        @test getproperty(m, Symbol("Child::base_a2")) ≈ 0.1
        mp = t.multi_parent[10]
        @test Set(propertynames(mp)) == Set([:multi_parent_1, :multi_parent_2, :base_b, :base_a1, :base_a2, :base_a3])
        @test mp.multi_parent_1 == 36 && mp.base_b == 90.0 && mp.base_a1 == 9
    end

    @testset "struct and vector<struct> (LorentzVector-like)" begin
        t = LazyTree(UnROOT.samplefile("RNTuple/test_int_vfloat_tlv_vtlv_rntuple_v1-0-0-0.root"), "ntuple")
        @test collect(t.one_integers) == Int32[9, 8, 7, 6, 5]
        @test t.two_v_floats[1] == Float32[9, 8, 7, 6]
        @test t.three_LV[1] === (pt = 19.0f0, eta = 19.0f0, phi = 19.0f0, mass = 19.0f0)
        @test length(t.four_v_LVs[2]) == 7
        @test t.four_v_LVs[2][5] == (pt = 18.0f0, eta = 18.0f0, phi = 18.0f0, mass = 18.0f0)
    end

    @testset "NanoAOD RNTupleImporter file (very wide structs)" begin
        f = UnROOT.samplefile("RNTuple/cmsopendata2015_ttbar_19980_NANOAOD_RNTupleImporter_rntuple_v1-0-0-1.root")
        # constructing the tree used to fail: `view` of a StructArray with >= 32
        # columns is not inferrable, so it cannot back a VectorOfVectors
        t = LazyTree(f, "Events")
        @test length(t) == 10
        @test length(propertynames(t)) == 969   # top-level fields
        @test collect(t.nElectron) == UInt32[0, 0, 3, 1, 1, 2, 0, 5, 0, 1]
        @test t.Electron_pt[3] ≈ Float32[55.494945, 22.64056, 11.299458]
        # the collection containing the electron members is a wide struct
        wide = [p for p in propertynames(t) if begin
                    E = eltype(getproperty(t, p))
                    E <: AbstractVector && eltype(E) <: NamedTuple && :Electron_pt ∈ fieldnames(eltype(E))
                end]
        @test length(wide) == 1
        col = getproperty(t, only(wide))
        @test length(fieldnames(eltype(eltype(col)))) >= 32
        @test length(col[3]) == 3
        @test col[3][1].Electron_pt ≈ 55.494945f0
        # every field of the first event is readable
        for p in propertynames(t)
            getproperty(t, p)[1]
        end
        @test true
    end

    @testset "ATLAS PHYSLITE" begin
        f = UnROOT.samplefile("RNTuple/uproot-physlite-rntuple_v1-0-0-0.root")
        # the checksummed part of the DataHeader header envelope is 1217 bytes
        # long: a previous hash dependency miscomputed XXH3 for lengths ≡ 1 (mod
        # 64) and the checksum verification rejected the file
        @test (f["DataHeader"].anchor.fLenHeader - 8) % 64 == 1
        dh = LazyTree(f, "DataHeader")
        @test length(dh) == 100
        @test dh[2].DataHeader.m_commonOID2 == 0x0038295400000001
        @test length(dh[2].DataHeader.m_fullElements) == 5
        @test dh[2].DataHeader.m_fullElements[1] == (oid2 = 0x00000c7400000001, dbIdx = 0x00000001, objIdx = 0x00000063)
        t = LazyTree(f, "EventData")
        @test length(t) == 100
        @test length(propertynames(t)) == 854   # top-level fields
        @test t.var"EventInfoAuxDyn:eventNumber"[1:3] == [293298001, 293298007, 293298017]
        pt = t.var"AnalysisJetsAuxDyn:pt"
        @test length(pt[1]) == 9
        @test pt[1][1:3] ≈ Float32[121843.53, 115375.39, 77780.22]
        @test t.var"AnalysisElectronsAuxDyn:pt"[2] ≈ Float32[23935.309]
        # `DataVector<xAOD::Jet_v1>` items carry no data themselves (everything
        # is in the Aux stores): a vector of empty structs, sized by the offsets
        @test length.(t.AnalysisJets[1:10]) == [9, 8, 9, 4, 7, 11, 8, 11, 4, 9]
        @test t.AnalysisJets[1][1] == (;)
        et = LazyTree(f, "EventTag")
        @test et.EventNumber[1:3] == [293298001, 293298007, 293298017]
    end

    @testset "unknown field name" begin
        f = UnROOT.samplefile("RNTuple/test_ntuple_int_5e4.root")
        @test_throws KeyError LazyTree(f, "ntuple", ["nonexistent"])
    end
end
