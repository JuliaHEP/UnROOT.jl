import ROOT
import sys

Nitems = 10
data = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

df  =  ROOT.RDataFrame("myntuple", sys.argv[1])

if list(df.Take['std::int32_t']("x_Int32")) != data:
    sys.exit(1)
if list(df.Take['std::int64_t']("x_Int64")) != data:
    sys.exit(1)

for n in df.GetColumnNames():
    df.Display(n).Print()
