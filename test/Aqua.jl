using Aqua

@testset "Aqua.jl" begin
    Aqua.test_all(UnROOT;
    ambiguities = (; broken=true),
    piracies = (; broken=true)
    )
end
