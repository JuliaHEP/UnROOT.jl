using UnROOT
const HERE = @__DIR__
const a = ROOTFile("$HERE/samples/NanoAODv5_sample.root")
const b = a["Events"]["Electron_dxy"]
const lb = a["Events/Electron_dxy"]

@show a,b,lb
lb[1:3]

for i in lb
    i
    break
end

function f()
    for n in keys(a["Events"])
        lb = a["Events/$n"]
        lb[1]
        for i in lb
            break
        end
    end
end

