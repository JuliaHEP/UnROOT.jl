using SnoopCompileCore
HERE = @__DIR__
inf_timing = @snoopi tmin=0.01 begin
    using UnROOT
    a = ROOTFile("$HERE/samples/NanoAODv5_sample.root")
    b = a["Events"]["Electron_dxy"]
    lb = a["Events/Electron_dxy"]
    tb = Table(a, "Events", ["Electron_dxy"])

    @show a,b,lb,tb
    lb[1:3]
    tb[1:3]
    tb.Electron_dxy

    for i in lb
        i
    end
    for i in tb
        i
        break
    end

end
using SnoopCompile
pc = SnoopCompile.parcel(inf_timing)
SnoopCompile.write("$HERE/../src/precompile.jl", pc[:UnROOT], always=true)
