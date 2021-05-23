using Test, UsingMerge

foo(x::Int)=2

module Bar
  export foo
  foo(x::Float64)=3
end

@usingmerge Bar

@test length(methods(foo))==2
