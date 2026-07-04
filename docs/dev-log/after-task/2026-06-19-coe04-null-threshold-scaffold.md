# After-task report: COE-04 null-threshold scaffold

Date: 2026-06-19 04:05 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Strengthen the Paper 2 / COE-04 null-side evidence without promoting a full
Type-I or reusable null-threshold claim.

## Changed files

- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-coe04-null-threshold-scaffold.md`

## What changed

The heavy near-orthogonal null/signal grid now computes an empirical 95%
full-vs-intercept overfit-tail marker from the existing 12 fixed null seeds.
The gate keeps that marker below 8 log-likelihood units and requires both
planted medium-signal fixtures to beat the marker by more than 10x while still
recovering both component `Gamma_shape` blocks above 0.90 correlation.

This is a fixed-grid scaffold only. It does not close formal Type-I
calibration, reusable null-threshold coverage, `rho` estimation, interval
calibration, bridge completion, release readiness, or scientific coverage.

## Checks

- `gh pr list --state open`
  - only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - no recent all-branch commits were reported.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  - `FAIL 0 | WARN 0 | SKIP 12 | PASS 92`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 328`.

## Remaining guardrails

- COE-04 remains `partial`.
- Formal reusable null-threshold / Type-I calibration remains open.
- Broader moderate-overlap and high-overlap calibration remain open.
- Mixed-family recovery remains open beyond the construction smoke.
- `kernel_unique()` / source-specific `*_unique()` remain compatibility syntax
  and are not part of the Paper 2 multi-kernel path.
