import random
import ROOT

# Create a ROOT file to store histograms
file = ROOT.TFile("TH3F.root", "RECREATE")

# Create a 3D histogram
histogram = ROOT.TH3F(
        "histogram",
        "Example 3D Histogram;X Axis;Y Axis;Z Axis",
        10, -1, 1,
        20, -2, 2,
        30, -3, 3)

random.seed(42)

# Fill the histogram with some random data
for i in range(1, 10000):
    x = random.random() * 2 - 1
    y = random.random() * 4 - 2
    z = random.random() * 6 - 3
    histogram.Fill(x, y, z)

# Write the histogram to the ROOT file
histogram.Write()

# Close the ROOT file
file.Close()
