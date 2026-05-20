# M3.3a nbinom2 fitted-diagnostics lane

**Branch**: `codex/m3-3a-nbinom2-fit-diagnostics-2026-05-20`

**Active perspectives**: Ada orchestrated; Curie owned simulation-grid
diagnostic fidelity; Fisher owned the inference-target interpretation;
Grace owned local/CI gates; Rose owned cross-file consistency. No
spawned subagents were running.

## Purpose

Add fitted-dispersion diagnostics to the M3 grid after the corrected
`nbinom2` r20/b20 pilot showed that the M3 `Sigma_unit_diag` target
was now usually underestimated, with truth above the bootstrap interval
more often than below it.

This lane does not claim that EXT-13 / CI-08 / CI-10 are fixed. It
adds the row-level evidence needed before another larger grid: fitted
`phi_nbinom2`, fitted link-residual variance, and per-cell summaries
of those diagnostics.

## Files

- `dev/m3-grid.R`
- `tests/testthat/test-m3-grid-summary.R`
- `docs/design/42-m3-dgp-grid.md`
- `docs/dev-log/audits/2026-05-20-m3-3a-nbinom2-fit-diagnostics-r20.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-m3-3a-nbinom2-fit-diagnostics.md`

## Changes

- Added `m3_fitted_nbinom2_phi()` so M3 rows record fitted
  `phi_nbinom2` only for traits whose rows actually use family id 5.
- Added `m3_fitted_link_residual()` so M3 rows record the fitted
  link-residual increment implied by `extract_Sigma(...,
  link_residual = "auto") - extract_Sigma(...,
  link_residual = "none")`.
- Added `est_phi_nbinom2` and `est_link_residual` to both `psi` and
  `Sigma_unit_diag` row outputs; failed fits keep `NA`.
- Added `m3_summarise()` columns:
  `median_est_phi_truth_ratio`, `median_est_link_residual`, and
  `median_link_residual_truth_ratio`.
- Updated Design 42's M3 output-schema note so the diagnostic columns
  are part of the durable grid contract.

## Validation

- `Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); cat("parse ok\n")'`
  -> passed.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-grid-summary")'`
  -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 15 ]`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> 0 errors, 1 warning, 5 notes. The warning occurred during
  package installation; notes were local/current-time and existing
  package metadata/import notes.
- Tiny direct M3 smoke:
  `m3_run_cell(family = "nbinom2", d = 1, n_reps = 1, n_units = 20,
  n_traits = 3, phi = 0.8, init_strategy = "single_trait_warmup",
  start_method = list(method = "res", jitter.sd = 0.1), optimizer =
  "optim", optArgs = list(method = "BFGS"), n_init = 2, se = FALSE,
  targets = "Sigma_unit_diag", n_boot = 2, ci_level = 0.80)`
  -> returned finite `est_phi_nbinom2` and `est_link_residual` columns;
  summary returned the new median diagnostic columns.
- Corrected two-scenario r20/b20 diagnostic artifact:
  `/tmp/gllvmtmb-m3-3a-fit-diagnostics-r20/nbinom2-two-scenario-fit-diagnostics-r20-b20.rds`
  -> both scenarios remained `TARGET_FAIL`. Baseline coverage was
  0.76 with median estimate/truth 0.546 and median fitted phi/truth
  0.691. Low-phi coverage was 0.54 with median estimate/truth 0.520
  and median fitted phi/truth 0.799. Full table recorded in
  `docs/dev-log/audits/2026-05-20-m3-3a-nbinom2-fit-diagnostics-r20.md`.

`git diff --check` was clean.

## Definition-of-Done Notes

1. **Implementation**: local branch only at report creation; PR/CI
   status to be filled in at merge closeout.
2. **Simulation recovery**: not a new family, estimator, or likelihood.
   The tiny direct M3 smoke only verifies diagnostic plumbing.
3. **Documentation**: Design 42 output-schema note updated; no roxygen
   or Rd changes because this is dev-grid machinery.
4. **Runnable user-facing example**: not applicable; no user-facing API
   or article example changed.
5. **Check-log entry**: this lane appends a check-log block with exact
   commands.
6. **Review pass**: Curie/Fisher/Rose/Grace perspectives were active.
   No Gauss/Noether TMB likelihood review was needed because
   `src/gllvmTMB.cpp` and likelihood parameterisation were untouched.

## Next Safe Action

Run a corrected r20/b20 diagnostic artifact on this branch and inspect
whether `median_est_phi_truth_ratio` and fitted link-residual summaries
explain the one-sided `Sigma_unit_diag` interval misses before scaling
another production grid.
