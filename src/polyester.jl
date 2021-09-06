# special Requires.jl syntax
import .Polyester: splitloop, combine, NoLoop

splitloop(t::LazyTree) = NoLoop(), eachindex(t), t
combine(t::LazyTree, ::NoLoop, j) = LazyEvent(innertable(t), j)

splitloop(e::Base.Iterators.Enumerate{LazyTree{T}}) where T = NoLoop(), eachindex(e.itr), e
combine(e::Iterators.Enumerate{LazyTree{T}}, ::NoLoop, j) where T =  @inbounds e[j]
