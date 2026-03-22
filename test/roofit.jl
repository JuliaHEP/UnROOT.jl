using Test
using UnROOT

@testset "RooFitResult" begin
    f = UnROOT.samplefile("roofit_result_realworld.root")
    result = f["nll"]

    @test result isa UnROOT.RooFitResult
    @test result.name == "nll"
    @test result.status == -1
    @test result.covqual == 2
    @test result.edm ≈ 0.014090517273824262
    @test result.minnll ≈ -178536.03672914507
    @test result.numbadnll == 0

    @test result.constpars isa UnROOT.RooArgList
    @test result.initpars isa UnROOT.RooArgList
    @test result.finalpars isa UnROOT.RooArgList
    @test length(result.constpars) == 82
    @test length(result.initpars) == 389
    @test length(result.finalpars) == 389

    first_final = result.finalpars[1]
    @test first_final isa UnROOT.RooRealVar
    @test first_final.name == "SI2_00"
    @test first_final.value ≈ -1.8252763390685456
    @test first_final.error ≈ 0.79984069066555175

    @test result.finalpars["SI2_01"].value ≈ 0.76333421068542007
    @test result.finalpars["SI2_01"].error ≈ 0.42208430228632055
    @test result.finalpars["SI2_02"].value ≈ -2.4544611236639802
    @test result.finalpars["SI2_04"].value ≈ -2.613183099470453
    @test result.finalpars["SI2_05"].value ≈ -4.2837665773207991
    @test result.finalpars["SI2_06"].value ≈ -5.1379624978482523
    @test result.finalpars["SI2_00"] === first_final
    @test first_final.plotbins == 100
    @test first_final.unit == ""
    @test first_final.label == ""
    @test first_final.bool_attributes == Set{String}()
    @test first_final.string_attributes == Dict{String, String}()

    @test result.correlation_matrix isa Matrix{Float64}
    @test result.covariance_matrix isa Matrix{Float64}
    @test size(result.correlation_matrix) == (389, 389)
    @test size(result.covariance_matrix) == (389, 389)
    @test result.correlation_matrix[1, 1] == 0.0
    @test result.correlation_matrix[1, 2] == 0.0
    @test result.correlation_matrix[2, 2] == 0.0
    @test result.covariance_matrix[1, 1] == 0.0
    @test result.covariance_matrix[1, 2] == 0.0
    @test result.covariance_matrix[2, 2] == 0.0

    @test result.global_correlation_coefficients isa Vector{Float64}
    @test length(result.global_correlation_coefficients) == 389
    @test result.global_correlation_coefficients[1] ≈ 1.0099761526156472
    @test result.global_correlation_coefficients[2] ≈ 1.007696988338753
    @test result.global_correlation_coefficients[3] ≈ 1.0055821548962376
    @test occursin("RooFitResult(nll, 389 floating parameters)", sprint(show, result))
    @test occursin("RooArgList(389 entries)", sprint(show, result.finalpars))
    shown_var = sprint(show, first_final)
    @test occursin("RooRealVar(SI2_00=-1.8252763390685456 +/- ", shown_var)
    @test occursin("0.799840690665551", shown_var)

    close(f)
end

@testset "Synthetic RooFitResult fixtures" begin
    f = UnROOT.samplefile("roofit_result_synthetic.root")

    full = f["fit_full"]
    @test full isa UnROOT.RooFitResult
    @test full.status == 3
    @test full.covqual == 3
    @test full.numbadnll == 2
    @test full.minnll ≈ 12.5
    @test full.edm ≈ 0.125
    @test full.constpars === missing
    @test length(full.initpars) == 2
    @test length(full.finalpars) == 2
    @test full.finalpars["x"].value ≈ 1.5
    @test full.finalpars["x"].error ≈ 2.0
    @test full.finalpars["y"].value ≈ -1.5
    @test full.finalpars["y"].error ≈ 3.0
    @test full.correlation_matrix isa Matrix{Float64}
    @test full.covariance_matrix isa Matrix{Float64}
    @test full.global_correlation_coefficients isa Vector{Float64}
    @test full.correlation_matrix ≈ [1.0 0.5; 0.5 1.0]
    @test full.covariance_matrix ≈ [4.0 3.0; 3.0 9.0]
    @test full.global_correlation_coefficients ≈ [0.8, 0.9]
    @test full.finalpars["x"].plotbins == 100
    @test full.finalpars["x"].bool_attributes == Set{String}()
    @test full.finalpars["x"].string_attributes == Dict{String, String}()
    @test occursin("RooFitResult(fit_full, 2 floating parameters)", sprint(show, full))
    @test collect(full.finalpars) == full.finalpars.args

    nocov = f["fit_nocov"]
    @test nocov isa UnROOT.RooFitResult
    @test nocov.status == 3
    @test nocov.covqual == 0
    @test nocov.constpars === missing
    @test length(nocov.initpars) == 2
    @test length(nocov.finalpars) == 2
    @test nocov.correlation_matrix === missing
    @test nocov.covariance_matrix === missing
    @test nocov.global_correlation_coefficients === missing

    close(f)
end
