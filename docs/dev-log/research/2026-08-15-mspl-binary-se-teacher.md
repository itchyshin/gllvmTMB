# Teacher extract — Codex binary LA-MSPL SE lane (PROTECTED)

**Date:** 2026-08-15
**Lane:** `cursor/mspl-se-feasibility-pin`
**Method:** `git -C` read-only. This checkout did not switch to
`codex/lane-b-mspl-interval-feasibility`. No file was copied, staged,
or merged from that tree.

**Source worktree:** `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`
**Branch / HEAD:** `codex/lane-b-mspl-interval-feasibility` @
`e91c7b7ce7c6f526eeccc0eb2fe518a4d4b6da20`

**Absorb rule:** none. Learn the method map. Do not import helpers.
Do not enable public `vcov()` / `confint()` / `sdreport()` from this
note.

A longer scout receipt already lives at
`docs/dev-log/research/_sweep-codex-interval-mspl-next.md`. This file
is the Poisson/Bernoulli-logit facing teacher the SE-pin GOAL asked
for.

---

## One-line verdict

Binary MSPL intervals can be *built* after `se = FALSE` fits. They are
**not** calibrated. The public SE door stays closed. Poisson inherits
the *discipline*, not the numbers.

---

## What the binary lane actually made work

Four different objectives, not four views of one matrix
(`docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-private-uncertainty-method-map.md`
@ `108815f4` in the Codex tree).

| Route | Object | Formable? | Joint coverage |
|---|---|---|---|
| Penalised numerical Hessian | `stats::optimHess` on \(\nabla^2 Q_P(\hat\theta)\) | yes, as a private diagnostic | not gated; SE/SD 1.07–1.35 on low-prevalence cloglog |
| Penalty-off Wald | \(\nabla^2 Q_0\) at the MSPL point, never optimised | 21/36 finite; 15/36 `likelihood_hessian_non_pd` | **9 / 36** |
| Penalised profile | nuisance-reoptimised crossing of \(Q_P\) | 36/36 after bracket-first bisection | **24 / 36** |
| Percentile bootstrap | full penalised refit | 36/36 | **20 / 36** |
| Godambe / sandwich | additive scores \(\nabla Q_P = \sum_s u_s\) | typed `score_decomposition_unavailable` | never built |
| Delete-one-site jackknife | site-deletion refits | **WITHDRAWN** | do not revive |

Campaign: 1,200 shards · 12,000 outer fits · 6,000,000 bootstrap
refits · 108,000 endpoints. Gate was availability ≥ 0.95 **and** a
90% Wilson coverage interval wholly inside [0.92, 0.98]. Overall
106/108 availability, 54/108 coverage, 53/108 joint. Receipt
SHA-256 `8232f1a8…c277ea1`.

**Smallest route that actually formed a number:** the penalised
numerical Hessian on `fit$tmb_obj`. TMB’s analytic Hessian is
unavailable with random effects. That route is a diagnostic, not
inference. The more informative single curvature object is \(Q_0\),
because that is where the non-PD failures appeared.

This GOAL therefore pins **both** Hessians (G0 Q3 = c). It does not
build profile, bootstrap, sandwich, or jackknife.

---

## `se = TRUE` is not a switch

In this tree and in the Codex tree, `estimator == "mspl"` sets
`sd_rep <- NULL` in `R/fit-multi.R` and writes
`sdreport_error = "LA-MSPL is an experimental point estimator;
standard errors are withheld until repeated-sampling calibration"`.
The `control$se` branch is reached only for non-MSPL fits.

Every private interval runner on the Codex lane fitted with
`se = FALSE`, then inverted a numerical outer Hessian or walked a
penalised profile. That is not `TMB::sdreport()`.

**Teacher for this pin.** Fit with `se = TRUE` only to prove the
public door still withholds. Form SEs on a *named private
construction*. Do not flip the withholding branch.

---

## Sandwich blocker (estimator-level)

`.gllvmTMB_mspl_sandwich_feasibility()` on the Codex branch records:

1. TMB’s outer gradient is total-only.
2. The Laplace log-determinant is added outside
   `joint_nll_penalized`.
3. Jeffreys and loading/covariance penalties use global \(N_{\mathrm{eff}}\)
   and \(X_{\mathrm{mspl}}\).

A Poisson atom \(X_*^\top\mathrm{diag}(\mu)X_*\) is also global.
Changing family does not create per-site scores. Sandwich stays
deferred.

---

## Seven lessons this pin inherits

1. Availability is cheap; calibration is the gate (106/108 vs 54/108).
2. Penalty-off Wald is the weakest route (9/36). Conditional-on-PD
   coverage lied (0.98 vs 0.52–0.63 unconditional). Retain non-PD.
3. Overcoverage is failure too (profile cell `C011` covered 1.000).
4. Bootstrap can collapse in saturated-mean regimes (`C011` target 3
   covered 0.01). Poisson analogues: all-zero traits *and* large \(\mu\).
5. Sandwich is blocked at the estimator, not the family.
6. Do not promote a passing subset. The frozen gate was 36/36.
7. Poisson information size is \(\mathrm{tr}(W)=\sum\mu\), not row
   count. A PD Hessian can still be mis-scaled.

---

## What this note does not do

- No checkout or absorb of the protected branch.
- No copy of Codex `R/mspl.R` helpers.
- No coverage, width, or nominal-95% claim.
- No Poisson or Bernoulli admission.
- No NEWS `covered`.
