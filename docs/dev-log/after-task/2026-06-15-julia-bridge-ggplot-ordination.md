# After Task: Julia Bridge ggplot Ordination

Date: 2026-06-15

## Goal

Expose the richer `plot(type = "ordination")` visual route for Julia-engine fits
without implying that the whole `gllvmTMB_multi` plotting suite is bridged.

## Implemented

- Added `plot.gllvmTMB_julia()`.
- Routed only `type = "ordination"` through the existing `.plot_ordination_gtmb()`
  helper over cached Julia bridge scores/loadings.
- Kept unsupported plot types, bootstrap overlays, and standardized loading
  arrows as explicit errors until the bridge carries the required payloads.

## Files Changed

- `R/plot-gllvmTMB.R`
- `tests/testthat/test-julia-bridge.R`
- `NAMESPACE`
- `man/plot.gllvmTMB_multi.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-ggplot-ordination.md`

## Tests Added

- Added a synthetic `gllvmTMB_julia` test for `plot(type = "ordination")`
  returning a `ggplot` with `gllvmTMB_meta` / `gllvmTMB_data`, plus negative
  tests for unsupported non-ordination plot types and standardized loadings.
  This satisfies the visual-helper dispatch and failure-path clauses.

## Benchmark Numbers

N/A -- no hot path changed. This is R-side plotting over cached matrices.

## R-Parity Verdict

Parity: N/A -- this slice does not change likelihoods, estimates, CIs, or Julia
engine math.

## Checks Run

```sh
Rscript -e 'devtools::document()'
```

Result: registered the S3 method and wrote `man/plot.gllvmTMB_multi.Rd`;
roxygen emitted existing unresolved-link warnings outside this slice.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::load_all("."); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Result: `PASS 125`, `FAIL 0`, `WARN 0`, `SKIP 0`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

Result: `PASS 125`, `FAIL 0`, `WARN 0`, `SKIP 0` in `47.7s`.

## Consistency Audit

- `rg -n "plot\\.gllvmTMB|type.*ordination|extract_ordination|rotate_loadings|gllvmTMB_meta|gllvmTMB_data" R/plot-gllvmTMB.R`
  confirmed the existing helper could be reused for ordination metadata.
- `rg -n "standardize_loadings_by_total_variance|gtmb_trait_names|n_traits|report\\$|data\\[\\[|trait_col|use\\$" R/plot-gllvmTMB.R`
  identified total-variance dependencies that are not present in the Julia
  bridge payload, so standardized loadings are deliberately rejected.

## GitHub Issue Maintenance

No issue action taken in this local slice. This is part of the current R-first
Julia bridge completion lane.

## What Did Not Go Smoothly

`plot(type = "ordination")` could not safely inherit every `gllvmTMB_multi`
plot option. Standardized loading arrows depend on total-variance extractors
that the Julia bridge does not expose yet.

## Team Learning

Florence/Rose lens: visual access can be admitted in small truthful steps; a
single plot type is better than a broad plotting claim with missing payloads.

## Remaining Risks

- Non-ordination plot types remain unavailable for Julia bridge fits.
- Standardized loading arrows require a future total-variance payload or
  extraction route.
- This test verifies object shape and metadata, not rendered pixel snapshots.

## Known Limitations

No new Julia engine behavior, interval overlays, covariance plots, missing
masks, newdata prediction, or ordinal probabilities are added here.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter = "julia-bridge")'
```

## Rose Verdict

Rose verdict: PASS WITH NOTES -- `plot(type = "ordination")` is truthfully wired
for Julia bridge fits; broader plot types and standardized loading arrows remain
queued behind richer bridge payloads.
