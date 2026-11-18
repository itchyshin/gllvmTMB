# Dual-arm L1 probe receipt — rescued from orphan g0-unlock clone

**Date:** 2026-08-18  
**Lane:** `cursor/mspl-forkB-l1-smoke-20260818` (folded into [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128))  
**Runner:** `dev/mspl-fork-b-l1-smoke.R`  
**Source clone:** `~/local-scratch/lanes/gllvmTMB-g0-unlock-20260818` (separate `.git`; tip `a6bb6916`, **not** an ancestor of [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130))  
**Not rescued:** the `R/mspl.R` `objective=` commit on that tip. That work lives on #1130 (`d364e952` / `4e3feb74`).

**Cell:** Bernoulli logit, ordinary `latent(d=1, unique=FALSE)`, `n_site=80`, `T=4` (not the ADEMP T=8 cell)  
**Estimand:** E1 only (first-trait intercept / first `b_fix`). E2 is out.  
**Arms:** `unpenalized` (fork B) and `penalised` (fork A ablation) via `objective=`  
**n_rep actually finished:** 6 (aborted). ADEMP L1 band is 50–100.  
**seed_base:** 20260818 (seeds 20260819..20260824)

**calibrated:** FALSE  
**public_confint:** refused  
**coverage_claim:** none  
**Totoro:** not run  
**MSPL-04:** still `blocked`  
**#1077:** still draft

## Verdict: INCOMPLETE, not a gate

Six replicates are below the signed L1 band. Do not read the table as L1 PASS or L1 FAIL. The 50-rep ADEMP receipt on the T=8 cell remains `docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md`.

| Arm | Fork | returned / refused / R-SAT | cov_ret | cov_eff | availability | refusal | median width |
|---|---|---|---|---|---|---|---|
| unpenalized | B | 6 / 0 / 0 | 1.000 Wilson [0.610, 1.000] | 1.000 Wilson [0.610, 1.000] | 1.000 | 0.000 | 1.014 |
| penalised | A | 5 / 1 / 0 | 1.000 Wilson [0.566, 1.000] | 0.833 Wilson [0.436, 0.970] | 0.833 | 0.167 | 1.090 |

The one fork-A refusal is `lower_crossed|upper_truncated` on seed 20260822. If someone wrongly applied the L1 gate to n=6, fork A would fail refusal (0.167 > 0.15) and availability (0.833 < 0.90). That counterfactual is recorded so the incomplete probe cannot be promoted later as a silent PASS.

## What this is not

- Not a replacement for #1128's 50-rep T=8 ADEMP receipt.
- Not a claim that `a6bb6916` should be merged or that #1130 should be rewritten from the orphan.
- Not L2, not T*, not E2, not Totoro admission.
- Not `NEWS` `covered`, not MSPL-04 promotion, not undraft of #1077.

Raw and summary CSVs sit next to this file (`*-raw.csv`, `*-summary.csv`). Re-run after #1130 merges, with `L1_N_REP` in 50–100, before treating dual-arm numbers as an L1 gate.
