using Test
using UnROOT


@testset "SourceStream remote" begin
    r = ROOTFile("root://eospublic.cern.ch//eos/root-eos/cms_opendata_2012_nanoaod/Run2012B_DoubleMuParked.root")
    @test r["Events"].fEntries == 29308627
    show(devnull, r) # test display

    t = LazyTree("https://scikit-hep.org/uproot3/examples/Zmumu.root", "events")
    @test t.eta1[1] ≈ -1.21769
    @test t.eta1[end] ≈ -1.57044
    show(devnull, t) # test display
end
