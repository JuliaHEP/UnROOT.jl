using Test
using UnROOT

nthreads = UnROOT._maxthreadid()
nthreads == 1 && @warn "Running on a single thread. Please re-run the test suite with at least two threads (`julia --threads 2 ...`)"

@testset "UnROOT tests" verbose = true begin
    include("Aqua.jl")
    include("bootstrapping.jl")
    include("compressions.jl")
    include("jagged.jl")
    include("lazy.jl")
    include("histograms.jl")
    include("views.jl")
    include("multithreading.jl")
    include("remote.jl")
    include("displays.jl")
    include("type_stability.jl")
    include("utils.jl")
    include("misc.jl")

    include("type_support.jl")
    include("custom_bootstrapping.jl")
    include("lorentzvectors.jl")
    include("NanoAOD.jl")

    include("issues.jl")

    if VERSION >= v"1.9"
        include("rntuple.jl")
        include("./RNTupleWriting/lowlevel.jl")
    end
end
