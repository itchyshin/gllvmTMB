# After Task: R/Julia Bridge Capability Drift Guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Hopper, Karpinski, Rose, Shannon, Grace

## 1. Goal

Add a small guard against gate-vs-engine drift. The R bridge has a conservative
`gllvm_julia_capabilities()` ledger, while the paired Julia checkout exposes
`GLLVM.bridge_capabilities()`. If Julia exposes a row that R keeps gated, the
difference should be named. If R advertises a row that Julia does not expose,
the test should fail as an overclaim.

## 2. Implemented

- Added `.gllvm_julia_capabilities_df()` to normalise R and Julia capability
  surfaces to the same data-frame shape.
- Added `.gllvm_julia_expected_capability_drifts()` for intentional
  cross-surface differences. The current expected row is `binomial` /
  `cbind_binomial`, linked to `GJL-GATE-CBIND-BINOMIAL`, `gllvmTMB#488`, and
  `JUL-01`.
- Added `.gllvm_julia_capability_drift()` to compare R and Julia capability
  surfaces over the shared logical capability columns.
- Added a pure-R test fixture that proves:
  - the expected `cbind_binomial` drift is labelled `gated`;
  - a future Julia-broader row without a gate is `unregistered`;
  - an R-broader row is also `unregistered`.
- Added a live JuliaCall test that reads `GLLVM.bridge_capabilities()` from
  `GLLVM.jl-integration` and confirms the only current drift is the registered
  `GJL-GATE-CBIND-BINOMIAL` row.

No capability was promoted. This is a governance and regression guard.

## 3. Files Changed

- Bridge internals: `R/julia-bridge.R`
- Tests: `tests/testthat/test-julia-bridge.R`
- Validation/status ledgers: `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/coordination-board.md`, `docs/dev-log/check-log.md`
- After-task report: this file

## 4. Checks Run

- Pre-edit coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,author,updatedAt,isDraft,mergeStateStatus,url`
  -> one open draft PR, #489, on `codex/r-bridge-grouped-dispersion`, merge
  state `CLEAN`.
- Recent hot-file scan:
  `git log --all --oneline --since='6 hours ago' --name-only -- R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/coordination-board.md man/gllvm_julia_capabilities.Rd`
  -> recent overlapping edits were from the current Codex bridge stack only.
- Julia surface scout:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); gllvm_julia_setup(); caps <- JuliaCall::julia_eval("GLLVM.bridge_capabilities()"); str(caps); JuliaCall::julia_command("GC.gc()")'`
  -> `JuliaCall` returned a `JuliaNamedTuple` list with the expected bridge
  capability columns.
- First no-Julia bridge test:
  `GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures, `14` expected live-Julia skips.
- First live bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> failed in the new live drift guard because `as.data.frame()` does not
  coerce class `JuliaNamedTuple` directly.
- Formatting and no-Julia rerun:
  `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R && GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures, `14` expected live-Julia skips.
- Live bridge rerun:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> `0` failures.

## 5. Tests of the Tests

The pure-R test injects two artificial future mistakes: an unregistered
Julia-broader `nb1` fixed-effect-X row and an R-broader ordinal X-CI row. Both
must be reported as `unregistered`, so the guard fails future silent drift in
either direction.

The live test uses the actual `GLLVM.bridge_capabilities()` surface and would
fail if Julia adds a new bridge capability that R has not admitted or gated.

## 6. Consistency Audit

- `JUL-01` remains `partial`.
- The only current expected cross-surface drift is `binomial` /
  `cbind_binomial`, because Julia exposes a count-matrix bridge flag but the R
  bridge still gates cbind marshaling.
- The guard does not change user-facing dispatch behavior and does not make
  `engine = "julia"` broader.
- The gate registry remains the user-facing stop-message ledger; the drift
  helper is the R/Julia capability-surface comparison.

## 7. Roadmap Tick

This advances `gllvmTMB#488` from a named-gate inventory toward an actual
drift-control guard. It is still not enough to close #488, because public matrix
rows and future Julia capability additions still need issue-ledger review.

## 8. What Did Not Go Smoothly

The first live test exposed a real coercion gap: `JuliaCall` returns
`GLLVM.bridge_capabilities()` as class `JuliaNamedTuple`, which prints like a
list but does not dispatch through `as.data.frame()` directly. The normaliser
now unclasses list-like surfaces before coercion.

## 9. Team Learning

- Hopper: drift checks should operate on structured capability columns, not
  search error-message text.
- Karpinski: the Julia bridge can expose a broader engine surface while R
  remains deliberately narrower; the comparison should preserve that distinction.
- Rose: unregistered R-broader rows are overclaims and must fail immediately.
- Shannon: this slice was started only after the prior PR head was green and
  merge-clean.

## 10. Known Limitations And Next Actions

- This guard compares the flat bridge capability table only. It does not yet
  compare every individual `GJL-GATE-*` stop to a public capability-matrix row.
- A later slice can expose a read-only drift table for maintainers if the
  internal helper proves useful during review.
