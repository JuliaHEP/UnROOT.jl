using Documenter, UnROOT

makedocs(;
    modules=[UnROOT],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        assets=String[],
    ),
    pages=[
        "Introduction" => "index.md",
        "API" => "api.md",
    ],
    repo="https://github.com/tamasgal/UnROOT.jl/blob/{commit}{path}#L{line}",
    sitename="UnROOT.jl",
    authors="Tamas Gal and contributors",
)

deploydocs(;
    repo="github.com/tamasgal/UnROOT.jl",
)
