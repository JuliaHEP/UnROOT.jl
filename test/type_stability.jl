using Test
using UnROOT


@testset "Type stability" begin
    @testset "LazyTree iteration over scalar branch" begin
        rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
        t = LazyTree(rootfile, "Events", ["MET_pt"])[1:10]

        function sum_met(t)
            s = 0.0f0
            for evt in t
                s += evt.MET_pt
            end
            s
        end

        @inferred sum_met(t)
        @inferred sum(t.MET_pt)
        close(rootfile)
    end

    @testset "LazyBranch scalar indexing" begin
        rootfile = UnROOT.samplefile("tree_with_large_array.root")
        ba_int = LazyBranch(rootfile, "t1/int32_array")
        ba_flt = LazyBranch(rootfile, "t1/float_array")

        # single-index access must be type-stable
        @inferred ba_int[1]
        @inferred ba_flt[1]
        @inferred ba_int[end]
        @inferred ba_flt[end]

        close(rootfile)
    end

    @testset "LazyBranch jagged indexing" begin
        rootfile = UnROOT.samplefile("tree_with_jagged_array.root")
        ba = LazyBranch(rootfile, "t1/int32_array")

        @inferred ba[1]
        @inferred ba[end]

        close(rootfile)

        rootfile = UnROOT.samplefile("tree_with_jagged_array_double.root")
        ba = LazyBranch(rootfile, "t1/double_array")

        @inferred ba[1]
        @inferred ba[end]

        close(rootfile)
    end

    @testset "LazyBranch iteration" begin
        rootfile = UnROOT.samplefile("tree_with_large_array.root")
        ba = LazyBranch(rootfile, "t1/int32_array")

        function sum_branch(ba)
            s = Int64(0)
            for x in ba
                s += x
            end
            s
        end

        @inferred sum_branch(ba)
        close(rootfile)
    end

    @testset "LazyTree row access type stability" begin
        rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
        t = LazyTree(rootfile, "Events", ["MET_pt", "nMuon"])

        getrow(t, i) = t[i]
        getmet(t, i) = t[i].MET_pt
        getnmuon(t, i) = t[i].nMuon

        @inferred getrow(t, 1)
        @inferred getmet(t, 1)
        @inferred getnmuon(t, 1)

        close(rootfile)
    end

    @testset "LazyEvent field access type stability" begin
        rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
        t = LazyTree(rootfile, "Events", ["MET_pt", "nMuon", "Muon_pt"])

        evt = t[1]
        getmet(evt) = evt.MET_pt
        getnmuon(evt) = evt.nMuon
        getmuonpt(evt) = evt.Muon_pt

        @inferred getmet(evt)
        @inferred getnmuon(evt)
        @inferred getmuonpt(evt)

        close(rootfile)
    end

    @testset "basketarray type stability" begin
        rootfile = UnROOT.samplefile("tree_with_large_array.root")
        branch = rootfile["t1"]["int32_array"]

        get_basket(f, b) = UnROOT.basketarray(f, b, 1)
        @inferred get_basket(rootfile, branch)

        close(rootfile)
    end

    @testset "LazyTree column access via getproperty" begin
        rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
        t = LazyTree(rootfile, "Events", ["MET_pt", "nMuon"])

        getcol_float(t) = t.MET_pt
        getcol_uint(t) = t.nMuon

        @inferred getcol_float(t)
        @inferred getcol_uint(t)

        close(rootfile)
    end
end
