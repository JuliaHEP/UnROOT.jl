using Test
using UnROOT

nthreads = UnROOT._maxthreadid()
nthreads == 1 && @warn "Running on a single thread. Please re-run the test suite with at least two threads (`julia --threads 2 ...`)"


@testset "Parallel and enumerate interface" begin
    t = LazyTree(UnROOT.samplefile("NanoAODv5_sample.root"), "Events", ["Muon_pt"])
    @test eachindex(enumerate(t)) == eachindex(t)
    nmu = 0
    for evt in t
        nmu += length(evt.Muon_pt)
    end
    @test nmu == 878

    nmu = 0
    for (i,evt) in enumerate(t)
        nmu += length(evt.Muon_pt)
    end
    @test nmu == 878


    if get(ENV, "CI", "false") == "true"
        if nthreads == 1
            @warn "CI wasn't run with multiple threads"
        end
    end

    nmus = zeros(Int, nthreads)

    Threads.@threads for i in 1:length(t)
        nmus[Threads.threadid()] += length(t.Muon_pt[i])
    end
    @test sum(nmus) == 878

    et = enumerate(t)
    @test firstindex(et) == firstindex(t)
    @test lastindex(et) == lastindex(t)
    test_i, test_evt = et[2]
    @test test_i == 2
    @test test_evt isa UnROOT.LazyEvent
    @test !isempty(hash(t.Muon_pt.b))
end

t = LazyTree(UnROOT.samplefile("NanoAODv5_sample.root"), "Events", ["Muon_pt"])
@testset "Multi threading" begin
    nmus = zeros(Int, nthreads)
    Threads.@threads for (i, evt) in enumerate(t)
        nmus[Threads.threadid()] += length(t.Muon_pt[i])
    end
    @test sum(nmus) == 878

    nmus .= 0
    Threads.@threads for evt in t
        nmus[Threads.threadid()] += length(evt.Muon_pt)
    end
    if nthreads > 1
        @test count(>(0), nmus) > 1# test @threads is actually threading
    end
    @test sum(nmus) == 878


    nmus .= 0
    Threads.@threads for evt in t
        nmus[Threads.threadid()] += length(evt.Muon_pt)
    end
    if nthreads > 1
        @test count(>(0), nmus) > 1
    end
    @test sum(nmus) == 878

    nmus .= 0
    t_dummy = LazyTree(UnROOT.samplefile("NanoAODv5_sample.root"), "Events", ["Muon_pt"])
    chained_tree = vcat(t,t_dummy)
    Threads.@threads for evt in chained_tree # avoid using the same underlying file handler
        nmus[Threads.threadid()] += length(evt.Muon_pt)
    end
    @test sum(nmus) == 2*878
    @test mapreduce(length, +, [t,t_dummy]) == length(t) + length(t_dummy)

    for j in 1:3
        inds = [Vector{Int}() for _ in 1:nthreads]
        Threads.@threads for (i, evt) in enumerate(t)
            push!(inds[Threads.threadid()], i)
        end
        @test sum([length(inds[i] ∩ inds[j]) for i=1:length(inds), j=1:length(inds) if j>i]) == 0
    end
end
