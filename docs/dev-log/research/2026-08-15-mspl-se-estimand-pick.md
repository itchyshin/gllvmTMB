# Estimand pick — LA-MSPL SE feasibility pin

**Date:** 2026-08-15
**Lane:** `cursor/mspl-se-feasibility-pin`
**G0:** Shinichi pre-approved the ultra-plan Ada defaults
(Q1 = a, Q2 = a, Q3 = c).

Teacher:
`docs/dev-log/research/2026-08-15-mspl-binary-se-teacher.md`.

---

## Pick

**Both numerical curvature diagnostics, reported as separate typed
objects.**

| Name | Tape | Object | Action |
|---|---|---|---|
| Penalised Hessian | \(Q_P\) | `fit$tmb_obj` (`estimator_id = 1`) | `stats::optimHess` at \(\hat\theta_{\mathrm{MSPL}}\) |
| Penalty-off Hessian | \(Q_0\) | `fit$mspl$unpenalized_tmb_obj` (`estimator_id = 2`) | evaluate only; never optimise |

This is the smallest pair the binary lane actually formed. The
penalised Hessian is the route that always produced a matrix. The
penalty-off Hessian is the route that produced the non-PD failures
the binary campaign refused to repair. Running one alone cannot
tell *"Poisson curvature is unusable"* from *"this tape is
unusable."*

Neither object is `TMB::sdreport()`. Neither is \(I_{LA}(\beta)\).
The GLM-outer atom \(\tfrac12\log\det(X_*^\top W X_*)\) is a
penalty term, not an information matrix. Poisson still uses the
unpinned placeholder \(c = 1\), which does not vanish with \(N\).

---

## Rejected tonight

| Route | Why not |
|---|---|
| Sandwich / Godambe | Estimator-level blocker: no additive scores. Poisson \(W=\mathrm{diag}(\mu)\) is still global. |
| Penalised profile | Formable on binary (36/36) but expensive and still failed coverage (24/36). Breaks the 30-minute local budget. |
| Bootstrap | Same budget problem; saturated-mean collapse on binary. |
| Jackknife | Shinichi rejected. Do not revive. |
| Public `se = TRUE` → `sdreport()` | Withheld at the estimator. Do not edit `R/fit-multi.R`. |
| Public `vcov()` / `confint()` | Q1 = (a). Fail-closed. |

---

## Metrics (pre-registered; availability only)

For each of Bernoulli-logit and Poisson, on one tiny complete
ordinary \(q=1\) fixture:

- construction completes (yes/no)
- Hessian PD (yes/no) for each tape
- all SEs finite (yes/no) for each tape
- every attempt stays in the denominator

Non-PD is a typed status, not a repair. No pseudoinverse, no
eigenvalue clip, no nearest-PD, no substituting \(Q_P\) for \(Q_0\).

**Not computed:** coverage, width, nominal 95%, SE/SD ratios as a
promotion gate.

---

## Public contract that must not move

- `gllvmTMBcontrol(se = TRUE)` on an MSPL fit still leaves
  `sd_report` NULL and `mspl$inference$available` FALSE.
- `vcov()`, `confint()`, `standard_errors()` still throw
  `gllvmTMB_mspl_inference_unsupported`.
- Poisson registry stays `planned`.
- Prepare fence stays `family_id ∈ {0, 1, 2}`.
- The pin is unexported. Tests poison a silent \(Q_P\)/\(Q_0\) swap
  by asserting `estimator_id` 1 vs 2 and unequal tape NLLs when the
  penalty is nonzero.

---

## Non-claims

Forming a finite SE is not “MSPL has standard errors.” Poisson
\(c = 1\) is not a derived rate. Binary coverage numbers do not
transfer. D-135 (logit-only vault note vs admitted probit/cloglog
registry rows) is left untouched; this pin runs logit only.
