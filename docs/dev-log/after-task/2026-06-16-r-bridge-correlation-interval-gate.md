# After Task: R Bridge Correlation Interval Gate

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Hopper, Emmy, Florence, Fisher, Rose, Shannon, Grace

## 1. Goal

Make the Julia bridge correlation-interval boundary explicit. A
`gllvmTMB_julia` object can now produce point-only ordinary unit-tier
correlation rows through `extract_Sigma_table(..., measure = "correlation")`,
but `extract_correlations()` and `plot_correlations()` are interval/status
helpers and must not imply confidence intervals exist for Julia bridge fits.

## 2. Implemented

- Added `GJL-GATE-CORRELATION-INTERVALS` to the Julia bridge gate registry with
  `JUL-01A` validation-row linkage.
- `extract_correlations(gllvmTMB_julia, ...)` now fails with that gate id and
  points users to point-only `extract_Sigma_table(fit, measure =
  "correlation")`.
- `plot_correlations(gllvmTMB_julia, ...)` now fails with the same gate id and
  points users to point-only `plot_Sigma_table(..., measure = "correlation")`
  or `plot_Sigma_heatmap(..., measure = "correlation")`.
- Roxygen documentation for `extract_correlations()` and `plot_correlations()`
  now names the Julia bridge boundary.
- Tests pin the registry row and the two user-facing gate messages.

This slice does not compute correlation confidence intervals, bootstrap rows,
profile rows, or new uncertainty displays for Julia bridge fits.

## 3. Files Changed

- Bridge gate registry: `R/julia-bridge.R`
- Correlation helpers: `R/extract-correlations.R`,
  `R/plot-covariance-tables.R`
- Generated docs: `man/extract_correlations.Rd`,
  `man/plot_correlations.Rd`
- Tests: `tests/testthat/test-julia-bridge.R`
- Validation/status ledgers: `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/coordination-board.md`, `docs/dev-log/check-log.md`
- After-task report: this file

## 4. Checks Run

- Pre-edit coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,author,updatedAt,isDraft,mergeStateStatus,url`
  -> one open draft PR, #489, on `codex/r-bridge-grouped-dispersion`.
- Recent hot-file scan:
  `git log --all --oneline --since="6 hours ago" --name-only -- R/extract-correlations.R R/plot-covariance-tables.R R/julia-bridge.R tests/testthat/test-julia-bridge.R tests/testthat/test-plot-covariance-tables.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/coordination-board.md`
  -> recent overlapping edits were from the current Codex bridge stack only.
- Formatting and whitespace:
  `air format R/julia-bridge.R R/extract-correlations.R R/plot-covariance-tables.R tests/testthat/test-julia-bridge.R`
  and `git diff --check`
  -> clean.
- No-Julia R bridge test:
  `GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `0` failures and `13` expected live-Julia skips.
- Roxygen/Rd:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/extract_correlations.Rd` and `man/plot_correlations.Rd`.
- Plot-helper tests:
  `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables", reporter = "summary")'`
  -> completed with `0` failures.
- Live R-to-Julia bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `0` failures.

## 5. Tests of the Tests

The new test would fail if `extract_correlations()` or `plot_correlations()`
fell back to a generic class error for `gllvmTMB_julia` objects, or if the gate
registry lost the correlation-interval row.

## 6. Consistency Audit

- `JUL-01A` remains `partial`.
- Point-only correlation rows remain available through `extract_Sigma_table()`
  and the Sigma table/heatmap/comparison helpers.
- Interval-bearing correlation extractors remain gated; no lower/upper endpoint
  support was added for fitted Julia bridge objects.
- `plot_correlations()` remains an interval-aware helper over
  `extract_correlations()` rows. Julia bridge users should use the point-only
  Sigma table/heatmap helpers until correlation endpoint/status semantics are
  specified.

## 7. Roadmap Tick

This is a gate/status hardening slice under `JUL-01A`, not a capability
promotion. It prepares the later `EXT-JL-INTERVAL` lane by preventing accidental
overclaims in the meantime.

## 7a. GitHub Issue Ledger

Do not update issues until the current PR #489 GitHub checks finish and this
slice is pushed. If pushed green, sync `gllvmTMB#488` and `gllvmTMB#340`.

## 8. What Did Not Go Smoothly

The first patch attempt used stale plot-helper prose and failed cleanly. The
second patch used exact current context and applied without changing unrelated
plot behavior.

## 9. Team Learning

- Hopper: An explicit gate can be as important as a routed method when adjacent
  point-only helpers already exist.
- Emmy: `plot_correlations()` should follow `extract_correlations()` semantics,
  not silently reinterpret point-only Sigma table rows as interval rows.
- Florence: Point-only correlation displays belong in Sigma table/heatmap
  helpers; confidence-eye/interval correlation plots require endpoints.
- Fisher: Correlation intervals need method/status metadata before promotion.
- Rose: The gate keeps `JUL-01A` partial and blocks accidental interval wording.
- Shannon: This slice was developed locally while the previous push's CI was
  still running; it must not be pushed until that run completes.

## 10. Known Limitations And Next Actions

- Implement interval-bearing Julia bridge correlation rows only after CI/status
  payload semantics exist for the relevant covariance target.
- Add richer extractor parity by family only after native-vs-Julia point and
  `link_residual = "auto"` contracts are specified.
- Keep structured tiers, rotations, residual-split reporting, and mixed-family
  interval rows gated.
