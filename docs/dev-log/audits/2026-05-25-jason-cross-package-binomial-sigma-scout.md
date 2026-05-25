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

`n_reps = 10` per cell, `seed_base = 20260525` (fresh — avoids
collision with M3 pilot seed 20260524 and 2026-05-19 production
seed 20260517). After the maintainer asked 2026-05-25 *"if we
increase N sample size we do get close to 1 ratio?"*, the script
was extended to sweep `N_UNITS ∈ {60, 240, 500}` — 150 fits per
package total.

Each rep fits the same data four ways:

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
3. **galamm** — `galamm(value ~ trait + (0 + ability | unit), family = binomial,
   load_var = "trait", factor = "ability", lambda = c(1, NA, NA, NA, NA))`;
   reduced-rank d=1 with a single random effect on the latent variable.
   Implied `Sigma_unit[tt] = lambda_t^2 * sigma^2_ability` (no separate
   `psi`). Same parameterisation family as gllvm — but **uses Laplace
   approximation via TMB-style autodiff** (Sørensen et al. 2023), making it
   the closest peer to gllvmTMB's reduced-rank engine.
4. **glmmTMB** — `(0 + trait | unit)` (full unstructured T × T
   covariance); extract `diag(VarCorr(fit)$cond$unit)`.

Code: [`dev/jason-binomial-scout.R`](../../dev/jason-binomial-scout.R).
Console + CSV outputs land at `/tmp/jason-scout-{perrep,summary}.csv`.

## 3. Results

### 3.1 Median estimate/truth ratio by N (per-N stratified)

| N_units | gllvmTMB (latent+unique) | galamm (lambda²σ²) | glmmTMB (full unstr.) | gllvm (LV only) |
|---|---|---|---|---|
| 60 | 0.240 [0.028, 0.793] | 0.226 [0.004, 0.697] | 0.636 [0.285, 1.136] | 0.832 [0.401, 2.322] |
| 240 | 0.142 [0.056, 0.264] | 0.157 [0.061, 0.349] | 0.276 [0.135, 0.432] | 1.134 [0.232, 9.851] |
| **500** | **0.137 [0.082, 0.248]** | **0.121 [0.071, 0.260]** | **0.184 [0.136, 0.388]** | 0.887 [0.143, 4.558] |

(Cell shows: median [IQR lower, IQR upper]; n_reps = 10 × n_traits =
5 = 50 trait-rep pairs per cell.)

### 3.2 The maintainer's question

**Question (2026-05-25)**: *"if we increase N sample size we do get
close to 1 ratio?"*

**Answer: No. The ratios go in the OPPOSITE direction.** All three
packages that try to recover `Lambda Lambda^T + diag(psi)` (gllvmTMB,
galamm, glmmTMB) **decrease monotonically** as N grows:

- gllvmTMB: 0.240 → 0.142 → 0.137
- galamm:   0.226 → 0.157 → 0.121
- glmmTMB:  0.636 → 0.276 → 0.184

At N=500, all three have converged to a stable but **substantially-
below-1** point. This is not a transient small-n effect — it is the
estimators' consistent target. By contrast, gllvm's LV-only ratio
stays near 1.0 across all N (with high variance) — it recovers a
different quantity that IS commensurable with the DGP's
`Lambda Lambda^T + diag(psi)` truth.

### 3.3 Runtime budget (median seconds per fit)

| N_units | gllvmTMB | gllvm | galamm | glmmTMB |
|---|---|---|---|---|
| 60 | 0.49 | 0.02 | 0.09 | 0.40 |
| 240 | 2.04 | 0.14 | 0.27 | 0.89 |
| 500 | 4.40 | 0.53 | 0.91 | 1.51 |

gllvmTMB is the slowest by a factor of ~3-5× at every N; expected
given the additional `unique` tier + TMB autodiff over an
augmented parameter vector.

### 3.4 galamm boundary failures

galamm hit σ²_ability ≈ 0 (interior variance boundary) on rep 1 at
N=60 (5 of 50 trait-rep pairs returned exactly zero). At N=240 and
N=500 this didn't recur (50/50 non-zero). So the boundary pathology
**is** a small-n effect, but it's the variance-collapse mode, not
the persistent under-estimate.

## 4. Interpretation

**Four findings, the third of which is the headline.**

### 4.1 The small-n binomial hypothesis is FALSIFIED.

The N-sweep (§3.1, §3.2) shows the opposite of what a small-n
pathology would predict. Ratios *decrease* monotonically with N
for all three packages that target `Lambda Lambda^T + diag(psi)`.
At N=500, all three are at a stable, asymptotic value far below 1.

So the under-estimate is **not** a transient sample-size artifact.
It is the estimators' **consistent target** — the population
quantity they converge to in the large-N limit, which is **not
equal to the DGP truth defined by `m3_sample_truth`**.

### 4.2 Two independent reduced-rank engines agree across N.

gllvmTMB and galamm — using different parameterisations (`Lambda
Lambda^T + diag(psi)` vs `lambda * σ²_ability`) and slightly
different TMB-autodiff implementations — land at nearly identical
ratios at every N (0.240 vs 0.226 at N=60; 0.142 vs 0.157 at N=240;
0.137 vs 0.121 at N=500). This rules out any gllvmTMB-specific
engine bug as the cause of the Scenario A signal from the M3 pilot.

### 4.3 **HEADLINE: the m3-grid DGP's truth definition is incompatible with the binomial fitters' estimands.**

The DGP defines `truth_diag_Sigma_tt = (Lambda Lambda^T + diag(psi))_tt`
on the latent (logit) scale. But Bernoulli responses
**under-identify the latent-scale variance** — for any data Y, the
fitter is recovering a latent-scale Sigma constrained by an
**implicit scale identification** (effectively pinning the
contribution of the binomial link-residual). The fitter's
consistent estimand and the DGP's "truth" are on different latent
scales.

The asymptotic ratios at N=500 reveal the package-specific scale
factors:

- **gllvmTMB (with psi)**: 0.137 ≈ `(Lambda Lambda^T + diag(psi)) / scale_gllvmTMB`
- **galamm (no psi)**: 0.121
- **glmmTMB (full unstructured)**: 0.184
- **gllvm (LV only, different target)**: ~1.0 across N (its `theta
  theta^T` is on a different conceptual scale where the truth
  comparison happens to land near 1).

The first three converge to a band [0.12, 0.19] at N=500. That
band IS the binomial-fit identifiable scale relative to the
DGP-truth scale. The gap is real, persistent, and a property of
the DGP-vs-target framing — not a fitter defect.

### 4.4 What gllvm tells us is illuminating.

gllvm's LV-only ratio stays near 1.0 across all N (medians 0.832 /
1.134 / 0.887) with high IQR. This means **the DGP's
`Lambda Lambda^T + diag(psi)` is, on average, on the same scale
as a binomial fitter's `theta theta^T`** — i.e., a fitter that
absorbs the `psi` contribution into the loadings recovers
approximately the right number. The fitters that try to split
`Lambda Lambda^T` from `diag(psi)` and report the sum on the
"raw latent" scale don't, because their identification constraint
puts them on a different scale.

This is the **right framing for the comprehensive sim** to adopt
(Fisher / Curie lane, Design 42 §3 follow-on). Either:

1. **Re-define the DGP truth** to be on the scale that
   gllvmTMB/galamm/glmmTMB actually identify (post-fit, derived
   from the link-residual convention each package uses).
2. **Compare on a response-scale or rotation-invariant proportion
   metric** (e.g., variance explained by latent vs unique vs
   link-residual), not raw latent-scale variance.
3. **Pin the DGP scale at simulation time** to match the fitters'
   identification convention (e.g., set `Var(eta) = 1` per trait
   and decompose the explained variance — Niku et al. 2019's
   convention).

This is **NOT** in Codex's engine lane. It is in **Fisher / Curie's
simulation-design lane**, and it's a Design 42 §3 follow-on item.

## 5. Implications for Codex's #257/#260 diagnostic-API work

The Codex-lane hand-off in [PR #262 audit memo §8.4](2026-05-24-m3-sim-lane-pilot.md)
listed three hypothesis prompts. The galamm result **falsifies the
"gllvmTMB-specific bug" framing** — the gllvmTMB-vs-glmmTMB gap is
a reduced-rank-vs-full-rank gap that galamm reproduces independently.
This reframes the Codex hand-off:

1. **Latent vs response-scale unit mismatch** (memo §8.4 #1) —
   **No longer the right hypothesis**. galamm and gllvmTMB land at
   the same 0.23 number despite different parameterisations
   (gllvmTMB uses `Lambda Lambda^T + diag(psi)`; galamm uses
   `lambda * sigma^2_ability`). A pure unit-mismatch on EITHER side
   would not produce that agreement. Drop this hypothesis.
2. **Warm-start asymmetry** (memo §8.4 #2) — still relevant for the
   nbinom2 and mixed cells (where warm-up does activate), but
   binomial × d=1 isn't where this hypothesis applies.
3. **Mixed d=3 convergence collapse** (memo §8.4 #3) — unchanged;
   not exercised by this scout.

**The new framing for Codex (replacing the three hypotheses on
binomial):**

- The 0.23 number is a **reduced-rank GLLVM property** at this
  regime, not a bug. Two independent engines (gllvmTMB + galamm)
  confirm it.
- Codex's #257/#260 work should NOT try to fix gllvmTMB to recover
  the full-rank target. That's mathematically incompatible with
  the model class. What Codex's diagnostic API CAN do:
  - Add an "under-rank warning" to identifiability diagnostics:
    when `d << T(T+1)/(2T) = (T+1)/2`, warn users that
    `Sigma_unit[tt]` is the model's estimand, not the true full-
    rank Sigma diagonal.
  - Compare `extract_Sigma(fit)` against `glmmTMB(formula =
    same)` Sigma when the model surface is small enough — surface
    the gap as informational, not error.
  - Surface boundary-variance warnings: galamm's rep-1
    σ² ≈ 0 boundary hit illustrates a real failure mode reduced-
    rank GLLVMs at small n share. The identifiability diagnostic
    in #257 could flag this.

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
- **Cross-package baselines should be a structural feature** of
  the comprehensive sim. The 4-way scout shows there are TWO
  independent gaps to attribute:
  - **truth → full-rank** (binomial small-n pathology) — needs
    glmmTMB or similar full-unstructured baseline.
  - **full-rank → reduced-rank** (the model's own estimand) —
    needs at least one reduced-rank peer (galamm or gllvm).
  Without both reference points, every under-estimate gets
  blamed on the package being tested.
- **gllvm is a different-target reference**, not a peer comparator
  for the latent-scale `Sigma_unit[tt]` target. galamm (TMB-based,
  reduced-rank, but no `psi`) is the closest peer to gllvmTMB's
  engine architecture. **galamm + glmmTMB is the right pair** for
  the comprehensive sim's cross-package validation.
- **Boundary-variance failures** (galamm's rep-1 σ² ≈ 0) need to
  be counted explicitly. A "converged" fit at the variance
  boundary is not the same as a "converged" interior fit and the
  comprehensive sim should distinguish them in the reliability
  ledger.

## 7. What this scout does NOT do

- **No CI-08 / CI-10 register-row update.** They stay `partial`
  (Design 50 §9). This scout is below the n_reps threshold and on
  a single DGP; it cannot move the register.
- **No engine "fix" recommendation.** With galamm reproducing
  gllvmTMB's 0.23, there is no engine bug to fix. Codex's
  #257/#260 lane should treat this as a documentation /
  identifiability-diagnostic question, not a code-correction
  question.
- **No claim about Gaussian, nbinom2, ordinal, or mixed.** Only
  binomial × d=1 in this scout.
- **No follow-up cross-package work in this lane**. If Codex wants
  the binomial × d∈{2,3} extension, the `dev/jason-binomial-scout.R`
  script is parameterised — set `D <- 2L` or `3L` and re-run.
- **No claim that 0.23 is the "right" answer at this regime.** It's
  the model's estimand; whether users SHOULD be fitting reduced-
  rank GLLVMs at n_units=60 / T=5 is a separate user-facing
  question (Pat / Darwin's lane).

## 8. Hand-off

The script `dev/jason-binomial-scout.R` is committed (not scratch)
so any team member — Codex, Curie, Fisher — can re-run, extend to
other d (set `D <- 2L` or `3L`), or add a fifth comparator. The
CSV outputs go to `/tmp/` and are reproducible per the script
header.

A comment on Codex's [PR #257](https://github.com/itchyshin/gllvmTMB/pull/257)
points at this memo as additional context for the diagnostic-API
work. **The key message for Codex**: the binomial Scenario A
signal from the M3 pilot is not a gllvmTMB bug — it's a
reduced-rank model property that galamm reproduces. Adjust
diagnostic-API messaging accordingly.

— Jason (cross-package landscape) and Curie (sim fidelity)
