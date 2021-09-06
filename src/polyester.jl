Polyester.splitloop(t::LazyTree) = Polyester.NoLoop(), eachindex(t), t
Polyester.combine(t::LazyTree, ::Polyester.NoLoop, j) = LazyEvent(innertable(t), j)

Polyester.splitloop(e::Base.Iterators.Enumerate{LazyTree{T}}) where T = Polyester.NoLoop(), eachindex(e.itr), e
Polyester.combine(e::Iterators.Enumerate{LazyTree{T}}, ::Polyester.NoLoop, j) where T =  @inbounds e[j]
