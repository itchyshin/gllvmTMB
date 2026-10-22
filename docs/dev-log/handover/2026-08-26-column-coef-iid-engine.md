# Handover — internal IID response-column coefficient engine

**Date:** 2026-08-26
**Branch:** `codex/column-coef-iid-engine`
**Base:** `5a202fc8154a8e0c50c41ebb76932b0d805bdee8`
**Lane:** `codex:response-column-coef-iid`

## Goal and boundary

This narrow slice admits internal Gaussian `column_coef()` point fitting by
reusing the released response-column matrix-normal slope engine with identity
response-column covariance. It does not export or teach the helper, implement
structured `rho`, change TMB arithmetic, or alter/deprecate/warn from any
`*_slope()` API.

## Current state

- Focused six-file parser/IID/slope regression gate: PASS.
- Exact no-intercept coefficient-versus-slope objective, map, optimum,
  covariance, and fitted-value gate: PASS.
- Long/wide equality, `|`/`||`, known-DGP recovery, and finite-gradient gates:
  PASS.
- `pkgdown::check_pkgdown()`: PASS.
- Unchanged `where-does-the-tree-go` article render: baseline FAIL at
  `extract_Sigma(level = "column_slope")`; article repair remains separate.
- Broad `devtools::test()`: passed every file through
  `test-extractors-extra.R`, then was intentionally stopped at the declared
  20-minute ceiling in unrelated `test-extractors.R`; do not report this as a
  full-suite pass.
- Post-merge main run `33001159527` on the exact base remained active at the
  first closeout draft. Do not push this branch until it is terminal.

## Protected lanes

The LV lane at checkpoint `5185a96500a598147fe4c8fb6f50f0e26ada85cc` remains
frozen while main CI completes. Its owner explicitly agreed to preserve the
three response-column rows in `docs/design/01-formula-grammar.md` during
rebase and not restore blanket `*_coef()`-blocked wording. This slice touches
none of the LV-owned implementation paths. Random-slope confirmation paths
also remain untouched.

## Next safe actions

1. Receive terminal Rose review and fix only attributable findings.
2. Confirm run `33001159527` is terminal green on exact base.
3. Re-run the focused six-file gate and `git diff --check` after any review fix.
4. Commit only the leased IID paths, push once, open one narrow PR, and wait for
   exact-head CI before merging normally without bypass.
5. Observe post-merge main CI and release the IID lease.
6. Start fixed-`rho` `phylo_coef()` from fresh main under a new lease and new
   acceptance ledger. Do not combine estimated `rho` or article repair into
   the fixed-`rho` PR.

## Files

- Implementation: `R/column-coef-foundation.R`, `R/gllvmTMB.R`,
  `R/fit-multi.R`.
- Tests: `tests/testthat/test-column-coef-engine-iid.R`,
  `tests/testthat/test-column-coef-foundation.R`.
- Contracts: `docs/design/01-formula-grammar.md`,
  `docs/design/131-response-column-coefficient-foundation.md`,
  `docs/design/35-validation-debt-register.md`.
- Evidence: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-08-26-column-coef-iid-engine.md`, and the
  programme Ultra Plan.

FINDINGS-OF-RECORD: none beyond the admitted internal IID Gaussian point route
and the reproduced pre-existing tree-article extractor failure.

CARRIED-OVER: fixed and estimated phylogenetic source-strength engines, public
extractor/API, article migration, and animal/kernel/spatial extensions remain
on fresh sequential lanes.
