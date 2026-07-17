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

## Status at session close (all DONE + pushed unless marked)
1. **Reader surfaces FENCED for 0.6 — DONE** (`3e4a4f5b`, `a1756724`): NEWS entry (V reported,
   data-hungry, diagonal ≠ independence), `extract_Sigma()` roxygen, and the two stale in-code comments
   corrected. Article "Looking ahead" note still forward-looking on PR #751 (correct until #753 merges).
2. **`link_residual` convention RESOLVED — DONE** (`3db828ec`; Shinichi's steer + Hadfield notes + the
   Mizuno/Ayumi tutorial). The softmax link residual is **`(π²/6)(I+J)`** — **π²/3 on the diagonal**
   (each contrast is a logit, as binomial), **π²/6 off-diagonal** (shared-baseline coupling), reducing to
   binomial's π²/3 at K=2. It is the softmax's own random-utility (Gumbel) residual — NOT MCMCglmm's
   *arbitrary* identification residual `(1/K)(I+J)`, and NOT its MCMC-specific `c²=(16√3/15π)²`
   correction (Bayesian-only; "brms doesn't need c2"). Documented in NEWS + `extract_Sigma()` roxygen.
   **REMAINING (1.0 wiring):** *apply* the matrix — `link_residual_per_trait()` (`R/extract-sigma.R:~115`)
   is scalar-per-trait; the multinomial needs a `(K-1)×(K-1)` block added to Σ. Until then
   `extract_Sigma()` returns latent-scale V and warns.
3. **Article Mizuno paragraph — DONE** (PR #751 `63c12fe2`): forward-looking, fenced.
4. **Cross-family correlation is now UNBLOCKED on the scale side (1.0 arc).** The link variance is the
   commensurability piece: it standardizes a category contrast (diag π²/3) against binomial (π²/3),
   Gaussian, etc., so `corr(contrast_k, trait_j) = cov / sqrt[(V_kk+π²/3)(V_jj+σ²_d,j)]` is now
   well-defined. Two open pieces: a multinomial gives a **(K-1)-vector** of correlations per partner (not
   a scalar) — the reporting-convention call (Design 84 "harder open problem"); and the parser/
   `extract_correlations` cross-blocks are still fenced to standalone-only. Recovery stays data-hungry.

## Deeper 1.0 arc (the genuine recovery)
- Real one-per-species recovery — a prior/penalty on the loadings + posterior-mean or interval reporting
  (Bayesian, or penalized-likelihood with proper uncertainty), cross-checked vs MCMCglmm on the
  reconciled scale. The `phylo_diag_fixed_var` ridge + larger N is a candidate to calibrate (recipe
  preserved). Pairs naturally with the cross-family correlation wiring (step 4 above).

## State / guards
- **PR #753** (draft, `claude/tier2a-phylo-multinomial`, HEAD `3db828ec`): capability + test fix +
  after-task + fencing + link-residual correction. CI green through `e915a711`; later commits are
  doc-only. (PR title still says "regularization pending" — now stale; regularization was a negative
  result. Retitle at your leisure.)
- **PR #751** (`docs/multinomial-article`): article + Mizuno paragraph.
- **No "covered" claim was made** — the capability is fenced, per the D-43 gate (the 3-lens verification
  was the Rose-equivalent for the negative). Multi-seed discipline held throughout (single seeds lie).
- Compute stayed local (N≤1600 sparse A⁻¹); a full 1.0 calibration is a Totoro job (never GitHub Actions).
