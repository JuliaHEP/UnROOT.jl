using Test
using UnROOT
using FHist


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

    f = UnROOT.samplefile("TH3F.root")
    h = f["histogram"]
    @test 45699.0 ≈ h[:fTsumw]
    @test 45699.0 ≈ h[:fTsumw2]
    @test 133.84083137224275 ≈ h[:fTsumwx]
    @test 15255.146094082058 ≈ h[:fTsumwx2]
    @test 489.6839597196363 ≈ h[:fTsumwy]
    @test 60853.5600420268 ≈ h[:fTsumwy2]
    @test 206.84178180322968 ≈ h[:fTsumwxy]
    @test -424.5948793991111 ≈ h[:fTsumwz]
    @test 137144.65414345643 ≈ h[:fTsumwz2]
    @test -233.101696139249 ≈ h[:fTsumwxz]
    @test -383.8438776730445 ≈ h[:fTsumwyz]
    @test 2 == h[:fStatOverflows]
    @test -1111 == h[:fMinimum]
    @test -1111 == h[:fMaximum]
    @test 99999.0 == h[:fEntries]
    @test 0.0 == h[:fNormFactor]

    @test 10 == h[:fXaxis_fNbins]
    @test -1.0 == h[:fXaxis_fXmin]
    @test 1.0 == h[:fXaxis_fXmax]
    @test 0 == h[:fXaxis_fFirst]
    @test 0 == h[:fXaxis_fLast]

    @test 20 == h[:fYaxis_fNbins]
    @test -2.0 == h[:fYaxis_fXmin]
    @test 2.0 == h[:fYaxis_fXmax]
    @test 0 == h[:fYaxis_fFirst]
    @test 0 == h[:fYaxis_fLast]

    @test 30 == h[:fZaxis_fNbins]
    @test -3.0 == h[:fZaxis_fXmin]
    @test 3.0 == h[:fZaxis_fXmax]
    @test 0 == h[:fZaxis_fFirst]
    @test 0 == h[:fZaxis_fLast]
    close(f)
end
