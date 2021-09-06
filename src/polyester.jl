Polyester.splitloop(x::LazyTree) = Polyester.NoLoop(), eachindex(x), x
Polyester.combine(t::LazyTree, ::Polyester.NoLoop, j) = LazyEvent(innertable(t), j)
