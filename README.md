# UsingMerge.jl

This  package exports  a single  macro `@usingmerge`  which differs from
`using` in that it "merges" the exported definitions automatically.

The wish for this started in
[this thread](https://discourse.julialang.org/t/function-name-conflict-adl-function-merging/10335/7).
At  the time I was very new to Julia  and did not think I could do anything
myself about the problem. Two years later, knowing better Julia, I realized
I could do something. Here it is.

I introduce the problem with an example.

In  my `Gapjm`  package (a  port of  some GAP  libraries to Julia) I have a
function  `invariants` which computes the invariants of a finite reflection
group.  However when  I use  `BenchmarkTools` to  debug for  performance my
package, I have the following problem:

```
julia> G= # some group...

julia> invariants(G)
WARNING: both Gapjm and BenchmarkTools export "invariants"; uses of it in module Main must be qualified
ERROR: UndefVarError: invariants not defined
Stacktrace:
 [1] top-level scope at REPL[4]:1
 [2] eval(::Module, ::Any) at ./boot.jl:331
 [3] eval_user_input(::Any, ::REPL.REPLBackend) at /buildworker/worker/package_linux64/build/usr/share/julia/stdlib/v1.4/REPL/src/REPL.jl:86
 [4] run_backend(::REPL.REPLBackend) at /home/jmichel/.julia/packages/Revise/kqqw8/src/Revise.jl:1163
 [5] top-level scope at none:0
```

This  is  annoying!  I  do  not  want  to  have to qualify every call to my
function  `invariants` just  because I  am timing  my code!  What can I do?
Well, first I could just import the methods I am using in `BenchmarkTools`:

```
julia> using BenchmarkTools: @btime
```
Actually,  every exported name  from `BenchmarkTools`, except `invariants`,
does not conflict with my code:

```
julia> names(BenchmarkTools)
30-element Array{Symbol,1}:
 Symbol("@ballocated")
 Symbol("@belapsed")
 Symbol("@benchmark")
 Symbol("@benchmarkable")
 Symbol("@btime")
 Symbol("@tagged")
 :BenchmarkGroup
 :BenchmarkTools
 :addgroup!
 :allocs
 :gctime
 :improvements
 :invariants
 :isimprovement
 :isinvariant
 :isregression
 :judge
 :leaves
 :loadparams!
 :mean
 :median
 :memory
 :params
 :ratio
 :regressions
 :rmskew
 :rmskew!
 :trim
 :tune!
 :warmup
```

so I can do:

```
julia> using BenchmarkTools: @ballocated, @belapsed, @benchmark, @benchmarkable, @btime, @tagged, BenchmarkGroup, BenchmarkTools, addgroup!, allocs, gctime, improvements, isimprovement, isinvariant, isregression, judge, leaves, loadparams!, mean, median, memory, params, ratio, regressions, rmskew, rmskew!, trim, tune!,
 warmup
```

Still no conflict. Can I go further and do something even for `invariants`?
Well, I have one method for `invariants` in my package:

```
invariants(a::Group, args...)
```
while `BenchmarkTools` has four:

```
invariants(group::BenchmarkGroup)
invariants(x)
invariants(f, group::BenchmarkGroup)
invariants(f, x)
```
Even though some of these last methods apply to `Any`, they do not conflict
with  my method  (since at  least one  of the  arguments of  my method, the
first,  is qualified with my type `Group`), so  I can use them also by just
defining:

```
invariants(group::BenchmarkGroup) = BenchmarkTools.invariants(group)
invariants(x) = BenchmarkTools.invariants(x)
invariants(f, group::BenchmarkGroup) = BenchmarkTools.invariants(f, group)
invariants(f, x) = BenchmarkTools.invariants(f, x)
```

The  last thing to do is  make the docstring of `BenchmarkTools.invariants`
accessible to the help of `invariants`. It happens it has no docstring, but
if it had one I must do (this *adds* to the doc of `invariants`):

```
@doc (@doc BenchmarkTools.invariants) invariants
```

I  call  the  end  result  of  the  above  process  `merging`  the  package
`BenchmarkTools`  with  my  current  package.  What  I  announce  here is a
macro  `@usingmerge`  which  does  all  the  above automatically. If you do

```
julia> using UsingMerge
julia> @usingmerge BenchmarkTools
```

The  function determines conflicting method names in the package and merges
them as above, and does `using` of the non-conflicting names.

Just like for `using` you can `usingmerge` only some of the names of the
package

```
julia> @usingmerge BenchmarkTools: invariants, ratio
```

The macro `@usingmerge` has two optional arguments

```
julia> @usingmerge reexport BenchmarkTools
```
will   reexport  all  non-conflicting  names  (a  conflicting  name  is  by
definition  already present in your environment and will be exported if you
did export it).

```
julia> @usingmerge verbose=true BenchmarkTools
```

will  print all conflicts resolved, and `verbose=2` will print all executed
commands.  

You will find some more information in the docstring of `@usingmerge`.

Since  I wrote this function,  I found that I  got the hoped for modularity
benefits in my code. For example, I have in my `Gapjm.jl` package modules

  - `Perms`      Permutations
  - `Cycs`       Cyclotomic numbers (sums of complex roots of unity)
  - `Pols`       Univariate Laurent polynomials
  - `Mvps.jl`    Multivariate Puiseux polynomials
  - `Posets.jl`  Posets
  - `FFields.jl` Finite fields

that I designed as independent, stand-alone packages which each can be used
without importing anything else from my package. To use them together I can
now  just `using_merge` each  of them instead  of writing (unpleasant) glue
code.

I  do not advocate always  replacing the semantics of  `using` with that of
`@usingmerge`,  but  I  feel  that  `@usingmerge`  is a nice tool for using
packages  together without having to write glue code (and without having to
modify  any of the used packages). The meaning of "pirating a type" becomes
a   little  bit  wider  in  this  context,  as  you  saw  with  the  method
`invariants(y)`  in `BenchmarkTools`: it is, I would say, polite, if any of
your  methods which has  a possibly conflicting  name uses at  least one of
your own types in its signature.

The  program only merges methods  of functions. If a  conflicting name is a
`macro`,  a `struct` or  a type, a  message is printed  and the name is not
merged.

Any  kind of feedback will be welcome. My implementation is perhaps not the
best,  as I kind  of parse the  printed output of  `methods`. Accessing the
internal structure of the returned object would be better but I do not know
what's  officially accessible  in there.  If you  have any  comments on the
code, functionality or documentation please contact me.
