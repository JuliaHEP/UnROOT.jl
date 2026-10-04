using Test
using UnROOT: xxh3_64, xxh64

# Known-answer tests for the hash functions UnROOT relies on for RNTuple and
# LZ4 checksums, generated with the reference implementation (python-xxhash
# 3.x wrapping xxHash 0.8). The lengths cover every code path of XXH3: empty,
# 1-3, 4-8, 9-16, 17-128, 129-240, and the long path with partial blocks, a
# full block, and the `len ≡ 1 (mod 64)` case that XXHashNative < 1.1.1 hashed
# incorrectly.
@testset "xxh3_64 and xxh64 known answers" begin
    pat(n, a, b) = UInt8[(i * a + b) % 256 for i in 0:n-1]
    cases = [
        (UInt8[],                   0x2d06800538d394c2, 0xef46db3751d8e999),
        (codeunits("a"),            0xe6c632b61e964e1f, 0xd24ec4f1a98c6e5b),
        (codeunits("abc"),          0x78af5f94892f3950, 0x44bc2cf5ad770999),
        (codeunits("hello world"),  0xd447b1ea40e6988b, 0x45ab6734b21e6968),
        (UInt8.(0:16),              0x9ef341a99de37328, 0x5603e60c527599b6),
        (UInt8.(0:63),              0x6187eb9089b0ed55, 0xf7c67301db6713f0),
        (UInt8.(0:127),             0x85c6174c7ff4c46b, 0x7a7fe14647b9ab92),
        (UInt8.(0:200),             0x1485411ca6c9c142, 0x6fb6526bc7788ecf),
        (UInt8.(0:239),             0x375a384d957fe865, 0x012947f0da6a27b1),
        (UInt8.(0:240),             0x02e8cd95421c6d02, 0x8d643f23bf2808e1),
        (pat(256, 1, 0),            0x9408a4433b952d71, 0x1facbe8406cd904b),
        (pat(257, 1, 0),            0xd02c25704c5cee8a, 0x80381162756d40e6),
        (pat(1024, 1, 0),           0xa870f92984398d22, 0x6f3914f18fe4df57),
        (pat(1025, 1, 0),           0x78c86e91ee939852, 0x0614c40149130943),
        (pat(1217, 7, 0),           0x27183c8b67703ed3, 0x2c48fc010d405858),
        (pat(3000, 13, 5),          0x29dfd8b96acba614, 0x7383cd6e1bd01459),
        (pat(100000, 31, 7),        0xccf90df7e7e37036, 0x3ac9cbc5a9b7f843),
    ]
    for (bytes, h3, h64) in cases
        v = collect(bytes)
        @test xxh3_64(v) == h3
        @test xxh64(v) == h64
        # non-dense inputs take the byte-wise load path
        @test xxh3_64(@view v[1:end]) == h3
        @test xxh64(@view v[1:end]) == h64
        # a view that does not start at the beginning of its parent
        padded = vcat(UInt8[0xaa, 0xbb, 0xcc], v)
        @test xxh3_64(@view padded[4:end]) == h3
        @test xxh64(@view padded[4:end]) == h64
    end
    @test xxh3_64("abc") == 0x78af5f94892f3950
end
