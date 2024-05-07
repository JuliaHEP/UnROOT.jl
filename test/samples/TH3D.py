import random
import ROOT

# Create a ROOT file to store histograms
file = ROOT.TFile("TH3D.root", "RECREATE")

# Create a 3D histogram
histogram = ROOT.TH3D(
        "histogram",
        "Example 3D Histogram;X Axis;Y Axis;Z Axis",
        10, -10_000_000, 10_000_000,
        20, -20_000_000, 20_000_000,
        30, -30_000_000, 30_000_000)

random.seed(42)

# Fill the histogram with some random data
for i in range(1, 100000):
    x = random.random() * 30_000_000 - 15_000_000
    y = random.random() * 50_000_000 - 25_000_000
    z = random.random() * 70_000_000 - 35_000_000
    histogram.Fill(x, y, z)

# Write the histogram to the ROOT file
histogram.Write()

# Close the ROOT file
file.Close()
