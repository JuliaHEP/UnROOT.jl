## Commonly used
```@autodocs
Modules = [UnROOT]
Filter   = t -> contains(string(t), "Lazy")
```

## More Internal
```@autodocs
Modules = [UnROOT]
Filter   = t -> !(contains(string(t), "Lazy"))
```
