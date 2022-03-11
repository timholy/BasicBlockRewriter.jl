module BasicBlockRewriter

using Core: GotoNode, GotoIfNot, ReturnNode, SlotNumber, SSAValue, NewvarNode, SimpleVector
using Core: svec
using Base: mapany

export fragments, Fragment, FragmentData

const emptyvec = Any[]

struct LNNRef
    id::Int
end
struct ConstRef
    id::Int
end

struct Fragment
    code::Vector{Any}
end
Fragment() = Fragment([])
Base.isempty(frag::Fragment) = isempty(frag.code)
Base.length(frag::Fragment) = length(frag.code)
Base.:(==)(frag1::Fragment, frag2::Fragment) = frag1.code == frag2.code
const _frag_hash_seed_ = Int === Int64 ? 0xb2608230b093d1b4 : 0x441223d4
Base.hash(frag::Fragment, h::UInt) = hash(frag.code, hash(_frag_hash_seed_, h))

struct FragmentData
    lnns::Vector{LineNumberNode}
    consts::Vector{Any}
end
FragmentData() = FragmentData(LineNumberNode[], [])
Base.isempty(fragdata::FragmentData) = isempty(fragdata.lnns) && isempty(fragdata.consts)

function relocatable_fragment!(frags, stmts, ssa1::Integer)
    toslot = Dict{Union{SlotNumber,SSAValue},SlotNumber}()
    frag, fragdata = Fragment(), FragmentData()
    for (i, stmt) in enumerate(stmts)
        if isa(stmt, GotoNode) || isa(stmt, GotoIfNot) || isa(stmt, ReturnNode) || isa(stmt, NewvarNode) || stmt === nothing
            if !isempty(frag)
                push!(frags, fragdata => frag)
                frag, fragdata = Fragment(), FragmentData()
            end
            push!(frags, stmt)
        else
            push!(frag.code, rewrite_statement(stmt, ssa1:ssa1+length(stmts)-1, i+ssa1-1, fragdata, toslot))
        end
    end
    return frags
end

function rewrite_statement(@nospecialize(stmt), rng::AbstractUnitRange, ssa::Integer, fragdata::FragmentData, toslot::AbstractDict)
    stmt === nothing && return stmt
    if isa(stmt, LineNumberNode)
        push!(fragdata.lnns, stmt)
        return LNNRef(length(fragdata.lnns))
    end
    # Handle some "nontrival" code elements
    isa(stmt, SlotNumber) && return get!(() -> SlotNumber(length(toslot)+1), toslot, stmt)
    if isa(stmt, SSAValue)
        id = stmt.id
        return id ∈ rng ? SSAValue(id - first(rng) + 1) : get!(() -> SlotNumber(length(toslot)+1), toslot, stmt)
    end
    isa(stmt, QuoteNode) && return QuoteNode(rewrite_statement(stmt.value, rng, ssa, fragdata, toslot))
    if isa(stmt, Expr)
        out = Expr(stmt.head)
        out.args = mapany(arg -> rewrite_statement(arg, rng, ssa, fragdata, toslot), stmt.args)
        return out
    end
    isa(stmt, SimpleVector) && return svec([rewrite_statement(stmt[i], rng, ssa, fragdata, toslot) for i = 1:length(stmt)]...)
    if isa(stmt, GlobalRef)
        # Where possible, do the lookup now (helps with uniquing)
        return isdefined(stmt.mod, stmt.name) ? getfield(stmt.mod, stmt.name) : stmt
    end
    isa(stmt, Core.Box) && return Core.Box(rewrite_statement(stmt.contents, rng, ssa, fragdata, toslot))
    # Preserve types as hard-coded since they are fundamental and can lose specialization if passed as an argument
    isa(stmt, UnionAll) && return stmt
    (isa(stmt, DataType) || isa(stmt, Union) || stmt === Union{}) && return stmt
    isa(stmt, Function) && return stmt
    # Values
    push!(fragdata.consts, stmt)
    return ConstRef(length(fragdata.consts))
end

function fragments(m::Method)
    if isdefined(m, :generator) && m.generator isa Core.GeneratedFunctionStub
        @warn "skipping generated function $m"
        return emptyvec
    end
    src = Base.uncompressed_ast(m)
    cfg = Core.Compiler.compute_basic_blocks(src.code)
    frags = []
    for rng in map(bb->bb.stmts, cfg.blocks)
        relocatable_fragment!(frags, src.code[rng.start:rng.stop], rng.start)
    end
    return frags
end

end
