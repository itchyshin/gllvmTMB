# After-task report -- COE-04 fixed-rho sensitivity grid

Date: 2026-06-18 14:03 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds a fixed-`rho` sensitivity gate for the latent-only two-kernel
Paper 2 path. It does not estimate `rho`; it refits a small grid of supplied
`rho` values and checks whether positive cross-kernel signal is supported
relative to a block-null `rho = 0` fit.

## Implementation

- `tests/testthat/test-coevolution-two-kernel.R`
  - fixture now retains the matrices and association patterns needed to rebuild
    the phy cross-kernel;
  - `.c3_profile_phy_rho()` refits the same two-kernel model over a supplied
    fixed-`rho` grid;
  - the new heavy gate uses `rho = c(0, 0.25, 0.55, 0.85)` and requires the
    planted `rho = 0.55` plus the best positive grid point to beat `rho = 0`.
- `NEWS.md`, `docs/design/35-validation-debt-register.md`, and
  `docs/design/65-cross-lineage-coevolution-kernel.md` now record this as
  sensitivity evidence only.
- Dashboard `status.json` and `sweep.json` now show fixed-`rho` sensitivity as
  part of `COE-04 partial`.

## Scientific Boundary

The exploratory probe and committed test both preserve the key caution: the
best grid point may sit at the high edge because fixed kernel strength and
loading magnitudes trade off. The test therefore supports cross-signal
sensitivity, not `rho` recovery, profile intervals, or scientific coverage.

## Checks

- `devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 8 | PASS 47`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "coevolution-two-kernel")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 145`.
- `devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 11 | PASS 142`.
- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "kernel|coevolution")`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 265`.
- JSON validation for `docs/dev-log/dashboard/status.json` and
  `docs/dev-log/dashboard/sweep.json` passed.

## Review roles

- Fisher: fixed-`rho` sensitivity interpretation and anti-overclaim boundary.
- Curie: heavy simulation/test gate shape.
- Boole: method/API grammar remains fixed-kernel; no new user-facing function.
- Rose: validation-row and dashboard wording stay partial.
- Grace: test and JSON validation evidence recorded.

## Not done

- No in-engine `rho` estimation.
- No calibrated `rho` profile or interval.
- No mixed-family or non-Gaussian coevolution gate.
- No explicit two-kernel Psi support.
- No bridge, release, or scientific-coverage gate closure.
