## Don't "double access"
Inside an event-loop:
```julia
for evt in mytree
    evt.nMuon!=4 && continue
    calculation(evt.nMuon)
end
```
This is bad practice. Since `evt` is a lazy construct, read happens when you access a property by e.g. `evt.nMuon`.
This means that if you need a branch multiple times, you should allocate a variable first:
```julia
for evt in mytree
    nmu = evt.nMuon
    nmu !=4 && continue
    calculation(nmu)
end
```

## `Threads.@threads` should go with `enumerate()`
Unlike `@batch` from polyester, there's not much we can do to customize behavior of `@threads`. It is essentially
calling `getindex()`, which we want to keep eager for regular use (e.v `mytree[120]` is eager). Thus, if for some
reason you want to use `@threads` instead of `@batch`, you should use it with `enumerate`:
```julia
# check Threads.nthreads() > 1
Threads.@threads for (_, evt) in enumerate(mytree)
    ...
end
```
