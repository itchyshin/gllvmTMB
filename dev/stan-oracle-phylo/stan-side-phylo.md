# Stan side — phylogenetic reduced-rank latent GLLVM (Arc 1)

**Files.**

| role | path |
|---|---|
| Stan program | `dev/stan-oracle-phylo/gllvm_phylo.stan` |
| harness | `dev/stan-oracle-phylo/stan-side-phylo.R` |
| output | `dev/stan-oracle-phylo/stan-value-phylo.json` |
| model input (only) | `dev/stan-oracle-phylo/model-spec-phylo.md` |
| data input | `dev/stan-oracle-phylo/tmb-fixture-phylo.json` |

**Fence honoured.** The density was written from `model-spec-phylo.md` alone.
`dev/stan-oracle/gllvm_ordinary.stan` and `dev/stan-oracle/stan-side.R` were read as a
*harness* template (`log_prob` plumbing, `adjust_transform`, the grid-then-measure protocol),
not as a model. Nothing under `src/`, no TMB-building R file, and neither `tmb-side-phylo.md`
nor `dev/stan-oracle/tmb-side.R` was read. The fixture was read as **data** (dense `A`, its
Cholesky, `theta`, the observations, and the declared metadata).

Author role: Stan model author. Date: 2026-08-03.

---

## 1. The density implemented

Exactly the boxed expression of spec §8.1 — **two** terms, hierarchical, tips-only, all
normalising constants retained:

```
target += normal_lpdf(y | eta, sigma_eps);                            // (D), N = 48 terms
for (k in 1:K)
  target += multi_normal_cholesky_lpdf(col(G, k) | zeros_S, L_A);     // (G), K = 1 term
```

with `eta[i] = mu[tt[i]] + dot_product(Lambda[tt[i]], G[ss[i]])`.

Design choices forced by the spec, and honoured:

- **Hierarchical, not marginal** (§0). `G` is an explicit block; nothing is integrated out.
  The marginal `(ΛΛ') ⊗ A` form is singular at `K < T` and has no density.
- **`A` enters as data through its lower Cholesky `L_A`** (`cholesky_factor_cov[S]`). `A` is
  never inverted in the Stan program; both `g'A⁻¹g` and `log|A|` come out of the triangular
  solve inside `multi_normal_cholesky_lpdf`. The `-K/2·log|A|` term is therefore **kept**
  (§8.3), not dropped as a parameter-free constant.
- **`Lambda` is a plain unconstrained `matrix[n_t, K]`** — not `cholesky_factor_*`, not
  `positive_ordered`. §7.2 forbids encoding the rotation convention as a constrained Stan
  type, because that changes the measure.
- **No `psi` block, no phylogenetic scale parameter.** `unique = FALSE` is loadings-only
  (§3.3), and a free `σ²_phy` would be exactly non-identified against `Λ` (§4.3).
- **No priors, no Jacobians.** `_lpdf` form throughout; `log_prob(..., adjust_transform = FALSE)`.
- **Naming.** The spec's `T` is spelled `n_t` — `T` is reserved in the Stan language
  (truncation syntax `T[a, b]`).

---

## 2. The `log_prob` call

```r
sm    <- rstan::stan_model("gllvm_phylo.stan")     # rstan 2.32.7
fit0  <- rstan::sampling(sm, data = stan_data, chains = 0)   # shell only, no sampler runs
upars <- rstan::unconstrain_pars(fit0, pars)
lp    <- rstan::log_prob(fit0, upars, adjust_transform = FALSE, gradient = FALSE)
```

`chains = 0` builds a `stanfit` shell with no draws — enough for `unconstrain_pars()` /
`log_prob()`. **No sampler is ever run.** `adjust_transform = FALSE` suppresses Stan's
constraint-transform Jacobian for `sigma_eps > 0`, which the spec requires absent (§0).

`stan_data` carries `L_A`, so each `A` reading (covariance vs precision; ridge vs no ridge) is
a *different `stanfit` shell over the same compiled program* — the density code is byte-identical
across every grid cell.

---

## 3. Parameter order Stan expects

Declaration order in the `parameters` block *is* the order of the unconstrained vector.
**15 unconstrained parameters**, matching the fixture's 15 `theta` entries — but **in a
different order**, so `unconstrain_pars()` is fed a named list, never a raw vector.

| # | Stan block | dim | unconstrained length | scale on the unconstrained vector |
|---|---|---|---|---|
| 1 | `mu` | `vector[3]` | 3 | identity |
| 2 | `Lambda` | `matrix[3, 1]`, **column-major** | 3 | identity |
| 3 | `sigma_eps` | `real<lower=0>` | 1 | **`log(sigma_eps)`** |
| 4 | `G` | `matrix[8, 1]`, **column-major** | 8 | identity |

Fixture order, by contrast: `b_fix`(3) → `log_sigma_eps`(1) → `theta_rr_phy`(3) → `g_phy`(8).
The two orders agree only on the first block. **Blocks 2 and 3 are transposed between the two
conventions** — concatenating the fixture vector and handing it to `log_prob()` directly would
silently swap `Lambda[1,1]` with `log_sigma_eps` and produce a finite, wrong number.

---

## 4. Where the fixture's scale/layout differed from my declarations

Four axes were enumerated **before** measuring. The density is identical in all 16 cells; only
the mapping of the fixture's stored values onto natural-scale quantities differs.

### 4.1 `lambda_diag` — **the fixture DIFFERS from the spec's primary reading**

Spec §7.2 states `λ_kk > 0` is "held on the log scale internally", so the spec-derived primary
reading exponentiates the `K` diagonal entries of `theta_rr_phy`. **It does not match.**

- `exp` (spec primary): `Λ = (e^0.9, 0.5, −0.6)' = (2.4596, 0.5, −0.6)'` → **−416.2028346968**, off by **273.57**.
- `identity` (**matched**): `Λ = (0.9, 0.5, −0.6)'` → **−142.633394873782**, off by **1.19e-12**.

`theta_rr_phy` is on the **natural scale**. The positive-diagonal convention is either not
enforced by a log transform, or is enforced elsewhere; at `λ_11 = 0.9 > 0` the constraint
happens to hold anyway, so this fixture cannot distinguish "no transform" from "transform not
exercised". **This is the one substantive divergence between the spec's stated internal
parameterisation and the fixture.** It is a *storage-scale* fact (spec OPEN item 5), not a
density fact: the boxed density was not touched to obtain agreement.

### 4.2 `A_role` — **matches the spec**

`A` is the phylogenetic **covariance/correlation** of the latent scores (`Cov(g_·k) = A`), not
a precision. The `precision` reading (`Cov = A⁻¹`) misses by **11.81** at the otherwise-matched
mapping. Independent corroboration: `A` is symmetric with unit diagonal to `<1e-12`, and the
fixture's stored `A_chol_upper` reproduces `chol(A)` to **1.17e-15**.

### 4.3 `sigma_scale` — **matches the spec**

`log_sigma_eps = −1.20397280432594` is the log of an **SD**: `sigma_eps = 0.3`. Reading it as a
log-variance (`sd = 0.5477`) misses by **63.97**. Consistent with spec §2's warning that the
repo prose writes `N(a, b)` with `b` a variance while Stan's `normal_lpdf` takes an SD — here
the *stored* quantity is already an SD.

### 4.4 `ridge` — a data-preparation difference the fixture discloses

The fixture's own metadata declares `ridge_added_to_A = 1e-08`. The spec says nothing about
jitter (§5 only fixes the unit diagonal). A ridge shifts **both** `log|A|` and the quadratic
form, so it is not a constant offset.

- `A` as tabulated: **142.633396802112**, off by **1.93e-06**.
- `A + 1e-08·I`: **142.633394873782**, off by **1.19e-12**.

Corroborated independently of the log-density: the fixture's own `checks.log_det_A_phy_rr`
= `−7.861154398716260` equals `log|A + 1e-08 I|` to **1.69e-14** and `log|A|` only to **4.63e-07**.

**Provenance, stated plainly.** Axes 4.1–4.3 were declared before any number was computed.
Axis 4.4 was added *after* a first pass in which the `(identity, cov, sd)` cell missed by
1.93e-06 — a residual too large to be arithmetic and far too small to be a wrong density. It
was resolved by reading the fixture's **disclosed** `ridge_added_to_A` field (data, not source)
and confirmed by the independent `log|A|` check above. Both settings remain in the reported grid.

### 4.5 What was NOT ambiguous, and why

- **Tips-only vs augmented nodes (spec OPEN item 1, "the single item most likely to invalidate
  the comparison").** Settled by the fixture as data: `g_phy` has **8 = S·K** entries, and
  `checks.n_aug_phy_equals_n_species` / `checks.species_aug_id_is_identity` are both true. Spec
  §8.1 is the right sample space; the augmented §8.5 variant (`≈2S−1` per axis) is not this file.
- **`G` layout / Kronecker order (spec §4.3, OPEN item 5).** `K = 1`, so an `S × K` block of
  length 8 has no species-major/axis-major ambiguity, and the hierarchical form never forms a
  Kronecker product. Not live axes on this fixture — and therefore **not tested by it**.
- **Term count (spec §8.1 tripwire, OPEN item 7).** The fixture's `theta` has exactly
  `T + 1 + (TK − K(K−1)/2) + SK = 3 + 1 + 3 + 8 = 15` entries and **no** `theta_diag_phy` /
  `psi_phy` block. Two density terms, consistent with `unique = FALSE`. Asserted in the harness.
- **Species→row alignment (spec OPEN item 3).** `ss` is built with
  `match(data$species, meta$tip_order)`, so `A`'s rows are indexed in the fixture's declared tip
  order rather than by R's default factor sort. Here the two coincide (`sp1…sp8`), so this
  fixture does not discriminate a permutation error either.

---

## 5. Results

**Matched cell:** `lambda_diag = identity`, `A_role = cov`, `sigma_scale = sd`, `ridge = 1e-08`
— **exactly one** of 16 cells inside a 1e-8 tolerance.

| quantity | value |
|---|---|
| log-density (matched) | **−142.633394873782** |
| neg log-density | **142.633394873782** |
| fixture `joint_neg_log_density` | 142.633394873781 |
| absolute difference | **1.19e-12** |
| (D) data term | −118.984057417466 |
| (G) phylogenetic term | −23.649337456316 |
| log-density, spec-primary (`exp`) cell | −416.2028346968 |

**Constants (spec §8.4), all kept by the Stan program.** The target evidently keeps them too:
`−K/2·log|A| = +3.930577199358`, the 2π block `= −51.460557859...`, `C = −47.529980660...`.
Dropping either would shift the answer by those amounts, and neither shift is present.
**Spec OPEN item 8 is resolved: the comparison target retains the log-determinant and the
2π constants.**

---

## 6. Verification

| check | result |
|---|---|
| compiles (rstan 2.32.7, stanc3) | **yes** |
| `log_prob` finite | yes, −142.63 (and finite in all 16 cells) |
| repeatable (bit-identical on re-evaluation) | yes |
| changes under `mu[1] += 0.10` | Δ = −11.124253 |
| changes under `G[1,1] += 0.25` | Δ = −45.742044 |
| changes under `Lambda[1,1] += 0.15` | Δ = −39.458396 |
| changes under `sigma_eps *= 1.50` | Δ = +206.223865 |
| independent hand-computed density (§8.1 written out in R) | agrees to **1.14e-13** |

The hand check matters: it shows the Stan program reproduces the spec's algebra term by term,
not merely that it is self-consistent.

---

## 7. What this does and does not establish

**Does.** The joint density of spec §8.1 — hierarchical, tips-only, loadings-only, two terms,
all constants — reproduces the fixture's stored value to 1.19e-12 under a mapping identified
from a grid declared in advance. No mapping choice can rescue a wrong likelihood to 12
significant figures, so the agreement is informative about the density, not only about the
mapping.

**Does not.**
1. The `lambda_diag = identity` mapping was **measured, not derived** — the spec's stated
   internal log-scale parameterisation (§7.2) is *contradicted* by this fixture.
2. `K = 1`, `S = 8`, `T = 3`, balanced, one clade-pair tree, tip order already sorted. The
   fixture cannot discriminate: `Λ` packing order for `K ≥ 2`, `G` species-major vs axis-major,
   Kronecker order, species-permutation errors, unbalanced `N ≠ ST`, or the `K < T` gate.
3. It says nothing about the **augmented-node** representation (§8.5) — this fixture is
   tips-only, and the two are different sample spaces.
4. `unique = TRUE` (the `+ Ψ_phy ⊗ A` tier) is untested; it would add a third density term.
5. One fixture at one `θ`. The difference-of-differences protocol (§8.4) across two distinct
   `(θ, G)` was **not** run — the fixture's `checks.perturbed_*` values do not state which
   perturbation produced them, so they are not usable as a second point.
