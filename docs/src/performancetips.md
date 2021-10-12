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
