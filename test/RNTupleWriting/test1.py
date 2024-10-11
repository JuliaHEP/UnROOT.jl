import ROOT
import sys

df  =  ROOT.RDataFrame("myntuple", sys.argv[1])
if len(list(df.GetColumnNames())) != 4:
    sys.exit(1)

if list(df.Take['std::int32_t']("x3")) != [5, 6, 7, 8, 9, 10, 11, 12, 13, 14]:
    sys.exit(1)
