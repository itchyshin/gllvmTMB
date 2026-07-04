# After-Task Report -- COE-04 Mixed-Family Construction Smoke

Date: 2026-06-19
Branch: `codex/r-bridge-grouped-dispersion`
Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Add one narrow Paper 2 coevolution gate for heterogeneous trait families without
expanding the model claim beyond point-estimate construction evidence.

## Scope

Changed:

- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-coe04-mixed-family-construction-smoke.md`

## What Changed

- Added a heavy COE-04 construction smoke that fits the latent-only two-kernel
  coevolution path on long-format mixed-family data.
- The fixture keeps host traits Gaussian and casts partner traits to Poisson
  counts through the package's per-row family dispatch.
- The test verifies convergence, finite log likelihood, near-orthogonal kernel
  diagnostics, finite component shared-Sigma blocks, and finite component
  `Gamma_shape` point blocks.

## Checks

- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  passed with `FAIL 0 | WARN 0 | SKIP 12 | PASS 92`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  passed with `FAIL 0 | WARN 0 | SKIP 0 | PASS 313`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with
  `No problems found.`
- Dashboard JSON validation and `git diff --check` passed.

## Definition Of Done

1. Implementation: local test slice implemented; not merged to `main`.
2. Simulation recovery test: not claimed. This is construction-smoke evidence
   only, not mixed-family recovery.
3. Documentation: Design 65, the validation-debt register, dashboard source,
   check log, and this after-task report updated.
4. Runnable user-facing example: not added; the cross-lineage article remains
   internal and fixed-rho/point-estimate only.
5. Check-log entry: added for the exact commands and remaining gates.
6. Review pass: local Curie/Fisher-style test-scope discipline applied by
   keeping the claim at construction evidence only.

## Still Not Claimed

- No mixed-family `Gamma` recovery threshold.
- No mixed-family interval calibration.
- No broader heterogeneous-family coverage.
- No in-engine `rho` estimation or profile intervals.
- No bridge completion, release readiness, or scientific coverage completion.
