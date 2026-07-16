# Design 83 — Multinomial (unordered categorical) response family

**Status date:** 2026-07-16.
**Decision owner:** maintainer (S. Nakagawa); re-scoped multinomial out of "post-CRAN" into the
0.6 dev cycle, **fixed-effects-only (Tier 1)**.
**Scope:** R-only this arc (Julia parity is a separate later arc).
**Design panel (ultra-plan):** Gauss (TMB likelihood), Boole (R API), Noether (symbolic
alignment / identifiability), Fisher + Emmy (inference / S3), Curie (recovery), Rose + Jason
(honesty / register / use-case). Ada orchestrated; this doc consolidates their reviews.
**Runtime id:** `family_id 16` (next free after `nbinom1 = 15`).
**Register row:** `docs/design/35-validation-debt-register.md` **FAM-20**.

---

## 1. Context — the decisive gate (why fixed-effects-only)

The natural companion to the ordinal cell is a genuine *unordered* categorical response. A
prior-work sweep established four load-bearing facts:

1. **`ordinal_probit` (fid 14) is a fully `covered` family — NOT fenced for identifiability.**
   Its cumulative-probit threshold model recovers cleanly (FAM-14). The board phrase "ordinal
   fenced" refers only to holding ordinal (with nbinom2) out of the Lane-A interval-**coverage
   certificate** — a coverage-scoping decision, not a likelihood wall. So a categorical family
   inherits **no** negative result from ordinal.
2. **The obstruction is architectural.** gllvmTMB's headline feature — latent-scale mixed-family
   correlations — assumes **one** latent residual dimension per trait (a single scalar `σ²_d`;
   Design 02 "Link Residual Contract"). An unordered categorical response over `K` categories is
   intrinsically **`K−1` latent dimensions** (baseline-category logits), so it cannot supply that
   single scalar. This is the same class of obstruction Design 62 records for delta/hurdle
   families ("two linear predictors on two non-comparable scales … no single covariance"),
   generalized from 2 scales to `K−1`.
3. **Therefore Tier 1 is fixed-effects-only** — exactly the Design 62 delta precedent (two-part
   families were shipped fixed-effects-only, no latent). The `K−1`-dimensional latent-scale
   correlation surface is **Tier 2, deferred** (open derivation; reversible only by first defining
   a principled per-category / stacked-liability reporting convention).
4. **Two facts de-risk the build:** a **validated baseline-category softmax already exists** in the
   engine (the missing-*predictor* MD6c path, `src/gllvmTMB.cpp:2320-2334`) — port that kernel, do
   not re-derive; and **category contrasts can be carried as pseudo-trait factor levels**, so the
   existing `0 + trait + (0 + trait):x` grammar produces the per-category design with **no parser
   change**.

`categorical()` is already an exported constructor for missing-*predictor* imputation
(`R/missing-predictor.R:143`, MIS-31). The response family is therefore named **`multinomial()`**;
the two must be kept apart in all prose.

---

## 2. Symbolic decomposition (baseline-category logit / softmax)

Reference parameterization: brms `categorical()` / VGAM baseline-category logit. For a categorical
trait `t` with `K_t` unordered categories, observation `y_{it} ∈ {1,…,K_t}`, reference category 1:

- `η_{it1} ≡ 0`  (baseline pinned for identifiability)
- `η_{itk} = β0_{tk} + xᵢᵀ β_{tk}`,  k = 2,…,K_t   (Tier 1: fixed effects only — no latent/RE term)
- `P(y_{it}=k) = exp(η_{itk}) / [ 1 + Σ_{j=2}^{K_t} exp(η_{itj}) ]`   (softmax; baseline is the
  implicit `exp(0) = 1` term in the denominator)

A single categorical trait occupies **`K_t − 1` free linear predictors**. Free parameters per
categorical trait = **`(K_t − 1)(1 + p)`** (intercept + `p` slopes per non-baseline category); the
baseline contributes **0**. Coefficients are **contrasts vs the reference**: `β0_{tk}` is the
log-odds of category `k` vs category 1 at `x = 0`; `β_{tk}` is the change in that log-odds per unit
`x`.

### Alignment table (symbol ↔ implementation)

| Symbol in prose | keyword / covstruct | DGP draw | recovery extractor | truth value |
|---|---|---|---|---|
| baseline pin `η_{it1} ≡ 0` (⇔ `β0_{t1}≡0`, `β_{t1}≡0`) | reference = first factor level; **structural pin, no free param** | not drawn (fixed 0) | assert engine holds NO free predictor for category 1; denom gathers the implicit `exp(0)=1` | `η_{it1}=0` exact |
| per-category intercepts `β0_{tk}`, k=2..K | pseudo-trait `<T>:cat<k>` intercept | draw `β0_{tk}`, softmax draw | `fixef()` / coef row `trait:cat_k` (**name-keyed**) | `log[P(k)/P(1)]` at `x=0` |
| per-category slopes `β_{tk}`, k=2..K | `(0 + trait):x` on pseudo-trait level | `η_{itk}=β0+xβ` | `fixef()` row `trait:cat_k:x` | `∂/∂x log[P(k)/P(1)]` |
| response draw `y_i` | `family = multinomial()`, y a ≥3-level unordered factor | `sample.int(K,1,prob=softmax)` | grouped softmax logLik, once per observation-group | `E[1{y=k}] = p_ik` |
| reference-choice invariance | relevel `y` | refit with a different baseline | logLik + fitted `p_ik` **unchanged to 1e-6** | invariant; coefficients relabel |
| **link residual `σ²_{d,t}`** | link-residual slot | — | `link_residual_per_trait()` returns **NA** (guarded) | **N/A by design** (K−1 dim) |

### Identifiability

The softmax is shift-invariant: `η_k → η_k + c` leaves every `P(y=k)` unchanged, so the map
`(η_1,…,η_K) ↦ (p_1,…,p_K)` has a one-dimensional null space (the all-ones direction). With `K` free
etas the model is rank-deficient by exactly 1 per group. **Pinning `η_{it1} ≡ 0`** selects one
representative per equivalence class → the parameter→probability map is injective. The engine must
allocate exactly `(K−1)(1+p)` free entries per trait and emit exactly `K−1` non-baseline predictors.

**Reference-choice invariance (proof).** For any other baseline `r'`, set `η'_{ik} = η_{ik} − η_{ir'}`;
then `η'_{ir'} = 0` and, by shift-invariance, `P'(y=k) = P(y=k)` for every `k`, `i`. The
per-observation probability vector — hence the likelihood at every data point and the maximized
log-likelihood — is identical; only coefficients relabel (`β'_k = β_k − β_{r'}`). **Recovery tests
must compare coefficients to truth at the SAME declared reference, and assert invariance
separately — never assert raw-coefficient equality across different baselines.**

### The `K = 2` reduction

A 2-category "multinomial" is exactly `binomial(link = "logit")` (one non-baseline logit). Following
the ordinal `K=2 → binomial(probit)` precedent, **`multinomial()` on a 2-level response must error
and redirect to `binomial()`** (guard mirrors `R/missing-predictor.R:1167`).

---

## 3. Why the latent-scale correlation surface is deferred (Tier 2)

The Link Residual Contract (Design 02) requires **one scalar `σ²_d` per trait**; every currently
supported family has a one-dimensional latent liability (binomial's single logistic/probit/cloglog
axis; ordinal's *single ordered* axis, which is exactly why ordinal yields a scalar and multinomial
does not). An unordered categorical response has no monotone axis to collapse `K` exchangeable
categories onto; its sufficient latent representation is the vector of `K−1` contrasts, and the
induced trait-level covariance is a `(K−1)×(K−1)` matrix, not a scalar. Any projection to a single
number is arbitrary — "mathematically undefined, not merely hard to compute" (the Design 62 wording).

The delta escape hatch (constrain latent to one interpretable submodel — Design 02 Hurdle/delta
resolution) **does not transfer**: the `K−1` contrasts are exchangeable, so there is no privileged
single scale to nominate. Categorical is therefore strictly harder than delta and stays deferred.

**Consequences enforced in Tier 1:**
- `multinomial()` declares its `link_residual_rule` as **N/A-by-design**;
  `link_residual_per_trait()` (`R/extract-sigma.R`) gains an explicit `fid == 16 → NA_real_` branch.
- `extract_correlations()` / `extract_sigma()` / `extract_repeatability()` **hard-refuse** a fit
  containing a categorical trait (a typed `cli_abort`, not a silent NA fall-through).
- `latent()` / `unique()` / `indep()` / `dep()` / `phylo_*` / `spatial_*` / random-slope / cluster
  terms on a multinomial trait **fail loud** (a single Tier-1 covstruct choke-point), enforced by a
  dedicated fail-loud **test** — a fence that is only documented is not fenced.

---

## 4. Architecture (the build contract)

### 4.1 Representation — pseudo-trait-level expansion + group index

Each categorical observation (unit `u`, trait `T`, response `y ∈ {1..K}`, predictors `x`) is expanded
into **`K−1` pseudo-trait-level rows**, one per non-baseline category `c ∈ {2,…,K}`, in ascending
category order, tied by a new integer **`.multinom_group_`** index (contiguous, 0-based, identical
across a group; `−1` for every non-multinomial row). Each pseudo-row carries pseudo-trait level
`"<T>:cat<c>"`, the predictors copied verbatim, the group's mask, and the group weight on the first
row only. Category-specific fixed effects then flow through the *existing* `X_fix`/`eta` pipeline
(the block-diagonal design the softmax needs); the baseline is pinned **structurally** (no baseline
row). No parser change — this is a data-prep pre-pass (`expand_multinomial_response()`) between the
`traits()` pivot and the fit call.

### 4.2 C++ likelihood — port the MD6c softmax, evaluate once per group

A `multinom_group_loglik` lambda, evaluated **once at the group anchor row** (first row of the block,
detected by a `multinom_group_id` change), contributes 0 at the other `K−2` rows — the
anti-double-counting contract. It reuses the MD6c max-subtraction LSE (`src/gllvmTMB.cpp:2320-2334`):

```
log P(y = observed) = Σ_j y_j·η_j  −  logsumexp(0, η_1, …, η_L)      (L = K−1)
```

with `y_j` the 0/1 indicator "observed category == contrast j" (all zero ⇒ baseline observed,
numerator = 0). The baseline `0` is folded into the running max, so `s ≥ 1` and `log_denom` is finite
for any `η`; an AD-safe floor mirrors ordinal's `tiny_p` (defensive, should never bind).

### 4.3 New TMB data — one required vector, no new parameter vector

- **Required:** `DATA_IVECTOR(multinom_group_id)` (length `n_obs`; `−1` off-family).
- **Recommended:** `DATA_IVECTOR(multinom_K_per_trait)` (length `n_traits`; `K_t − 1` for a
  multinomial trait, built like `n_ordinal_cuts_per_trait`) — gives `L` in O(1) and a run-length
  cross-check against the block.
- **No new `PARAMETER_VECTOR`** (the key simplification vs ordinal): category effects enter through
  `X_fix`/`b_fix`; the baseline pin is structural. Dispersion + auto-`Psi` are `map`-ed off.

### 4.4 Guards (Tier 1)
`K < 3` → redirect to `binomial()`; `multinomial()` inside a mixed-family `list(...)` → reject
(defer to Tier 2); any latent/RE/structured term on a categorical trait → fail loud; a categorical
trait must **own all rows of its trait** (softmax is estimated per trait); `weights` on a multinomial
trait rejected in Tier 1 (per-group weight semantics deferred); unobserved non-baseline categories →
abort (`droplevels`, infer `K` from observed categories).

### 4.5 The one integration point to pin first (C1a)
The exact response encoding the C++ branch reads — a per-row 0/1 indicator (Gauss) vs a repeated
category code reconstructed C-side (Boole) — must be decided in C1a; the R expansion emits whatever
the branch consumes. **Critically, the inline recovery DGP (§6) must match the C++ coefficient
packing term-by-term** (baseline = category 1, `K−1` column-major blocks) or name-keyed recovery
silently breaks.

---

## 5. Inference & S3 contract (Tier 1)

The `K−1` pseudo-row expansion breaks the "one row = one scalar response cell" invariant that every
S3 method assumes (methods co-index at `n = length(y)`). Each method therefore needs a
`multinom_group_id`-aware reduction from pseudo-rows → observations.

| Method | Tier-1 behaviour | Deferred (Tier 2) |
|---|---|---|
| `predict(type="response")` | K per-category probabilities (long-in-category, sums to 1); point only | prediction intervals / prob SEs |
| `predict(type="link")` | K−1 non-baseline etas (category 1 omitted) | SEs on etas |
| `fitted()` (new method) | per-category probability; modal category via arg | — |
| `simulate()` | per-group softmax draw → one category, expanded to the pseudo-row encoding; add `16L` to `supported` | family-aware `newdata` (M2/M3) |
| `residuals()` | **not defined** → `status = "unsupported_family"` (nominal categories have no ordered CDF; the pseudo-rows are not independent) — exactly where fid 14 already lands | ordinal quantile residual / multinomial deviance residual, calibration-gated |
| `confint()` / SE | **Wald** on per-category `b_fix` intercept + slope (free) | profile CI (runs but uncalibrated → **not advertised**) |
| `print()` / `summary()` | `trait:cat_k[:x]` coefficient labels + a baseline advisory line | — |
| `extract_correlations` / `_sigma` / `_repeatability` | **hard-refuse** a fid-16 trait (typed abort) | latent-scale trait correlation |

---

## 6. Recovery (ADEMP, Tier 1 — no inheritance)

**Aim.** A fixed-effects-only multinomial fit recovers the `(K−1)` per-category intercepts and slopes
from a known softmax DGP (K = 3 and K = 4), and is baseline-invariant.

**DGP.** `η_{itk} = β0_{tk} + x_i β_{tk}` (k=2..K), `x ~ N(0,1)`; `y ~ Categorical(softmax)` drawn
**inline** via `sample.int(K, 1, prob = p)` — needs **no** package `simulate()`. `n_unit = 400`
(K=3) / `600` (K=4); truth chosen so no category starves (min `p ≥ 0.17`). K=3 truth
`β0 = (0.5, −0.4)`, `β = (1.0, −0.8)`.

**Targets & bands.** Recover the `(K−1)` intercepts + slopes, **name-keyed** to `b_fix`, within
**abs 0.30** (largest coefficient per cell **abs 0.40**) — the ordinal **fixed-effect** band
(`test-ordinal-probit.R`), **NOT** the 2.5× variance band (there are no variance components in
fixed-effects-only C2). One 5-seed aggregate cell: seed-mean within abs 0.30. Baseline-invariance:
refit at a different reference → objective + fitted `p_ik` identical to **1e-6**. `K=2` byte-identity
to `binomial(logit)` to **1e-6**.

**Test files.** `tests/testthat/test-multinomial-recovery.R` (K=3/K=4 recovery; K=2 reduction;
invariance; 5-seed; mixed gaussian+poisson smoke); `test-multinomial-unit.R` (fast: fid==16 +
`(K−1)`-block contract; **fail-loud latent-on-multinomial guard**; an optimiser-free reference-
invariance math gate); `test-enum-runtime-ids.R` updated for id 16. `dev/multinomial-recovery.R`
calibrates the bands over 20–50 seeds on **Totoro/DRAC** (never GitHub Actions — D-50).
**Do NOT author `test-matrix-multinomial-unit.R`** — a "matrix" file is unit-tier covariance recovery,
which needs random effects on a categorical trait = out of Tier-1 scope; record that row
`blocked/planned`.

**The two-part draw trap (R4).** The inline `sample()` DGP does *not* depend on `simulate()`, so
recovery is not blocked by it — but it **must match the C++ packing** (§4.5). Separately,
`simulate.gllvmTMB_multi()` routes through `.draw_y_per_family()` whose `supported` set lacks 16 and
returns one scalar per row → a multinomial fit would **silently fall back to a Gaussian-on-link
draw**. Any test touching `simulate()` / `bootstrap_Sigma()` / predictive diagnostics on a
multinomial fit **must honest-skip** until the fid-16 draw branch lands — never accept the fallback.

---

## 7. Use case (Jason)

A **single unordered categorical trait** with an established multivariate use: discrete colour-morph
polymorphism (*Cepaea nemoralis* shell colour; Gouldian finch head colour), behavioural state
(foraging / vigilant / resting), microhabitat/substrate choice, or primary diet category. The
scientific question is fixed-effect: how does morph/state frequency shift with an environmental or
individual covariate? The multivariate-GLLVM payoff is fitting the categorical trait **alongside
other-family traits** (body size Gaussian, parasite load nbinom2, clutch size Poisson) in one stacked
model sharing the fixed-effect design.

**Honest framing (keeps it in scope, out of overclaim).** Unordered multinomial is **not** a standard
GLLVM community-matrix response — `gllvm`, `boral`, and the Warton/Niku/Hui line ship **ordinal**
(cumulative-link) for graded community data, not nominal multinomial. Frame `multinomial()` as "one
categorical trait, possibly alongside other-family traits," **never** as "many nominal species
columns" (that is the deferred Tier-2 stacked-liability surface). This satisfies Design 02 principle 6
("clear multivariate-GLLVM use case; not shipped just because it exists elsewhere").

---

## 8. Cross-references
- `docs/design/02-family-registry.md` — Link Residual Contract; "Unordered categorical (multinomial)"
  subsection (added this arc); the multinomial line moved from "planned; post-CRAN".
- `docs/design/62-two-part-family-naming-and-scope.md` — the governing precedent (fixed-effects-only
  for multi-scale families; the "no single latent-residual scale" scope boundary).
- `docs/design/35-validation-debt-register.md` — FAM-20 row (this family's evidence ledger).
- `src/gllvmTMB.cpp:2320-2334` — the validated MD6c baseline-softmax kernel to port.
- `R/missing-predictor.R:143` — the exported `categorical()` imputation family (the naming-collision
  reason the response family is `multinomial()`).
- `~/.claude/plans/categorical-multinomial-humble-babbage.md` — the ultra-plan (slice table, routing).
- Handoff: `docs/dev-log/handover/2026-07-16-claude-to-codex-multinomial.md` — the turnkey build package.
