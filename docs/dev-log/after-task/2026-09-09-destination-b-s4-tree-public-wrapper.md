# After Task: Destination B S4 public Tree workflow

## Goal

Expose one fail-closed public post-fit Tree workflow for the already paired S3b Gaussian `phylo_rr` cell, without widening `engine = "julia"`.

## Implemented

`gllvm_julia_phylo_rr()` returns the distinct `gllvmTMB_julia_phylo_rr` class for one fitted native Tree model. Its public surface is intentionally small: `print`, `summary`, `logLik`, `coef`, and read-only stored-endpoint `confint`. The wrapper now requires native convergence exactly zero with finite optimizer parameters; stored intervals require both `ci_method = "wald"` and `transformed_wald` on every available target.

## Mathematical Contract

For the approved cell, the source model has \(\eta=X\beta+Zb\), with `X = 0 + trait` and the R canonical phylogenetic precision passed to the existing multivariate Julia precision consumer. The public wrapper transports neither a new likelihood nor a covariance inverse: it only reads the consumer's observed-marginal transformed-Wald result.

## Files Changed

- `R/julia-bridge.R`: source-health, stored-interval, and `logLik` fail-closed gates.
- `tests/testthat/test-julia-phylo-rr-bridge.R`: hostile-input and public-reader regressions.
- `docs/dev-log/artifacts/2026-09-09-destination-b-s4-tree-public-workflow-receipt.json`: retained provenance and evidence.
- `docs/dev-log/check-log.md`: focused verification record.

## Tests Added

Four hostile-input checks cover an unconverged/fractional/malformed native optimizer, counterfeit profile endpoints, and missing CI metadata. They satisfy the test-of-tests malformed-input clause; the live Tree pair separately checks the public wrapper against the independent native fit.

## Benchmark Numbers

N/A — this is R bridge validation and public result reading, not a Julia numerical hot-path change.

## R-Parity Verdict

Paired Tree cell: within the signed tolerances. Absolute log-likelihood delta is \(1.54\times10^{-12}\); maximum fixed-effect, phylogenetic-covariance, and residual-variance deltas are \(6.88\times10^{-8}\), \(1.26\times10^{-7}\), and \(4.72\times10^{-10}\), respectively. Exact fixture provenance is retained in the S4 receipt.

## JET / Allocs / Aqua Verdicts

- JET: N/A — no Julia source changed in this S4 wrapper correction.
- Allocs: N/A — no Julia hot path changed.
- Aqua: N/A — no Julia exports or dependencies changed.

## Checks Run

```sh
GLLVM_S3B_LIVE_ADAPTER_TESTS=1 \
  GLLVM_DESTINATION_B_PROJECT='<isolated GLLVM.jl worktree>' \
  GLLVM_S3B_JULIA_HOME='<Julia 1.10 executable>' \
  Rscript --vanilla -e 'devtools::test(filter = "julia-phylo-rr-bridge", reporter = "summary")'
# 15 tests, 102 expectations, 0 failures, 0 skips, 0 errors, 0 warnings; 24.5 s

Rscript --vanilla -e 'tools::parse_Rd("man/gllvm_julia_phylo_rr.Rd"); cat("Rd parse: OK\\n")'
# Rd parse: OK
```

`git diff --check` was also clean. An independent re-review reported no P0 finding after the hostile-input repairs.

## Consistency Audit

Searched `R/julia-bridge.R`, `NAMESPACE`, `man/gllvm_julia_phylo_rr.Rd`, `vignettes/articles/current-limits.Rmd`, `README.md`, and `docs/` for `gllvm_julia_phylo_rr`, `engine = "julia"`, `phylo_rr`, and `0.7 parity`. The public Roxygen, generated Rd, namespace, and limitations vignette consistently say this is an explicit post-fit Tree exception and that generic engine admission remains closed.

## GitHub Issue Maintenance

No issue action: this is authorised local Destination B work. FRK remains explicitly parked at `gllvmTMB#1275`; no push, merge, release, or registry action was taken.

## What Did Not Go Smoothly

The first public wrapper had three review findings: it could relabel a non-Wald stored endpoint, did not enforce native fit health, and emitted `logLik` with `df = NA`. A second review then found malformed-input edges. All were corrected before this record, but the review illustrates why an adapter payload is not itself a public workflow.

## Team Learning

For a narrow bridge exception, every user-visible reader must validate the stored result contract independently. A successful native–Julia parameter pair is not enough to justify an interval label, a `logLik` degrees-of-freedom value, or generic-engine admission.

## Remaining Risks and Next Command

Only the single Gaussian ML ultrametric-Tree, trait-intercept, rank-one public workflow is evidenced. Dense `vcv`, pedigree, extra fixed effects, prediction, generic engine admission, recovery, coverage, 0.7 parity, and FRK remain unqualified.

```sh
# Next authorised Destination B slice: paired Gaussian B1 unit grouping.
```

Rose verdict: PASS WITH NOTES — the controlled S4 Tree workflow is locally evidenced; all broader phylogenetic and parity claims remain withheld.
