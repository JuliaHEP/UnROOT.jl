using Test
using UnROOT

@testset "RooFitResult" begin
    f = ROOTFile(joinpath(@__DIR__, "../data/test_RooFitResult.root"))
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

    close(f)
end
