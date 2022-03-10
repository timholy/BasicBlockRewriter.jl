# BasicBlockRewriter

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://timholy.github.io/BasicBlockRewriter.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://timholy.github.io/BasicBlockRewriter.jl/dev)
[![Build Status](https://github.com/timholy/BasicBlockRewriter.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/timholy/BasicBlockRewriter.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/timholy/BasicBlockRewriter.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/timholy/BasicBlockRewriter.jl)

This package explores a new approach to latency reduction in Julia. It determines the unique [basic blocks](https://en.wikipedia.org/wiki/Basic_block) present across a swath of Julia code and rewrites functions as calls to "fragments" that represent these blocks.

**This is a work in progress, and most of the features described below have not yet been implemented.**

## Analysis pass

Starting from a method, generate *relocatable fragments*:

- split the lowered code into blocks. Trim gotos, which are external to fragments.
- for each trimmed block, renumber `SlotNumber`s and internal `SSAValue`s by the order in which they appear
- convert external `SSAValue`s into slots

## Generating callable fragments

Starting from the original lowered code, block-internal SSAValues accessed from other blocks, as well as updates to slots, are assembled to create the fragment return values. Ideally this gets done "swath-wide" because the same fragment may be used in different ways (using or ignoring different possible return values) by other code.

Then the fragments from the analysis pass get wrapped in methods.

## Rewriting parent functions in terms of fragments

Parent lowered code gets replaced with calls to the fragments.
