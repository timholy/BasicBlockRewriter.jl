# Scans methods in Base and its sub-modules (excluding Core) and counts the number of instances
# of each unique fragment

using BasicBlockRewriter
using MethodAnalysis
using PyPlot: PyPlot, plt

"""
    collect_methods(; exclude=())

Collect all methods in the session, excluding modules listed in `exclude`.

    collect_methods(SomeModule; exclude=())

Collect all methods in `SomeModule` or one of its sub-modules, excluding modules listed in `exclude`.
"""
function collect_methods(top::Union{Tuple{},Tuple{Module}}=(); exclude=())
    meths = Method[]
    visit(top...) do item
        isa(item, Module) && return item ∉ exclude
        if isa(item, Method)
            push!(meths, item)
            return false
        end
        return true
    end
    return meths
end
collect_methods(top::Module; kwargs...) = collect_methods((top,); kwargs...)

function catalog_fragments!(fragdict, m::Method)
    try
        for frag in fragments(m)
            fragdict[frag] = get(fragdict, frag, 0) + 1
        end
    catch err
        if isa(err, ErrorException) && err.msg == "Code for this Method is not available."
            @warn "No code available for $m"
            return fragdict
        end
        @error "$err"
    end
    return fragdict
end

meths = collect_methods(; exclude=child_modules(Core))
fragdict = Dict{Vector{Any},Int}()
for m in meths
    catalog_fragments!(fragdict, m)
end

fig, axs = plt.subplots(1, 3, figsize=(8, 3))
ax = axs[1]
ax.hist(map(length, collect(keys(fragdict))))
ax.set_yscale("log")
ax.set_xlabel("# statements")
ax.set_ylabel("# fragments")

ax = axs[2]
bins = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000]
ax.hist(collect(values(fragdict)), bins)
ax.set_xscale("log")
ax.set_yscale("log")
ax.set_xlabel("# callers")
ax.set_ylabel("# fragments")

ax = axs[3]
kv = collect(fragdict)
ax.scatter(length.(first.(kv)), last.(kv))
ax.set_yscale("log")
ax.set_xlabel("# statements")
ax.set_ylabel("# callers")

fig.tight_layout()
