# After-task report: COE-04 moderate-overlap three-cell grid

Date: 2026-06-19 04:10 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Broaden the promoted Paper 2 / COE-04 moderate-overlap recovery evidence while
keeping the harder 0.40 cell as a claim-boundary stop marker.

## Changed files

- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-coe04-moderate-overlap-three-cell.md`

## What changed

The heavy moderate-overlap gate now promotes three cells:
`non_association_blend = 0.25`, `0.30`, and `0.35`. All three cells stay in
the moderate overlap class, converge, beat either one-component comparator by
more than 50 log-likelihood units, recover both component `Gamma_shape` blocks
above 0.95 correlation, and keep cross-component matches below 0.25.

The tested `0.40` cell remains a boundary: it detects signal but fails the
promoted component-separation thresholds.

## Checks

- `gh pr list --state open`
  - only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - no recent all-branch commits were reported.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  - `FAIL 0 | WARN 0 | SKIP 12 | PASS 92`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 341`.

## Remaining guardrails

- COE-04 remains `partial`.
- Harder moderate-overlap calibration beyond the promoted 0.25-0.35 grid
  remains open.
- High-overlap truth-recovery / failure calibration remains open beyond the
  current collapse, non-identical failure, and warning gates.
- Formal reusable null-threshold / Type-I calibration remains open.
- `rho` estimation, intervals, bridge completion, release readiness, and
  scientific coverage remain open.
