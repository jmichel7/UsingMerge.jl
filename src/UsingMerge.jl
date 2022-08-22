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
    nb=length(s)-1
    plural=nb>1 ? "s" : ""
    if !iszero(verbose&1) 
      print("# $mod adds $nb method$plural to $modofname.$name")
    end
    for (j,l) in enumerate(s[2:end])
      if j==1 
        if !isempty(eval(:(@doc $mod.$name)).meta[:results])
          if !iszero(verbose&1) println(" and doc") end
          myeval(:(@doc (@doc $mod.$name) $modofname.$name))
        else println() 
        end
      end
      if !iszero(verbose&4) println("   l=",l) end
      l1=replace(l,r"^\[[0-9]*\] (.*) in .*( at .*)?"=>s"\1")
      l1=replace(l1,r"#(s[0-9]*)"=>s"\1")
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
