# Item 3 — genuine one-per-species recovery of the among-category V — ULTRA-PLAN (launch-ready)

**Date:** 2026-07-17 · **Status:** STAGED, not executed. Launch only on maintainer approval; compute is
**Totoro** (or DRAC), never GitHub Actions (D-50). The deepest item of the Tier-2b 0.6 arc.

## The problem (settled — do not re-derive)
A `phylo_latent` multinomial reports the (K−1)×(K−1) among-category V as ΛΛᵀ. With **one categorical
draw per species**, the (K−1)-dim liability is weakly informed, so the reduced-rank MLE **rails**: a
loading → 0 and ρ̂ → ±1. This is not a bug — it is weak information. The whole regularization arc turned
on a single seed lying (ρ̂ = 0.57 looked like recovery; multi-seed SD was 0.6 with ±1 collapses).

**Two NEGATIVE results already banked (do NOT re-attempt):**
- Fixed `R = (1/K)(I+J)` OLRE is **inert** (proven active, zero effect on recovery; 3/3 adversarial
  lenses; reverted).
- Fixed-Ψ ridge is a **genuine but insufficient** regularizer (halves the ±1 collapse at v=1.0 but ~half
  the seeds still rail). Candidate only **combined with larger N**. Recipe:
  `docs/dev-log/after-task/2026-07-17-tier2a-regularization-negative-result.md`.

**The model that DOES recover (the gold standard to match):** MCMCglmm, via a parameter-expanded prior
on G + a **full-rank** `us(trait):species` + **posterior-MEAN** reporting. So item 3 is: a prior/penalty
on the phylo loadings + posterior-mean (or interval) reporting, cross-checked vs MCMCglmm **on the
reconciled scale** — NOT any fixed additive residual.

## What item 1 unlocks for item 3
Item 1 (the `(π²/6)(I+J)` observation-scale residual, shipping now) makes the gllvmTMB latent-scale V and
the MCMCglmm liability V **commensurable**. Phase A below is the reconciliation that item 1 makes
possible; without it the two packages' Vs are on different scales and the cross-check is meaningless.

## ADEMP design
- **Aims:** (1) does a prior/penalty + posterior-mean estimator recover the true V within interval at a
  given N? (2) At what N does one-per-species recovery become trustworthy (the N-ladder)? (3) Does it
  agree with MCMCglmm on the reconciled scale?
- **Data-generating:** phylo multinomial, K ∈ {3,4}, true V with known ρ (a ladder: ρ ∈ {0, ±0.4, ±0.8})
  and loading magnitude v ∈ {0.5, 1.0}. N-ladder: n_species ∈ {60, 150, 400, 1000} (one draw per
  species) + a replication arm (m draws per species) as the information-rich control.
- **Estimands:** the (K−1)×(K−1) V (and its correlations ρ); coverage of the interval; bias; ±1-collapse
  rate.
- **Methods (compared, in parallel):** (M1) current reduced-rank MLE (baseline that rails); (M2)
  penalized-likelihood ridge on Λ + N (the insufficient-alone candidate, now with N-ladder); (M3)
  posterior-mean — either a light Bayesian wrap or MCMCglmm itself as the reference; (M-gold) MCMCglmm
  parameter-expanded `us(trait):species` posterior mean.
- **Performance:** ±1-collapse rate, bias, RMSE, interval coverage, agreement-with-MCMCglmm (on reconciled
  scale), all as a function of N. **Multi-seed always** (≥50 seeds/cell; MCSE reported).

## Orchestration (Workflow, launch when approved)
Pipeline, not a single big fit. Sketch:
```
phase('Reconcile')  // Phase A — item-1-enabled scale reconciliation on a few seeds
  agent: fit gllvmTMB + MCMCglmm on the SAME data, confirm V comparable on the (π²/6)(I+J) scale
phase('Estimators') // Phase B — M1/M2/M3 per (K, ρ, v, N) cell, parallel
  pipeline over cells: fit each method -> extract V + interval
phase('Coverage')   // Phase C — multi-seed campaign on Totoro (≥50 seeds/cell)
  parallel over seeds within cell; accumulate collapse-rate/coverage/bias
phase('Verify')     // Phase D — 3 adversarial lenses per "recovered" claim (correctness / MCMCglmm-agreement / repro), ≥2 must pass
synthesis: the N-ladder table + the estimator recommendation
```
Compute: benchmark one cell locally → scale the seed×cell grid on **Totoro** (`OPENBLAS_NUM_THREADS=1`,
≤96 cores). MCMCglmm is the slow leg — budget it. Results stay **local** (D-50).

## Definition of done (default NOT-DONE per D-43)
A "recovery works" claim requires: multi-seed (≥50/cell) coverage ≥ nominal at a stated N, the
±1-collapse rate driven low, agreement with MCMCglmm on the reconciled scale, and **≥2 of 3 fresh
adversarial lenses** confirming — else report the exact rung reached and what it does NOT cover.

## Guards
Multi-seed always · Rose/D-43 panel before any covered claim · compute Totoro/DRAC never Actions ·
single seeds lie · state what each partial arc does NOT cover · reader surfaces carry no register codes.
