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
tl;dr: just use `@batch`.

Unlike `@batch` from polyester, there's not much we can do to customize behavior of `@threads`. It is essentially
calling `getindex()`, which we want to keep eager for regular use (e.v `mytree[120]` is eager). Thus, if for some
reason you want to use `@threads` instead of `@batch`, you should use it with `enumerate`:
```julia
julia> for evt in mytree
           @show evt
           break
       end
evt = "LazyEvent with: (:tree, :idx)"

julia> Threads.@threads for evt in mytree
           @show evt
           break
       end
evt = (nMuon = 0x00000000, Muon_pt = Float32[])
evt = (nMuon = 0x00000001, Muon_pt = Float32[3.4505641])
evt = (nMuon = 0x00000000, Muon_pt = Float32[])
evt = (nMuon = 0x00000002, Muon_pt = Float32[21.279676, 7.6710315])
```
