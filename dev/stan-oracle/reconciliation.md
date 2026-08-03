# Reconciliation — TMB joint log-density vs. independent Stan oracle

Role: Gauss (numerical reviewer). Date: 2026-08-03.
Worktree: `/Users/z3437171/local-scratch/worktrees/stan-oracle` @ `840d1da8`.
Toolchain: R 4.6.0 · TMB 1.9.21 · rstan 2.32.7 / StanHeaders 2.32.10 · gllvmTMB 0.6.0 (`src/gllvmTMB.so` built 2026-08-03).

---

## VERDICT

> **AGREE AFTER STATED ADJUSTMENTS.**
>
> The adjustments are (i) a **sign flip** (TMB minimises a negative log-density; Stan reports a
> log-density), (ii) **suppression of Stan's constraint Jacobian** (`adjust_transform = FALSE`), and
> (iii) a **scale/layout transport** of six parameter blocks from the engine's internal vector onto
> the specification's natural-scale quantities. **No normalising-constant correction was needed**
> (`k = 0`), and **no change was made to either density**.
>
> Agreement holds at **nine parameter points across three datasets** — including a rank-2 model, a
> ragged design with two fully missing cells, and a point with a *negative* leading loading — to a
> maximum relative difference of **8.1 × 10⁻¹⁶** (≈ 1–6 ulp of the running sum).
>
> The two implementations encode **the same model**. Failure mode 5 (model difference) is excluded.

One substantive defect was nonetheless found, in the **documentation**, not in either density:
`docs/design/04-random-effects.md` states an internal parameterisation for the loadings diagonal that
the engine does not implement. See §6.

---

## 1. The two raw numbers

At the published fixture point (`dev/stan-oracle/tmb-fixture.json`; 3 traits, 15 units, `d = 1`,
2 replicates per cell, `N = 90`, 70 parameters):

| side | call | raw value |
|---|---|---|
| **TMB** | `joint_obj$fn(theta)` | **`+429.588697635680`** |
| **Stan** | `rstan::log_prob(fit0, upars, adjust_transform = FALSE, gradient = FALSE)` | **`−429.588697635680`** |

Neither number is directly comparable to the other as printed. What follows is why, in the order the
failure modes were checked.

---

## 2. Failure mode 1 — SIGN

**Confirmed, and it is the whole of the apparent discrepancy's leading digit.**

`src/gllvmTMB.cpp` accumulates `nll -= dnorm(..., true)` and returns `nll`; `TMB::MakeADFun()` hands
that back as an objective to *minimise*. Stan's `log_prob` returns `target`, a log-density to
*maximise*.

**Adjustment 1 — negate the TMB value.** Compare `−tmb_nll` against `stan_lp`:

```
−(+429.588697635680)  =  −429.588697635680   ==   stan_lp
```

Justification: definitional, not tuned. No other reading of `MakeADFun`'s contract exists.

---

## 3. Failure mode 2 — CONSTANT TERMS

**Excluded: `k = 0`. Both sides retain every normalising constant.**

This was measured, not assumed. A third, pure-R implementation of `model-spec.md` §7.1 was written
(`spec_lp()` in `gauss-reconcile.R`) that reports its own total *with* and *without* the
`−½log(2π)` per term. At the fixture point:

```
n density terms  = N + n_u·K + n_u·T = 90 + 15 + 45 = 150
C                = −½ · 150 · log(2π) = −137.8407799807
(−tmb_nll) − (constant-free total) = −137.8407799807     →  k = −150.0000000000
```

i.e. the TMB value differs from a constant-*free* target by exactly all 150 constants, so it
contains all 150 — identical to Stan's `normal_lpdf` / `std_normal_lpdf` convention. The same holds
on the ragged dataset with 138 terms (`C = −126.8135175822`). **No constant adjustment applied.**

Supporting decomposition at the fixture point (from the pure-R spec implementation; the three terms
of §7.1):

| term | value |
|---|---|
| (D) data, 90 Gaussian rows | `−397.7245733849` |
| (Z) latent scores, 15 × N(0,1) | `−19.6184989981` |
| (Q) unique/Ψ, 45 × N(0, ψ_t) | `−12.2456252528` |
| **total** | **`−429.588697635680`** |

The TMB total equals this sum, so the *three-term hierarchical* reading of `model-spec.md` §0 (form
**b**) is the right one and §11 item 3 is answered affirmatively: the engine's random-effect vector
really is `(z, q)`, not a marginal `u`. Had the engine used the marginal form (a), the comparison
would have been a category error and would have failed by a large, non-constant amount.

---

## 4. Failure mode 3 — JACOBIANS

**Confirmed genuinely disabled on the Stan side; TMB applies none.**

TMB side: every `log_*` → `exp(log_*)` reparameterisation (`sigma_eps = exp(log_sigma_eps)`,
`sd_B = exp(theta_diag_B)`) is a plain substitution inside a `dnorm(..., true)` call, with no
compensating term added to `nll`. Correct — those are hyperparameters of the density, not variables
being transformed under a change of measure. (The `lognormal` branch of the same file *does* add
`− log(y)`, so the file is not blind to Jacobians; it correctly omits one here.)

Stan side: `psi` and `sigma_eps` are declared `<lower=0>`, so Stan's default *would* add
`Σ log ψ_t + log σ_ε`. `adjust_transform = FALSE` suppresses it.

**Adjustment 2 — `adjust_transform = FALSE`.** Verified, not trusted: at every one of the six
`K = 1` points the measured difference `log_prob(TRUE) − log_prob(FALSE)` equals
`sum(log(psi)) + log(sigma_eps)` to machine precision.

| point | measured TRUE − FALSE | `Σ log ψ + log σ_ε` |
|---|---|---|
| A/P1 | `−8.666472941009` | `−8.666472941009` |
| A/P2 | `−4.248307259719` | `−4.248307259719` |
| A/P3 | `−8.596063253572` | `−8.596063253574` |
| A/P4 | `−4.370111976949` | `−4.370111976949` |
| B/P1 | `−8.666472941009` | `−8.666472941009` |
| B/P5 | `−6.595499314402` | `−6.595499314402` |

(The 2 × 10⁻¹² residual at A/P3 is cancellation in a difference of numbers of magnitude 5 × 10⁴;
relative size 4 × 10⁻¹⁷.) A run left at the default `TRUE` would be off by ≈ 8.67 at the fixture
point and would read as a model error.

No Jacobian arises for the *unconstrained* blocks (`mu`, `Lambda`, `z`, `q`): their unconstraining
map is the identity.

---

## 5. Failure mode 4 — PARAMETER ORDER / SCALE

This is where the real work is, and where the pre-existing Stan-side result needed strengthening.

### 5.1 The methodological problem with the prior result

`stan-side.R` chose its transport by **evaluating an 8-cell grid and keeping the cell that matched
the TMB number**. Its own disclosure says so. That is three binary degrees of freedom fitted to one
number, and it cannot, by itself, distinguish "the transport is right" from "the transport absorbs a
model error". `stan-side.md` states the limitation honestly; it does not remove it.

### 5.2 What I did instead

The fence is lifted, so the transport was **read off `src/gllvmTMB.cpp` and fixed before any
comparison**, then held identical for every point and every dataset. Each line below is a source
citation, not an inference:

| Stan quantity | fixture block | rule | authority |
|---|---|---|---|
| `mu` | `b_fix` | identity, trait order `a,b,c` | `eta_fix = X_fix * b_fix` (cpp:793); `X_fix` verified `== model.matrix(~ 0 + trait)` |
| `sigma_eps` | `log_sigma_eps` | `exp()` | cpp:2103 `Type sigma_eps = exp(log_sigma_eps);` |
| `Lambda` | `theta_rr_B` | **identity — NO `exp()` on the diagonal** | cpp:902 `lam_diag = theta_rr_B.head(rank);` → cpp:909 `Lambda_B(i,j) = lam_diag(j);` |
| `psi` (variance) | `theta_diag_B` | `exp(2·θ)` — `exp(θ)` is an **SD** | cpp:1009 `sd_B = exp(theta_diag_B);` → cpp:1018 `dnorm(s_B(t,s), 0, sd_B(t), true)` |
| `z[l,k]` | `z_B` | `= z_B_mat[k,l]` (axis-fastest) | cpp:612 `PARAMETER_MATRIX(z_B)` is `d_B × n_sites`, flattened column-major |
| `q[l,t]` | `s_B` | `= s_B_mat[t,l]` (trait-fastest) | cpp:623 `PARAMETER_MATRIX(s_B)` is `n_traits × n_sites`, flattened column-major |
| `Lambda` packing, `K ≥ 2` | `theta_rr_B` | `head(rank)` = diagonal; `tail` = strict lower triangle, column-major; upper triangle **0** | cpp:904–913 (fill loop; `lam_lower(j*p − (j+1)*j/2 + i − 1 − j)` at cpp:911), corroborated by `R/lambda-constraint.R:1–28` |

**Adjustment 3 — the transport above.** It coincides with the cell `stan-side.R` selected
(`identity` / `sd` / `level_major`), which is the right answer for the right reason rather than a
lucky draw — but it is now *derived*, so the subsequent agreement is evidence about the density
rather than about the search.

### 5.3 Element-by-element index audit

Verified programmatically on both datasets (`gauss-reconcile.json → audit_*`):

- `trait_id == match(trait, c("a","b","c")) − 1` — **TRUE**
- `site_id == unit − 1` — **TRUE**
- `X_fix` is exactly the `0 + trait` indicator matrix, columns `traita, traitb, traitc` — **TRUE**
- active `use_*` flags: exactly `use_rr_B`, `use_diag_B`; every other block mapped off — **TRUE**
- `diag_B_skip = (0,0,0)` (no trait's Ψ pinned); all rows `family_id = 0`, `link_id = 0` — **TRUE**
- block counts `b_fix 3 · log_sigma_eps 1 · theta_rr_B 3 · z_B 15 · theta_diag_B 3 · s_B 45 = 70`,
  matching Stan's 70 unconstrained parameters — **TRUE**

### 5.4 Out-of-sample confirmation

With the transport frozen, the density was compared at **nine** points over **three** datasets. Only
**A/P1** was ever used by anyone to select anything; the other eight are out-of-sample.

**Dataset A** — balanced, `T = 3`, `K = 1`, `n_u = 15`, `N = 90`:

| point | TMB `fn(θ)` | Stan `log_prob` | \|diff\| | rel |
|---|---|---|---|---|
| A/P1 (published fixture θ) | `429.588697635680` | `−429.588697635680` | `2.27e−13` | `5.29e−16` |
| A/P2 (fresh) | `381.523945193974` | `−381.523945193974` | `1.14e−13` | `2.98e−16` |
| A/P3 (fresh, `Λ₁₁ = −1.6`) | `52949.378181794862` | `−52949.378181794862` | `0.00e+00` | `0.00e+00` |
| A/P4 (fresh) | `528.173868171660` | `−528.173868171660` | `1.14e−13` | `2.15e−16` |

**Dataset B** — *ragged*: cells `(unit 3, trait b)` and `(unit 11, trait c)` removed entirely, eight
further cells thinned to one replicate; `N = 78`. This exercises the per-row index maps `t(i)`,
`ℓ(i)` rather than a balanced grid, and forces both sides to carry a `q` density term for a
`(unit, trait)` cell with **no data**:

| point | TMB `fn(θ)` | Stan `log_prob` | \|diff\| | rel |
|---|---|---|---|---|
| B/P1 | `367.816158910061` | `−367.816158910061` | `1.71e−13` | `4.64e−16` |
| B/P5 (fresh) | `1133.995934554071` | `−1133.995934554071` | `4.55e−13` | `4.01e−16` |

**Dataset C** — `T = 4`, **`K = 2`**, `n_u = 12`, `N = 96`, 84 parameters. This closes
`stan-side.md` §7 limitation 1: it is the first case that exercises the **loadings packing order**,
the **triangular zeros**, and the **`z` layout** (all degenerate at `K = 1`):

| point | TMB `fn(θ)` | Stan `log_prob` | \|diff\| | rel | shift if the triangular zero is broken |
|---|---|---|---|---|---|
| C/Q1 | `1642.732618900325` | `−1642.732618900325` | `2.27e−13` | `1.38e−16` | `−193.03` |
| C/Q2 | `739.829145576315` | `−739.829145576314` | `1.14e−13` | `1.54e−16` | `+5.65` |
| C/Q3 | `13536.990910282924` | `−13536.990910282913` | `1.09e−11` | `8.06e−16` | `−1608.87` |

The last column is a control: setting `Λ[1,2]` (which the packing rule forces to 0) to a nonzero
value moves the Stan density by 5.6–1609, so these points are genuinely discriminating and the
agreement is not an accidental invariance.

### 5.5 Difference-of-differences (`model-spec.md` §7.3)

The constant-free comparison, for completeness — zero to machine precision, as it must be given §3:

```
(A/P2 − A/P1) : −1.14e−13      (A/P3 − A/P1) :  0.00e+00
(A/P4 − A/P2) :  0.00e+00      (B/P5 − B/P1) : −5.68e−13
```

---

## 6. Failure mode 5 — MODEL DIFFERENCE

**Excluded for the density.** After adjustments 1–3, the two implementations return the same number
at nine points spanning two ranks, two designs, both signs of the leading loading, and a
missing-cell configuration. There is no residual term, no factor, and no offset.

**But one real defect surfaced, in the documentation.** It is worth recording precisely, because it
is what sent the independent spec down the wrong path in the first place.

### 6.1 `docs/design/04-random-effects.md` misdescribes the loadings parameterisation

The design doc states (lines 128–131, and again in the internal-scale table at line 713–714):

- "Λ is parameterised as **lower-triangular** with **positive diagonal**"
- "The diagonal entries are on the log scale: λ_kk = exp(λ̃_kk)"
- table row: "Loadings diagonal (λ_kk) | log | **Positive by construction**"

`model-spec.md` §6.2 faithfully quotes this, and `stan-side.R`'s *spec-primary* cell therefore used
`Λ[k,k] = exp(θ_k)`. That reading is off by **792.25** at the fixture point.

**The engine does neither.** `src/gllvmTMB.cpp:902, 909`:

```cpp
vector<Type> lam_diag = theta_rr_B.head(rank);
...
else if (i == j) Lambda_B(i, j) = lam_diag(j);
```

No `exp`, no absolute value, no lower bound. The lower-triangular *zeros* **are** implemented
(cpp:906–907), so half the §6.2 convention is real; the **positive diagonal is not**. This is
corroborated three ways beyond the C++: `R/lambda-constraint.R:1–28` documents the packed layout
with the diagonal as a plain value (its "pin the leading loading to 1" pattern sets `theta = 1`, not
`log 1`); every R-side reconstruction writes `L[j,j] <- lam_diag[j]` (`R/profile-derived.R:628`,
`:747`, `:1334`, `:1504`; `R/profile-derived-curves.R:64`); and `R/fit-multi.R:5169` applies a ridge
penalty `½·Σθ²/τ²` **directly to `theta_rr_B`**, which is a natural-scale shrinkage and would be
incoherent on a log-scale diagonal.

The C++ comment says the block is "Ported from glmmTMB `src/glmmTMB.cpp` case `rr_covstruct`", so
the *code* is most likely faithful to its upstream and the *doc* is the error — but which of the two
is intended is a maintainer call, not mine.

**Consequence, and why this is not cosmetic.** With an unconstrained diagonal, the column-sign
indeterminacy of §6.3 is **not resolved by the parameterisation**: `(Λ_·k, z_·k) → (−Λ_·k, −z_·k)`
leaves the joint density exactly invariant. So

- `Σ_unit = ΛΛ' + Ψ` is unaffected (sign-flip invariant) — anything reported through `extract_Sigma()`
  is safe;
- **individual loadings are sign-arbitrary**, fixed only by optimizer initialisation, not by the
  model. Any per-loading interval, profile, Wald SE, or recovery study that treats `λ_tk` as an
  identified scalar inherits a bimodal target. The profile machinery in `R/profile-derived*.R`
  operates on exactly these entries.

I did not test whether that bites in practice; flagging it as the one place this exercise found where
the documented model and the implemented model differ.

### 6.2 A second, smaller finding: the fixture's JSON transport is lossy

`tmb-fixture.json` is written with `jsonlite::write_json(..., digits = NA)`, which is **not** bitwise
exact: the round-tripped `y` differs from the in-memory values by up to `4.88e−15`
(`identical()` → `FALSE`). That is the entire explanation for why `stan-side.R` reports `1.14e−13`
where my driver (which regenerates `y` from the same seed on both sides, no JSON) reports `2.27e−13`
at the same point. It is harmless at this tolerance, but it means the "≈ 1 ulp" claim in
`stan-side.md` §5 is really "≈ 1 ulp, on data that already differs in the 15th digit". Fix by
reading the `.rds` (which is exact and already written) or by writing 17 significant digits.

---

## 7. Every adjustment applied, with justification

| # | adjustment | applied to | justification | size at A/P1 |
|---|---|---|---|---|
| 1 | negate | TMB | `MakeADFun` returns an objective to minimise; `log_prob` returns a log-density | flips `+429.5887` → `−429.5887` |
| 2 | `adjust_transform = FALSE` | Stan | TMB adds no change-of-variables term for `exp()` reparameterised hyperparameters; verified equal to `Σ log ψ + log σ_ε` at every point | `+8.6665` |
| 3a | `sigma_eps = exp(log_sigma_eps)` | transport | cpp:2103 | — |
| 3b | `Lambda = theta_rr_B` (identity, no `exp`) | transport | cpp:902/917 | vs. `exp`: `792.25` |
| 3c | `psi = exp(2·theta_diag_B)` | transport | cpp:1009/1018 — `exp(θ)` is an SD | vs. variance-reading: `8.94` |
| 3d | `q[l,t] = s_B[t,l]` (trait-fastest) | transport | cpp:623, column-major flatten | vs. transposed: `102.20` |
| 3e | `z[l,k] = z_B[k,l]` (axis-fastest) | transport | cpp:612, column-major flatten | degenerate at `K=1`; exercised at `K=2` |
| 3f | `Lambda` packed lower-triangular fill | transport, `K ≥ 2` only | cpp:914–919 | exercised at `K=2` |
| — | **constant terms** | — | **none needed**, `k = 0`; both sides keep all `−½log(2π)` | `0` |
| — | **model** | — | **none. Neither density was altered.** | — |

---

## 8. Final difference

Headline (the published fixture point, A/P1):

```
−tmb_nll   = −429.588697635680
stan_lp    = −429.588697635680
|difference|         = 2.27e−13
relative difference  = 5.29e−16          (≈ 4 ulp of a 150-term sum)
```

Worst case over all nine points:

```
max |difference|          = 1.09e−11   (C/Q3, on a value of magnitude 1.35e+04)
max relative difference   = 8.06e−16   (C/Q3)
```

Both are at the floor set by floating-point summation order over 138–168 density terms (dataset B:
`78 + 12 + 48 = 138`; A: `90 + 15 + 45 = 150`; C: `96 + 24 + 48 = 168`). This is agreement to
machine precision.

All figures above are quoted from the drivers' `%.17g` output, not from the `.json` artifacts —
`jsonlite` writes ~15–16 significant digits, so the JSON copies differ in the last one or two digits
(see §6.2).

---

## 9. What this does NOT cover

State it plainly, per the standing rule that a partial arc names its own gaps.

1. **One family.** Gaussian identity only. Every other `family_id` branch in the C++ dispatch
   (Bernoulli/binomial, Poisson, NB, ordinal, beta, lognormal, hurdle/delta …) is untested by this
   oracle. The lognormal branch is the interesting next case precisely because it *does* carry a
   Jacobian.
2. **One structure.** `latent()` + `unique()` at a single grouping level, `use_rr_B` + `use_diag_B`
   only. Phylogenetic, spatial/SPDE, kernel, `meta_V`, `lv()` predictor-informed scores, slope
   blocks (`*_slope`), `W`-tier, and `re_int` terms were all mapped off and are untested.
3. **Joint density, not the marginal.** This compares the pre-Laplace joint at a fixed
   `(θ, z, q)`. It says nothing about the Laplace approximation itself, the inner optimisation, the
   gradient, `sdreport()`, or anything downstream of integration. A correct joint density is
   necessary, not sufficient, for a correct fit.
4. **No optimum involved.** All nine points are hand-chosen or seeded draws; none is a fitted
   optimum. That is deliberate (an optimum-only check can hide errors that vanish at stationarity),
   but it means nothing here validates the optimiser.
5. **Rank ≤ 2, `T ≤ 4`, one grouping level, ≤ 15 units.** Small by design.
6. **`diag_B_skip` never exercised.** All three/four traits carried a free Ψ; the `continue` branch at
   cpp:1017 (pinned trait) is untested.

---

## 10. Exact commands to reproduce

From the worktree root, `/Users/z3437171/local-scratch/worktrees/stan-oracle`:

```sh
# TMB side (writes tmb-fixture.rds / tmb-fixture.json)
Rscript dev/stan-oracle/tmb-side.R
#   -> joint nll(theta) = 429.5886976357

# Stan side as originally written (grid search over the transport)
Rscript dev/stan-oracle/stan-side.R
#   -> PRIMARY log-density = -1221.8356455352   (the spec's exp() reading — wrong, see sec.6.1)
#   -> unique matching cell: identity / sd / level_major = -429.588697635680

# This reconciliation: transport fixed a priori from src/, 6 points, 2 datasets
Rscript dev/stan-oracle/gauss-reconcile.R
#   -> writes dev/stan-oracle/gauss-reconcile.json

# The K = 2 case: loadings packing, triangular zeros, z layout
Rscript dev/stan-oracle/gauss-reconcile-k2.R
#   -> writes dev/stan-oracle/gauss-reconcile-k2.json
```

`gauss-reconcile.R` and `gauss-reconcile-k2.R` each run both engines in a single R session, so no
value crosses a JSON boundary before being compared (see §6.2). Runtimes: ≈ 10 s and ≈ 6 s
respectively, with `src/gllvmTMB.so` and the cached `gllvm_ordinary.rds` already built.

## 11. Artifacts

| path | what |
|---|---|
| `dev/stan-oracle/reconciliation.md` | this document |
| `dev/stan-oracle/gauss-reconcile.R` | driver: `K = 1`, balanced + ragged, 6 points |
| `dev/stan-oracle/gauss-reconcile.json` | its results, including the alignment audit and the term decomposition |
| `dev/stan-oracle/gauss-reconcile-k2.R` | driver: `T = 4`, `K = 2`, 3 points |
| `dev/stan-oracle/gauss-reconcile-k2.json` | its results |

Neither driver modifies `gllvm_ordinary.stan`, `tmb-side.R`, or `stan-side.R`.

---

## 10. Adversarial review (three independent lenses, fresh contexts)

Each lens was told to REFUTE the result and to default to "not established" when uncertain.

### 10.1 Numerics — **SOUND**

- **Independently reproduced the headline in a fresh session**, rebuilding TMB and re-running Stan
  `log_prob` rather than trusting the cached JSON: `tmb_nll = 429.588697635679921`,
  `stan_lp = -429.588697635680148`, `abs_diff = 2.27e-13`, `rel_diff = 5.29e-16`.
- Confirmed **no hidden tolerance**: the drivers print `abs_diff`/`rel_diff` and contain no
  `atol`/`rtol` gate that could be quietly loosened. With 150 O(1) log-density terms, ~4 ulp is the
  expected floating summation-order floor, not a permissive threshold.
- **Deliberately broke the model three ways and confirmed every one is caught**: SD-vs-variance on
  psi (8.94), `exp()` on the loadings diagonal (1191.2), un-transposed `q` (102.2). All are many
  orders of magnitude above the 5e-16 floor. **The comparison can fail, therefore it is a check.**
- Verified the compared blocks are **live, not mapped off**: none of `b_fix`, `log_sigma_eps`,
  `theta_rr_B`, `z_B`, `theta_diag_B`, `s_B` appear in TMB's `map=` list, so a wrong transport could
  not be masked by a frozen parameter.

### 10.2 Scope — **SOUND**

`grep` over the artifact set returns zero hits for the four overclaim vectors (validated / coverage /
phylo_latent / tmbstan-equivalence). The tmbstan trap is not committed: this compares a fixed-point
**pre-Laplace joint density**, never an MCMC posterior. One phrasing flag, addressed in §9: "the two
implementations encode the same model" is true only for the Gaussian-identity `latent`+`unique`
slice actually exercised, and only for the joint pre-Laplace density.

### 10.3 Tautology — **QUALIFIED.** Read this one.

**The finding: the model formula is independent; the parameter transport is not.**

- The Stan density **is** independent. `gllvm_ordinary.stan` implements the three-term density from
  `model-spec.md` alone; its `target +=` logic is untouched for the whole session (confirmed by
  mtime and by diff), and the file header records that nothing under `src/` was read.
- **But §5.2 lifted the fence for the transport.** The six-row mapping table cites
  `src/gllvmTMB.cpp` line numbers as its authority. So for those six items, agreement partly
  verifies that the driver correctly *transcribed* the C++ — not that the C++ is correct.
- Sharpest instance: the Lambda-packing transport replays `cpp:902-913`, which is **model-assembly
  logic, not mere plumbing**. The corroborating file (`R/lambda-constraint.R`) describes the same
  packing and derives from the same implementation, so it reduces transcription risk without
  establishing independence.

**Why this is a structural limit rather than an execution failure.** No published paper states
another program's internal storage layout — whether psi is kept as SD or variance, whether the
random-effect vector is level-major or trait-major, how the loadings are packed. Those facts are
knowable only by reading the implementation or by measuring against it. **A fixed-parameter oracle
can therefore be independent about the MATHEMATICS and cannot be fully independent about the
ENCODING.** That boundary should be stated wherever this route is described.

**Mitigating evidence, weighed by the same lens:** 9 points across 3 datasets; non-degenerate theta
(mixed signs, e.g. `Lambda[1,1] = -1.6`); a discriminating control that breaks the triangular-zero
packing rule and shifts the density by 5.65 to 1608.87; and — decisively — the exercise produced a
**real disagreement** (§6.1, the 792.25 `exp()` discrepancy) rather than only confirmation. A purely
tautological setup cannot generate a finding that contradicts its own source documents.

### 10.4 Net verdict

**The route works, with a stated boundary.** The likelihood *mathematics* was checked
independently and agrees to ~1 ulp. The *encoding conventions* were measured against the
implementation, not derived, and that half is not independent. Both halves must be reported together
wherever this result is cited.

---

## 11. Correction to §6.1's consequence claim (2026-08-03, after maintainer challenge)

§6.1 stated that the unconstrained loadings diagonal means "any per-loading interval, profile, Wald
SE, or recovery study that treats `lambda_tk` as an identified scalar inherits a bimodal target."
**That is stronger than the evidence supports and is corrected here.** The doc/engine divergence
itself stands unchanged; only its consequence is re-scoped.

### 11.1 Measured, not argued

Using the same fixture and joint objective:

```
baseline joint nll        : 429.588697635680
flip BOTH Lambda and z    : 429.588697635680   diff = 0.000e+00
flip Lambda ONLY          : 547.088294763655   diff = 1.175e+02
```

The paired sign flip `(Lambda_.k, z_.k) -> (-Lambda_.k, -z_.k)` is an **exact** invariance of the
joint density. Flipping Lambda alone is not a symmetry, which confirms the invariance is the
specific paired reflection rather than a general insensitivity to Lambda.

### 11.2 The two indeterminacies are different objects and need different constraints

`Sigma = Lambda Lambda' + Psi` is invariant under `Lambda -> Lambda Q` for orthogonal `Q`. That
group splits:

| indeterminacy | nature | dimension | constraint that fixes it | in gllvmTMB? |
|---|---|---|---|---|
| rotation | continuous | `K(K-1)/2` | lower-triangular zeros | **yes** (`cpp:915-916`) |
| sign | discrete | `2^K` | positive diagonal | **no** |

So the reduced-rank parameterisation **does** fix the rotation, as the upstream `rr_covstruct`
design intends. What is absent is only the discrete sign convention.

**At `K = 1` -- the rank used throughout this spike -- `K(K-1)/2 = 0`.** There is no rotation to fix
and the triangular constraint is vacuous; the sign flip is the entire indeterminacy, and there are
exactly two equivalent solutions.

### 11.3 Why the practical consequence is small

- It is a **discrete two-fold mirror, not a flat direction**: two isolated modes, not a ridge.
  Optimisation is unaffected -- it converges into one basin and stays there.
- A profile or Wald interval computed around that mode is a **valid local interval**. It is not
  incorrect; it is simply not unique across the mirror.
- Everything Design 66 actually gates -- `Sigma_unit`, correlations, communalities, ICC -- is
  **sign-invariant** and therefore untouched. `extract_Sigma()` is safe, as §6.1 already said.

**The one real exposure is aggregation across fits**: averaging `lambda_hat_tk` over simulation
replicates whose signs differ collapses the mean toward zero. The repo already guards this twice --
Design 66 treats loadings as rotation-variant diagnostics that are never gated, and the shipped
`gllvm` comparator Procrustes-aligns before comparing.

### 11.4 What still stands

The **documentation divergence** is unaffected by this correction and remains the finding worth
acting on: `docs/design/04-random-effects.md` asserts a positive log-scale diagonal that the engine
does not implement, and that assertion sent an independently written specification 792.25 off the
true value. Fixing the doc is clearly worthwhile; adding the positive-diagonal constraint to the
engine is a separate and much weaker case, since the quantities the package actually gates are all
sign-invariant.
