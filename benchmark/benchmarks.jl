using BenchmarkTools
using UnROOT

const SUITE = BenchmarkGroup()

SUITE["Latency"] = BenchmarkGroup()
_nanopath = joinpath(@__DIR__, "../test/samples/NanoAODv5_sample.root")
SUITE["Latency"]["load"] = @benchmarkable LazyTree(_nanopath, "Events") samples=1 evals=1


SUITE["Performance"] = BenchmarkGroup()
