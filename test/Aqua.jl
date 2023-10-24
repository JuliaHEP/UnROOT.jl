using Aqua

@testset "Aqua.jl" begin
    Aqua.test_all(UnROOT;
    ambiguities = (; broken=true),
    piracy = (; broken=true)
    )
end
