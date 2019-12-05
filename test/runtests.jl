using ROOTIO
using Test

@testset "io" begin
    ROOTIO.@io struct Foo
        a::Int32
        b::Int64
        c::Float32
    end

    foo = Foo(1, 2, 3)

    @assert foo.a == 1
    @assert foo.b == 2
    @assert foo.c ≈ 3
end
