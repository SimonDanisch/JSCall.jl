using Documenter, JSCall

makedocs(;
    modules=[JSCall],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/SimonDanisch/JSCall.jl/blob/{commit}{path}#L{line}",
    sitename="JSCall.jl",
    authors="Simon Danisch, Nextjournal",
    assets=[],
)

deploydocs(;
    repo="github.com/SimonDanisch/JSCall.jl",
)
