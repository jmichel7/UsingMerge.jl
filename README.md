# UsingMerge
Automatically compose packages

This  package  exports  a  single  macro  `@usingmerge`  which differs from
`using` in that it "merges" the exported definitions automatically.

The wish for this started in
[this thread](https://discourse.julialang.org/t/function-name-conflict-adl-function-merging/10335/7).
At  the time I was very new to Julia  and did not think I could do anything
myself about the problem. Two years later, knowing better Julia, I realized
I could do something. Here it is.

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jmichel7.github.io/UsingMerge.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jmichel7.github.io/UsingMerge.jl/dev/)
[![Build Status](https://github.com/jmichel7/UsingMerge.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jmichel7/UsingMerge.jl/actions/workflows/CI.yml?query=branch%3Amain)
