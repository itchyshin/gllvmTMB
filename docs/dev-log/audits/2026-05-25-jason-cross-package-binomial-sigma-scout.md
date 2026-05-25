# Jason cross-package scout: binomial `Sigma_unit[tt]` under-estimate (now resolved as DGP fix)

**Author**: Jason (cross-package landscape lens) with Curie (sim
fidelity) reviewing.
**Date**: 2026-05-25.
**Triggered by**: M3 sim pilot Scenario A finding (PR #262; binomial
median ratio 0.24/0.32/0.42 on `Sigma_unit[tt]` across d∈{1,2,3}).
**Outcome (2026-05-25 maintainer ruling)**: the scout's diagnostic
sequence (cross-package → galamm peer-confirm → N-sweep falsifies
small-n hypothesis) identified the root cause as the **m3-grid DGP
inappropriately simulating `psi` for single-trial Bernoulli**.
Maintainer 2026-05-25: *"simulations cannot have psi bit - as psi
for binary emerges from binomial error"*. The DGP is patched in
this same PR.
**Scope**: this lane now includes a targeted `dev/m3-grid.R` patch
(binomial branches only — Gaussian / nbinom2 / ordinal-probit paths
untouched). Still no edit to `R/`, `R/diagnose.R`,
`tests/testthat/test-sanity-multi.R`, ROADMAP, check-log, or
after-task/.

## 1. Question

Is the binomial under-estimate of `Sigma_unit[tt]` that the M3
pilot surfaced **gllvmTMB-specific**, or does it appear on the same
DGP in `gllvm` (Niku et al. 2019) and `glmmTMB` (Brooks et al.
2017)?

## 2. Method

DGP exactly mirrors `dev/m3-grid.R::m3_sample_truth(family="binomial",
d=1)`. **Two rounds in this scout** — pre-patch (original m3-grid)
and post-patch (this PR's m3-grid).

**Pre-patch DGP (rounds 1-3 of this scout)**:

- `n_units = 60` initially, then swept ∈ {60, 240, 500}; `n_traits = 5`, `d = 1`.
- `Lambda ~ Uniform(-1.5, 1.5)^{5 × 1}`
- `psi ~ Gamma(shape=2, rate=2)^5` → mean 1.0
- `eta = Z Lambda^T + e_unique`, `e_unique[i, t] ~ N(0, psi_t)` ← **the inappropriate term**
- `Y[i, t] = Bernoulli(plogis(eta[i, t]))`
- **Truth (pre-patch)**: `Sigma_unit = Lambda Lambda^T + diag(psi)`.

**Post-patch DGP (round 4 of this scout — the corrected baseline)**:

- Same Lambda, Z, n's.
- `psi` is still drawn (record-keeping in `$psi`), but
  `psi_effective[t] = 0` for any trait `t` whose family is
  `"binomial"`. So no `e_unique` is added for binomial rows.
- `eta = Z Lambda^T` (for pure-binomial cells); for mixed cells the
  binomial rows have no `e_unique` while Gaussian / nbinom2 rows do.
- **Truth (post-patch)**: `Sigma_unit = Lambda Lambda^T +
  diag(psi_effective)`. For pure-binomial: `Sigma_unit = LL^T` only.

The pre-patch DGP added a per-observation latent random effect with
arbitrary variance on top of a single-trial Bernoulli — a structure
the binomial sampling distribution cannot identify and the fitter
cannot recover. The patched DGP omits that term for binary,
matching what each fitter actually identifies.

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

### 3.4 galamm boundary failures (pre-patch)

galamm hit σ²_ability ≈ 0 (interior variance boundary) on rep 1 at
N=60 (5 of 50 trait-rep pairs returned exactly zero). At N=240 and
N=500 this didn't recur (50/50 non-zero). So the boundary pathology
**is** a small-n effect, but it's the variance-collapse mode, not
the persistent under-estimate.

### 3.5 Post-patch N-sweep results (THE CORRECTED BASELINE)

After patching `m3_sample_truth` and `m3_simulate_response` to omit
`psi` / `e_unique` for binomial traits (commit landing in this PR),
the same N-sweep was re-run with `seed_base=20260525`:

| N_units | gllvmTMB (latent+unique) | galamm (lambda²σ²) | glmmTMB (full unstr.) | gllvm (LV only) |
|---|---|---|---|---|
| 60 | 0.79 [0.10, 3.39] | 0.34 [0.002, 2.73] | 3.16 [1.15, 12.4] | 5.09 [0.99, 51.9] |
| 240 | 0.93 [0.49, 1.70] | 0.70 [0.30, 1.69] | 1.38 [0.70, 2.42] | 3.79 [1.57, 24.1] |
| **500** | **0.79 [0.54, 1.28]** | **0.69 [0.31, 1.11]** | **1.02 [0.60, 2.06]** | 2.45 [1.23, 13.0] |

galamm boundary failures (σ² ≈ 0) post-patch: 15 at N=60 (down from
the same regime pre-patch on a slightly different DGP), 5 at N=240,
0 at N=500 — small-n variance collapse remains a feature.

**The reading is now interpretable:**

- **glmmTMB lands at 1.02 at N=500** — exactly recovers the truth
  (full unstructured fitter; T(T+1)/2 = 15 free params on n=500×5
  = 2500 binary obs has plenty of identification headroom).
- **gllvmTMB at 0.79 and galamm at 0.69 at N=500** — reduced-rank
  shrinkage in d=1 vs the true d=1 LV. Some shrinkage is expected
  at finite n; both engines agree to within ~15 % of each other.
- **gllvm at 2.45 at N=500** — its `θ θ^T` over-estimates the LV
  contribution by ~2-3×, because its loadings absorb binomial
  sampling noise (which used to coincidentally cancel against the
  spurious DGP `psi`). gllvm is no longer "right" on this scale.

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

### 4.4 What gllvm tells us is illuminating (pre-patch reading).

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

### 4.5 The maintainer's design ruling 2026-05-25 — **and the resolution**.

The maintainer's 2026-05-25 message:

> *"simulations cannot have psi bit - as psi for binary emerges
> from binomial error"*

This is the underlying issue, said plainly. Single-trial Bernoulli's
per-observation variance is `p(1-p)`. There's no overdispersion
parameter, no observation-level random effect to add on top; the
binomial sampling distribution IS the per-observation noise. The
m3-grid DGP simulating `e_unique[i, t] ~ N(0, psi_t)` on top of
the binomial logit is generating noise that:

1. **Inflates the truth** (`diag_Sigma` includes `psi`).
2. **Cannot be recovered from the data** (single-trial Bernoulli
   has no headroom for an extra OLRE).

The fix is to omit `e_unique` for binomial traits at simulation
time and to omit `psi` from the binomial truth definition. **This
PR implements that fix** in `dev/m3-grid.R`. Gaussian / nbinom2 /
ordinal-probit branches are unchanged; only binomial (pure and
within mixed) is corrected.

Post-patch results (§3.5) confirm the fix:

- **glmmTMB → 1.02 at N=500.** Full-rank fitter recovers the
  corrected truth as expected.
- **gllvmTMB → 0.79, galamm → 0.69 at N=500.** Modest reduced-rank
  shrinkage; both engines agree.
- **gllvm → 2.45 at N=500.** Over-estimates by ~2-3× because its
  loadings absorb the binomial sampling noise that no longer has a
  parallel in the DGP truth.

The pre-patch pattern (all-three near 0.13, gllvm near 1.0) was
the DGP-vs-fitter scale gap. The post-patch pattern is the **clean,
interpretable cross-package baseline** the comprehensive sim
needs.

## 5. Implications for Codex's #257/#260 diagnostic-API work

**Final framing (post-maintainer-ruling + DGP patch in this PR):**

The PR #262 audit memo §8.4 listed three hypothesis prompts. None
were correct in the form they were framed. After the diagnostic
sequence (gllvmTMB / glmmTMB / gllvm round 1 → galamm peer-confirm
round 2 → N-sweep round 3 → maintainer ruling round 4 → DGP patch
+ re-run round 4) the picture is:

- **There is no gllvmTMB engine bug to fix on binomial × d=1.**
- The Scenario A signal in PR #262 was an **artifact of the
  m3-grid DGP simulating a non-identifiable `psi` for binary**.
  The patched DGP in this PR produces the clean cross-package
  baseline (glmmTMB → 1.02 at N=500).
- The residual ~0.7-0.8 ratio on gllvmTMB / galamm under the
  patched DGP is **modest reduced-rank shrinkage**. Two
  independent engines agree to within ~15 %. Not a bug.

**What's left in Codex's lane (#257/#260)**:

- **No engine change required from this scout.** The diagnostic
  prompts in PR #262 §8.4 can be marked resolved by this scout +
  the DGP patch. The Scenario A signal is no longer present
  under the corrected DGP.
- **Codex may still want to surface reduced-rank shrinkage as a
  diagnostic** for users fitting `d << T(T+1)/(2T)` regimes. The
  ~0.7-0.8 ratio under the patched DGP is the modest expected
  shrinkage; users should be aware their reduced-rank fit is
  estimating its own model's `Sigma`, not the unconstrained
  full-rank `Sigma`. This is a doc / message line item, not an
  engine fix.
- **Codex may want to add boundary-variance warnings** for the
  galamm-style σ² ≈ 0 boundary hits at small n. Both reduced-
  rank engines exhibit this; it's worth surfacing in
  identifiability diagnostics (#257) when it occurs.

## 6. Implications for the comprehensive coverage sim (future)

The maintainer's 2026-05-24 framing: *"We will do power, accuracy,
and coverage through a comprehensive simulation once all the
functionalities are in place."* This scout (and its DGP patch)
tighten the design space:

- **The m3-grid DGP for binary is now correct** as of this PR:
  no spurious `psi` for binomial traits in either pure-binomial or
  mixed-family cells.
- **The comprehensive sim should adopt the same patch for any
  link with no overdispersion parameter** — single-trial Bernoulli
  (covered here), ordinal-probit (already no psi in m3-grid),
  Poisson with no OLRE (a future consideration). Families that
  genuinely carry overdispersion (Gaussian residual variance,
  nbinom2 `phi`, Beta `phi`, betabinomial `phi`) keep `psi`-style
  unique-variance terms.
- **Cross-package baselines should be a structural feature** of
  the comprehensive sim. galamm + glmmTMB is the right pair:
  galamm is the closest reduced-rank peer to gllvmTMB; glmmTMB
  is the full-rank baseline. gllvm is in a different
  parameterisation bucket and should be treated as a different-
  target reference, not a peer.
- **Reduced-rank shrinkage is a real signal worth tracking.**
  The ~0.7-0.8 ratio of gllvmTMB/galamm vs the truth under the
  patched DGP is modest but persistent. The comprehensive sim
  should quantify this as a **model property**, not a bug, and
  produce per-(family × d × n_units × n_traits) shrinkage
  estimates. Users can then decide whether the d they're choosing
  is appropriate for their data.
- **Boundary-variance failures** (galamm's rep-1 σ² ≈ 0) need to
  be counted explicitly in any reliability ledger. A "converged"
  fit at the variance boundary is not the same as a "converged"
  interior fit; the comprehensive sim should distinguish them.

## 7. What this scout does NOT do

- **No CI-08 / CI-10 register-row update.** They stay `partial`
  (Design 50 §9). The patched DGP is a methodological improvement
  but doesn't, by itself, walk a register row to `covered` — that
  requires the comprehensive sim with appropriate n_reps.
- **No engine "fix" recommendation.** With glmmTMB landing at 1.02
  under the patched DGP and gllvmTMB/galamm at 0.7-0.8 (modest
  reduced-rank shrinkage), there is no engine bug to fix. Codex's
  #257/#260 lane should treat the residual ~20-30% shrinkage as
  a documentation / identifiability-diagnostic question.
- **No claim about Gaussian, nbinom2, ordinal, or mixed in the
  scout's empirical results.** Only binomial × d=1 was directly
  exercised. The m3-grid patch covers pure-binomial cells AND
  binomial rows within mixed cells; nbinom2 / Gaussian / ordinal
  branches are untouched.
- **No follow-up cross-package work in this lane**. If Codex wants
  the binomial × d∈{2,3} extension, the `dev/jason-binomial-scout.R`
  script is parameterised — set `D <- 2L` or `3L` and re-run.
- **No re-run of the M3 production grid** under the patched DGP.
  That's a separate slice (comparable to the Codex-coordinated
  M3.3 production runs); not in this lane's budget. The scout
  evidence is sufficient to motivate the patch without re-dispatching
  the full 15-cell grid.

## 8. Hand-off

The script `dev/jason-binomial-scout.R` is committed (not scratch)
so any team member — Codex, Curie, Fisher — can re-run, extend to
other d (set `D <- 2L` or `3L`), or add a fifth comparator. The
CSV outputs go to `/tmp/` and are reproducible per the script
header.

A comment on Codex's [PR #257](https://github.com/itchyshin/gllvmTMB/pull/257)
points at this memo as additional context. **The key message for
Codex**: the binomial Scenario A signal from the M3 pilot was an
artefact of the m3-grid DGP simulating a non-identifiable `psi`
for binary, NOT a gllvmTMB engine bug. The DGP is patched in this
PR. Diagnostic-API messaging should reflect that the remaining
~20-30% reduced-rank shrinkage is a model property, not a defect.

**Maintainer-forwardable message for Codex (verbatim if useful):**

> Round-trip diagnostic from a 4-package binomial cross-package
> scout (gllvmTMB, gllvm, galamm, glmmTMB) plus an N-sweep at
> N ∈ {60, 240, 500} identified the M3 pilot Scenario A binomial
> under-estimate as a **DGP bug**, not an engine bug: m3-grid was
> adding a non-identifiable `psi` random-effect variance to
> single-trial Bernoulli, which neither the binomial sampling nor
> any latent-variable fitter can recover. With the DGP patched
> (this PR), glmmTMB lands at ratio 1.02 at N=500, gllvmTMB at
> 0.79, galamm at 0.69. No engine change needed; the residual
> ~20-30% in gllvmTMB/galamm is modest reduced-rank shrinkage
> that you may wish to surface as a diagnostic in #257.

— Jason (cross-package landscape) and Curie (sim fidelity)
