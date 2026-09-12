using Test
using UnROOT
using Aqua
using TOML

# The downgrade-compat CI action promotes the test-target `[extras]` (and the
# weak dependencies) into `[deps]` for its joint floor resolve, so Aqua would
# report them as stale; they are never loaded by `using UnROOT` by design.
const _test_extras = Symbol.(keys(TOML.parsefile(joinpath(pkgdir(UnROOT), "Project.toml"))["extras"]))

@testset "Aqua.jl" begin
    Aqua.test_all(UnROOT;
    ambiguities = (; broken=true),
    piracies = (; broken=true),
    stale_deps = (; ignore=_test_extras),
    )
end
