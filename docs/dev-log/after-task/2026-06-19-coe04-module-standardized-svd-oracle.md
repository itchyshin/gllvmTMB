# After-Task Report -- COE-04 Module Standardized-SVD Oracle

Date: 2026-06-19
Branch: `codex/r-bridge-grouped-dispersion`
Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Strengthen the Paper 2 coevolution module gate by checking the fitted
`extract_coevolution_modules()` output against the covariance identity used in
the paper framing, without widening the claim beyond point-estimate derived
outputs.

## Scope

Changed:

- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-coe04-module-standardized-svd-oracle.md`

## What Changed

- Added a test-side inverse-square-root helper for the heavy COE-04
  near-orthogonal recovery fixture.
- The fixture now verifies that `extract_coevolution_modules()` returns the
  same standardized cross-lineage matrix as
  `Sigma_H^{-1/2} Gamma Sigma_P^{-1/2}`.
- The test also checks that the returned singular values equal `svd(R)$d`,
  `n_modules = 1` truncates modules and axis tables, and `scale = "effect"`
  scales both the module matrix and singular values by the fixed recorded
  `rho`.

## Checks

- Initial heavy rerun:
  `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  passed functionally with `FAIL 0 | WARN 2 | SKIP 0 | PASS 322`; the warnings
  came from a test-helper `ifelse()` evaluating an unused square-root branch.
- Final heavy rerun after fixing the helper:
  `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  passed with `FAIL 0 | WARN 0 | SKIP 0 | PASS 322`.
- Non-heavy focused rerun:
  `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  passed with `FAIL 0 | WARN 0 | SKIP 12 | PASS 92`.
- Dashboard JSON validation passed for `docs/dev-log/dashboard/status.json`
  and `docs/dev-log/dashboard/sweep.json`.
- `git diff --check` passed.
- The dashboard source was synced to `/tmp/gllvm-dashboard/`; both
  `http://127.0.0.1:8770/` and `http://127.0.0.1:8765/` returned HTTP 200.

## Definition Of Done

1. Implementation: local test slice implemented; not merged to `main`.
2. Simulation recovery test: extends the existing heavy near-orthogonal COE-04
   recovery fixture with a module-standardization oracle.
3. Documentation: Design 65, the validation-debt register, dashboard source,
   check log, and this after-task report updated.
4. Runnable user-facing example: not added; the cross-lineage article remains
   internal and fixed-rho/point-estimate only.
5. Check-log entry: added with exact commands and outcomes.
6. Review pass: Curie/Fisher-style claim discipline applied locally; this is a
   point-estimate module gate only.

## Still Not Claimed

- No module uncertainty.
- No biological rank calibration.
- No formal null-threshold calibration for module strength.
- No in-engine `rho` estimation or `rho` profile intervals.
- No interval calibration, bridge completion, release readiness, or scientific
  coverage completion.
