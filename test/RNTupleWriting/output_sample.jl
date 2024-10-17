using UnROOT

const RNT_primitive_Ts = [Float64, Float32, Float16, Int64, Int32, Int16, Int8, UInt64, UInt32, UInt16]
Nitems = 10
data = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

newtable = Dict( "x_$T" => T.(data) for T in RNT_primitive_Ts)
newtable["x_Bool"] = isodd.(data)
newtable["x_String"] = string.(data)

for T in RNT_primitive_Ts
    newtable["x_vec_$T"] = [rand(T, data[i]) for i in 1:Nitems]
end

UnROOT.write_rntuple(open(only(ARGS), "w"), newtable; rntuple_name="myntuple")
