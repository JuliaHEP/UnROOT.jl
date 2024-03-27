using Test
using UnROOT


@testset "Type stability" begin
    rootfile = UnROOT.samplefile("NanoAODv5_sample.root")
    t = LazyTree(rootfile, "Events", ["MET_pt"])[1:10]

    function f1()
        s = 0.0f0
        for evt in t
            s += evt.MET_pt
        end
        s
    end
    f2() = sum(t.MET_pt)

    @inferred f1()
    @inferred f2()

    close(rootfile)
end
