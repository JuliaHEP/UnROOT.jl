using Documenter, ROOTIO

makedocs(;
    modules=[ROOTIO],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tamasgal/ROOTIO.jl/blob/{commit}{path}#L{line}",
    sitename="ROOTIO.jl",
    authors="Tamas Gal",
    assets=String[],
)

deploydocs(;
    repo="github.com/tamasgal/ROOTIO.jl",
)
