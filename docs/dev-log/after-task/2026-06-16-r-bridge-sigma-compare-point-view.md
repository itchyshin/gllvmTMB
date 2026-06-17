# After Task: R Bridge Sigma Comparison Point View

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Hopper, Emmy, Fisher, Rose, Shannon, Grace

## 1. Goal

Let `compare_Sigma_table()` consume admitted `gllvmTMB_julia` bridge fits by
reusing the existing point-only `extract_Sigma_table()` route. Keep the claim
as an estimate-vs-truth table helper, not an interval, plot, or calibration
promotion.

## 2. Implemented

- `compare_Sigma_table()` now treats `gllvmTMB_julia` as a fitted object and
  calls `extract_Sigma_table()` before joining to the supplied truth matrix.
- The error message for unsupported `x` now names admitted `gllvmTMB_julia`
  bridge fits.
- `plot_Sigma_comparison()` roxygen wording now names the same bridge-fit
  input because it routes through `compare_Sigma_table()` when `truth` is
  supplied.
- `tests/testthat/test-julia-bridge.R` verifies that a fake Julia bridge fit
  returns point-only comparison rows with `validation_row = "JUL-01A"`,
  `interval_status = "none"`, finite truth values, and `error = estimate -
  truth`.

## 3. Files Changed

- Implementation: `R/extract-sigma-table.R`
- Roxygen wording: `R/plot-covariance-tables.R`
- Generated docs: `man/compare_Sigma_table.Rd`,
  `man/plot_Sigma_comparison.Rd`
- Tests: `tests/testthat/test-julia-bridge.R`
- Validation/spec ledgers: `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/audits/2026-06-16-richer-extractor-parity-spec.md`,
  `docs/dev-log/coordination-board.md`, `docs/dev-log/check-log.md`
- After-task report: this file

No TMB likelihood, formula grammar, NAMESPACE, NEWS, vignette, pkgdown
navigation, or Julia engine code changed.

## 4. Checks Run

- `gh pr list --state open --json number,title,headRefName,isDraft,updatedAt,url`
  -> one open draft PR, #489, on `codex/r-bridge-grouped-dispersion`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent commits were the current Codex bridge stack only.
- `gh pr view 489 --json headRefOid,mergeStateStatus,statusCheckRollup,updatedAt`
  -> pushed head `6a33865` had R-CMD-check ubuntu-latest and coevolution
  recovery in progress while this local follow-up was prepared.
- `air format R/extract-sigma-table.R R/plot-covariance-tables.R tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `compare_Sigma_table.Rd` and `plot_Sigma_comparison.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma-table", reporter = "summary")'`
  -> `0` failures.
- `GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures, `13` expected live-Julia skips.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures.

## 5. Tests of the Tests

The new pure-R assertion would have failed before this slice because
`compare_Sigma_table()` only treated `gllvmTMB_multi` as a fitted model. It now
proves that a `gllvmTMB_julia` fit can route through the point-table helper,
convert the supplied truth matrix to a correlation target, preserve `JUL-01A`,
and avoid interval status inflation.

## 6. Consistency Audit

- `JUL-01A` remains `partial`.
- `EXT-JL-RAW` now includes point-only estimate-vs-truth comparison rows.
- `EXT-JL-INTERVAL` remains gated: no `extract_correlations()` interval route,
  no lower/upper table intervals from fitted Julia bridge objects, and no
  profile/bootstrap-derived table rows were added.
- `plot_Sigma_comparison()` only inherits the bridge input through
  `compare_Sigma_table()` and still remains a visual comparison helper, not a
  calibration or uncertainty routine.
- No public README, vignette, NEWS, or pkgdown article claim was promoted.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. This is evidence for the richer extractor lane
under `JUL-01A` and PR #489.

## 7a. GitHub Issue Ledger

No issue was closed or commented. The next issue-ledger update can mention this
under #488 and #340 if the pushed PR checks stay green.

## 8. What Did Not Go Smoothly

The route was already effectively supported for users who manually called
`extract_Sigma_table(fit_jl, ...)` and then `compare_Sigma_table(rows, ...)`.
The gap was the direct fitted-object path, where the helper still checked only
for `gllvmTMB_multi`.

## 9. Team Learning

- Ada: Keep these extractor slices small enough that each added verb has a
  clear validation row.
- Hopper: Shared table helpers need bridge-aware class gates once the lower
  extractor route is admitted.
- Emmy: Direct fitted-object convenience routes should not duplicate table
  construction.
- Fisher: Estimate-vs-truth comparison rows are not inference intervals or
  calibration evidence.
- Rose: `JUL-01A` wording must keep comparison rows point-only.
- Shannon: The slice was prepared while the previous pushed head was still
  running; it should not be pushed until that head finishes cleanly or is
  debugged.
- Grace: Targeted table, no-Julia bridge, and live bridge tests passed; full
  package checks remain the release gate and GitHub PR check.

## 10. Known Limitations And Next Actions

- `extract_correlations()` still rejects `gllvmTMB_julia` objects and remains a
  future interval/status design lane.
- `compare_Sigma_table()` only compares rows that the point-table route can
  produce; for Julia bridge fits this is ordinary unit-tier only.
- Structured tiers, rotated ordinations, residual-split reporting, and
  interval-bearing extractor tables remain gated.
