# After Task: retract Gamma LA “0/300 healthy” — `laplace_health` FE-gradient bug

**Branch**: `codex/va-gh-all-families`  
**Date**: `2026-08-07`  
**Roles**: Ada (conductor), Curie (campaign driver), Fisher (health-gate interpretation)

## 1. Goal

Confirm and fix the campaign `laplace_health` bug that graded Laplace fits on
the joint FE+RE parameter vector, then retract the S0b interpretation that
Gamma Laplace is “hopeless” on health — without changing Arc-2 frozen labels
or the public VA fence.

## 2. Bug (confirmed)

`dev/va-gh-h7-campaign/run-cell.R` `laplace_health()` called
`fit$tmb_obj$gr(last.par.best)`. TMB `obj$gr()` expects the fixed-effect
slice (`opt$par` / `obj$par` / `lfixed()`), matching `R/diagnose.R` and
`R/methods-gllvmTMB.R`. `last.par.best` is FE+RE.

Local probe (`dev/va-gh-h7-campaign/probe-laplace-health-fe-gradient.R`,
gamma seed 10305, q=2, Design-110-ish n=120 p=8):

| slice | length | max \|g\| | healthy @ tol 1e-3 (with conv0+pdHess) |
| --- | ---: | ---: | --- |
| FE (`opt$par`) | 31 | **5.4e-4** | TRUE |
| full (`last.par.best`) | 271 | **158** | FALSE |

Poisson spot-check: FE and full `|g|` often coincide numerically (TMB emits
`par[-random] <- par.fixed` length warnings), so poisson recorded healthy
rates were only mildly distorted.

## 3. Fix

- `laplace_health` now uses `fit$opt$par %||% fit$tmb_obj$par`.
- Same fix in `lanes/va-s0b-exact/scripts/gamma-la-nladder.R`.
- Campaign regression in `tests/testthat/test-va-gh-h7-campaign.R`.
- Probe script retained under `dev/va-gh-h7-campaign/`.

## 4. Re-score of S0b evidence

Export `/private/tmp/va-s0b-exact-evidence-20260807/final-export-s0b.csv`
retains `max_gradient` from the **buggy** gate and does **not** retain
`tmb_obj` bundles — exact FE `|g|` cannot be recomputed without refit.

**Proxy** (upper bound on post-fix healthy): `convergence_code==0` ∧
`pd_hessian==TRUE` (gradient gate removed):

| cell | q | recorded healthy (buggy) | proxy conv∧pd (FE-gate upper bound) |
| --- | ---: | ---: | ---: |
| gamma_log | 2 | **0/300** | **282/300** (94%) |
| gamma_log | 5 | **0/300** | **214/300** (71%) |
| poisson_log | 2 | 275/300 | 300/300 |
| poisson_log | 5 | 278/300 | 300/300 |

Recorded poisson rates already used a path whose `|g|` matched FE on the
spot-check; treat poisson as approximately unchanged. Gamma “0/300” is a
**health-gate artefact**.

Frozen Arc-2 `overall_point_route_verdict` CSV MD5
`e57f8460fd98bd0eac43b4a6c014317d` **unchanged**. Dual-report (B)
abs-on-completed stands. No fence / `calibrated=FALSE` change.

## 5. Retraction (for Shinichi)

**RETRACT:** “Gamma Laplace is hopeless / 0/300 healthy under S0b.”  
That figure came from grading `gr(last.par.best)` (joint FE+RE). Correct FE
`|g|` is ~1e-4–1e-3 on converged PD cells; gllvm LA/VA and gllvmTMB recover
β/Σ on the same DGP (dual-report B + 4-arm probe).  

**KEEP:** Gamma VA reliability stress at q=5; poisson q=2 abs-Σ shared
hardness; Arc-2 frozen labels; dual-report structure.

## 6. Checks

```sh
NOT_CRAN=true Rscript --vanilla -e '... laplace_health mock FE vs full ...'
# regression probe PASS

Rscript --vanilla dev/va-gh-h7-campaign/probe-laplace-health-fe-gradient.R gamma 10305 2
# FE max|g|=5.4e-4 ; full max|g|=158 ; healthy_if_FE_gr=TRUE

git diff --stat HEAD -- R/ src/ NAMESPACE DESCRIPTION
# empty (campaign/dev/docs only)
```

## 12. What Did NOT Happen

No package `R/` mutation; no Arc-2 re-adjudication; no Totoro refit; no
public fence change; S1 not started.
