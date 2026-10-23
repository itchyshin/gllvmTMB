# L1 local smoke receipt — Design 125 fork B

**Date:** 2026-08-18 15:21:11 UTC  
**Lane:** `cursor/mspl-forkB-l1-smoke-20260818`  
**Harness:** `dev/mspl-forkB-l1-ademp.R`  
**Runner:** `dev/mspl-forkB-l1-smoke.R`  
**Cell:** `L1-anchor-n80-T8` (Bernoulli logit, ordinary `latent(d=1, unique=FALSE)`, \(\pi\approx0.5\))  
**Estimand:** E1 only (first-trait intercept / first `b_fix`). E2 is out: the probe still requires `b_fix`.  
**n_rep:** 50 (ADEMP L1 band is 50–100)  
**seed_base:** 20260818  
**Elapsed:** 88.2 s (local; no Totoro)  
**Tape actually walked:** `Q_0` / Design 125 fork **B** on all 50 rows (`nuisance_treatment = fixed_at_mspl`, `reference_is_maximum = FALSE`)  
**L0 source:** `pkgload::load_all()` of this tree after rebase onto `origin/main` @ `2f80d844` (includes [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) `d7f526d4`). **Main-reproducible.**

An earlier 50-rep walk against the L0 worktree ([#1126](https://github.com/itchyshin/gllvmTMB/pull/1126), blob `3a04da5f` of `R/mspl.R`) produced the same counts (50 / 0 / 44) and the same Wilson band. That walk is superseded by this one.

**calibrated:** FALSE  
**public_confint:** refused  
**coverage_claim:** none  
**Totoro:** not run  
**MSPL-04:** still `blocked`

## Numbers (honest; not a public claim)

| Quantity | Value | L1 rule | Met? |
|---|---|---|---|
| availability (non–R-SAT) | 1.0000 | ≥ 0.90 | yes |
| refusal | 0.0000 | ≤ 0.15 | yes |
| cov_ret | 0.8800 | Wilson reported | — |
| cov_eff (refusals priced as 0) | 0.8800 | Wilson not entirely below 0.80 | yes |
| Wilson 95% on cov_eff | [0.7620, 0.9438] | upper ≥ 0.80 | yes |
| n_returned / n_refused / n_cover | 50 / 0 / 44 | — | — |

**L1 gate: PASS** on this one local anchor cell. That is the ADEMP L1 plumbing-plus-crude-coverage gate, not a Totoro T\* campaign and not a licence for public `confint`.

The Wilson interval for \(\widehat{\mathrm{cov}}_{\mathrm{eff}}=0.88\) **overlaps** 0.80 (upper 0.944) and also **dips below** 0.80 (lower 0.762). The signed L1 rule is the former. Nominal 0.95 is **not** inside the interval; L1 does not require that.

A 1-rep smoke-first inspection of the same cell (seed_base + 1) returned a two-sided `Q_0` interval (availability 1, refusal 0) before the 50-rep walk. n_rep=1 is not an L1 gate.

## What this is not

- Not L2 (no near-tail cell, no multi-seed panel).
- Not T1/T2 and not a Totoro admission.
- Not E2 (loadings) coverage.
- Not `NEWS` `covered`, not MSPL-04 promotion, not undraft of #1077.
