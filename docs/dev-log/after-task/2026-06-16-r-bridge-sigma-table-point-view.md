# After Task: R Bridge Sigma Table Point View

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Hopper, Emmy, Fisher, Rose, Shannon, Grace

## 1. Goal

Expose the already-admitted Julia bridge unit-tier covariance/correlation
payload through `extract_Sigma_table()` without promoting interval-bearing
extractor parity. The table should be a report-ready point view over
`extract_Sigma()`, not a new confidence-interval surface.

## 2. Implemented

- `extract_Sigma_table()` now accepts `gllvmTMB_julia` objects.
- `.sigma_available_levels()` returns only the ordinary unit tier for Julia
  bridge objects; `level = "all"` therefore maps to `"unit"`.
- Julia bridge table rows use `validation_row = "JUL-01A"` instead of `EXT-18`.
- Interval columns remain point-only: `lower` and `upper` are `NA`,
  `interval_method = "none"`, and `interval_status = "none"`.
- Roxygen/Rd now states the Julia bridge scope boundary: ordinary unit tier
  only, no interval-bearing table rows.
- `tests/testthat/test-julia-bridge.R` covers pure-R fake payload table schema
  and live grouped JuliaCall table rows.

## 3. Files Changed

- Implementation: `R/extract-sigma-table.R`
- Generated docs: `man/extract_Sigma_table.Rd`
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
  -> previous pushed head `57cc406` had R-CMD-check ubuntu-latest and
  coevolution recovery passing, merge state clean.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `extract_Sigma_table.Rd`.
- `air format R/extract-sigma-table.R tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma-table", reporter = "summary")'`
  -> `0` failures.
- `GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures, `13` expected live-Julia skips.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures.

## 5. Tests of the Tests

The pure-R fake-payload test would have failed before this slice because
`extract_Sigma_table()` rejected `gllvmTMB_julia` objects. It now checks the
stable table schema, unit-level labelling, `JUL-01A` validation row, point-only
interval status, and level gate for `unit_obs`.

The live JuliaCall assertion runs inside the grouped-dispersion main-dispatch
loop, so it verifies that real `gllvmTMB(..., engine = "julia")` objects can
produce point-only Sigma table rows after the bridge roundtrip.

## 6. Consistency Audit

- `JUL-01A` remains `partial`.
- `EXT-JL-RAW` now includes point-only table schema.
- `EXT-JL-INTERVAL` remains gated: no `extract_correlations()` interval route,
  no lower/upper table intervals from fitted Julia bridge objects, and no
  profile/bootstrap-derived table rows were added.
- No public README, vignette, NEWS, or pkgdown article claim was promoted.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. This is evidence for the richer extractor lane
under `JUL-01A` and PR #489.

## 7a. GitHub Issue Ledger

No issue was closed or commented. The next issue-ledger update can mention this
under #488 and #340 if the pushed PR checks stay green.

## 8. What Did Not Go Smoothly

The table helper originally used the native `fit$use` flags to discover
available covariance levels, so Julia bridge objects had no route even though
`extract_Sigma()` itself was already admitted. The fix keeps discovery narrow
instead of synthesising broader levels.

## 9. Team Learning

- Ada: A table view can be useful without implying interval parity.
- Hopper: Julia bridge objects need small adapter hooks in shared extractor
  infrastructure, not duplicate table builders.
- Emmy: Validation-row labels should reflect the bridge row (`JUL-01A`), not
  the native extractor row (`EXT-18`).
- Fisher: Interval/status columns must remain honest empty fields until a real
  CI/status payload exists.
- Rose: User-facing Rd wording must distinguish point tables from
  interval-bearing extractor tables.
- Shannon: The slice waited for the previous pushed head to go green before
  preparing the next push.
- Grace: Targeted table, no-Julia bridge, and live bridge tests passed; full
  package checks remain the release gate and GitHub PR check.

## 10. Known Limitations And Next Actions

- `extract_correlations()` still rejects `gllvmTMB_julia` objects and remains a
  future interval/status design lane.
- `extract_Sigma_table()` supports only the ordinary unit tier for Julia bridge
  objects.
- Structured tiers, rotated ordinations, residual-split reporting, and
  interval-bearing extractor tables remain gated.
