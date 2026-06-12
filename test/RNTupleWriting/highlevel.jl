using UnROOT
using Test
using Tables: columntable

# round-trip helper: write `table` to a fresh file and read it back as a LazyTree
function _write_read(table; file_name="roundtrip.root", rntuple_name="myntuple")
    path = joinpath(mktempdir(), file_name)
    open(path, "w") do io
        UnROOT.write_rntuple(io, table; file_name, rntuple_name)
    end
    return LazyTree(path, rntuple_name)
end

@testset "RNTuple Writing - full type matrix round trip" begin
    table = (;
        f64 = [1.5, -2.5, 1e300],
        f32 = Float32[1.5, -2.5, 3e30],
        f16 = Float16[0.5, -1.5, 2.0],
        i8 = Int8[-128, 0, 127],
        u8 = UInt8[0, 128, 255],
        i16 = Int16[-32768, 0, 32767],
        u16 = UInt16[0, 1, 65535],
        i32 = Int32[typemin(Int32), 0, typemax(Int32)],
        u32 = UInt32[0, 1, typemax(UInt32)],
        i64 = Int64[typemin(Int64), 0, typemax(Int64)],
        u64 = UInt64[0, 1, typemax(UInt64)],
        b = [true, false, true],
        s = ["hello", "wörld ✓", ""],
        v = [Int32[1, 2, 3], Int32[], Int32[-7]],
        vv = [[Float64[1.0], Float64[2.0, 3.0]], Vector{Float64}[], [Float64[]]],
    )
    t = _write_read(table)
    @test sort(collect(propertynames(t))) == sort(collect(keys(table)))
    for c in keys(table)
        @test all(collect(getproperty(t, c)) .== getproperty(table, c))
    end
end

@testset "RNTuple Writing - non-default names" begin
    table = (; x = Int32[1, 2, 3])
    t = _write_read(table; file_name="some_other_filename_λ.root", rntuple_name="my_table_name")
    @test collect(t.x) == table.x
end

@testset "RNTuple Writing - bit column odd sizes" begin
    # exercise bit-packing for sizes around the 8-bit and 64-bit boundaries
    for n in (1, 7, 8, 9, 63, 64, 65, 100)
        bits = isodd.(1:n) .⊻ (mod.(1:n, 3) .== 0)
        t = _write_read((; b = bits))
        @test collect(t.b) == bits
    end
end

@testset "RNTuple Writing - string edge cases" begin
    table = (; s = ["", "a", "α β γ", repeat("x", 1000)])
    t = _write_read(table)
    @test collect(t.s) == table.s
end
