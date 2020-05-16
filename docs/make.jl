using Documenter, UnROOT

makedocs(;
    modules=[UnROOT],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tamasgal/UnROOT.jl/blob/{commit}{path}#L{line}",
    sitename="UnROOT.jl",
    authors="Tamas Gal",
    assets=String[],
)

deploydocs(;
    repo="github.com/tamasgal/UnROOT.jl",
)
