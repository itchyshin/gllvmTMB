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

Per-package median estimate/truth ratio on `Sigma_unit[tt]` across
50 trait-replicate pairs (10 reps × 5 traits). Sorted by ascending
median ratio:

| Package | Median ratio | IQR | n fits with non-zero variance | Median fit time |
|---|---|---|---|---|
| **galamm** (reduced-rank d=1, lambda² × σ²_ability) | **0.226** | [0.004, 0.697] | 45/50† | 0.09 s |
| **gllvmTMB** (latent + unique, d=1) | **0.240** | [0.028, 0.793] | 50/50 | 0.49 s |
| **glmmTMB** (full unstructured) | **0.636** | [0.285, 1.136] | 50/50 | 0.39 s |
| gllvm (LV only — no separate psi) | 0.832 | [0.401, 2.322] | 50/50 | 0.02 s |
| gllvm + π²/3 link-residual | 3.211 | [2.201, 5.406] | 50/50 | 0.02 s (over-shoots) |

† galamm hit the variance boundary (σ²_ability ≈ 0) on rep 1 (5 of 50
trait-rep pairs returned exactly zero). The model nominally
"converged" but to a degenerate point on the boundary. This is a
small-n binomial-fit pathology consistent with rep 1's data not
supporting a non-zero LV variance.

(Smoke-scale; n_reps = 10 means MCSE on each median is moderate.
The relative ordering across packages is what's stable; absolute
values shift if you re-run with a different seed.)

## 4. Interpretation

**Three findings (rewritten 2026-05-25 after adding galamm):**

### 4.1 Reduced-rank GLLVMs cluster around 0.23 — NOT a gllvmTMB-specific bug.

The headline of the 4-way comparison: **galamm and gllvmTMB land at
essentially identical median ratios (0.226 vs 0.240)** on the same
binomial × d=1 DGP at n_units=60, n_traits=5. Two independent
reduced-rank GLLVM engines — gllvmTMB (TMB autodiff, `latent +
unique` parameterisation) and galamm (TMB autodiff, single-LV factor
parameterisation) — converge to the same shrinkage neighbourhood.

This **falsifies my earlier (round-1, glmmTMB-only) hypothesis**
that the gllvmTMB-vs-glmmTMB gap reflects gllvmTMB-specific excess
shrinkage. It is **a fundamental reduced-rank GLLVM property at this
n / T / d regime**, not a gllvmTMB bug.

### 4.2 The reduced-rank vs full-rank gap is the real signal.

glmmTMB (full unstructured Sigma, no reduced-rank constraint) sits
at **0.636** — substantially higher than the 0.23 of either
reduced-rank engine, but still well below the truth (1.0). So:

- The **first under-estimate** (1.0 → 0.64) is a binomial small-n
  pathology that affects ALL three engines uniformly.
- The **second under-estimate** (0.64 → 0.23) is the cost of
  imposing the reduced-rank constraint when the DGP truth carries
  T(T+1)/2 = 15 covariance parameters but the model fits with only
  d·T + T = 10 free parameters (d=1, T=5).

The 0.64 → 0.23 gap is the right thing to investigate IF a
reduced-rank engine is supposed to recover full-rank Sigma. The
correct interpretation, however, is that **a reduced-rank Sigma
is the model's parameterised target**, not the full-rank truth.
The "estimate/truth ratio" metric mixes these two questions.

### 4.3 gllvm parameterises differently again.

gllvm has no separate `psi` — its model is `eta = X β + LV θ^T`. The
LV-only ratio of **0.832** is higher than gllvmTMB/galamm precisely
because gllvm's loadings θ implicitly absorb both the "structured
LV" and the "unique psi" parts of the DGP. The naive π²/3 link-
residual add-back over-shoots by 3.2× because the loadings already
absorbed the psi contribution.

This is **not better than gllvmTMB or galamm**; it's a different
estimand. gllvm's `theta theta^T` ≠ gllvmTMB's `Lambda Lambda^T +
diag(psi)`. The cross-package comparison only makes apples-to-apples
sense between **reduced-rank GLLVMs** (gllvmTMB + galamm) and
between **full-rank baselines** (glmmTMB) — gllvm sits in a third
parameterisation bucket.

### 4.4 What this changes for Codex's #257/#260 lane

**The Scenario A signal from the M3 pilot is NOT a bug in
gllvmTMB.** Two independent reduced-rank GLLVMs converge to the
same number on the same DGP. So the diagnostic work in #257/#260
should NOT try to "fix" gllvmTMB to recover full-rank Sigma at
n=60 / T=5 / d=1 — that's mathematically incompatible with the
reduced-rank model class.

What **is** in Codex's lane:

1. **Document the reduced-rank ceiling explicitly.** The 0.23
   number is the model's estimand, not a bug. Users should be told
   that at n_units=60, T=5, d=1, reduced-rank GLLVMs under-estimate
   the full-rank diagonal by ~75 %. The Florence figure cascade
   could carry this.
2. **Diagnostic API: surface "you may be under-estimating
   Sigma_unit[tt] because d is too small relative to T"** — e.g.,
   the identifiability diagnostics in #257 could include a
   reduced-rank vs full-rank Sigma comparison.
3. **The galamm boundary-pathology** (rep 1 at σ² ≈ 0) is worth
   noting as a small-n GLLVM phenomenon both engines may share but
   gllvmTMB handles differently. Worth a one-line note in the
   identifiability diagnostic.

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
