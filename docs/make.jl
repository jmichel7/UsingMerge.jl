using Documenter, UsingMerge

DocMeta.setdocmeta!(UsingMerge, :DocTestSetup, :(using UsingMerge); recursive=true)

makedocs(;
    modules=[UsingMerge],
    authors="Jean Michel <jean.michel@imj-prg.fr> and contributors",
    sitename="UsingMerge.jl",
    format=Documenter.HTML(;
        canonical="https://jmichel7.github.io/UsingMerge.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
    warnonly=:missing_docs,
)

deploydocs(;
    repo="github.com/jmichel7/UsingMerge.jl",
    devbranch="main",
)
