using BasicBlockRewriter
using Test
using Pkg

@testset "BasicBlockRewriter.jl" begin
    exampledir = joinpath(dirname(@__DIR__), "examples")
    # Pkg.activate(exampledir)
    # Pkg.instantiate()
    include(joinpath(exampledir, "fragment_counter.jl"))
end
