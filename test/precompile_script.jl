using SnoopCompileCore
HERE = @__DIR__
inf_timing = @snoopi tmin=0.01 begin
    using UnROOT
    a = ROOTFile("$HERE/samples/NanoAODv5_sample.root")
    b = a["Events"]["Electron_dxy"]
    lb = a["Events/Electron_dxy"]
    tb = Table(a, "Events")
    @show a,b,lb,tb
    tb[1:3]
    tb.Electron_dxy[1]
    tb[1].Electron_dxy[1]

    for i in tb
        for n in propertynames(tb)
            getproperty(i, n)
        end
        break
    end

end
using SnoopCompile
pc = SnoopCompile.parcel(inf_timing)
SnoopCompile.write("$HERE/../src/precompile.jl", pc[:UnROOT], always=true)
