# After-task — Tier-2a phylo-multinomial: regularization is a NEGATIVE result; fence one-per-species for 0.6

**Date:** 2026-07-17 · **Agent:** Claude (Fable 5), solo. **Branch:** `claude/tier2a-phylo-multinomial`
(PR #753, draft). **Arc:** Design 84 — the fixed-`R`/regularization headline for reporting the
(K−1)×(K−1) among-category correlation surface V for a phylo multinomial.

## Scope
The prior handover's headline: implement the fixed-`R=(1/K)(I+J)` regularization to make one-per-species
recovery of V practically usable, re-run the multi-seed ladder, wire `link_residual`, add the Mizuno
article paragraph. Shinichi flagged the premise ("OLRE is for overdispersed Poisson/negbin — do we need
it for multinomial?"). We tested the premise (Option C) before shipping. This report is the durable
record of a **negative result**: **no cheap fixed regularizer makes one-per-species recovery reliable.**

## What was tested and what it showed

### 1. The fixed-`R=(1/K)(I+J)` OLRE — built, then proven INERT (reverted)
- Implemented as a Laplace-integrated observation-level residual `e_g ~ N(0, R)`, R FIXED, on the K−1
  contrasts (C++ `src/gllvmTMB.cpp` DATA/PARAM/density/eta-shift + R `fit-multi.R` build/map/random +
  a `control$multinomial_regularize` flag). Compiled clean; mapped off cleanly for non-multinomial fits.
- **Mechanism confirmed active**, not a no-op: marginal nll 424.11 (OFF) → 425.79 (ON); `sdreport` shows
  `u_mn_olre` = 800 nonzero integrated random modes (max 0.366) at N=400.
- **Recovery: INERT.** 20-fit ladder, one-per-species, true ρ=0.6:
  - N=800: OFF mean 0.487 / sd 0.769 / rail 6/8 ; ON mean 0.482 / sd 0.774 / rail 6/8.
  - N=1600: OFF mean 0.613 / sd 0.494 / rail 1/8 ; ON mean 0.615 / sd 0.498 / rail 1/8.
  ON ≈ OFF to 2–3 decimals at every cell; more DATA (N=800→1600) is what fixes recovery, not the residual.
- **Why (theory, and 3/3 adversarial lenses UPHOLD, high confidence):** the multinomial-categorical
  residual `R=(1/K)(I+J)` is MCMCglmm's *scale-identification convention*, NOT overdispersion modelling.
  gllvmTMB's softmax already identifies the latent scale (the fixed-effects `multinomial()` recovers
  coefficients unbiasedly with no residual), so a fixed additive i.i.d. residual injects no directional
  information about the (K−1)-dim liability and is orthogonal to the reduced-rank factor V = ΛΛᵀ. It
  cannot reduce the sampling variance that drives the ±1 collapse. MCMCglmm recovers one-per-species via
  its **parameter-expanded prior on G + full-rank `us(trait):species` + posterior-mean reporting** — the
  three things the port left behind. The handover mis-attributed the credit to the fixed `R`.
- **Reverted.** Diff preserved (session scratchpad `olre-diff.txt`). Do NOT re-attempt the fixed-`R` OLRE.

### 2. Fixed-Ψ diagonal ridge (the outgoing note's "cheap-first" alternative) — genuine but INSUFFICIENT (reverted)
- `phylo_latent(species, d=2, unique=TRUE)` with the phylo-diag variance ψ FIXED at v (an R-only
  `control$phylo_diag_fixed_var`; maps `log_sd_phy_diag` off at 0.5·log(v); no C++). Estimated ψ collapses
  to ~0 (rails, per the prior after-task); fixing it > 0 is a real diagonal ridge on the phylo factor.
- N=800, 8 seeds, ρ from ΛΛᵀ (the true estimand, `fit$report$Sigma_phy`):
  - baseline: mean 0.49, rail 6/8 · v=0.25: 0.42, rail 6/8 · v=0.50: 0.39, rail 4/8 · v=1.0: 0.69, rail ~3–4/8.
  - The ridge is a **genuine regularizer** (unlike the inert OLRE): at v=1.0 it roughly halves boundary
    collapse and the surviving fits recover ρ̂≈0.58–0.73. But it is **not sufficient** — ~half the seeds
    still rail on ΛΛᵀ; and reporting the ridge-inclusive V = ΛΛᵀ+vI just shrinks ρ̂ toward 0 (mean
    0.13–0.33, a bias, not recovery). No v gives both low rail-hits AND mean≈0.6.
- **Reverted.** Diff preserved (`ridge-plumbing-diff.txt`). `phylo_diag_fixed_var` is a clean general
  control that could be re-added for a 1.0 ridge+N calibration, but it is an API addition (Discussion
  Checkpoint) and is NOT shipped in 0.6.

## Conclusion (Shinichi-facing)
**One-per-species multinomial phylo-V recovery is data-hungry; no cheap FIXED regularizer (OLRE or ridge)
makes it reliable at practical N.** The consistent estimator needs replication or large N (the collapse
clears with N: 6/8→1/8 rail from N=800→1600 with no regularizer). The genuine one-per-species fix is a
prior + posterior-mean/interval reporting (Bayesian or penalized-with-uncertainty) — a **1.0 arc**, not a
cheap 0.6 add.

## Decision for 0.6
- **Ship the committed capability** (report V via `extract_Sigma(level="phy")` / `extract_correlations()`),
  **fenced honestly**: recovery needs per-species replication OR large N; one-per-species is high-variance
  (point estimate rails at ±1). Do NOT claim "covered" for one-per-species.
- Article paragraph = forward-looking + fenced (Mizuno et al. 2025 is the method reference).
- Regularization headline = **DROPPED for 0.6**; the Bayesian/penalized recovery path is a 1.0 arc.

## Also shipped this session
- **`bf6d047d`** — fixed the stale `test-multinomial.R` fence regexp (the capability relaxed the abort
  message; the test still matched the old "fixed-effects-only") + added a positive Tier-2a test
  (multinomial + phylo_latent fits and returns the (K−1)×(K−1) V). Unblocks PR #753 CI (the suite had
  never been run before the capability commit).

## Checks
- `devtools::load_all()` compiles clean (OLRE + ridge both compiled before revert).
- `test-multinomial.R`: 44 pass / 0 fail (NOT_CRAN) after the fix.
- Recovery campaigns: local multi-seed (this report). `R CMD check` on the branch: pending on PR #753
  after `bf6d047d`.

## Follow-ups
1. **Fence the reader surfaces** (roxygen on the phylo path, NEWS, article) — one-per-species = replication
   or large N; regularization dropped for 0.6.
2. **`link_residual` for multinomial — CONVENTION RESOLVED (Hadfield MCMCglmm course notes, multinomial
   section).** `(1/K)(I+J)` is NOT a scalar and NOT π²/3: it is the covariance of the K−1 baseline
   CONTRASTS under independence of the underlying categories (2/K diagonal = own+baseline variance; 1/K
   off-diagonal = shared baseline). Key consequence, now documented on the reader surfaces: **a diagonal V
   is not independence** — the null is `(1/K)(I+J)`. What remains is *applying* a matrix residual (the
   current `link_residual_per_trait()` is scalar-per-trait), a 1.0 wiring task; `extract_Sigma()` returns
   the latent-scale V and warns for now. Fenced in NEWS + the `extract_Sigma` roxygen (`3e4a4f5b`).
3. **1.0 arc:** proper prior + posterior-mean/interval reporting (cross-check vs MCMCglmm on the
   reconciled scale). Ridge+N calibration is a candidate; `phylo_diag_fixed_var` recipe is preserved.

## Status
Regularization headline **NOT delivered — negative result, honestly**. Capability stands (reports V) and
will ship for 0.6 **fenced** (replication / large N). No "covered" claim for one-per-species.
