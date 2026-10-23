# L2 local smoke receipt — Design 125 fork B

- **Date:** 2026-08-18 19:52:12 UTC
- **Lane:** `cursor/mspl-forkB-L2-exec-20260818`
- **Harness:** `dev/mspl-forkB-l1-ademp.R`
- **Runner:** `dev/mspl-forkB-l2-smoke.R`
- **Estimand:** E1 only (first-trait intercept / first `b_fix`). E2 is out: the probe still requires `b_fix`.
- **Tape actually walked:** `Q_0` / Design 125 fork **B** on all 150 new rows (`nuisance_treatment = fixed_at_mspl`, `reference_is_maximum = FALSE`)
- **L0/L1 source:** `R CMD INSTALL` of this tree @ `2a2a0450` (`origin/main`, includes [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) and official L1 [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128)) into `/tmp/gllvmtmb-l2-rlib`. **Main-reproducible.**
- **Elapsed:** 30.6 s for the three new 50-rep cells (local; no Totoro). Compile of the worktree was separate.
- **calibrated:** FALSE
- **public_confint:** refused
- **coverage_claim:** none
- **Totoro:** not run
- **MSPL-04:** still `blocked`

L2 is a recording gate (ADEMP §P5). It does **not** freeze a T\* numeric band. Interior seeds are compared to inherited official L1 cov_eff **0.880** in prose only. The L1 Wilson-not-entirely-below-0.80 rule is **not** reapplied as an L2 pass/fail.

## Smoke-first (K2), inspected before the panel

Both 1-rep walks returned a two-sided `Q_0` / fork B interval, finite, `lo < hi`, after a compiled DLL was loaded. n_rep=1 is not an L2 gate.

| Arc | Cell | seed | lo | hi | truth | covered |
|---|---|---|---|---|---|---|
| K2a | `L1-neartail-n40-T4` | 20260822 | −3.196 | −1.212 | −1.6 | yes |
| K2b | `L1-anchor-n80-T8` | 20260820 | −0.575 | 0.594 | 0 | yes |

An earlier `pkgload::load_all(..., compile = FALSE)` on this fresh worktree had **no** `gllvmTMB` DLL and classified both cells `R-FIT`. That was a missing-binary, not a typed ADEMP refusal. Smoke-first was re-run after `R CMD INSTALL`.

## Numbers (honest; not a public claim)

Seed A is **inherited** from official L1. It was not re-walked.

| Role | Cell | seed_base | n_rep | avail. | refusal | cov_ret | cov_eff | Wilson 95% (eff = ret) | MCSE | n_ret / n_ref / n_cov |
|---|---|---|---|---|---|---|---|---|---|---|
| Seed A (inherit) | `L1-anchor-n80-T8` | 20260818 | 50 | 1.000 | 0.000 | 0.880 | 0.880 | [0.7620, 0.9438] | 0.0460 | 50 / 0 / 44 |
| Seed B (new) | `L1-anchor-n80-T8` | 20260819 | 50 | 1.000 | 0.000 | 0.900 | 0.900 | [0.7864, 0.9565] | 0.0424 | 50 / 0 / 45 |
| Seed C (new) | `L1-anchor-n80-T8` | 20260820 | 50 | 1.000 | 0.000 | 0.900 | 0.900 | [0.7864, 0.9565] | 0.0424 | 50 / 0 / 45 |
| Near-tail (new) | `L1-neartail-n40-T4` | 20260821 | 50 | 1.000 | 0.000 | 0.780 | 0.780 | [0.6476, 0.8725] | 0.0586 | 50 / 0 / 39 |

Refusal pricing: every refusal is a non-cover in `cov_eff`. Here refusal is 0 on every cell, so \(\widehat{\mathrm{cov}}_{\mathrm{ret}} = \widehat{\mathrm{cov}}_{\mathrm{eff}}\). Dual columns are still reported. Wilson and MCSE (\(\sqrt{\hat p(1-\hat p)/n}\)) use the same denominator as the named coverage.

**L2 verdict: RECORDED.** All 150 new rows are typed, two-sided, `tape = Q_0`, fork B. No empty cell. No uncalibrated Wald substitute.

Interior seeds sit next to inherited 0.880 (0.900 / 0.900 / 0.880). The near-tail cell is lower (0.780); its Wilson interval overlaps 0.80 and also dips below it. That is a description, not a T\* freeze and not an L1-rule FAIL.

Object: `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.rds`.

## What this is not

- Not T1/T2 and not a Totoro admission.
- Not a calibrated coverage claim and not a licence for public `confint`.
- Not E2 (loadings) coverage.
- Not `NEWS` `covered`, not MSPL-04 promotion, not undraft of #1077.
- Not a rewrite of official L1 0.880. The companion 0.935 / 400-row walk remains a different harness.
