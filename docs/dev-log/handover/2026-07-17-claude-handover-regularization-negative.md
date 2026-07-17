# Claude → Claude handover — Tier-2a phylo-multinomial: regularization is a NEGATIVE result

**Date:** 2026-07-17 · **From:** Claude (Fable 5), solo. **This supersedes the "regularization pending"
framing** in `2026-07-17-claude-handover.md`. **Read the after-task first — it has the full evidence:**
`docs/dev-log/after-task/2026-07-17-tier2a-regularization-negative-result.md`.

## TL;DR
The regularization headline was tested and **does not work**. No cheap FIXED regularizer makes
one-per-species multinomial phylo-V recovery reliable. **Ship the capability FENCED for 0.6; the real
(prior + posterior-mean) recovery path is a 1.0 arc.** Do NOT re-attempt the fixed-`R` OLRE or expect the
fixed-Ψ ridge to be sufficient.

## What shipped this session (all pushed)
- **`bf6d047d`** (PR #753) — fixed the stale `test-multinomial.R` fence regexp + added a positive Tier-2a
  test (multinomial + `phylo_latent` fits and returns the (K−1)×(K−1) V). **Unblocks PR #753 CI.**
- **`62c04c4e`** (PR #753) — the negative-result after-task.
- **`63c12fe2`** (PR #751, `docs/multinomial-article`) — forward-looking phylogenetic paragraph in the
  `multinomial()` article: Mizuno et al. 2025, phylo factor on the K−1 contrasts, **honestly fenced**
  (data-hungry; needs replication or large N; no covered claim).

## What was tested and KILLED (do not repeat)
1. **fixed-`R=(1/K)(I+J)` OLRE — INERT.** Built full (C++ + R + `control$multinomial_regularize`),
   proven active (nll 424→426; 800 integrated modes) but **byte-identical recovery ON vs OFF** across
   N=400/800/1600. 3/3 adversarial lenses UPHOLD. It is MCMCglmm's *scale-identification convention*, not
   overdispersion, and injects no directional info about V. **Reverted** (diff: scratchpad `olre-diff.txt`).
2. **fixed-Ψ diagonal ridge — GENUINE but INSUFFICIENT.** `control$phylo_diag_fixed_var` (R-only, no C++;
   maps `log_sd_phy_diag` off at a fixed value). At v=1.0 it roughly halves boundary collapse (6/8→~3/8
   rail) and surviving fits recover ρ̂≈0.6–0.7, but ~half still rail on ΛΛᵀ; the ridge-inclusive V just
   shrinks ρ̂ toward 0. **Reverted** (diff: `ridge-plumbing-diff.txt`; re-addable for a 1.0 ridge+N run).

## Why (the load-bearing insight — Shinichi caught the premise)
gllvmTMB's softmax already identifies the latent scale, so a fixed additive residual is not needed and
does not help. MCMCglmm recovers one-per-species via its **parameter-expanded prior on G + full-rank
`us(trait):species` + posterior-mean reporting** — NOT the fixed `R`. A frequentist point-MLE collapses
to the ±1 boundary at small N; only more data, or a genuine prior/penalty WITH posterior-mean/interval
reporting, fixes it. The reduced-rank ΛΛᵀ MLE rails when a loading → 0.

## Next steps (by leverage)
1. **Fence the reader surfaces for 0.6** (the capability stays; the claim is fenced): roxygen on the
   `extract_Sigma(level="phy")` / `phylo_latent`-on-multinomial path, a NEWS line, and (when PR #751
   lands after PR #753) update the article's "Looking ahead" note from forward-looking to "available,
   fenced". State plainly: one-per-species is high-variance (rails at ±1); use replication or large N.
   Also update the two stale in-code comments that still say "identifies V directly (no residual
   convention)" — `R/fit-multi.R:~1799` and `R/extract-sigma.R:~633` — to the honest weak-information
   framing.
2. **`link_residual` for multinomial — DEFERRED, needs Shinichi.** The "multivariate analog of π²/3"
   framing is wrong: `(1/K)(I+J)` (diagonal 2/K) is MCMCglmm's convention, not the logistic π²/3 scale.
   Decide the scale convention before wiring `link_residual_per_trait()` (`R/extract-sigma.R:~115`). Not
   needed for 0.6.
3. **1.0 arc:** the genuine one-per-species recovery — a prior/penalty on the loadings + posterior-mean
   or interval reporting (Bayesian, or penalized-likelihood with proper uncertainty), cross-checked vs
   MCMCglmm on the reconciled scale. The `phylo_diag_fixed_var` ridge + larger N is a candidate to
   calibrate (recipe preserved).

## State / guards
- **PR #753** (draft, `claude/tier2a-phylo-multinomial`): capability + test fix + after-task. CI
  re-running on `62c04c4e` (test verified locally 44/0 with NOT_CRAN; expected green).
- **PR #751** (`docs/multinomial-article`): article + Mizuno paragraph.
- **No "covered" claim was made** — the capability is fenced, per the D-43 gate (the 3-lens verification
  was the Rose-equivalent for the negative). Multi-seed discipline held throughout (single seeds lie).
- Compute stayed local (N≤1600 sparse A⁻¹); a full 1.0 calibration is a Totoro job (never GitHub Actions).
