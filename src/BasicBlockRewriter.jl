module BasicBlockRewriter

using Core: GotoNode, GotoIfNot, ReturnNode, SlotNumber, SSAValue, NewvarNode, SimpleVector
using Core: svec
using Base: mapany

export fragments

function relocatable_fragment(stmts, ssa1::Integer)
    toslot = Dict{Union{SlotNumber,SSAValue},SlotNumber}()
    stmtso = Any[]
    for (i, stmt) in enumerate(stmts)
        if isa(stmt, GotoNode) || isa(stmt, GotoIfNot) || isa(stmt, ReturnNode)
            break
        end
        push!(stmtso, rewrite_statement(stmt, ssa1:ssa1+length(stmts)-1, i+ssa1-1, toslot))
    end
    return stmtso
end

function rewrite_statement(stmt, rng, ssa, toslot)
    stmt === nothing && return stmt
    isa(stmt, Symbol) && return stmt
    isa(stmt, String) && return stmt
    isa(stmt, Char) && return stmt
    isa(stmt, LineNumberNode) && return nothing   # FIXME
    isa(stmt, Module) && return stmt
    isa(stmt, UnionAll) && return stmt
    isa(stmt, NewvarNode) && return NewvarNode(rewrite_statement(stmt.slot, rng, ssa, toslot))
    isa(stmt, SlotNumber) && return get!(() -> SlotNumber(length(toslot)+1), toslot, stmt)
    if isa(stmt, SSAValue)
        id = stmt.id
        return id ∈ rng ? SSAValue(id - first(rng) + 1) : get!(() -> SlotNumber(length(toslot)+1), toslot, stmt)
    end
    isa(stmt, QuoteNode) && return QuoteNode(rewrite_statement(stmt.value, rng, ssa, toslot))
    if isa(stmt, Expr)
        out = Expr(stmt.head)
        out.args = mapany(arg -> rewrite_statement(arg, rng, ssa, toslot), stmt.args)
        return out
    end
    if isa(stmt, GlobalRef)
        return GlobalRef(rewrite_statement(stmt.mod, rng, ssa, toslot), rewrite_statement(stmt.name, rng, ssa, toslot))
    end
    isa(stmt, SimpleVector) && return svec([rewrite_statement(stmt[i], rng, ssa, toslot) for i = 1:length(stmt)]...)
    # last to avoid slow subtyping as often as possible
    isa(stmt, Tuple) && return map(item -> rewrite_statement(item, rng, ssa, toslot), stmt)
    isa(stmt, Number) && return stmt
    isa(stmt, DataType) && return stmt
    error("unhandled statement ", stmt, " of type ", typeof(stmt))
end

function fragments(m::Method)
    src = Base.uncompressed_ast(m)
    cfg = Core.Compiler.compute_basic_blocks(src.code)
    return [relocatable_fragment(src.code[rng.start:rng.stop], rng.start) for rng in map(bb->bb.stmts, cfg.blocks)]
end

end
