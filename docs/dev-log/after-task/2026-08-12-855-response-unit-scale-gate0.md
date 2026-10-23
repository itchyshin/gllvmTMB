# After Task: #855 response-unit scale Gate 0

**Branch**: `codex/scale-equivariance-gate0`
**Date**: `2026-08-12`
**Roles (engaged)**: Ada, Gauss, Rose, Shannon

## 1. Goal

Determine whether #855 can safely begin an internal per-trait response-unit
scaling implementation on current `main`, without changing package behaviour or
claiming a new capability.

## 2. Implemented

No package code, tests, public documentation, likelihood, family, or formula
grammar changed.  Gate 0 produced a source-verified no-go decision packet at
`docs/dev-log/audits/2026-08-12-855-response-unit-scale-gate0.md`.

## 4. Files Touched

- `docs/dev-log/audits/2026-08-12-855-response-unit-scale-gate0.md` — decision packet.
- This after-task report.
- `docs/dev-log/plan-actual/2026-08-12-855-response-unit-scale-gate0.md` — plan reconciliation.
- `docs/dev-log/check-log.md` — compact check receipt.

No status-inventory, NEWS, README, ROADMAP, vignette, generated Rd, or pkgdown
file changed because Gate 0 made no user-facing change.

## 3a. Decisions and Rejected Alternatives

**Decision:** do not implement #855's per-trait internal scaling on the current
pooled-`sigma_eps` parameterisation.  **Rationale:** exact per-trait scaling
requires `sigma_eps / s_t`, which one scalar cannot represent.  **Rejected:**
back-transforming public outputs while leaving the pooled likelihood unchanged;
that would fit a different model.  **Confidence:** high, from direct engine and
consumer reads plus the halted #856 record.

## 5. Checks Run

- `lane_preflight.sh`: foreign dirty Claude lane and multiple Codex lanes found;
  created an isolated worktree from `origin/main` at `cb312689`.
- Live issue/PR read: #855, #872, #897, and open PRs were reconciled before the
  worktree was created; no issue state was modified.
- `rg -n 'logLik\\.|AIC\\(|BIC\\(|anova\\(|extract_residual|residuals\\.|predict\\.gllvmTMB_multi|simulate\\.gllvmTMB_multi|tmb_data\\$y|report\\$eta|report\\$sigma_eps' R`
  located all high-risk response-scale consumers; verdict recorded in the audit.
- Read `docs/dev-log/after-task/2026-07-30-856-per-trait-sigma-eps.md`; its
  halted banner establishes that the vector-residual proposal is not reusable.

No fits, simulations, compilation, tests, package checks, or compute were run:
this was a source/architecture gate and no executable behaviour changed.

## 6. Tests of the Tests

No tests changed.  Existing `test-scale-equivariance.R` remains the in-suite
common-scale guard; the fuller dev oracle additionally observes fixed effects,
communality, and log likelihood.  Neither is evidence for unequal per-trait
scaling with a pooled residual SD.

## 8. Consistency Audit

- `rg -n 'response[- ]unit scale|response standardi[sz]ation|scale equivariance' README.md NEWS.md ROADMAP.md docs/design docs/dev-log/known-limitations.md`
  found no public claim requiring correction; the new audit distinguishes this
  architecture question from standardized loading outputs.
- `rg -n 'MIS-35|scale-equivariance|scale equivariance|scale-constant|scale constant|#855|851' docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/handover`
  confirmed MIS-35 is intentionally narrow and prior #856 material is visibly
  marked halted.

## 7a. Issue Ledger

- #855 inspected and narrowed; not commented or closed because no implementation
  landed.
- #872 inspected and retained as the separate two-tier-flatness issue.
- #897 inspected and retained as unrelated ordinal diagnostics work.
- #952 observed as a dirty experimental MSPL PR; not touched.

## 9. What Did Not Go Smoothly

The original proposed arc treated the per-trait residual requirement as an
implementation complication.  The historical #856 halt and direct C++ contract
show it is instead the premise-level blocker.  Finding that before code or
compute is the intended value of Gate 0.

## 11. Team Learning

**Shannon** identified the crowded/foreign lane state, so the gate used a fresh
worktree and no shared-lane files.  **Gauss** established that pooled
`sigma_eps` prevents a model-preserving per-trait transform and that REML cannot
inherit an ML Jacobian.  **Rose** required a distinction between response-unit
equivariance and standardized-loading output, and kept #851/#872/#897 fenced.
**Ada** consolidated the evidence into a stop decision rather than manufacturing
an implementation slice.

## 10. Known Residuals

#855 remains open and blocked on an architectural choice.  A future arc must
either target one already-measured scale-dependent constant locally under the
existing model, or propose a distinct per-trait residual-capability programme
with simulation/compute approval.  Do not reopen #851 tier scoping, claim a
package-wide scale-equivalence fix, or treat #872 as resolved.

## 12. Cross-Product Coverage

This gate covers the current native-Laplace source contract for pooled
`sigma_eps`, the ML common-scale law, and the direct R consumers that expose
`y`, `eta`, or `sigma_eps`.  It does NOT cover REML, AGHQ, VA, EVA, weighted or
masked likelihood transformations, mixed-family traits, offsets, shared fixed
coefficients, loading constraints, common-variance terms, random slopes,
structured covariance tiers, bootstrap calibration, old serialized objects, or
any per-trait residual redesign.  Those are separate cells that require a
fresh mathematical contract and evidence.
