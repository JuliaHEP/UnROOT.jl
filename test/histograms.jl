using Test
using UnROOT


@testset "histograms" begin
    f = UnROOT.samplefile("histograms1d2d.root")
    for k in ["myTH1F", "myTH1D"]
        @test f[k][:fName] == k
        @test f[k][:fEntries] == 4.0
        @test f[k][:fSumw2] == [0.0, 800.0, 2.0, 0.0]
        @test f[k][:fXaxis_fXmin] == -2.0
        @test f[k][:fXaxis_fXmax] == 2.0
        @test f[k][:fXaxis_fXbins] == []
        @test f[k][:fXaxis_fNbins] == 2
        @test f[k][:fN] == [0.0, 40.0, 2.0, 0.0]
    end

    k = "myTH1D_nonuniform"
    @test f[k][:fName] == k
    @test f[k][:fEntries] == 4.0
    @test f[k][:fSumw2] == [0.0, 800.0, 2.0, 0.0]
    @test f[k][:fXaxis_fXmin] == -2.0
    @test f[k][:fXaxis_fXmax] == 2.0
    @test f[k][:fXaxis_fXbins] == [-2, 1, 2]
    @test f[k][:fXaxis_fNbins] == 2
    @test f[k][:fN] == [0.0, 40.0, 2.0, 0.0]

    for k in ["myTH2F", "myTH2D"]
        @test f[k][:fName] == k
        @test f[k][:fEntries] == 4.0
        @test f[k][:fSumw2] == [0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test f[k][:fXaxis_fXmin] == -2.0
        @test f[k][:fXaxis_fXmax] == 2.0
        @test f[k][:fXaxis_fXbins] == []
        @test f[k][:fXaxis_fNbins] == 2
        @test f[k][:fYaxis_fXmin] == -2.0
        @test f[k][:fYaxis_fXmax] == 2.0
        @test f[k][:fYaxis_fXbins] == []
        @test f[k][:fYaxis_fNbins] == 4
        @test f[k][:fN] == [0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    end

    th1 = UnROOT.parseTH(f["myTH1F"];raw=false)
    @test bincounts(th1) == [40.0, 2.0]
    @test binedges(th1) == -2.0:2.0:2.0
    @test th1.sumw2 == [800.0, 2.0]

    th2 = UnROOT.parseTH(f["myTH2D"];raw=false)
    @test bincounts(th2) == [20.0 0.0 0.0 20.0; 1.0 0.0 0.0 1.0]
    @test binedges(th2) == (-2.0:2.0:2.0, -2.0:1.0:2.0)
    @test th2.sumw2 == [400.0 0.0 0.0 400.0; 1.0 0.0 0.0 1.0]

    th3 = UnROOT.parseTH(f["myTH1D_nonuniform"];raw=false)
    @test bincounts(th3) == [40.0, 2.0]
    @test binedges(th3) == [-2.0, 1.0, 2.0]
    @test th3.sumw2 == [800.0, 2.0]

    close(f)

    f = UnROOT.samplefile("TH2_5.root")
    h = UnROOT.TH2F(f.fobj, f.directory.keys[1], f.streamers.refs)
        @test h[:fName] == "myTH2F"
        @test h[:fEntries] == 4.0
        @test h[:fSumw2] == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 400.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        @test h[:fXaxis_fXmin] == -2.0
        @test h[:fXaxis_fXmax] == 2.0
        @test h[:fXaxis_fXbins] == []
        @test h[:fXaxis_fNbins] == 4
        @test h[:fYaxis_fXmin] == -2.0
        @test h[:fYaxis_fXmax] == 2.0
        @test h[:fYaxis_fXbins] == []
        @test h[:fYaxis_fNbins] == 4
        @test h[:fN] == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 20.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    close(f)

    f = UnROOT.samplefile("cms_ntuple_wjet.root")
    binlabels = ["Root", "Weight", "Preselection", "SelectGenPart", "GoodRunsList", "EventFilters", "SelectLeptons", "SelectJets", "Trigger", "ObjectsSelection", "SSPreselection", "NjetGeq4", "AK4CategTagHiggsJets", "AK4CategTagVBSJets", "AK4CategChannels", "AK4CategPresel"]
    @test f["AK4CategPresel_cutflow"][:fXaxis_fModLabs].objects == binlabels
    close(f)
end
