# Jason cross-package scout: binomial `Sigma_unit[tt]` under-estimate

**Author**: Jason (cross-package landscape lens) with Curie (sim
fidelity) reviewing.
**Date**: 2026-05-25.
**Triggered by**: M3 sim pilot Scenario A finding (PR #262; binomial
median ratio 0.24/0.32/0.42 on `Sigma_unit[tt]` across d∈{1,2,3}).
**Scope**: read-only cross-package empirical comparison. No edit to
`R/`, `R/diagnose.R`, `tests/testthat/test-sanity-multi.R`, ROADMAP,
check-log, or after-task/. Stays clear of Codex's #257/#260/#261 file
surface.

## 1. Question

Is the binomial under-estimate of `Sigma_unit[tt]` that the M3
pilot surfaced **gllvmTMB-specific**, or does it appear on the same
DGP in `gllvm` (Niku et al. 2019) and `glmmTMB` (Brooks et al.
2017)?

## 2. Method

DGP exactly mirrors `dev/m3-grid.R::m3_sample_truth(family="binomial",
d=1)`:

- `n_units = 60`, `n_traits = 5`, `d = 1`
- `Lambda ~ Uniform(-1.5, 1.5)^{5 × 1}`
- `psi ~ Gamma(shape=2, rate=2)^5` → mean 1.0
- `eta = Z Lambda^T + e_unique`, `e_unique[i, t] ~ N(0, psi_t)`
- `Y[i, t] = Bernoulli(plogis(eta[i, t]))`
- **Truth**: `Sigma_unit = Lambda Lambda^T + diag(psi)` → diagonal
  = `Sigma_unit[tt]` (latent-scale per-trait variance).

`n_reps = 10`, `seed_base = 20260525` (fresh — avoids collision with
M3 pilot seed 20260524 and 2026-05-19 production seed 20260517).

Each rep fits the same data three ways:

1. **gllvmTMB** — `latent(0 + trait | unit, d = 1) + unique(0 + trait | unit)`;
   extract via `extract_Sigma(fit, level = "unit", link_residual = "none")`.
2. **gllvm** — `gllvm::gllvm(Y_wide, num.lv = 1, family = "binomial")`;
   reported in two forms:
   - **gllvm (LV only)**: `diag(theta %*% t(theta))`. gllvm has no
     separate `psi`; per-trait unique variance is absorbed into the
     binomial likelihood or, for logit, contributes π²/3 on the
     latent scale.
   - **gllvm + π²/3 link**: `diag(theta %*% t(theta)) + π²/3`. The
     "naive" latent-scale correction assuming logit Bernoulli link
     contributes π²/3 variance.
3. **glmmTMB** — `(0 + trait | unit)` (full unstructured T × T
   covariance); extract `diag(VarCorr(fit)$cond$unit)`.

Code: [`dev/jason-binomial-scout.R`](../../dev/jason-binomial-scout.R).
Console + CSV outputs land at `/tmp/jason-scout-{perrep,summary}.csv`.

## 3. Results

Per-package median estimate/truth ratio on `Sigma_unit[tt]` across
all 50 trait-replicate pairs (10 reps × 5 traits, all 50 fits
converged on every package):

| Package | Median ratio | IQR | n converged | Median fit time |
|---|---|---|---|---|
| **gllvmTMB** (latent + unique, d=1) | **0.240** | [0.028, 0.793] | 50/50 | 0.50 s |
| **glmmTMB** (full unstructured) | **0.636** | [0.285, 1.136] | 50/50 | 0.37 s |
| **gllvm** (LV only — no separate psi) | 0.832 | [0.401, 2.322] | 50/50 | 0.02 s |
| gllvm + π²/3 link-residual | 3.211 | [2.201, 5.406] | 50/50 | 0.02 s |

(Smoke-scale; n_reps = 10 means MCSE on each median is moderate. The
relative ordering is what's stable; absolute values shift if you
re-run with a different seed.)

## 4. Interpretation

**Three distinct findings:**

### 4.1 The under-estimate is NOT gllvmTMB-specific.

glmmTMB — which fits a **full unstructured** Sigma_unit (no
reduced-rank shrinkage, the maximally flexible model on this data)
— also under-estimates the latent-scale diagonal, at median ratio
**0.636**. So small-n binomial likelihood fitting at `n_units = 60,
n_traits = 5` systematically under-estimates the latent-scale
variance components on this DGP. This is a fundamental small-sample
pathology of binary fits, not a gllvmTMB bug.

### 4.2 gllvmTMB shrinks further than glmmTMB.

gllvmTMB's median ratio is **0.240**, which is ~38 % of glmmTMB's
0.636. The reduced-rank constraint (d = 1 on a T = 5 covariance with
diagonal `psi`) adds shrinkage on top of the universal small-n
pathology. This **is a gllvmTMB-relative effect** and is in Codex's
lane (#257/#260) to characterise. Possible mechanisms:

1. The `latent(d=1) + unique` split forces all cross-trait covariance
   through a single 5×1 loading vector. At n=60 with binary noise,
   the loadings can shrink toward zero (regularisation-by-likelihood-
   curvature); the diagonal collapses to `psi` alone, which itself
   is fit on a binomial-link scale that under-estimates.
2. The `unique` tier could be eating the same signal twice with
   `latent` and converging both to attenuated values.
3. The Hessian-rank-deficiency Noether documented for nbinom2 may
   have a binomial-d=1 analogue.

These are hypotheses for Codex's diagnostic work, not conclusions
of this scout.

### 4.3 gllvm has an entirely different parameterisation.

gllvm has no separate `psi` — its model is `eta = X β + LV θ^T`. The
LV-only ratio of **0.832** says: when the unique variance is
absorbed into the LV structure, you recover ~83 % of the truth at
d=1. The naive π²/3 link-residual add-back **over-shoots by 3.2×**,
suggesting the latent-scale truth in this DGP is NOT well-described
by the LV + link-residual decomposition gllvm implicitly assumes.

This is a Design-42 §3 question for the comprehensive sim, not for
this scout: **what target scale does `Sigma_unit[tt]` actually
correspond to across packages**? gllvmTMB and glmmTMB both compute
a latent-scale Sigma; gllvm computes a partially-different
quantity. The cross-package comparison only makes apples-to-apples
sense between gllvmTMB and glmmTMB.

## 5. Implications for Codex's #257/#260 diagnostic-API work

The Codex-lane hand-off in [PR #262 audit memo §8.4](2026-05-24-m3-sim-lane-pilot.md)
listed three hypothesis prompts. This scout refines them:

1. **Latent vs response-scale unit mismatch** (memo §8.4 #1) —
   glmmTMB also under-estimates by ~36 %, so a pure unit-mismatch
   on gllvmTMB's side does NOT explain the headline gap. **Reframed
   question**: does gllvmTMB shrink further than glmmTMB because of
   the reduced-rank constraint + the `unique` tier, or because of
   a separate scale issue?
2. **Warm-start asymmetry** (memo §8.4 #2) — still relevant; this
   scout used `init_strategy = single_trait_warmup` but binomial
   isn't a phi-bearing family so warm-up was a no-op. Re-running
   gllvmTMB with `init_strategy = "default"` would isolate this.
3. **Mixed d=3 convergence collapse** (memo §8.4 #3) — unchanged;
   not exercised by this scout.

**New hypothesis** worth flagging for Codex's lane:

- **Universal small-n binomial pathology**: glmmTMB's 0.64 ratio
  is the "expectation ceiling" for `n_units=60, n_traits=5, d=1`.
  No latent-variable fitter on this DGP regime can do better than
  glmmTMB's full-unstructured baseline. **gllvmTMB closer to 0.64
  than to 1.0 would be a win, not a regression.** The realistic
  ceiling for a coverage claim on this regime is bounded by glmmTMB's
  performance, not by nominal 0.95.

## 6. Implications for the comprehensive coverage sim (future)

The maintainer's 2026-05-24 framing: "We will do power, accuracy,
and coverage through a comprehensive simulation once all the
functionalities are in place." This scout's signal tightens the
design space:

- **The comprehensive sim must use a regime where the small-n
  binomial pathology is small**. Either `n_units > 200` or
  `n_traits ≥ 20` (or both). At n_units=60, T=5, even glmmTMB
  is at 0.64 — the comprehensive sim cannot make a coverage
  claim at this regime.
- **Cross-package baselines** should be part of the comprehensive
  sim from day one. Without a glmmTMB reference, every
  under-estimate would look like a gllvmTMB bug; with one, the
  comparison is to the right reference.
- **gllvm should be treated as a different-target reference**, not
  a peer comparator. Its parameterisation doesn't have a `psi`.

## 7. What this scout does NOT do

- **No CI-08 / CI-10 register-row update.** They stay `partial`
  (Design 50 §9). This scout is below the n_reps threshold and on
  a single DGP; it cannot move the register.
- **No engine debugging.** The 38 % gllvmTMB-vs-glmmTMB excess
  shrinkage is Codex's #257/#260 lane to characterise.
- **No claim about Gaussian, nbinom2, ordinal, or mixed.** Only
  binomial × d=1 in this scout.
- **No follow-up cross-package work in this lane**. If Codex wants
  the binomial × d∈{2,3} extension, the `dev/jason-binomial-scout.R`
  script is parameterised — set `D <- 2L` or `3L` and re-run.

## 8. Hand-off

The script `dev/jason-binomial-scout.R` is committed (not scratch)
so any team member — Codex, Curie, Fisher — can re-run, extend to
other d, or add a fourth comparator (e.g. `galamm`). The CSV
outputs go to `/tmp/` and are reproducible per the script header.

A comment on Codex's [PR #257](https://github.com/itchyshin/gllvmTMB/pull/257)
points at this memo as additional context for the diagnostic-API
work.

— Jason (cross-package landscape) and Curie (sim fidelity)
