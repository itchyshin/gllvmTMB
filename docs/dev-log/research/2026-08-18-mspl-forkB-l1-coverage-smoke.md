# L1 local coverage smoke — Design 125 fork B (anchor cell)

**Date:** 2026-08-18 06:50 local
**Lane:** measured on `cursor/mspl-forkB-l1-coverage-gate-20260818` (L0 unlock + L1 harness); this receipt is being landed on a `main`-based PR that does **not** ship `R/mspl.R`.
**Door used:** `.gllvmTMB_mspl_profile_feasibility` with a `tape` selector (`tape = "Q_0"`). Self-report: fork **B**, `objective_source = fit$mspl$unpenalized_tmb_obj (penalty-off Laplace at fixed MSPL nuisance)`, `reference_is_maximum = FALSE`.
**Not on current `main`:** current `main` still has the fork-A-only probe (no `objective=` / `tape=` selector). Re-run after [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) merges so the receipt is `main`-reproducible. This is the same "measured against an L0 worktree" fence [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) used for its ADEMP smoke.

## What was run

Anchor cell only (`n_site = 80`, `T = 8`, Bernoulli logit, `latent(d = 1, unique = FALSE)`), `n_rep = 50`, estimands E1 (intercepts) and E2 (loadings). Local laptop. Not Totoro. Not T\*.

Table: `docs/dev-log/research/2026-08-18-mspl-forkB-l1-coverage-smoke.tsv` (800 coordinate-rows + header).
Object: `docs/dev-log/research/2026-08-18-mspl-forkB-l1-coverage-smoke.rds`.

## Numbers

| Unit | n | returned | covered | cov_eff | Wilson 95% | availability | refusal | L1 gate |
|---|---:|---:|---:|---:|---|---:|---:|---|
| anchor / E1 | 400 | 400 | 374 | 0.9350 | [0.9065, 0.9553] | 1.000 | 0.000 | **PASS** (all three L1 conditions met) |
| anchor / E2 | 400 | 0 | 0 | 0.0000 | [0.0000, 0.0095] | 0.000 | 1.000 | **NOT-EVALUABLE** (uniform `R-ENV`) |

Cluster bootstrap on E1 (resample 50 whole replicates, B = 2000): mean 0.9353, boot [0.9124, 0.9575], design effect 0.991. The naive Wilson band is not optimistic here; within-replicate coordinate outcomes did not inflate the interval.

E2 is **not a pass**. The door structurally refuses every `theta_rr_B` target (`gllvmTMB_mspl_profile_target`). That was predicted from the fork-A probe and is still true of this fork-B walk: loadings are not an admitted profile target. `NOT-EVALUABLE` is the honest label, not an escape hatch.

## What this is not

- Not a Totoro admission, not a T\* freeze, not a `covered` register flip, not MSPL-04 moving off `blocked`.
- Not a public `se` / `vcov` / `confint`. `#1077` stays draft.
- Not a claim that current `main` can reproduce the walk. The harness on this PR reports `L1_STATUS: NOT-RUN` against current `main` until #1130 (or an equivalent door) lands.
- Not the ADEMP harness in #1128 (`dev/mspl-forkB-l1-ademp.R`). Different files, and this receipt includes the E2 `R-ENV` half that #1128's E1-only smoke did not measure.
