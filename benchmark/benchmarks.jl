using BenchmarkTools
using UnROOT

const SUITE = BenchmarkGroup()

SUITE["Latency"] = BenchmarkGroup()
const l1 = UnROOT.samplefile("NanoAODv5_sample.root")
SUITE["Latency"]["load NanoAOD"] = @benchmarkable LazyTree(l1, "Events") samples=1 evals=1


SUITE["Performance"] = BenchmarkGroup()
const p1 = LazyTree(UnROOT.samplefile("RNTuple/test_ntuple_int_multicluster.root"), "ntuple")
SUITE["Performance"]["read RNTuple multicluster"] = @benchmarkable p1.one_integers[1] samples=1 evals=1
