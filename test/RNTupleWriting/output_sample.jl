using UnROOT

Nitems = 10
data = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
newtable = Dict(
    "x1" => Float64.(data),
    "x2" => Float32.(data),
    "x3" => Int32.(data),
    "y1" => UInt16.(data),
)
UnROOT.write_rntuple(open(only(ARGS), "w"), newtable; rntuple_name="myntuple")
