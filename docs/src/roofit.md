# RooFit Results

UnROOT can read top-level `RooFitResult` objects written to a ROOT file.

This is useful for workflows where a fit is performed in ROOT/RooFit and the
result inspection happens in Julia.

## Open a RooFitResult

```julia
using UnROOT

f = ROOTFile("path/to/file.root")
fit = f["fit_full"]
```

The returned object exposes the core fit payload:

```julia
fit.status
fit.covqual
fit.edm
fit.minnll
fit.numbadnll
```

## Access Parameters

The parameter collections are available as `RooArgList`s:

```julia
fit.constpars
fit.initpars
fit.finalpars
```

These can be indexed by position:

```julia
first_parameter = fit.finalpars[1]
first_parameter.name
first_parameter.value
first_parameter.error
```

or by RooFit parameter name:

```julia
x = fit.finalpars["x"]
x.value
x.error
```

## Access Covariance Data

If the original `RooFitResult` stored covariance information, UnROOT exposes:

```julia
fit.correlation_matrix
fit.covariance_matrix
fit.global_correlation_coefficients
```

For example:

```julia
size(fit.covariance_matrix)
fit.correlation_matrix[1, 2]
fit.global_correlation_coefficients[1]
```

When the source `RooFitResult` does not contain covariance information, these
fields are `missing`.

## Example

The repository ships a synthetic RooFit fixture in
`test/samples/roofit_results.root`. You can inspect it with:

```julia
using UnROOT

f = UnROOT.samplefile("roofit_results.root")
fit = f["fit_full"]

fit.status
fit.finalpars["x"].value
fit.correlation_matrix[1, 2]
fit.global_correlation_coefficients
```

## Current Scope

The current implementation is focused on `RooFitResult` and the subset of the
`Roo*` ecosystem needed to deserialize its core payload. It is not intended as
full RooFit object support in UnROOT yet.
