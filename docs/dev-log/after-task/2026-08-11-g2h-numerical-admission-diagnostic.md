# After Task: G2h retained numerical-admission diagnostic

## 1. Goal

Diagnose the private G2h numerical-admission hold from retained artifacts and return one approval-ready repair decision without fitting, profiling, retrying, or changing the frozen model.

## 2. Implemented

The diagnostic verifies G2h provenance, recomputes the saved AD gradient twice at the retained optimum, maps the maximum to `lambda_sp2`, examines saved covariance-derived curvature, and records the existing warm-restart guard's boundary veto. The paired symbolic alignment note gives the exact mapping and predeclares one conditional same-objective polish repair.

## 3a. Decisions and Rejected Alternatives

The one recommendation is a narrow optimizer-control repair that may polish a non-boundary gradient despite one unchanged near-zero diagonal-SD boundary. Rejected: relaxing the `1e-3` threshold; changing the fixture, DGP, rank, likelihood, source gate, or parameterisation; interpreting the profile result as campaign evidence; and retrying the completed root.

## 4. Files Touched

- `dev/isdm-package-recovery/2026-08-11-g2h-numerical-admission-diagnostic.md`
- `docs/dev-log/plan-actual/2026-08-11-g2h-numerical-admission-reconciliation.md`
- this report and `docs/dev-log/check-log.md`

No source code, frozen G2h input/output, public API, Rd, README, NEWS, vignette, pkgdown configuration, or Issue #953 changed.

## 5. Checks Run

Read-only provenance and manifest readback passed. Two direct AD-gradient evaluations were identical with maximum `0.001290534`. Saved `sd_report$pdHess` is true; its `cov.fixed` inverse gave loading-coordinate curvature `261.7304`, while the diagonal-boundary coordinate was flat. `git diff bdc3da6a -- R/isdm-developer-fit.R R/fit-multi.R R/diagnose.R src/gllvmTMB.cpp` was empty.

## 6. Tests of the Tests

No test or model source was changed. The diagnosis cross-checks the gradient result against three independent retained representations: the decision ledger, saved `fit_health`, and repeated AD evaluation. The proposed future no-fit tests explicitly cover both boundary-permitted loading gradients and boundary-dominated rejection cases.

## 7a. Issue Ledger

No issue was created, inspected, commented, or changed. Issue #953 remains expressly out of scope.

## 8. Consistency Audit

`rg -n 'theta_rr_B|theta_diag_B|isdm_gbif|isdm_pa|iJSDM|isdm' R src/gllvmTMB.cpp docs/design dev/isdm-package-recovery` confirmed the private iJSDM route, rank-one loading, diagonal-SD, and source-gate names used in the alignment note. G2c stays `G2C_SMOKE_ADMISSION_HOLD`; G2d--G2g records remain unchanged. No public G2h claim exists.

## 9. What Did Not Go Smoothly

Direct `TMB::ADFun$he()` is unavailable with random effects. The saved positive-definite `sd_report$cov.fixed` is the relevant retained Hessian-derived evidence; no new Hessian, fit, or profile computation was substituted.

## 10. Known Residuals

The diagnosis is local to one synthetic retained fit. Its covariance correlations and curvature cannot prove global identifiability or recovery. The recommended repair has not been implemented or tested, and G2h remains a hold.

## 11. Team Learning

Gauss's numerical perspective separates the coordinate causing the gradient from the coordinate at the variance boundary. Rose's provenance perspective keeps the frozen raw cutoff binding even when scaled/local stationarity indicates the miss is numerically negligible.

## 12. Cross-Product Coverage

This covers only retained G2h optimizer, gradient, covariance, profile, map, and provenance diagnostics for the private nonspatial six-species iJSDM. It does not cover repair implementation, replacement smoke, recovery, campaign, spatial or detection extensions, count data, empirical data, comparators, zero inflation, or public/package work.

**Roadmap tick**: N/A; no public roadmap row changed.
