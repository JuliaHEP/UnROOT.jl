## Chunk Iteration
```julia
t = LazyTree(...)
res = 0.0
for rang in Iterators.partition(1:lastindex(t), 10^6)
    res += sum(t[rang].nMuon) #
end
res
```
Note, `t[rang]` is eager, if you don't need all branches, it's much better to use `t.nMuon[rang]`, or limit which
branches are selected during `LazyTree()` creation time.

This pattern works the best over network, for local files, stick with:
```
for evt in t
    ...
end
```
usually is the best approach.
