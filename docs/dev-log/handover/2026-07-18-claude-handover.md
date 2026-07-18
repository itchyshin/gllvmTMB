# Session Handoff: multinomial Tier-2b — cross-family SHIPPED; next lane = choose the depth arc

**Date:** 2026-07-18 · **From:** Claude (Opus 4.8) · **To:** the next Claude lane picking up the
multinomial arc. Everything below is **on `main`** — nothing is unpushed, nothing is carried-over.
Read this + the linked after-task reports; you start with no re-discovery.

## Critical Context
This lane took the multinomial capability from "fixed-effects only" to **cross-family latent sharing**
across all response families, framed as **0.6** (not 1.0; D-42). The whole Tier-2b arc — item 1 (link
residual), item 2a-ii (cross-family correlations), and the `unique = TRUE` consistency fix — is
**merged**. The one big remaining piece is the **item-3 one-per-unit recovery certificate** (data-hungry;
harness + compute already staged on Totoro), plus a short menu of smaller deferred refinements. The next
lane **chooses which depth arc to pursue** — that is Shinichi's call at a discussion checkpoint.

## Goals / mission (the durable why)
`gllvmTMB` = multivariate stacked-trait GLLVMs. The multinomial (nominal) trait is now a first-class
citizen of the mixed-family latent-factor model. **1.0** (capability-maturity milestone) still wants:
Julia parity, the methods paper, and the full coverage/recovery campaign. **0.6** is where this arc lives.

## What Was Accomplished (all merged to `main`)
- **#758 — item 1:** `extract_Sigma`/`extract_Omega` apply the softmax observation-scale link residual
  `(π²/6)(I+J)` for a multinomial trait (π²/3 diag, π²/6 off-diag; McFadden 1974). Tier-agnostic.
- **#759 — item-2 ruling + spike + item-3 evidence:** Discussion-Checkpoint rulings recorded (parser
  1a→1b; reporting **2C** = reference-invariant multiple-correlation + optional (K−1)-vector). Engine
  spike proved the softmax already composes with a shared latent factor (no C++ change needed).
- **#760 — vdiffr doc note** (the 2 local snapshot failures are pre-existing graphics-device drift; they
  `skip_on_ci`, so CI is green — do NOT treat them as regressions).
- **#761 — item 2a-ii cross-family:** a `multinomial()` trait shares an ordinary `latent(0+trait|unit,d)`
  with Gaussian/binary/count/ordinal traits; auto subset-expansion (raw long data + a `family_var`
  column, no hand-built columns); new export `extract_cross_correlations()` (2C). Article
  `vignettes/articles/cross-family-correlations.Rmd`. Fail-closed fence (only `phylo_rr`/`rr_B`/`lv_B`).
- **#762 — `unique = TRUE` default works + Ψ=unique+link consistency:** the default `latent()` now fits a
  cross-family multinomial cleanly — the categorical contrast **between-unit Ψ auto-suppresses** (one-hot
  0/1, unidentified like single-trial binary; Link Residual Contract, design 02), while identified
  partners (Gaussian σ², overdispersed-Poisson OLRE) keep theirs. Article reworded to the two-Ψ contract
  + the honest replicated-design nuance. Two doc drifts fixed (OLRE scope; design-02 nbinom2 → trigamma).

**Verification banked:** multi-seed 5-family recovery (5/5 conv, pdHess) across Gaussian/binary/count/
ordinal/nominal; broad suite **5504 pass** (only the 2 pre-existing vdiffr); Rose adversarial review clean
on every step; fence boundaries proven (default ✅, loadings-only ✅, explicit `unique()`/`indep()` abort ✅).

## Current Working State
- **Working / done:** the entire cross-family multinomial capability, on `main`, tested, documented.
- **Deferred (fenced, fail-closed):** multiple multinomial traits per fit; an **explicit** per-contrast
  `unique()`/`indep()` on a categorical trait; a **replication-aware** contrast-Ψ (Rose check-6: it is
  identifiable in principle under replicated categorical designs — currently suppressed as a conservative
  simplification, unlike multi-trial binomial).
- **In-progress evidence, NOT a covered claim (item 3):** one-per-unit *phylo* among-category recovery is
  data-hungry — grid-wide boundary railing at accessible N (see the item-3 after-task). gllvmTMB is
  ~unbiased at scale; **MCMCglmm is the one persistently biased low** (its own issue, likely prior
  shrinkage / c² back-transform — an open question, not gllvmTMB's).

## Key Decisions & Rationale
- **Ψ = unique + link-specific** (design 02 Link Residual Contract, restated 2026-07-05): observation-level
  residual splits into an *estimated unique* (Gaussian σ², overdispersed-Poisson OLRE) and a *fixed
  link-specific* term; for a categorical trait the unique part is **0** (like binary). This is the "heart
  of gllvm" — do not re-derive; cite it.
- **2C reporting** (reference-invariant multiple correlation, observation scale default via the residual)
  keeps the arbitrary baseline category off the headline surface.
- **No C++ change** was ever needed — the softmax composes with shared LV generically.

## Files Created / Modified (durable pointers; details in the after-tasks)
- `R/extract-sigma.R`, `R/extract-correlations.R`, `R/extract-omega.R`, `R/fit-multi.R`, `R/gllvmTMB.R`
  (capability + fence + auto-suppress + reporting).
- `vignettes/articles/cross-family-correlations.Rmd` (the article), `covariance-correlation.Rmd`,
  `docs/design/02-family-registry.md` (consistency).
- `tests/testthat/test-cross-family-multinomial.R` (25 pass), `test-multinomial.R`, `test-link-residual-multinomial.R`.
- After-tasks: `docs/dev-log/after-task/2026-07-18-tier2b-item2aii-cross-family.md`,
  `2026-07-17-tier2b-item3-recovery-launch.md`, `2026-07-17-tier2b-item2-spike.md`.
- Dev harnesses (results local, D-50): `dev/cross-family-5family-demo.R`, `dev/cross-family-5family-multiseed.R`,
  `dev/phylo-multinomial-recovery-harness.R`. Totoro `~/gtmb_work` has gllvmTMB compiled + MCMCglmm + the harnesses.

## Next Immediate Steps (the next lane — pick ONE at a discussion checkpoint with Shinichi)
1. **Item-3 recovery certificate** (deepest, compute): the definitive Totoro campaign — larger-N + a
   ridge-penalized gllvmTMB arm + interval coverage + ρ-ladder + K=4 + a **D-43 panel** before any covered
   claim. Ultra-plan it; harness + env are ready on Totoro.
2. **Calibrated intervals for the cross-family correlations** (extract_cross_correlations is point-only;
   coverage not certified — the 0.6→1.0 headline is interval coverage).
3. **Replication-aware contrast-Ψ** (Rose check-6): keep the categorical contrast Ψ when replicated
   categorical data identifies it (mirror the multi-trial-binomial `n_trials` gate). Engine change.
4. **Cross-family with structure:** a multinomial sharing a `phylo_latent`/`spatial_latent` with other
   traits (currently ordinary `latent` + phylo are separate paths).
5. **Small doc cross-refs** the pkgdown scan flagged (response-families.Rmd needs a multinomial row;
   covariance See-also → gllvm-vocabulary; binomial single-trial scoping) — low-effort consistency.

## Blockers / Open Questions
- The **MCMCglmm low-bias mystery** (open, not gllvmTMB's) — worth a short note if item 3 resumes.
- Whether item 3's data-hungry recovery is worth the compute vs. shipping intervals first — Shinichi's call.

## Gotchas & Failed Approaches
- **Single seeds lie** — every recovery number here is multi-seed; do the same.
- The parametric **bootstrap** route for `Sigma_unit` was the WRONG route (prior arc) — the certificate
  path is PROFILE / log-SD-Wald.
- The **fixed-R OLRE** regularizer was INERT (proven; reverted) — do not re-attempt.
- vdiffr `test-plot-visual-snapshots.R` fails **locally** on this Mac (graphics-device drift) — pre-existing,
  `skip_on_ci`, NOT a regression. Confirmed on clean `main`.
- **Two Ψ's** — never conflate the between-unit `latent()` Ψ with the observation-level link residual.

## Landing State
All work merged to `main` (#758–#762). This handover is the only new artifact; commit on this branch, open
a PR, **do not auto-merge** (Shinichi merges). Nothing unpushed once this branch is pushed.

## How to Resume (paste ONE line in an authenticated terminal at the repo root)
Interactive (you steer which arc):
```
claude "Rehydrate from docs/dev-log/handover/2026-07-18-claude-handover.md on main. The multinomial cross-family arc is SHIPPED (item 1 + 2a-ii + unique=TRUE, #758–#762). Pick the next depth arc with me at a discussion checkpoint — default candidate is the item-3 recovery certificate (Totoro, ultra-plan) or calibrated cross-family intervals. Spawn Rose before any covered claim; multi-seed always; compute local→Totoro (D-50)."
```

## Mission control
| Thread | State | Where | Next |
|---|---|---|---|
| item 1 — matrix link residual | ✅ MERGED #758 | `main` | — |
| item 2a-ii — cross-family + 2C | ✅ MERGED #761 | `main` | — |
| unique=TRUE default + Ψ contract | ✅ MERGED #762 | `main` | — |
| item 3 — one-per-unit recovery certificate | 🔴 in-progress evidence, NOT covered | Totoro `~/gtmb_work` | ultra-plan the definitive campaign |
| cross-family calibrated intervals | 🔴 not started | — | 0.6→1.0 headline |
| replication-aware contrast-Ψ | 🟡 deferred (Rose check-6) | fenced | engine change if in scope |
| multiple multinomial traits / structured cross-family | 🟡 deferred, fail-closed | fenced | future |
