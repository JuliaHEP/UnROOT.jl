# Bootstrapping

Some core ROOT types — `TTree`, `TBranch`, histogram classes, leaf types, and
their attribute parents — are only fully defined in the C++ ROOT framework and
cannot be inferred from the file format alone.  UnROOT handles these by
hard-coding their layouts in
[`src/bootstrap.jl`](https://github.com/JuliaHEP/UnROOT.jl/blob/main/src/bootstrap.jl).
This is what the term *bootstrapping* refers to in this codebase.

Each bootstrapped class corresponds to a ROOT `ClassDef` version number stored
in the file's object preamble.  When multiple versions exist, separate structs
named `TypeName_N` (e.g. `TBranch_8`, `TBranch_12`) are defined and dispatched
to automatically.  Types with a single implementation handle any version
gracefully via the ROOT preamble `endcheck` mechanism.

The [ROOT C++ source](https://github.com/root-project/root) is the authoritative
reference for validating field layouts and version numbers when extending or
correcting these definitions.

## Supported Classes

| Class | Highest Supported Version | All Supported Versions | Notes |
|---|:---:|---|---|
| `ROOT::TIOFeatures` | 1 | 1 | Thin wrapper around a single `UInt8` bitmask for I/O feature flags; introduced in ROOT v6.14, appears in `TBranch` (v13) and `TTree` (v20) |
| `TAttAxis` | 4 | 4 | Axis visual attributes (divisions, colors, fonts); older versions 1–3 are not present in files produced by any supported ROOT release |
| `TAttBox2D` | 0 | 0 | Pure virtual; no persistent fields — present only to satisfy the C++ inheritance chain during streaming |
| `TAttFill` | 2 | 1, 2 | Fill colour and style attributes; versions 1 and 2 have identical persistent layout |
| `TAttLine` | 2 | 1, 2 | Line colour, style, and width attributes; versions 1 and 2 have identical persistent layout |
| `TAttMarker` | 3 | 1, 2, 3 | Marker colour, style, and size attributes; versions 2 and 3 are aliases for version 1 (no structural changes between them in ROOT) |
| `TAttText` | 2 | 2 | Text attributes (angle, size, align, colour, font); version 1 is not encountered in practice |
| `TAxis` | 10 | 10 | Histogram axis definition including bin edges, labels, and display options |
| `TBranch` | 13 | 8, 12, 13 | Core branch type; versions 9–11 were never released by the ROOT team; v12 added `fFirstEntry`; v13 added `fIOFeatures` |
| `TBranchElement` | 10 | 9, 10 | Branch for split C++ objects (STL containers, custom classes); v10 narrowed `fClassVersion` from `Int32` to `Int16` |
| `TFriendElement` | 2 | 2 | Represents a friend `TTree` attached to another tree; version 1 not encountered in practice |
| `TH1` | 8 | 8 | 1D histogram base class; reading is dispatched to concrete subclasses `TH1I`, `TH1F`, `TH1D` |
| `TH2` | 5 | 4, 5 | 2D histogram base class; versions 4 and 5 have identical persistent fields |
| `TH3` | 6 | 6 | 3D histogram base class |
| `TLatex` | 2 | 2 | LaTeX-formatted text object used in histogram annotations |
| `TLeaf` | 2 | 2 | Base class for all `TLeaf` variants; single implementation handles all versions via preamble `endcheck` |
| `TLeafB` | 1 | 1 | Byte leaf; `fMinimum`/`fMaximum` are `UInt8` |
| `TLeafC` | 1 | 1 | Character-array leaf; `fMinimum`/`fMaximum` are `Int32` (encoding the maximum array length) |
| `TLeafD` | 1 | 1 | Double-precision float leaf (`Float64`) |
| `TLeafElement` | 1 | 1 | Leaf used with split-object `TBranchElement` branches |
| `TLeafF` | 1 | 1 | Single-precision float leaf (`Float32`) |
| `TLeafG` | 1 | 1 | Unsigned 64-bit integer leaf (always `Int64`, `fIsUnsigned` is ignored by ROOT for this type) |
| `TLeafI` | 1 | 1 | 32-bit integer leaf; `fIsUnsigned` selects between `Int32` and `UInt32` |
| `TLeafL` | 1 | 1 | 64-bit integer leaf; `fIsUnsigned` selects between `Int64` and `UInt64` |
| `TLeafO` | 1 | 1 | Boolean leaf |
| `TLeafS` | 1 | 1 | 16-bit integer leaf; `fIsUnsigned` selects between `Int16` and `UInt16` |
| `TNamed` | 1 | 1 | Base for all named ROOT objects; carries `fName` and `fTitle` |
| `TPaveStats` | 5 | 5 | Statistics box drawn on histograms (mean, RMS, entries, fit parameters) |
| `TPaveText` | 2 | 2 | Multi-line text pave drawn on histograms |
| `TText` | 3 | 3 | Simple positioned text object |
| `TTree` | 20 | 5, 6–20 | The primary columnar data container; version 5 uses a structurally different float-based header; subsequent field additions: `fDefaultEntryOffsetLen` at v18, `fNClusterRange`/`fClusterSize` at v19, `fIOFeatures` at v20 |
| `TVirtualPaveStats` | 0 | 0 | Pure virtual; no persistent fields — present only to satisfy the C++ inheritance chain during streaming |
