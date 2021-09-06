# Bake `sysimage` with `PackageCompiler.jl`
You can bake a sysimage tailored for your analysis to reduce latency.
```julia
> cat readtree.jl
using UnROOT

const r = ROOTFile("/home/akako/.julia/dev/UnROOT/test/samples/NanoAODv5_sample.root")

const t = LazyTree(r, "Events", ["nMuon", "Electron_dxy"])


@show t[1, :Electron_dxy]

> time julia --startup-file=no readtree.jl
t[1, :Electron_dxy] = Float32[0.00037050247]

________________________________________________________
Executed in   10.82 secs    fish           external
   usr time   11.09 secs  580.00 micros   11.09 secs
   sys time    0.65 secs  189.00 micros    0.65 secs
```

In Julia, `]add PackageCompiler':
```julia
julia> using PackageCompiler

julia> PackageCompiler.create_sysimage(:UnROOT; precompile_statements_file="./readtree.jl", sysimage_path="./unroot.so", replace_default=false)'
```

profit:
```fish
> time julia -J ./unroot.so readtree.jl 
t[1, :Electron_dxy] = Float32[0.00037050247]

________________________________________________________
Executed in  619.20 millis    fish           external
   usr time  902.29 millis    0.00 millis  902.29 millis
   sys time  658.59 millis    1.05 millis  657.54 millis
```
