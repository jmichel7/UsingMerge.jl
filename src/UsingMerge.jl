"""
This module exports a single macro [`@usingmerge`](@ref) which differs from
`using` in that it "merges" the exported definitions automatically.

The wish for this started in
[this thread](https://discourse.julialang.org/t/function-name-conflict-adl-function-merging/10335/7).
At  the time I was very new to Julia  and did not think I could do anything
myself about the problem. Two years later, knowing better Julia, I realized
I could do something. Here it is.

I introduce the problem with an example.

In  my `Chevie` package  I have a  function `invariants` which computes the
invariants of a finite reflection group. However when I use
`BenchmarkTools`  to debug for performance my package, I have the following
problem:

```
julia> G= # some group...

julia> invariants(G)
WARNING: both Chevie and BenchmarkTools export "invariants"; uses of it in module Main must be qualified
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

You will find some more information in the docstring of [`@usingmerge`](@ref).

Since  I wrote this function,  I found that I  got the hoped for modularity
benefits in my code. For example, I my package `Chevie` uses the packages

  - `PermGroups` Permutations and permutation groups
  - `CyclotomicNumbers`  Sums of complex roots of unity
  - `LaurentPolynomialss`  Univariate Laurent polynomials
  - `PuiseuxPolynomials`    Multivariate Puiseux polynomials
  - `FinitePosets.jl`
  - `FiniteFields.jl`

that I designed as independent, stand-alone packages which each can be used
without  importing anything from my package. To use them together I can now
just `@usingmerge` each of them instead of writing (unpleasant) glue code.

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
"""
module UsingMerge
export @usingmerge
"""
`@usingmerge [reexport] [verbose=true] SomeModule[: symbol1, symbol2...]`

do  `using` module `SomeModule`, in addition merging all method definitions
(or  `using` from  `SomeModule` methods  definitions `symbol1, symbol2...`)
exported  by  `SomeModule`  with  methods  of  the same name in the current
module.

If  `reexport` is given all  new names (non-conflicting with  a name in the
current  module)  exported  from  `SomeModule`  are  (re-)exported from the
current  module. If a  name is not  new it is  assumed that the decision to
export it or not has been taken before.

If `verbose=true` conflicting methods are printed.
If `verbose=2` every executed command is printed before execution.
If `verbose=3` boths happens.

If  a name exported  by `SomeModule` conflicts  with a name  which is not a
method a warning is printed and the name is not merged (not imported).

An example of use:
```julia
julia> using UsingMerge

julia> foo(x::Int)=2
foo (generic function with 1 method)

julia> module Bar
       export foo
       foo(x::Float64)=3
       end
Main.Bar

julia> @usingmerge verbose=3 Bar
# Bar.foo conflicts with Main.foo --- adding methods
Main.foo(x::Float64) = Bar.foo(x)
```

One  could have done `@usingmerge Bar:  foo` to import/merge `foo` only. In
any  case, note that the equivalent of `using  Bar: Bar` is done in any case
to put the name `Bar` in scope.
"""
macro usingmerge(e...)
  verbose=0
  reexport=false
  mod=nothing
  modnames=nothing
  for ee in e
    if ee==:reexport reexport=true
    elseif ee isa Symbol mod=ee
    elseif ee.head== :(=) && ee.args[1]==:verbose verbose=ee.args[2]
    elseif ee.head== :call && ee.args[1]== :(:)
       mod=ee.args[2]
       modnames=[ee.args[3]]
    elseif ee.head== :tuple && ee.args[1] isa Expr && 
      ee.args[1].head== :call && ee.args[1].args[1]== :(:)
       mod=ee.args[1].args[2]
       modnames=[ee.args[1].args[3]]
       append!(modnames,ee.args[2:end])
    end
  end
  esc(Expr(:block,
  :(
if !@isdefined using_merge
function using_merge(mod::Symbol,modnames=nothing;reexport=false,verbose=0)
  function remove_linenums(e)
    if !(e isa Expr) return e end
    args=remove_linenums.(e.args)
    Expr(e.head,filter(a->!(a isa LineNumberNode),args)...)
  end
  function myeval(e)
    if !iszero(verbose&2) 
      println(remove_linenums(e))
    end
    eval(e)
  end
  mymodule=@__MODULE__
  # first, bring in scope mod in case it is not
  if !isdefined(mymodule,mod) myeval(:(using $mod: $mod)) end
  if reexport myeval(:(export $mod)) end
  if isnothing(modnames) modnames=setdiff(names(eval(mod)),[mod]) end
  for name in modnames
    if !isdefined(mymodule,name) 
      myeval(:(using .$mod: $name))
      if reexport myeval(:(export $name)) end
      continue
    end
    # now we know name is conflicting
    if string(name)[1]=='@'
      println("# not importing conflicting macro $name")
      continue
    end
    if !(eval(name) isa Function)
      println("# not importing non-Function conflicting name $name")
      continue
    end
    if !(eval(:($mod.$name)) isa Function)
      println("# not importing conflicting name $name: it is not a Function in $mod")
      continue
    end
    methofname=methods(eval(name))
    modofname=nameof(parentmodule(eval(name)))
    s=split(repr(methods(eval(:($mod.$name)))),"\n")
    if VERSION>v"1.8.5" s=s[2:2:end] else s=s[2:end] end
    nb=length(s)
    plural=nb>1 ? "s" : ""
    if !iszero(verbose&1) 
      print("# $mod adds $nb method$plural to $modofname.$name")
    end
    for (j,l) in enumerate(s)
      if j==1 
        doc=eval(:(@doc $mod.$name))
        if !isnothing(doc) && typeof(doc)!=Base.Docs.DocStr && !isempty(doc.meta[:results])
          if !iszero(verbose&1) println(" and doc") end
          myeval(:(@doc (@doc $mod.$name) $modofname.$name))
        else println() 
        end
      end
      if !iszero(verbose&4) 
        @show l
      end
      if VERSION>v"1.8.5" 
        l1=replace(l,r"^\s*\[[0-9]*\]\s*"=>"")
      else
        l1=replace(l,r"^\[[0-9]*\] (.*) in .*( at .*)?"=>s"\1")
        l1=replace(l1,r"#(s[0-9]*)"=>s"\1")
      end
      e1=Meta.parse(l1)
      if !iszero(verbose&4) println("\n   =>",e1) end
      e2=e1.head==:where ? e1.args[1] : e1
      for (i,f) in enumerate(e2.args[2:end])
        if (f isa Expr) && f.head==:parameters
          e2.args[i+1]=:($(Expr(:parameters, :(kw...))))
        end
      end
      e=deepcopy(e1)
      e2.args[1]=Meta.parse("$modofname.$name")
      if e.head==:where e=e.args[1] end
      for (i,f) in enumerate(e.args[2:end])
        if !(f isa Expr) continue end
        if f.head==:(::) 
          if length(f.args)==2 e.args[i+1]=f.args[1]
          elseif f.args[1] isa Symbol e.args[i+1]=f.args[1]
          else e.args[i+1]=f.args[1].args[2]
          end
        end
      end
      e.args[1]=Expr(:.,mod,QuoteNode(e.args[1]))
      myeval(Expr(:(=),e1,e))
    end
  end
end
end),
# :(using $mod: $mod),
 :(using_merge($(Core.QuoteNode(mod)),$modnames;reexport=$reexport,verbose=$verbose))))
end
end
