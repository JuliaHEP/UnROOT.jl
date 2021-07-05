using UnROOT
const t = ROOTFile("./NanoAODv5_sample.root");
for _=1:10
    array(t, "Events/Electron_dxy")
end
