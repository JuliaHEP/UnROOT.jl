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
    @test f["AK4CategPresel_cutflow"][:fXaxis_fLabels].objects == binlabels
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

    f = UnROOT.samplefile("TH3D.root")
    h = f["histogram"]
    @test 45699.0 ≈ h[:fTsumw]
    @test 45699.0 ≈ h[:fTsumw2]
    @test 1338408313.7224275 ≈ h[:fTsumwx]
    @test 1.5255146094082097e+18 ≈ h[:fTsumwx2]
    @test 4896839597.196363 ≈ h[:fTsumwy]
    @test 6.085356004202659e+18 ≈ h[:fTsumwy2]
    @test 2.0684178180322988e+16 ≈ h[:fTsumwxy]
    @test -4245948793.9911203 ≈ h[:fTsumwz]
    @test 1.371446541434572e+19 ≈ h[:fTsumwz2]
    @test -2.3310169613924896e+16 ≈ h[:fTsumwxz]
    @test -3.838438776730456e+16 ≈ h[:fTsumwyz]
    @test 2 == h[:fStatOverflows]
    @test -1111 == h[:fMinimum]
    @test -1111 == h[:fMaximum]
    @test 99999.0 == h[:fEntries]
    @test 0.0 == h[:fNormFactor]

    @test 10 == h[:fXaxis_fNbins]
    @test -10000000.0 == h[:fXaxis_fXmin]
    @test 10000000.0 == h[:fXaxis_fXmax]
    @test 0 == h[:fXaxis_fFirst]
    @test 0 == h[:fXaxis_fLast]

    @test 20 == h[:fYaxis_fNbins]
    @test -20000000.0 == h[:fYaxis_fXmin]
    @test 20000000.0 == h[:fYaxis_fXmax]
    @test 0 == h[:fYaxis_fFirst]
    @test 0 == h[:fYaxis_fLast]

    @test 30 == h[:fZaxis_fNbins]
    @test -30000000.0 == h[:fZaxis_fXmin]
    @test 30000000.0 == h[:fZaxis_fXmax]
    @test 0 == h[:fZaxis_fFirst]
    @test 0 == h[:fZaxis_fLast]
    close(f)

    # issue #168 — TH1 v3 / TAxis v6: old ROOT file format (before automatic schema
    # evolution for these classes was bumped to the current versions).
    f = UnROOT.samplefile("dedx2COMET.root")
    h = f["h1"]
    @test 999999.0 == h[:fEntries]
    @test 100 == h[:fXaxis_fNbins]
    @test 0.0 == h[:fXaxis_fXmin]
    @test 2.0 == h[:fXaxis_fXmax]
    @test 102 == length(h[:fSumw2])
    @test 102 == length(h[:fN])
    close(f)

    # issue #368 — parseTH for various histogram shapes and types
    # detector_01: TH2D with 1 x-bin and 18 y-bins (weighted entries)
    f = UnROOT.samplefile("issue368_detector_01.root")
    th = UnROOT.parseTH(f["detector"]; raw=false)
    @test size(bincounts(th)) == (1, 18)
    @test binedges(th) == ([-0.5, 0.5], collect(0.5:1.0:18.5))
    @test 18.0 == f["detector"][:fEntries]
    @test bincounts(th)[1, 1] ≈ 3.8658676965592687
    @test bincounts(th)[1, 2] ≈ 4.1477256011194195
    @test sum(bincounts(th)) ≈ 72.74561242725682
    @test size(th.sumw2) == (1, 18)
    close(f)

    # detector_03 and detector_06: same shape, different data
    for (fname, expected_entries, expected_sum) in [
            ("issue368_detector_03.root", 17.0, 70.65136726472892),
            ("issue368_detector_06.root", 18.0, 63.34617303726971),
        ]
        f = UnROOT.samplefile(fname)
        th = UnROOT.parseTH(f["detector"]; raw=false)
        @test size(bincounts(th)) == (1, 18)
        @test expected_entries == f["detector"][:fEntries]
        @test sum(bincounts(th)) ≈ expected_sum
        close(f)
    end

    # detector_merged: TH2D with 4 x-bins and 18 y-bins (merge of multiple detectors)
    f = UnROOT.samplefile("issue368_detector_merged.root")
    th = UnROOT.parseTH(f["detector"]; raw=false)
    @test size(bincounts(th)) == (4, 18)
    @test 53.0 == f["detector"][:fEntries]
    @test bincounts(th)[1, 1] ≈ 3.8658676965592687
    @test bincounts(th)[2, 3] ≈ 3.8161558387265013
    @test sum(bincounts(th)) ≈ 206.74315272925546
    @test size(th.sumw2) == (4, 18)
    close(f)

    # test: TH2D with 32 x-bins and 18 y-bins
    f = UnROOT.samplefile("issue368_test.root")
    th = UnROOT.parseTH(f["detector"]; raw=false)
    @test size(bincounts(th)) == (32, 18)
    @test 469.0 == f["detector"][:fEntries]
    @test sum(bincounts(th)) ≈ 1673.7181862148902
    close(f)

    # pyhf_test_histograms: two TH1D histograms with 43 bins each
    f = UnROOT.samplefile("issue368_pyhf_test_histograms.root")
    th_bkg = UnROOT.parseTH(f["h_bkg"]; raw=false)
    th_sig = UnROOT.parseTH(f["h_sig"]; raw=false)
    @test length(bincounts(th_bkg)) == 43
    @test binedges(th_bkg) == collect(130.0:20.0:990.0)
    @test 870.0 == f["h_bkg"][:fEntries]
    @test bincounts(th_bkg)[1] ≈ 2.1360466600930423e8
    @test bincounts(th_bkg)[2] ≈ 1.4139781437516856e8
    @test sum(bincounts(th_bkg)) ≈ 7.613936311815422e8
    @test length(bincounts(th_sig)) == 43
    @test 1740.0 == f["h_sig"][:fEntries]
    @test bincounts(th_sig)[1] ≈ 2016.471097311273
    @test sum(bincounts(th_sig)) ≈ 83192.95516266659
    close(f)

    # th2f: large TH2F with 1920 x-bins and 255 y-bins
    f = UnROOT.samplefile("issue368_th2f.root")
    th = UnROOT.parseTH(f["myHisto"]; raw=false)
    @test size(bincounts(th)) == (1920, 255)
    @test 74880.0 == f["myHisto"][:fEntries]
    @test sum(bincounts(th)) ≈ 33451.23003458977
    @test bincounts(th)[1, 199] ≈ 1.0
    close(f)
end
