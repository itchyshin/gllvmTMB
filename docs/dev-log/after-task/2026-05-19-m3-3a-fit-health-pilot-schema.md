# After Task: M3.3a Fit-Health Pilot Schema

**Branch**: `codex/m3-3a-fit-health-pilot-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Start Branch B after PR #206 passed CI, and make the M3.3a pilot
artifact schema carry the robust-modeling diagnostics needed to compare
starts, optimizers, `pdHess`, skipped-SE fits, bootstrap failures, and
multicore bootstrap behavior.

## 2. Implemented

- `dev/m3-grid.R` now accepts and records `start_method`, start jitter,
  optimizer, optimizer arguments, `n_init`, `init_jitter`, `se`, and
  `n_cores_boot`.
- Each per-target row now carries fit-health metadata: convergence
  code/message, objective, max gradient, `pdHess`, `sdreport_ok`,
  `sdreport_error`, selected restart, restart count, objective spread,
  and boundary flags.
- `m3_summarise()` reports diagnostic rates and medians:
  `pd_hessian_rate`, `sdreport_ok_rate`, `median_max_gradient`,
  `median_restart_count`, and `median_objective_spread`.
- `dev/precompute-m3-grid.R` now exposes CLI arguments for starts,
  optimizer choice, skipped SEs, bootstrap cores, and stores those
  settings in artifact metadata.
- The dev driver now prefers `pkgload::load_all(".")` so local pilot
  runs use the current branch implementation rather than an older
  installed namespace.

## 3. Files Changed

- `dev/m3-grid.R`
- `dev/precompute-m3-grid.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-19-m3-3a-fit-health-pilot-schema.md`

## 3a. Mathematical Contract

No likelihood, family, formula grammar, covariance keyword, or package
API changed in this branch. The mathematical target remains
`Sigma_unit_diag = diag(Lambda Lambda^T + Psi)` for the unit-tier
bootstrap path. This branch changes the artifact schema and pilot
controls only.

## 3b. Decisions and Rejected Alternatives

**Decision**: record diagnostic metadata per target row.
**Rationale**: simulations need stable columns for aggregation, even
when fit failures produce no trait-level intervals.
**Rejected alternative**: parse `check_gllvmTMB()` text or inspect
saved fit objects after the fact.
**Confidence**: high.

**Decision**: keep two-level Gaussian as a separate smoke in this
slice.
**Rationale**: the current M3 grid is unit-tier latent+unique. A full
within/between target grid needs a follow-up DGP expansion rather than
a rushed schema change.
**Rejected alternative**: force a two-level DGP into the existing
`family` column.
**Confidence**: medium-high.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); invisible(parse(file="dev/precompute-m3-grid.R")); cat("parse ok\n")'`
  - Outcome: `parse ok`.
- Summary mock with diagnostic columns
  - Outcome: summary included `pd_hessian_rate`, `sdreport_ok_rate`,
    `median_max_gradient`, `median_restart_count`, and
    `median_objective_spread`.
- Gaussian driver smoke with `se = FALSE`, residual start, two
  restarts, and bootstrap `Sigma_unit_diag`
  - Outcome: completed; artifact recorded `start_method = "res"`,
    `n_init = 2`, `se = FALSE`, `sdreport_ok = FALSE`, restart count
    2, and `n_cores_boot = 1`.
- Tiny `nbinom2` driver smoke with the same settings
  - Outcome: fit and bootstrap completed; one-rep toy summary was
    `TARGET_FAIL`, with median estimate/truth ratio above 2.
- Tiny mixed-family driver smoke with the same settings
  - Outcome: fit and bootstrap completed; one-rep toy summary was
    `TARGET_FAIL`.
- Gaussian multicore bootstrap smoke with `n_cores_boot = 2`
  - Outcome: completed and recorded `n_cores_boot = 2`.
- Two-level Gaussian smoke outside the unit-tier M3 grid
  - Outcome: optimizer converged, max gradient passed, `sdreport`
    warned because `se = FALSE`, selected restart 2, and boundary flags
    exposed near-zero unit-tier SD.

## 5. Tests of the Tests

This branch changes dev-only scripts under `dev/`, so it uses
script-level assertions and smoke runs rather than `testthat` files.
The smokes exercise successful fit rows, bootstrap rows, multicore
bootstrap metadata, fit-health summary aggregation, and a two-level
hard-fit diagnostic path.

## 6. Consistency Audit

- `rg -n "fit_health|pd_hessian|sdreport_ok|selected_restart|n_cores_boot|start_method" dev/m3-grid.R dev/precompute-m3-grid.R`
  - Outcome: the driver and library agree on the new metadata fields.

## 7. Roadmap Tick

M3 remains `3/8`. This is the first Branch B schema/pilot smoke after
PR #206; it does not promote CI-08 / CI-10 or any family stress lane to
covered.

## 8. What Did Not Go Smoothly

The first CLI smoke used the previously installed package namespace
instead of the local branch implementation, so `se = FALSE` was ignored
and fit-health fallback lacked the Branch 0 helper. The driver now uses
`pkgload::load_all(".")` when available, and `m3_fit_health_row()` has a
local fallback for older fit objects.

## 9. Team Learning

**Ada** kept Branch B dependent on PR #206 rather than mixing pilot
schema changes into the green Branch 0 PR.

**Curie** made the pilot artifact schema richer before increasing
replicate count, so later failures are classifiable.

**Fisher** kept the target boundary clear: one-rep smokes are schema
evidence, not coverage evidence.

**Grace** added explicit `n_cores_boot` tracking and confirmed both
single-core and two-core bootstrap smoke paths.

**Rose** kept the validation-debt status unchanged. No coverage row
moves until a real M3.3a pilot runs.

**Shannon** tracked this as a dependent branch while PR #206 remains
open and green.

## 10. Known Limitations And Next Actions

- The real M3.3a pilot still needs replicate count greater than one:
  start with Gaussian, `nbinom2`, mixed-family, and the separate
  two-level Gaussian DGP.
- The unit-tier M3 grid does not yet include a true within/between
  target schema. Add `Sigma_unit_obs_diag` or a separate two-level
  pilot function before scaling that cell.
- The one-rep `nbinom2` and mixed-family smokes completed compute but
  failed target coverage; this is an early warning, not a statistical
  conclusion.
