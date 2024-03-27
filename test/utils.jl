using Test
using UnROOT

# @stack
struct A
    n::Int32
    m::Int64
end
struct B
    o::Float16
    p
    q::Bool
end
struct C
    r
    s
    t
    u
end
@UnROOT.stack D A B C
expected_fieldnames = (:n, :m, :o, :p, :q, :r, :s, :t, :u)
expected_fieldtypes = [Int32, Int64, Float16, Any, Bool, Any, Any, Any, Any]

@testset "utils" begin
    @test fieldnames(D) == expected_fieldnames
    @test [fieldtype(D, f) for f in fieldnames(D)] == expected_fieldtypes
end
