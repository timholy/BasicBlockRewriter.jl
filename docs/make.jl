using BasicBlockRewriter
using Documenter

DocMeta.setdocmeta!(BasicBlockRewriter, :DocTestSetup, :(using BasicBlockRewriter); recursive=true)

makedocs(;
    modules=[BasicBlockRewriter],
    authors="Tim Holy <tim.holy@gmail.com> and contributors",
    repo="https://github.com/timholy/BasicBlockRewriter.jl/blob/{commit}{path}#{line}",
    sitename="BasicBlockRewriter.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://timholy.github.io/BasicBlockRewriter.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/timholy/BasicBlockRewriter.jl",
    devbranch="main",
)
