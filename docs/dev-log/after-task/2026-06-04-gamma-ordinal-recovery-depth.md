# After-task: gamma + ordinal_probit recovery-DEPTH cells

- Date: 2026-06-04
- Author: Claude Code
- Branch: `claude/family-validation-gamma-ordinal`
- Issue: #348 (family-validation completion); board #340 / Design 61 §1c
- Register rows: FAM-09 (gamma), FAM-14 (ordinal_probit) of
  `docs/design/35-validation-debt-register.md` — **NOT edited here** (a
  separate v0.2.0-tag-prep PR is refreshing Design 35 concurrently; the
  implied register changes are stated below for later reconciliation).

## Scope

Deepen the intercept-only recovery validation for the **gamma** (log link)
and **ordinal_probit** families. Both rows are register-`covered` on the
*intercepts + dispersion/cutpoints* recovery axis, but board #340 / Design
61 §1c flags them `partial` (`P`) on recovery **depth**: no prior cell
jointly recovers the trait fixed effects AND a NON-TRIVIAL between-unit
random-effect covariance Sigma — including its off-diagonal cross-trait
correlation — from one intercept-only fit. TESTS/validation only; NO engine
change. No engine bug was found.

## What existed before (the gap)

- `test-family-gamma.R`: recovers gamma intercepts + CV, but the latent
  `latent(d = 2)` Sigma itself is not asserted against truth.
- `test-ordinal-probit.R`: recovers cutpoints + intercepts, but the
  `unique(0 + trait | unit)` DGP carries NO between-unit variance (only the
  fixed N(0, 1) latent residual), so no planted Sigma is recovered.
- `test-matrix-gamma-unit.R` / `test-matrix-ordinal-unit.R` /
  `test-tiers-*.R`: recover the gamma CV, per-trait diagonal variances and
  loadings, but not a known FULL unstructured Sigma_B with a planted
  cross-trait correlation in the same intercept-only cell.

## Changes

- `tests/testthat/test-gamma-recovery-depth.R` (new): one heavy-gated cell.
  Simulates `value ~ 0 + trait + dep(0 + trait | unit)` from KNOWN
  log-intercepts, KNOWN gamma CV (shape 2 → CV 0.7071), and a KNOWN full
  between-unit covariance with planted cross-trait correlation rho = 0.5
  (SDs 0.7/0.6/0.5), with 5 replicates per cell so the CV and Sigma are
  jointly identified. Asserts: conv == 0, PD Hessian, family_id 4, dep_B
  flag, intercepts, CV, and `report$Sigma_B` (full unstructured T×T)
  diagonal variances + off-diagonal correlation.
- `tests/testthat/test-ordinal-recovery-depth.R` (new): one heavy-gated
  cell. Simulates `dep(0 + trait | unit)` ordinal (K = 4, tau = 0/0.7/1.4)
  from KNOWN latent intercepts and a KNOWN full between-unit covariance
  (SDs 0.9/1.0/0.8, planted rho = 0.5), 5 replicates per cell. Asserts:
  conv == 0, PD Hessian, family_id 14, dep_B flag, sigma_d == 1 exactly,
  intercepts, cutpoints, and `report$Sigma_B` diagonal + off-diagonal
  correlation.
- `.github/workflows/gamma-ordinal-recovery-depth.yaml` (new): heavy
  `pull_request` (+ `workflow_dispatch`) gate, modelled on
  `spatial-indep-slope-nongaussian-recovery.yaml`, running both files with
  `GLLVMTMB_HEAVY_TESTS=1`. Fails on any failed expectation / error; skips
  do NOT fail. Paths-filtered to the engine, the two depth tests, and the
  workflow.

## Bands (all INHERITED, none invented)

- intercepts: abs 0.30 (gamma: nb2 band `test-nb2-recovery.R:48`, ordinal:
  `test-ordinal-probit.R:66`).
- gamma CV: abs 0.15 (`test-matrix-gamma-unit.R`, mean-dependent → wide).
- ordinal cutpoints: abs 0.30 (`test-ordinal-probit.R:58-60`, looser of
  the two thresholds applied uniformly).
- Sigma_B diagonal variance: 40% median relative (the smoke-grade
  structural band, `test-matrix-ordinal-unit.R`, gamma tiers cells).
- Sigma_B off-diagonal correlation: gamma abs 0.25 (PHY-11 band), ordinal
  abs 0.30 (ordinal's looser smoke-grade convention).

## Outcome / checks

CI-only validation (no local R in this environment). The
`gamma-ordinal-recovery-depth` workflow is the evidence of record (run
26921782160, job 79423568227, `conclusion: success`):

```
tests/testthat/test-gamma-recovery-depth.R:   0 failed, 0 errored, 0 skipped across 1 tests
tests/testthat/test-ordinal-recovery-depth.R: 0 failed, 0 errored, 0 skipped across 1 tests
```

- **gamma → COVERED on recovery depth.** The joint cell passed
  NON-SKIPPED (10 assertions) at the FIRST n tried: n_unit = 120, 5 reps
  per cell. Intercepts, gamma CV, and the full between-unit `Sigma_B`
  (diagonal variances + planted rho = 0.5 cross-trait correlation) all
  recovered inside the inherited bands. No widening, no skip.
- **ordinal_probit → COVERED on recovery depth.** The joint cell passed
  NON-SKIPPED (12 assertions) at the FIRST n tried: n_unit = 150, 5 reps
  per cell. Intercepts, K = 4 cutpoints, sigma_d == 1, and the full
  between-unit `Sigma_B` (diagonal + planted rho = 0.5) all recovered
  inside the inherited bands. No widening, no skip.
- **No engine bug found.** Both fits converged PD on the first attempt;
  no engine change was needed or made.

## Register implication (for the concurrent Design 35 refresh to reconcile)

- **FAM-09 (gamma):** the gamma depth cell PASSED non-skipped in CI, so the
  recovery-DEPTH axis (board #340 / Design 61 §1c) moves `partial` →
  **`covered`**, with `test-gamma-recovery-depth.R` cited as the joint
  intercepts + CV + full between-unit Sigma (off-diagonal correlation)
  evidence (n_unit = 120, 5 reps). The cross-package comparator axis stays
  `partial` (unchanged — gllvm Procrustes / glmmTMB LL still outstanding).
- **FAM-14 (ordinal_probit):** the ordinal depth cell PASSED non-skipped in
  CI, so recovery-DEPTH moves `partial` → **`covered`** with
  `test-ordinal-recovery-depth.R` cited (joint cutpoints + intercepts +
  full between-unit Sigma, n_unit = 150, 5 reps); the cross-package mirt
  `graded` axis stays `partial` (unchanged).

## Follow-up

- Cross-package comparators remain outstanding for both (gamma: gllvm
  Procrustes / glmmTMB LL; ordinal: mirt `graded`) — separate axis, not in
  this scope.
- Reconcile the FAM-09 / FAM-14 register rows once the concurrent Design 35
  PR lands, using the CI job-log outcome.

https://claude.ai/code/session_01E83SkoXEaWMo1WRxj2Hud4
