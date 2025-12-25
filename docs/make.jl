using Documenter, UnROOT
using DocumenterVitepress

makedocs(;
    modules=[UnROOT],
    format=DocumenterVitepress.MarkdownVitepress(; repo="github.com/JuliaHEP/UnROOT.jl"),
    pages=[
        "Introduction" => "index.md",
        "Example Usage" => "exampleusage.md",
        "Performance Tips" => "performancetips.md",
        "Advanced Usage" => [
            "Parse Custom Branch" => "advanced/custom_branch.md",
            "Reduce startup latency" => "advanced/reduce_latency.md",
        ],
        "For Contributors" => "devdocs.md",
        "APIs" => "internalapis.md",
    ],
    repo="https://github.com/JuliaHEP/UnROOT.jl/blob/{commit}{path}#L{line}",
    sitename="UnROOT.jl",
    authors="Tamas Gal and contributors",
)

deploydocs(;
    repo="github.com/JuliaHEP/UnROOT.jl",
    push_preview=true
)
