import ROOT

# Create a ROOT file to store histograms
file = ROOT.TFile("TH3F.root", "RECREATE")

# Create a 3D histogram
histogram = ROOT.TH3F("histogram", "Example 3D Histogram;X Axis;Y Axis;Z Axis", 50, -5, 5, 50, -5, 5, 50, -5, 5)

# Fill the histogram with some random data
for i in range(1, 10000):
    x = 1./i
    y = 1./(2*i)
    z = 1./(3*i)
    histogram.Fill(x, y, z)

# Write the histogram to the ROOT file
histogram.Write()

# Close the ROOT file
file.Close()
