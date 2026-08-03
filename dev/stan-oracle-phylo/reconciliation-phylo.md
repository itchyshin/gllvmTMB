# Reconciliation — TMB joint log-density vs. independent Stan oracle, PHYLOGENETIC arc

Role: Gauss (numerical reviewer). Date: 2026-08-03.
Worktree: `/Users/z3437171/local-scratch/worktrees/stan-phylo` @ `ff70b5e8`.
Toolchain: R 4.6.0 · TMB 1.9.21 · rstan 2.32.7 · ape 5.8.1 · gllvmTMB 0.6.0 (`src/gllvmTMB.so` built 2026-08-03).

Model: `value ~ 0 + trait + phylo_latent(species, d = K, vcv = A)`, Gaussian identity,
loadings-only (`unique = FALSE`), dense/legacy `vcv =` path.

Predecessor: `dev/stan-oracle/reconciliation.md` (Arc 0). Its failure-mode order, driver structure,
and three of its adjustments are reused here; its §6.2 JSON-lossiness finding recurs (§9.3).

---

## VERDICT

> **AGREE AFTER STATED ADJUSTMENTS.**
>
> The adjustments are (i) a **sign flip**, (ii) **suppression of Stan's constraint Jacobian**
> (`adjust_transform = FALSE`), and (iii) an **eight-rule parameter/data transport** derived from
> `src/gllvmTMB.cpp` and `R/fit-multi.R` — including, as rule 6, the engine's **undocumented
> `1e-8` ridge on `A`**. **No normalising-constant correction was needed** (`k = 0`): both sides
> keep every `−½log(2π)` *and* the `−K/2·log|A|` term. **Neither density was altered.**
>
> Agreement holds at **seven parameter points across two trees** — including a rank-2 model on a
> second, larger tree with a **permuted tip order** and a **ragged design with two empty cells** —
> to a maximum absolute difference of **1.82 × 10⁻¹²** and a maximum relative difference of
> **3.99 × 10⁻¹⁶** (≈ 1–8 ulp).
>
> The two implementations encode **the same model**. Failure mode 5 (model difference) is excluded
> for the density.

Two substantive findings sit outside the density comparison, both in the **implemented-vs-documented
model**, not in the agreement:

1. **The engine silently evaluates the phylogenetic prior at `A + 1e-8·I`, not at the user's `A`**
   (`R/fit-multi.R:3224`, undocumented anywhere). Bounded in §8.
2. Arc 0's `docs/design/04-random-effects.md` loadings-diagonal divergence is **confirmed to apply to
   the phylogenetic block too** (`theta_rr_phy` is natural-scale, not `exp()`). §9.1.

---

## 1. The two raw numbers

At the published fixture point (`dev/stan-oracle-phylo/tmb-fixture-phylo.json`; 3 traits, 8 tip
species, `K = d_phy = 1`, 2 replicates per cell, `N = 48`, 15 parameters):

| side | call | raw value |
|---|---|---|
| **TMB** | `joint_obj$fn(theta)` | **`+142.63339487378119`** |
| **Stan** | `rstan::log_prob(fit0, upars, adjust_transform = FALSE, gradient = FALSE)` | **`−142.63339487378124`** |

```
|difference|         = 5.68e-14
relative difference  = 3.99e-16
```

Neither number is directly comparable to the other as printed. What follows is why, in the order the
failure modes were checked.

---

## 2. Failure mode 1 — SIGN

**Confirmed; definitional, not tuned.** `src/gllvmTMB.cpp` accumulates `nll -= dnorm(...)` for the
data term and `nll += 0.5*(...)` for the phylogenetic term (cpp:1170–1171), and returns `nll`;
`TMB::MakeADFun()` hands that back as an objective to **minimise**. Stan's `log_prob` returns
`target`, a log-density to **maximise**.

**Adjustment 1 — negate the TMB value.**

---

## 3. Failure mode 2 — CONSTANT TERMS

**Excluded: `k = 0`.** Measured, not assumed, with a **third, pure-R implementation** of the spec
density (`spec_lp()` in `gauss-reconcile-phylo.R`) that reports its total with and without the
`−½log(2π)` factors. At all four dataset-A points:

```
n density terms       = N + S·K = 48 + 8 = 56
C                     = −½·56·log(2π) = −51.4605578594617
(−tmb_nll) − (constant-free total) = C   →  k = −56.0000000000 terms, exactly
```

i.e. the TMB value differs from a constant-free target by exactly all 56 constants, so it contains
all 56 — identical to Stan's `normal_lpdf` / `multi_normal_cholesky_lpdf` convention. The third
implementation reproduces the TMB total independently, to `0` – `4.5e−13`.

**The `−K/2·log|A|` term is the phylo-specific case of this failure mode, and it is the one that
would have been easy to lose.** It is parameter-free (`A` is data), so it looks droppable — but it is
**not numerically zero**, unlike Arc 0's `log|I| = 0`. Both sides retain it:

| dataset | `log|A + 1e-8 I|` | `−K/2·log|A|` kept | shift if **dropped** | shift if **sign-flipped** |
|---|---|---|---|---|
| A (`K=1`) | `−7.8611543987162609` | `+3.930577199358` | `−3.930577199` | `+7.861154399` |
| B (`K=2`) | `−10.74915852155274` | `+10.749158522` | `−10.749158522` | `+21.498317035` |

The engine's stored `log_det_A_phy_rr` equals `log|A + 1e-8 I|` to the last printed digit on both
datasets, and equals `+log det(A)` — the **covariance's** log-determinant, not the precision's
(`R/fit-multi.R:3226`; the `tree =` branch at `:3172` reaches the same sign via
`−log_det_precision`). **No constant adjustment applied.**

Term decomposition at the fixture point (third implementation):

| term | value |
|---|---|
| (D) data, 48 Gaussian rows | `−118.984057417465` |
| (G) phylogenetic scores, 1 × MVN₈(0, A) | `−23.6493374563161` |
| **total** | **`−142.633394873781`** |

Two terms, not three — confirming `unique = FALSE` is loadings-only and no `Ψ_phy` companion is
active (`use_phylo_diag = 0`).

---

## 4. Failure mode 3 — JACOBIANS

**Confirmed genuinely disabled on the Stan side; TMB applies none.**

TMB: `sigma_eps = exp(log_sigma_eps)` (cpp:2103) is a plain substitution inside `dnorm(..., true)`,
with no compensating term. `theta_rr_phy` and `g_phy` are untransformed (identity unconstraining
map), so no Jacobian arises there. (The `lognormal` branch at cpp:2149 *does* add `− log(y)`, so the
file is not blind to Jacobians; it correctly omits one here.)

Stan: `sigma_eps` is the **only** constrained declaration (`real<lower=0>`), so Stan's default would
add exactly `log σ_ε`. `adjust_transform = FALSE` suppresses it.

**Adjustment 2 — `adjust_transform = FALSE`.** Verified, not trusted: at every one of the seven
points the measured `log_prob(TRUE) − log_prob(FALSE)` equals `log(sigma_eps)`:

| point | measured TRUE − FALSE | `log σ_ε` | \|diff\| |
|---|---|---|---|
| A/P1 | `−1.20397280432593` | `−1.20397280432594` | `7.3e−15` |
| A/P2 | `−0.162518929497764` | `−0.162518929497775` | `1.0e−14` |
| A/P3 | `−2.99573227355404` | `−2.99573227355399` | `4.9e−14` |
| A/P4 | `+0.875468737353913` | `+0.875468737353900` | `1.3e−14` |
| B/Q1–Q3 | — | — | `1.3e−14`, `5.6e−16`, `4.9e−13` |

A run left at the default `TRUE` would be off by `1.20` at the fixture point.

---

## 5. Failure mode 4 — PARAMETER ORDER / SCALE

### 5.1 The transport is DERIVED, not searched

`stan-side-phylo.R` chose its mapping by **evaluating a 16-cell grid and keeping the cell that
matched** (`stan-value-phylo.json → mapping_used.how = "MEASURED against the fixture's stored
value"`). Its §7 discloses this. Arc 0's adversarial review flagged exactly that as weaker evidence.

The fence is lifted, so the transport below was **read off the source and fixed before any comparison
was made**, then held identical for every point and both datasets. Each row is a citation:

| # | Stan quantity | fixture block | rule | authority |
|---|---|---|---|---|
| 1 | `mu` | `b_fix` | identity; trait order `levels(df$trait)` | cpp:793 `eta_fix = X_fix * b_fix`; `X_fix` verified `== model.matrix(~ 0 + trait)` |
| 2 | `sigma_eps` | `log_sigma_eps` | `exp()` — an **SD** | cpp:2103 `Type sigma_eps = exp(log_sigma_eps);` |
| 3 | `Lambda` | `theta_rr_phy` | **identity — NO `exp()` on the diagonal**; packed diag-first, then strict lower triangle column-major, upper triangle **exactly 0** | cpp:1144–1163 (`lam_diag = theta_rr_phy.head(rank)`; `Lambda_phy(i,j) = lam_diag(j)`) — mirrors `theta_rr_B` at cpp:902–913 |
| 4 | `G[s,k]` | `g_phy` | `= g_phy[s,k]`; `PARAMETER_MATRIX(n_aug_phy × d_phy)` flattened column-major = **species-fastest** | cpp:694, cpp:2043 `g_phy(species_aug_id(o), k)` |
| 5 | `A` role | `Ainv_phy_rr` | `A` is the **covariance** of `g[,k]` (here a correlation, unit diagonal); the engine stores its **inverse** | R/fit-multi.R:3225; cpp:1172 `quad = g' Ainv g` |
| 6 | `A` argument | `Ainv_phy_rr`, `log_det_A_phy_rr` | the engine evaluates at **`A + 1e-8·I`**, not at the user's `A` | R/fit-multi.R:3224 `Aphy <- Aphy + diag(1e-8, nrow(Aphy))` |
| 7 | `log|A|` | `log_det_A_phy_rr` | `+log det(A + 1e-8 I)` — the **covariance's** log-det | R/fit-multi.R:3226; cpp:1170–1171 |
| 8 | species index | `species_aug_id` | `= species_id = match(species, levels(df$species)) − 1`, **factor-level order, NOT tree tip order**; identity map (dense path, no augmented internal nodes) | R/fit-multi.R:3223, :3227–3228 |

**Adjustment 3 — the transport above.** It coincides with the cell `stan-side-phylo.R` selected
(`identity` / `cov` / `sd` / `ridge = 1e-8`) — the right answer for the right reason rather than a
lucky draw of 1-in-16, and now *derived*, so the subsequent agreement is evidence about the density
rather than about the search.

### 5.2 Element-by-element alignment audit

Verified programmatically on both datasets (`gauss-reconcile-phylo*.json → audit*`), all **TRUE**:

- `species_id == as.integer(df$species) − 1`; `trait_id == as.integer(df$trait) − 1`
- `X_fix` is exactly the `0 + trait` indicator matrix
- `n_aug_phy == n_species` (8, 10) and `species_aug_id == species_id` — the **dense/legacy path**, no
  augmented internal nodes, confirming the tips-only sample space
- active flags: `use_phylo_rr = 1`; **every** other `use_*` flag `= 0`, including `use_phylo_diag`
- no ordinary blocks (`theta_rr_B`, `z_B`, `theta_diag_B`, `s_B`) present
- block counts: A `b_fix 3 · log_sigma_eps 1 · theta_rr_phy 3 · g_phy 8 = 15`;
  B `4 · 1 · 7 · 20 = 32`, with `7 = T·K − K(K−1)/2` (cpp:1148) — both match Stan's unconstrained count
- `A` symmetric to `0`, unit diagonal to `0` — a **correlation**, so the phylogenetic scale is carried
  entirely by `Lambda`, exactly as `z_B ~ N(0, I)` carries none in Arc 0

### 5.3 Out-of-sample confirmation — 7 points, 2 trees

The transport was frozen before any of these ran. Only **A/P1** was ever used by anyone to select
anything; **the other six are out-of-sample**, and the whole of dataset B is a tree no one had seen.

**Dataset A** — `rcoal(8)`, `T = 3`, `K = 1`, `N = 48`, tip order already sorted, balanced:

| point | TMB `fn(θ)` | Stan `log_prob` | \|diff\| | rel |
|---|---|---|---|---|
| A/P1 (published fixture θ) | `142.63339487378119` | `−142.63339487378124` | `5.68e−14` | `3.99e−16` |
| A/P2 (fresh) | `193.49128577711625` | `−193.49128577711627` | `2.84e−14` | `1.47e−16` |
| A/P3 (fresh, `σ_ε = 0.05`) | `3842.2289564410466` | `−3842.2289564410471` | `4.55e−13` | `1.18e−16` |
| A/P4 (fresh, large loadings) | `216.9667014044947` | `−216.9667014044947` | `0.00e+00` | `0.00e+00` |

**Dataset B** — a **second, larger tree** `rcoal(10)`, `T = 4`, **`K = 2`**, `N = 104`, 32 parameters,
with two properties dataset A cannot supply:

- **permuted tip order**: tip labels `t10,t3,t7,t1,t9,t2,t5,t8,t4,t6` versus factor levels
  `t1,t10,t2,…,t9`, so `A[levs, levs]` is a genuine permutation (audit:
  `Ainv` matches `solve(A[levs,levs] + rI)` to `1.78e−15`, but differs from `solve(A + rI)` in **tip**
  order by `18.47`);
- **ragged**: cells `(t3, y)` and `(t9, w)` removed entirely (2 of 40 cells carry **no data**), five
  further cells thinned to one replicate — exercising the per-row maps `t(i)`, `s(i)` rather than a
  rectangular grid.

| point | TMB `fn(θ)` | Stan `log_prob` | \|diff\| | rel |
|---|---|---|---|---|
| B/Q1 | `920.14050651840171` | `−920.14050651840193` | `2.27e−13` | `2.47e−16` |
| B/Q2 | `565.35045819544234` | `−565.35045819544234` | `0.00e+00` | `0.00e+00` |
| B/Q3 | `10657.511462049859` | `−10657.511462049857` | `1.82e−12` | `1.71e−16` |

### 5.4 Difference-of-differences (constant-free comparison)

Zero to machine precision, as §3 requires:

```
A:  (P2−P1) −2.84e−14    (P3−P1) +4.55e−13    (P4−P2) −2.84e−14
B:  (Q2−Q1) −2.27e−13    (Q3−Q1) −1.82e−12
```

---

## 6. The phylo-specific traps, each checked explicitly

Every control below **breaks exactly one derived rule** and reports the resulting shift in the Stan
log-density. All are 10–15 orders of magnitude above the `≤1.8e−12` agreement floor, so **the
comparison can fail, and therefore it is a check**.

| trap | control | shift at A/P1 (`K=1`) | shift at B/Q1 (`K=2`) |
|---|---|---|---|
| **`A` vs `A⁻¹`** | read `A` as a precision (`Cov = A⁻¹`) | `+11.808` | `+115.544` |
| **`log|A|` present?** | drop the `−K/2·log|A|` term | `−3.9306` | `−10.7492` |
| **`log|A|` sign** | use `log|A⁻¹|` instead of `log|A|` | `+7.8612` | `+21.4983` |
| **Kronecker ordering** | read `g_phy` **axis-fastest** instead of species-fastest | *degenerate* | `−36.723` |
| **loadings packing** | read `theta_rr_phy` row-major into the lower triangle | *degenerate* | `+26.194` |
| **triangular zeros** | set `Λ[1,2] = 0.85` (the packing forces 0) | *degenerate* | `−199.664` |
| **species alignment** | index `A` in **tree tip order** instead of factor-level order | *degenerate* | `+79.032` |
| **species alignment** | random permutation of `A`'s rows/cols | `−4.1385` | — |
| **variance transform** | read `log_sigma_eps` as a log-**variance** | `+63.971` | — |
| **loadings transform** | `exp()` the loadings diagonal (the doc's claim) | `−273.569` | `−1844.235` |
| **the ridge** | drop the engine's `1e-8` on `A` | `−1.93e−06` | `−2.86e−05` |

Reading the traps in the brief's own terms:

- **A versus A⁻¹.** The engine builds `Ainv_phy_rr = solve(A + 1e-8·I)` in R and evaluates
  `quad = g' Ainv g` (cpp:1172). The Stan side never inverts `A`: it takes `L_A = chol(A + 1e-8·I)'`
  as data and gets both the quadratic form and the log-determinant from the triangular solve inside
  `multi_normal_cholesky_lpdf`. **Two different numerical routes to the same mathematics.** Measured
  at A/P1: `quad` via the engine's `Ainv` = `40.5…`, via Cholesky = `40.5…`, differing by
  `1.42e−14`, i.e. `7.1e−15` in the log-density; the log-determinants differ by `2.66e−15`. So the
  route difference is **real but not the dominant residual** — the `5.68e−14` headline is ordinary
  floating-point summation order over 56 terms. (`A` is well conditioned here: `κ = 46.1` on A,
  `140.5` on B. On a badly conditioned tree the route difference would grow and should be re-measured
  rather than assumed.)
- **The log|A| term.** Present on **both** sides, and **parameter-free but not omissible**. Because
  it is constant in θ it survives a difference-of-differences check unnoticed; only the **pointwise**
  comparison catches it. Both sides carry it, so no adjustment is applied — but the two control rows
  above show what a miss would have cost (`3.93`/`10.75` to drop, `7.86`/`21.50` to sign-flip).
- **Kronecker ordering.** The engine never forms `ΛΛ' ⊗ A`; it evaluates the equivalent reduced-rank
  factorisation, `K` independent `N_S(0, A)` densities on the columns of `g_phy` with `Λ` carrying the
  trait covariance. The ordering question therefore reduces to how `PARAMETER_MATRIX(g_phy)`
  (`n_aug_phy × d_phy`) flattens: **column-major, species-fastest**. Degenerate at `K = 1`; **live and
  confirmed at `K = 2`** (axis-major reading is off by `36.72`).
- **Correlation or covariance, and any scaling.** `A = ape::vcv(tree, corr = TRUE)` is a
  **correlation** — `max|diag(A) − 1| = 0` on both trees. No further scaling is applied. The overall
  phylogenetic variance lives entirely in `Λ`; `Σ_phy = ΛΛ'` (cpp:1176–1177).
- **The phylo variance parameter's transform.** Under `unique = FALSE` there is **no free phylogenetic
  variance/scale parameter at all** — it would be exactly non-identified against `Λ`. So the transform
  question devolves onto (a) the **loadings**, which are **natural scale**, neither log-SD nor
  log-variance (§9.1), and (b) the **residual** `sigma_eps`, which **is** a log-**SD** (reading it as a
  log-variance costs `63.97`). The `Ψ_phy` tier that would introduce `log_sd_phy_diag` (cpp:1189+) is
  mapped off and untested here (§10.4).

---

## 7. Failure mode 5 — MODEL DIFFERENCE

**Excluded for the density.** After adjustments 1–3, the two implementations return the same number
at seven points spanning two trees, two ranks, two trait counts, a balanced and a ragged design, a
sorted and a permuted tip order, and residual SDs from `0.05` to `2.4`. There is no residual term, no
factor, and no offset.

The one place the two sides genuinely disagreed before adjustment — the `1e-8` ridge — is a
**data-preparation difference**, not a difference in the mathematics: both sides evaluate the same
`MVN(0, Σ)` density; they disagreed on what `Σ` is. That is reported in §8 rather than resolved by
editing either density.

---

## 8. Finding 1 — the engine evaluates at `A + 1e-8·I`, and says so nowhere

`R/fit-multi.R:3224`, dense/legacy path:

```r
Aphy <- phylo_vcv[levs, levs, drop = FALSE]
Aphy <- Aphy + diag(1e-8, nrow = nrow(Aphy))   # <- undocumented
Ainv_phy_rr      <- Matrix::Matrix(solve(Aphy), sparse = TRUE)
log_det_A_phy_rr <- as.numeric(determinant(Aphy, logarithm = TRUE)$modulus)
```

No roxygen comment, no design doc, no NEWS entry mentions it (`tmb-side-phylo.md` reached the same
conclusion independently). The user supplies `A`; the model fitted is the one with `A + 1e-8·I`.

**Why it is not merely cosmetic.** It is **not a constant offset** — it shifts both `log|A|` and the
quadratic form, so it survives a difference-of-differences check and cannot be absorbed into `k`. It
is small but **four to five orders of magnitude above the comparison floor**: any future oracle,
cross-package, or Julia-parity check that takes the user's `A` at face value will miss by roughly
`2e−6` … `3e−5` and have no way to attribute it.

**Bounded, not merely flagged.** The induced shift in the joint log-density, across tree sizes and a
deliberately near-degenerate radiation (`dev`-scratch probe, pure R, no TMB/Stan involved):

| tree | `min eig(A)` | `κ(A)` | `1e-8 / min eig` | Δ log-density |
|---|---|---|---|---|
| `rcoal(8)` | `1.14e−02` | `3.4e+02` | `8.8e−07` | `−6.6e−07` |
| `rcoal(25)` | `2.46e−03` | `6.3e+03` | `4.1e−06` | `−3.5e−06` |
| `rcoal(50)` | `4.71e−04` | `6.0e+04` | `2.1e−05` | `−1.4e−05` |
| `rcoal(100)` | `3.08e−05` | `2.1e+06` | `3.2e−04` | `+3.3e−06` |
| `rcoal(200)` | `2.34e−04` | `4.5e+05` | `4.3e−05` | `−2.4e−05` |
| 20 tips, recent radiation `ε = 1e−7` | `8.35e−05` | `1.1e+05` | `1.2e−04` | `+9.6e−05` |

So across `κ` up to `2 × 10⁶` the perturbation stays at `≤ 1e−4` in log-density — **negligible for
inference, material for verification**. Two caveats worth stating: the ridge is **additive and
absolute** (`1e-8`), so it is only safe because `ape::vcv(corr = TRUE)` has a unit diagonal; a user
passing a covariance on a much smaller scale would get a proportionally larger perturbation. And this
audit covers only the dense path — the `tree =` and sparse-`Ainv` paths add no ridge at all, so the
three routes do not agree with each other to better than this amount.

**Recommendation (maintainer's call, not mine):** document it, or make it relative
(`* mean(diag(Aphy))`), or drop it and let `solve()` fail loudly on a singular `A`. Any of the three
is better than an undocumented absolute constant.

---

## 9. Finding 2 and other observations

### 9.1 Arc 0's loadings-diagonal divergence extends to the phylogenetic block

`docs/design/04-random-effects.md` states the reduced-rank diagonal is held as `λ_kk = exp(λ̃_kk)`;
`model-spec-phylo.md` §7.2 faithfully repeats it, and `stan-side-phylo.R`'s spec-primary cell
therefore exponentiated. **The phylo block does not do this either** — cpp:1144–1163 mirrors
cpp:902–913 exactly: `lam_diag = theta_rr_phy.head(rank)`, no `exp`, no bound. The cost of believing
the doc is **`273.57` at `K = 1`** and **`1844.24` at `K = 2`**.

The lower-triangular **zeros** *are* implemented (cpp:1149–1150, control: breaking `Λ[1,2]` moves the
density by `199.66`), so — as in Arc 0 — the rotation half of the convention is real and the
positive-diagonal half is not. Arc 0 §11 already re-scoped the consequence: the residual
indeterminacy is a **discrete `2^K` sign mirror**, and everything the package gates
(`Σ_phy = ΛΛ'`, correlations) is sign-invariant. Nothing here changes that; it only shows the same
doc defect covers a second block.

### 9.2 The Stan side's mapping was measured; this one is derived — and they coincide

`stan-side-phylo.R` searched 16 cells (`lambda_diag × A_role × sigma_scale × ridge`) and found
**exactly one** inside `1e−8`. That is four binary degrees of freedom fitted to one number. The
derived transport reaches the same cell without looking at the fixture's value, and then holds at six
further points on a tree the search never saw. That upgrades the evidence from "a unique cell exists"
to "the derived encoding is correct".

Honest boundary, inherited verbatim from Arc 0 §10.3: **the mathematics was checked independently;
the encoding was read off the implementation.** No published source states another program's internal
storage layout, its ridge, or its species ordering. A fixed-parameter oracle can be independent about
the *density* and cannot be fully independent about the *encoding*.

### 9.3 The JSON transport is lossy — Arc 0 §6.2 recurs

`stan-side-phylo.md` reports `1.19e−12` at the fixture point; this driver reports `5.68e−14` at the
same point with the same two engines. The difference is entirely `jsonlite::write_json(digits = NA)`,
which is not bitwise exact. Both drivers here regenerate the data in-session and run both engines in
one R process, so no value crosses a JSON boundary before being compared. Reading
`tmb-fixture-phylo.rds` (already written, and exact) would fix the published route.

### 9.4 A gap in the fixture's own metadata

`tmb-fixture-phylo.rds$checks$perturbed_lambda_value` / `perturbed_g_value` record perturbed
log-densities but **not which perturbation produced them**, so `stan-side-phylo.md` §7 correctly
declined to use them as a second point. Storing the perturbed `theta` alongside the value would make
the fixture self-contained for a second-point check.

---

## 10. What this does NOT cover

1. **One family.** Gaussian identity only. Every other `family_id` branch is untested.
2. **One phylo path.** The **dense/legacy `vcv = <matrix>`** route only. The canonical
   **`tree =` augmented sparse** path (`n_aug_phy = 2·n_tips − 2`, internal-node scores as latent
   variables — a **different sample space**) and the `vcv = <sparseMatrix>` path are **untested**.
   This is the largest gap: the augmented path is the one users are steered toward, and it is the one
   where a tips-vs-nodes error would be invisible to this oracle.
3. **`unique = FALSE` only.** The `phylo_latent(..., unique = TRUE)` tier (`+ Ψ_phy ⊗ A`,
   `log_sd_phy_diag`/`g_phy_diag`, cpp:1189+) would add a third density term and a genuine
   variance-transform question; `use_phylo_diag = 0` throughout here.
4. **No other structure.** `phylo_slope`, `phylo_dep`, `phylo_scalar`, `animal_*`, kernel, spatial,
   `meta_V`, ordinary `latent()`/`unique()` alongside a phylo term — all mapped off.
5. **Joint density, not the marginal.** This compares the pre-Laplace joint at fixed `(θ, g)`. It says
   nothing about the Laplace approximation, the inner optimisation, gradients, `sdreport()`, or
   anything downstream. A correct joint density is necessary, not sufficient.
6. **No optimum involved.** All seven points are hand-chosen or seeded draws.
7. **Small and well conditioned.** `S ≤ 10`, `T ≤ 4`, `K ≤ 2`, `κ(A) ≤ 141`. The `A`-vs-`A⁻¹` route
   agreement (§6) is a statement about well-conditioned trees only.
8. **`d_phy ≥ 3`** and rank-deficiency edge cases (`K = T`, `K > T`) untested.

---

## 11. Every adjustment applied, with justification

| # | adjustment | applied to | justification | size at A/P1 |
|---|---|---|---|---|
| 1 | negate | TMB | `MakeADFun` returns an objective to minimise; `log_prob` returns a log-density | flips `+142.6334` → `−142.6334` |
| 2 | `adjust_transform = FALSE` | Stan | TMB adds no change-of-variables term; measured `= log σ_ε` at all 7 points | `+1.2040` |
| 3a | `mu = b_fix` (identity, trait-level order) | transport | cpp:793 | — |
| 3b | `sigma_eps = exp(log_sigma_eps)` | transport | cpp:2103 | vs. log-variance: `63.97` |
| 3c | `Lambda = theta_rr_phy` packed, identity, upper-tri 0 | transport | cpp:1144–1163 | vs. `exp`: `273.57` (`1844.24` at `K=2`); vs. row-major: `26.19`; vs. broken zero: `199.66` |
| 3d | `G[s,k] = g_phy[s,k]`, species-fastest | transport | cpp:694, cpp:2043 | degenerate at `K=1`; `36.72` at `K=2` |
| 3e | `Cov(g[,k]) = A` (covariance, not precision) | transport | R/fit-multi.R:3225, cpp:1172 | vs. precision: `11.81` |
| 3f | **`A → A + 1e-8·I`** | transport | R/fit-multi.R:3224 | `1.93e−06` (`2.86e−05` at B) |
| 3g | `log|A|` = `+log det(A + 1e-8 I)`, retained | transport | R/fit-multi.R:3226, cpp:1170 | drop: `3.93`; sign-flip: `7.86` |
| 3h | species index = factor-level order | transport | R/fit-multi.R:3223, :3227 | `4.14` (permuted); `79.03` (tip order, dataset B) |
| — | **constant terms** | — | **none needed**, `k = 0`; both sides keep all 56 `−½log(2π)` **and** the `−K/2·log|A|` | `0` |
| — | **model** | — | **none. Neither density was altered.** `gllvm_phylo.stan` mtime asserted unchanged by both drivers. | — |

---

## 12. Final difference

Headline (the published fixture point, A/P1):

```
−tmb_nll  = −142.63339487378119
stan_lp   = −142.63339487378124
|difference|        = 5.68e-14
relative difference = 3.99e-16
```

Worst case over all seven points:

```
max |difference|        = 1.82e-12   (B/Q3, on a value of magnitude 1.07e+04)
max relative difference = 3.99e-16   (A/P1)
```

Both are at the floor set by floating-point summation order over 56 (dataset A) and 124 (dataset B)
density terms. This is agreement to machine precision.

All figures are quoted from the drivers' `%.17g` output, not from the `.json` artifacts (§9.3).

---

## 13. Exact commands to reproduce

From the worktree root, `/Users/z3437171/local-scratch/worktrees/stan-phylo`:

```sh
# TMB side (writes tmb-fixture-phylo.rds / .json)
Rscript dev/stan-oracle-phylo/tmb-side-phylo.R
#   -> joint nll(theta) = 142.6333948738

# Stan side as originally written (16-cell grid over the transport)
Rscript dev/stan-oracle-phylo/stan-side-phylo.R
#   -> matched cell: identity / cov / sd / ridge=1e-8 = -142.633394873782
#   -> spec-primary (exp) cell = -416.2028346968   (wrong; see sec.9.1)

# THIS reconciliation, dataset A: transport derived a priori, 4 points,
# constants + Jacobian + A-vs-Ainv audits, 7 discriminating controls
Rscript dev/stan-oracle-phylo/gauss-reconcile-phylo.R
#   -> writes gauss-reconcile-phylo.{rds,json}     (~2 min)

# THIS reconciliation, dataset B: SECOND tree, T=4, K=2, permuted tips,
# ragged design, 3 points, 9 controls incl. Kronecker order + triangular zeros
Rscript dev/stan-oracle-phylo/gauss-reconcile-phylo-k2.R
#   -> writes gauss-reconcile-phylo-k2.{rds,json}  (~2 min)
```

Both drivers run TMB and Stan in a **single R session** with the data regenerated in-session, so no
value crosses a JSON boundary before comparison. Each asserts `gllvm_phylo.stan`'s mtime is unchanged
on exit. `src/gllvmTMB.so` and the cached `gllvm_phylo.rds` are assumed already built.

## 14. Artifacts

| path | what |
|---|---|
| `dev/stan-oracle-phylo/reconciliation-phylo.md` | this document |
| `dev/stan-oracle-phylo/gauss-reconcile-phylo.R` | driver: dataset A, `K = 1`, 4 points, all failure-mode audits |
| `dev/stan-oracle-phylo/gauss-reconcile-phylo.json` / `.rds` | its results: transport table, alignment audit, controls, route analysis |
| `dev/stan-oracle-phylo/gauss-reconcile-phylo-k2.R` | driver: dataset B, second tree, `T = 4`, `K = 2`, permuted tips, ragged, 3 points |
| `dev/stan-oracle-phylo/gauss-reconcile-phylo-k2.json` / `.rds` | its results |

Neither driver modifies `gllvm_phylo.stan`, `tmb-side-phylo.R`, or `stan-side-phylo.R`.

---

## 11. Adversarial review (three fresh contexts, told to refute)

### 11.1 Phylo substance -- **SOUND**. The phylogeny is genuinely under test.

This arc's specific way of being vacuous would be for `A` to cancel out, so that the two sides agree
while testing nothing phylogenetic. The verifier ran the control itself rather than trusting the
report: at the identical theta, swapping the real tree for a **star phylogeny** (`A = I`) shifts the
TMB objective `142.63339487 -> 128.64258320` (delta 13.99), and Stan independently reproduces
`-128.642583200032` against TMB's `128.642583200032`, agreeing to `2.84e-14` -- the same floor as
the real tree. **Both sides track a real change in `A` and still agree.**

Deliberately wrong phylogenetic assemblies are all detected, by margins 10-15 orders above the
`<= 1.8e-12` agreement floor:

| wrong assembly | shift in the density |
|---|---|
| `A` read as a precision instead of a covariance | `+11.808` |
| species-permuted `A` | `-4.139` |
| `log\|A\|` dropped | `-3.931` |
| `log\|A\|` sign-flipped | `+7.861` |
| Kronecker/axis order wrong (K=2) | `-36.72` |
| tip-order vs factor-level mismatch | `+79.03` |
| mismatched `Ainv` and `log\|A\|` (verifier's own construction) | `17.92` |

### 11.2 Scope -- **SOUND**

No coverage, calibration, or validation claim appears; `grep -i "coverage|calibrat|certif"` returns
zero hits. The pre-Laplace boundary is stated before any numbers were run. No validation-debt
register row moved.

### 11.3 Tautology -- **QUALIFIED. Read this; it is a correction to this document.**

Section 10 presents the eight-rule parameter transport as **derived a priori** and treats its
coincidence with the Stan side's measured grid as corroboration -- "the right answer for the right
reason... not a lucky draw". **The file timestamps do not support that framing.**

`stan-value-phylo.json` and `stan-side-phylo.R`, which contain the 16-cell *measured* grid search and
its published match (`identity/cov/sd/ridge=1e-8`), were finalised at **09:13:47**.
`gauss-reconcile-phylo.R`, which declares its transport "FIXED BEFORE any comparison is made"
(`:44`), was written at **09:19:57** -- six minutes later, with the correct answer already on disk.
The derivation was therefore authored **not blind** to the result it reproduces.

This is the same limitation Arc 0's tautology lens found -- the model formula is independent, the
parameter *transport* is not -- recurring here in a sharper form, because this time the document
claimed derivation rather than measurement. **The general limitation was disclosed (section 9.2,
"the encoding was read off the implementation"); the specific chronology was not.** It is recorded
here.

**What survives the criticism, verified independently by the same lens:**

- **Every source citation is objectively correct.** The verifier checked each against the file:
  `src/gllvmTMB.cpp:793`, `:2103`, `:1144-1163`, `:2043`, and `R/fit-multi.R:3223-3228` all match as
  quoted. The transport is right, whatever order it was written in.
- **Six of the seven points are genuine out-of-sample checks.** A/P2-P4 use hand-chosen new theta;
  B/Q1-Q3 use a **second tree**, permuted tips, a ragged design and `K = 2` -- structurally
  untouched by the grid search, which only ever ran on A/P1.
- Because a wrong rule moves the density 10-15 orders above the agreement floor, an overfitted or
  error-cancelling transport would have to survive six structurally different configurations by
  coincidence.

**Net:** the agreement is real and the transport is correct; what is *not* established is that the
transport was derived independently of the answer. Cite this arc with that qualification attached.
