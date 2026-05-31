# Design 69 -- Phase 3 PHYLOGENETIC missing-predictor design + borrow-map (gllvmTMB lane)

**Status: DESIGN / ANALYSIS ONLY (2026-05-31).** No engine code, no TMB fits.
This document elaborates the gllvmTMB lane for **Phase 3** of the shared
missing-data contract (Design 59): a SPECIES-level Gaussian missing predictor
`mi(x)` whose covariate model carries a phylogenetic structured prior,
`impute = list(x = x ~ 1 + phylo(1 | species, tree = tree))`. It is the
direct continuation of Design 67 section 2.1 (the Phase-3 bullet) and is grounded
in the drmTMB lane's ALREADY-IMPLEMENTED MD4 structured route, which is the
concrete porting source.

Part of GitHub issue #332 (gllvmTMB missing-data umbrella). Companion to
Design 67 (`docs/design/67-missing-predictor-design.md`, the umbrella
predictor borrow-map) and Design 59 (`docs/design/59-missing-data-layer.md`,
the authoritative shared contract -- NOT edited here).

> **Doc-number note.** Slots 66 (open capstone power-study PR #369) and 67
> (the missing-predictor umbrella) are taken; 68 is free and 69 is free.
> This Phase-3 elaboration takes **69** as requested. The number is cosmetic;
> the contract anchors remain Design 59 (shared contract) and Design 67
> (predictor umbrella).

> **Section-reference convention.** This document cites the gllvmTMB Design 59
> sections by their actual numbers: structured-confounding decision = Design 59
> section 3 (bullet 1); identifiability mechanics = Design 59 section 6; the
> Phase-3 verification gate = Design 59 section 9; the open decision on the
> joint field = Design 59 section 10 decision 3.

---

## 0. Scope, non-goals, position in the ladder

**In scope (design only):** the Phase-3 phylogenetic Gaussian covariate model;
the exact prior and its reuse of the EXISTING sparse `Ainv_phy_rr`; the
species-to-long level-mismatch broadcast; the identifiability stance
(independent-only in Phase 3); the phylo-signal gate; the function-by-function
drmTMB -> gllvmTMB borrow-map; the Phase-3 section 9 verification gates.

**Explicit non-goals (unchanged from Design 59 section 4 / Design 67 section 0):**
measurement error (observed `x` is exact); the Level-2 joint / shared phylo
field (`correlate_with="response"`, eigenvector-orthogonalized) -- **deferred to
Phase 4** (section 4 below; Design 59 section 10 decision 3); MNAR sensitivity,
bootstrap SE, and phylo-signal diagnostics as v1 API (they are section 9 gates,
not surface); non-Gaussian / categorical predictors (Phase 5); the discrete
finite-state SUM (Phase 5; Design 67 section 2.2). `engine="laplace"` only.

**Position in the conservative ladder (Design 67 section 0; binding):**

```
Phase 2a  Gaussian fixed, obs-level        (= drmTMB MD3a, mi_family==0 fixed)
Phase 2b  Gaussian + grouped intercept     (= drmTMB MD3b, has_mi_group)
Phase 2c  Gaussian group/species-level     (= drmTMB MD4 level-mismatch)
Phase 3   Gaussian + PHYLO structured prior (= drmTMB MD4 structured)  <-- THIS DOC
Phase 4   spatial/animal/relmat + multivariate borrowing + Level-2 joint field
Phase 5   non-Gaussian / categorical (finite-state SUM)
```

Phase 3 is the **flagship continuous slice**: it is the first time the
covariate prior carries biological covariance, and it is the slice where the
Design 59 section 3 confounding caution and the Design 59 section 9 phylo-signal
gate bite. It is still a CONTINUOUS Gaussian predictor, so it stays on the
Laplace-latent path (Design 67 section 2.1); it is NOT a finite-state SUM.

Phase 3 lands only with its slice issue and its section 9 tests written first
(tests-as-binding-contract, Design 59 sections 4b / 8). It builds directly on the
Phase 2c machinery (`x_full`, the species-level latent, the `mi_unit_id` /
`mi_species_id` broadcast); Phase 3 adds ONE thing to Phase 2c -- the
phylogenetic structured term on the covariate mean.

---

## 1. The structured covariate model (the prior + how it composes)

### 1.1 The model

`x` is a SPECIES-level trait with one value per species, some species missing.
Write `s = 1, ..., S` for species and let `x_species(s)` be the (possibly
missing) trait of species `s`. The Phase-3 covariate model is

```
x_species(s) = W(s, .) alpha  +  u_x(s)  +  eps_x(s)
u_x ~ N(0, sd_x^2 A)                     (the phylogenetic structured field)
eps_x(s) ~ N(0, sigma_x^2)               (species-level residual)
```

equivalently, marginalising the residual into the mean,

```
x_species(s) ~ N( eta_x(s), sigma_x^2 ),   eta_x(s) = W(s, .) alpha + u_x(s)
```

with the phylogenetic field placed as a structured INTERCEPT on `eta_x`. Here:

- `W` is the fully-observed covariate design for the covariate model (the RHS
  of the `impute` formula minus the `phylo()` term); `alpha` are its
  coefficients. For the canonical Phase-3 call
  `x ~ 1 + phylo(1 | species, tree = tree)`, `W` is the intercept column and
  `alpha` is the scalar covariate intercept.
- `u_x` is a per-species phylogenetic random intercept with covariance
  `sd_x^2 A`, `A` the phylogenetic correlation matrix implied by the tree.
- `sigma_x^2` is the species-level Gaussian residual variance of the covariate
  model (the `sigma_mi` of drmTMB `mi_family==0`).

**The prior on `u_x` is a Gaussian Markov random field with precision
`Q_A = A^{-1}`,** so

```
u_x ~ N(0, sd_x^2 A)  ==  GMRF(Q_A) scaled by sd_x,   Q_A = A^{-1}.
```

This is exactly the covariate prior named in Design 59 section 6 and Design 67
section 2.1: `x_species ~ N(alpha, sigma_x^2 A) = GMRF(Q_A)`. The phylogenetic
covariance enters ONLY through `u_x` (the structured intercept), never through
`sigma_x^2` (the residual), so the two are identifiable as a Pagel-style
partition (a phylogenetic component `sd_x^2 A` plus an i.i.d. residual
`sigma_x^2 I`), mirroring gllvmTMB's existing phylo / non-phylo variance split
(`docs/design/13-phylo-signal-partition.md`).

### 1.2 How `x_mis` (the Laplace latent) composes with the structured field

The missing entries of `x_species` are STILL Laplace latents -- the structured
field changes the PRIOR on the covariate mean, not the integration regime.
Concretely (continuation of Design 67 section 2.1, "Gaussian predictor -- Laplace
latent"):

- **Latent parameter:** `PARAMETER_VECTOR(x_mis)`, length = number of missing
  SPECIES-level values. (Not long rows; not all species -- only the missing
  ones.) `x_mis` joins the TMB `random` set and is Laplace-integrated.
- **Reconstruction (species level):**
  `x_full(s) = observed(s) ? x_obs(s) : x_mis(j(s))`, where `j(s)` maps a
  missing species to its slot in `x_mis`. This is identical in shape to
  Phase 2c; Phase 3 changes nothing here.
- **Covariate nll (species level):**
  `x_full(s) ~ N(eta_x(s), sigma_x^2)` summed over SPECIES, with
  `eta_x(s) = W(s,.) alpha + sd_x * g_x(s)` (the standardized-field form,
  section 3.2). This is one Gaussian density block evaluated at species level.
- **Structured-field nll:** the GMRF penalty on the phylogenetic field
  (`g_x` or `u_x`), evaluated through the sparse `Ainv_phy_rr` (section 2,
  section 3).

So there are now THREE latent vectors integrated by Laplace in a Phase-3 fit:
the response-side latents (`b`, the latent axes, the response phylo fields),
the covariate phylogenetic field (`g_x` / `u_x`), and the missing-covariate
latent (`x_mis`). All three are "just random effects" to TMB; the Laplace
integral is

```
L(theta) = INT p(y_obs | x_full, b, theta_y)
              * p(x_full | g_x, alpha, sigma_x, theta_x)   <- covariate model
              * p(g_x | sd_x, A)                            <- GMRF(Q_A) prior
              * p(b | theta_b)
           d x_mis  d g_x  d b
```

(the Design 59 section 6 observed-data likelihood, with `g_x` added as the
phylogenetic covariate field). The covariate field `g_x` and the
missing-covariate latent `x_mis` are DISTINCT: `g_x` is the smooth
phylogenetically-correlated mean surface (length = number of phylogenetic
nodes), `x_mis` are the actual missing trait values (length = number of missing
species), drawn around that surface with residual `sigma_x`. A missing species
`s` gets information from its phylogenetic neighbours through `g_x(s)` (the
mean), then `x_mis(j(s))` is its conditional mode given that mean and any
response-side evidence.

---

## 2. The `Ainv_phy_rr` reuse mechanism (no dense n^2 matrix)

This is the whole point of the slice: the GMRF precision `Q_A = A^{-1}` that
the covariate prior needs is the SAME sparse precision the response-side phylo
block already builds. gllvmTMB constructs it once and the covariate prior
points at it.

### 2.1 The existing sparse precision (verified)

In `src/gllvmTMB.cpp` the phylogenetic precision is already a DATA slot
(verified at the cited lines):

```cpp
// src/gllvmTMB.cpp:208-211
DATA_INTEGER(n_aug_phy);           // n_aug_phy >= n_species (== n_species in legacy path)
DATA_SPARSE_MATRIX(Ainv_phy_rr);   // n_aug_phy x n_aug_phy (sparse)
DATA_SCALAR(log_det_A_phy_rr);     // precomputed: log|A|
DATA_IVECTOR(species_aug_id);      // n_obs, 0-indexed row in g_phy
```

It is built on the R side in `R/fit-multi.R` (verified):

- Sparse tree path: `inv <- MCMCglmm::inverseA(phylo_tree)` ->
  `Ainv_phy_rr <- inv$Ainv` (already a sparse `dgCMatrix`),
  `log_det_A_phy_rr <- -sum(log(inv$dii))`, `n_aug_phy <- nrow(Ainv_phy_rr)`,
  and `species_aug_id` maps each observation's tip to its augmented row
  (`R/fit-multi.R:1340-1350`). `n_aug_phy = 2*n_tips - 1` (tips + internal
  nodes) -- a genuinely sparse augmented precision, NOT a dense `n^2` matrix.
- VCV / dense fallback paths (`R/fit-multi.R:1366-1386`) collapse to
  `n_aug_phy == n_species`, `species_aug_id == species_id`.
- All three are packed into `tmb_data` at `R/fit-multi.R:1686-1689`.

The existing phylo prior is evaluated through this sparse matrix as a quadratic
form with the precomputed log-det (verified, the `phylo_rr` block):

```cpp
// src/gllvmTMB.cpp:612-616
for (int k = 0; k < d_phy; k++) {
  vector<Type> g_k = g_phy.col(k);
  Type quad = (g_k.matrix().transpose() * Ainv_phy_rr * g_k.matrix())(0, 0);
  nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                + log_det_A_phy_rr + quad);
}
```

This is `-log N(g_k; 0, A)` evaluated through `A^{-1}` -- exactly the form the
covariate prior needs, with `A^{-1} = Q_A`.

### 2.2 The covariate prior points at the SAME slots

The Phase-3 covariate phylogenetic field reuses `Ainv_phy_rr`,
`log_det_A_phy_rr`, `n_aug_phy`, and the augmented index. No new sparse matrix,
no dense `n^2` matrix, no second `inverseA` call. The covariate model and the
response model share ONE tree and ONE precision (Design 59 section 4b TMB-hook
contract: "the covariate prior reuses the package's existing sparse
`Ainv`/`GMRF(Q)` machinery (no dense n^2)").

There is one builder subtlety worth stating: the EXISTING `Ainv_phy_rr` is
built from the tree given to the RESPONSE side. In Phase 3 the covariate model
supplies its OWN `phylo(1 | species, tree = tree)` term. The Phase-3 builder
MUST confirm the covariate tree is the same object/topology as the response
tree (or, if the response has no phylo term, build `Ainv_phy_rr` from the
covariate tree using the same `R/fit-multi.R:1340-1350` path). When they agree,
the covariate field simply reuses the response-side slots; when they differ,
that is a Phase-4 multi-tree concern and Phase 3 errors loudly (one tree per
fit in v1, matching the gllvmTMB phylo grammar's "one phylo term" guard at
`R/fit-multi.R:547-550`). See open question Q3.

### 2.3 The drmTMB analogue (what is being ported)

drmTMB's MD4 structured route does the identical thing with a GENERIC structured
precision `Q_mi_struct` (verified DATA slots):

```cpp
// src/drmTMB.cpp:32-36
DATA_INTEGER(has_mi_struct);
DATA_IVECTOR(mi_struct_index);
DATA_VECTOR(mi_struct_value);
DATA_SPARSE_MATRIX(Q_mi_struct);
DATA_SCALAR(log_det_Q_mi_struct);
```

For the phylo case drmTMB fills `Q_mi_struct` from
`build_structured_mu_structure()` -> `build_phylo_mu_structure()`, which calls
`drm_phylo_augmented_precision(tree, species)` and returns
`precision$precision` (the sparse `Q`) and `precision$log_det_precision`
(consumed in `drm_build_gaussian_mi_structured_intercept`,
`R/missing-data.R:1897-1898`). gllvmTMB's `Ainv_phy_rr` /
`log_det_A_phy_rr` ARE the `Q_mi_struct` / `log_det_Q_mi_struct` inputs that
block needs -- already built, already sparse. The borrow is therefore
"point the covariate prior at the existing slots" rather than "build a new
precision".

---

## 3. The structured-field nll: which parametrization (a real design choice)

drmTMB and gllvmTMB write the SAME `N(0, sd^2 A)` prior in two mathematically
equivalent but textually different parametrizations. The borrow-map must NOT
copy drmTMB's text verbatim; it must follow gllvmTMB's HOUSE parametrization.

### 3.1 drmTMB's unstandardized form (the source)

drmTMB folds `sd` into the penalty and enters the field UNSCALED
(verified `has_mi_struct` block, `src/drmTMB.cpp:776-793`):

```cpp
// src/drmTMB.cpp:778-781   field enters eta UNSCALED
for (int i = 0; i < mi_eta.size(); ++i) {
  mi_eta(i) += mi_struct_value(i) * u_mi_struct(mi_struct_index(i));
}
// src/drmTMB.cpp:782-792   penalty carries sd via 2n*log_sd and exp(-2 log_sd)
vector<Type> Q_u_mi_struct = Q_mi_struct * u_mi_struct;
Type quadratic_mi_struct = 0;
for (int j = 0; j < u_mi_struct.size(); ++j)
  quadratic_mi_struct += u_mi_struct(j) * Q_u_mi_struct(j);
nll += 0.5 * (
  Type(u_mi_struct.size()) * log(2.0 * M_PI) +
  2.0 * Type(u_mi_struct.size()) * log_sd_mi_struct(0) -
  log_det_Q_mi_struct +
  exp(-2.0 * log_sd_mi_struct(0)) * quadratic_mi_struct );
```

i.e. `u_mi_struct ~ N(0, sd^2 Q^{-1})` written directly (note the `2n*log_sd`
normalising term and the `exp(-2 log_sd)` on the quadratic; and `Q^{-1} = A`,
so `-log_det_Q = +log_det_A`).

### 3.2 gllvmTMB's standardized form (the house style -- follow this)

gllvmTMB's existing per-trait phylogenetic intercept block (`phylo_diag`) is the
closest in-house analogue to a structured covariate intercept. It draws a
STANDARDIZED unit-variance field through `Ainv_phy_rr` and applies `sd` when the
field ENTERS eta (verified):

```cpp
// src/gllvmTMB.cpp:625-630 (comment) and :644-647 (penalty)
//   eta(o) += exp(log_sd_phy_diag(t)) * g_phy_diag(species_aug_id(o), t)
//   "equivalent to drawing a per-trait phylogenetic intercept u_t ~ N(0, sd^2 A)"
//   -log p(g_t) = 0.5 * (n_aug_phy*log(2pi) + log_det_A + g_t' Ainv g_t)
vector<Type> g_t = g_phy_diag.col(t);
Type quad = (g_t.matrix().transpose() * Ainv_phy_rr * g_t.matrix())(0, 0);
nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI) + log_det_A_phy_rr + quad);
```

The two are identical distributions (`u = sd * g`, `g ~ N(0, A)` gives
`u ~ N(0, sd^2 A)`); the gllvmTMB form keeps the penalty constant in `sd` and
scales the field into the mean, the drmTMB form scales the penalty and leaves
the field raw.

**Decision (binding for the borrow-map):** the Phase-3 covariate field uses
gllvmTMB's STANDARDIZED-field convention, reusing the `phylo_diag` penalty
shape exactly:

```
g_x ~ N(0, A) via Ainv_phy_rr        (unit-variance GMRF penalty, :644-647 shape)
eta_x(s) += sd_x * g_x(node(s))      (scale into the covariate mean)
```

Reasons: (i) it reuses the EXACT penalty already in gllvmTMB (one fewer place
for a sign / log-det error); (ii) it keeps `sd_x` interpretable as the
phylogenetic SD of the covariate, parallel to `sd_phy_diag` for the response;
(iii) the standardized field plays nicely with the eigenvector
orthogonalization that Phase 4 will add (the orthogonalization operates on the
field, not the penalty). The drmTMB unstandardized penalty is ported in SPIRIT
(same prior, same sparse `Q`, same log-det) but re-expressed in gllvmTMB's
parametrization. This is flagged as open question Q1.

### 3.3 The species-to-node index

`g_x` lives on the augmented phylogeny (length `n_aug_phy`). The covariate model
is at SPECIES level, so `eta_x(s)` reads `g_x` at the augmented node of species
`s` via the same `species_aug_id`-style map the response side uses
(`src/gllvmTMB.cpp:211`, `:626`). Because the covariate model is per-species
(not per-long-row), the index is a species->node map (call it
`mi_species_node_id`), simpler than the response side's per-observation
`species_aug_id`. The residual `eps_x` and the missing latents `x_mis` are at
species level too, so the whole covariate block is species-indexed; the
broadcast to long rows happens AFTER, on `x_full` (section 4 / Design 67
section 2).

---

## 4. The level-mismatch: species-level `x` broadcast to long rows

This is inherited from Phase 2c (Design 67 section 2.0 / section 2.1, the
`mi_unit_id` mechanism). Phase 3 does not change the broadcast; it is restated
here because correctness of the phylogenetic borrowing depends on it.

### 4.1 The three levels and the two indices

```
SPECIES level     x_full(s), eta_x(s), g_x, u_x, x_mis(j)      (one row per species)
        |  mi_species_id: species(s) -> ... (which species each long row belongs to)
LONG row level    eta(o) for o = 1..n_obs, each o is one (unit, trait) cell
        |  mi_unit_id / mi_species_id(o): long row o -> its species
```

gllvmTMB's likelihood is stacked-long: one loop over `(unit, trait)` cells
(Design 67 section 2.0; `src/gllvmTMB.cpp` family loop). A species-level missing
`x` appears in EVERY long row whose species is `s`, ACROSS ALL TRAITS. So:

- there is ONE latent `x_mis(j)` per missing SPECIES, shared by all of that
  species' long rows (Design 67 section 2.0: "the Gaussian latent `x_mis(u)` is
  shared by all of unit `u`'s trait rows -- one latent per missing unit-value,
  not per long row");
- the response-side delta correction is broadcast through the long->species
  index. Following the drmTMB delta form (`src/drmTMB.cpp:806`,
  `mu(i) += beta_mu(mi_col)*(mi_x_full(i) - X_mu(i, mi_col))`), gllvmTMB applies,
  for each long row `o`:

  ```
  eta(o) += b_fix(mi_col) * ( x_full(mi_species_id(o)) - X_fix(o, mi_col) )
  ```

  The delta form lets the existing `X_fix %*% b_fix` term stand and corrects
  only the missing entries (Design 67 section 2.1).

### 4.2 One observed value per species (the broadcast guard)

A species-level covariate must have exactly ONE value per species (observed or
missing), the same value broadcast to all that species' rows and all traits.
The builder validates this (Design 59 section 7 Phase 2c: "validate one observed
value per group"; drmTMB MD4 analogue). Concretely the Phase-3 builder checks
that, within each species, the observed `x` values are constant (no
species with two different observed `x`), and records the per-species
observed/missing status. A species with NO observed value is a missing species
-> gets an `x_mis` slot; a species with an observed value uses `x_obs`. This is
the level-mismatch validation; it is verified by the section 9 broadcast-correctness
gate (section 6).

### 4.3 Why the broadcast is correct under phylogeny

The phylogenetic borrowing operates at SPECIES level (`g_x`, `eta_x`,
`sigma_x`), which is exactly the level at which `x` is defined. The broadcast to
long rows is downstream of the covariate model and does not touch the
phylogenetic prior. So the species-level GMRF and the long-row broadcast are
ORTHOGONAL operations: the GMRF decides the species-level conditional mode of a
missing `x`; the broadcast feeds that one value into every (species, trait)
cell. There is no double-counting of the phylogenetic prior across traits
because the prior is evaluated once per species, not once per long row -- the
same discipline Design 67 section 2.3 enforces for the discrete SUM, here trivial
because the Gaussian latent is genuinely shared.

---

## 5. Identifiability (LOAD-BEARING): independent-only in Phase 3

### 5.1 The decision

**Phase 3 ships the Level-1 INDEPENDENT covariate field only.** The covariate
phylogenetic field `g_x` is its OWN field, drawn from `N(0, sd_x^2 A)` with its
OWN `sd_x`, and is NOT shared with -- and NOT correlated with -- any response-side
phylogenetic field (`g_phy`, `g_phy_diag`, the response `phylo_latent` /
`phylo_unique` fields). They reuse the same PRECISION `Ainv_phy_rr` (same tree,
section 2), but they are SEPARATE latent vectors with separate variances. The
shared / joint field -- `correlate_with="response"`, with the
eigenvector-orthogonalized ("phylo+") form -- is **deferred to Phase 4**
(Design 59 section 10 decision 3; Design 67 section 5 open question 3; Design 67
section 2.1 "flag for the Phase 4 identifiability gate").

This matches the locked Design 59 default verbatim (Design 59 section 4,
"Conservative default / ambitious opt-in: Level-1 independent default; Level-2
joint field opt-in via `correlate_with = "response"` (eigenvector-
orthogonalized)") and the Phase 3 rollout line (Design 59 section 7 Phase 3:
"Level-1 independent default").

### 5.2 Why the confounding is the real risk (Design 59 section 3)

Design 59 section 3 (bullet 1) is explicit: "Structured confounding is the real
risk of the ambitious joint model. When the covariate model and response share
the SAME structured field, `beta_x` is confounded (Dupont, Marques & Kneib 2023,
the established spatial result; Wang, Edge, Schraiber & Pennell 2025 preprint,
the phylogenetic analogue, treat as indicative). Consequence: Level-1
independent covariate model is the default; the Level-2 joint field is opt-in,
with the literature's eigenvector-fixed-effect ('phylo+/spatial+')
orthogonalization as its recommended form." Design 59 section 6 restates the
remedy: "default independent fields identify `beta_x`; `correlate_with='response'`
adds eigenvector fixed effects to avoid confounding."

The mechanism: if the covariate `x` and the response `y` are both driven by the
SAME latent phylogenetic field, then the regression slope `b_fix(mi_col)` of `y`
on `x` cannot be separated from the shared field's contribution -- the field
explains covariation that the slope would otherwise claim, and `beta_x` is
biased (spatial-confounding result, transported to phylogeny). The independent
default avoids this by giving the covariate its OWN field: `x`'s phylogenetic
structure informs the IMPUTATION of missing `x` (the legitimate borrowing), but
does not leak into the `y`-on-`x` slope.

### 5.3 Why the confounding is SHARPER in the multivariate engine

This is the gllvmTMB-specific escalation (Design 67 section 2.1 / section 5
open question 3). In drmTMB the shared field would feed the covariate model and
ONE (or two) response equations. In gllvmTMB the shared phylogenetic field
feeds the covariate model AND **every trait's eta simultaneously** (the
response side already has `phylo_latent` / `phylo_unique` / `phylo_rr` fields
shared across traits, `src/gllvmTMB.cpp:584-647`). A `correlate_with="response"`
joint field would therefore be a single phylogenetic field doing triple duty:
(i) the covariate mean, (ii) the cross-trait latent phylogenetic covariance,
(iii) the per-trait phylogenetic intercepts. The confounding surface is
higher-dimensional and the identifiability harder to reason about than in the
uni-/bivariate drmTMB case. Shipping the independent field first lets Phase 3
recover `beta_x` cleanly and defers the joint-field identifiability analysis
(reproduce Dupont 2023 / Wang 2025-preprint bias + eigenvector remedy on a
multivariate sim) to the Phase 4 identifiability gate (Design 59 section 9
"Identifiability check (Phase 4)").

### 5.4 What "independent" means operationally in Phase 3

- `g_x` is a NEW `PARAMETER_VECTOR` / matrix column, separate from `g_phy` and
  `g_phy_diag`. It has its OWN `log_sd_x`. No cross-covariance parameter
  between `g_x` and any response field is declared.
- The covariate model may STILL contain fixed covariates `W` that overlap with
  response covariates `z` -- that overlap is fine and is not the confounding at
  issue; the confounding is specifically the SHARED structured (phylogenetic)
  field, which Phase 3 does not build.
- The Phase-3 section 9 independence gate (section 6) asserts that the covariate
  field is statistically independent of the response phylo field: perturbing the
  response phylo configuration must not move the covariate field's estimate
  beyond Monte-Carlo noise, and vice versa.

---

## 6. The phylo-signal gate (Design 59 section 9)

### 6.1 The claim and its evidence

Phylogenetic imputation HELPS when the phylogenetic signal in `x` is strong and
DEGRADES toward the independent (no-borrowing) case when the signal is weak;
forcing a phylogenetic prior on a phylogenetically-unstructured trait ADDS noise
rather than information. This is the Design 59 section 3 caution ("Phylogenetic
imputation must be conservative + diagnosed ... Phylo imputation adds noise when
signal is weak") and the Design 59 section 9 gate ("Phylo recovery (Phase 3):
high vs low phylogenetic signal -- borrowing helps when strong, degrades to
approximately independent when weak ...; the phylo-signal gate flags the weak
case").

Evidence base (Design 59 section 11; the md-evidence agent is sourcing the
precise pages -- reference the claim, not yet a page number):

- **Penone et al. (2014)** *Methods Ecol. Evol.* 5:961-970 -- phylogenetic
  imputation accuracy depends on phylogenetic signal; gains shrink as signal
  weakens.
- **Molina-Venegas (2024)** *Methods Ecol. Evol.* -- cautions on the
  reliability of phylogenetic trait imputation under weak/uncertain signal.
- **Goolsby, Bruggeman & Ane (2017)** *Methods Ecol. Evol.* 8:22-27
  (`Rphylopars`) -- phylogenetic-covariance-based trait imputation; the
  reference implementation whose behaviour the strong-signal case should
  approach. (Also Johnson, Fitzpatrick, Pearse & Revell 2021, *Glob. Ecol.
  Biogeogr.* 30:51-62, on the same signal-dependence.)

The frequentist mechanism is transparent in our model: `sd_x` (the phylogenetic
SD of the covariate) and `sigma_x` (the residual) compete to explain
species-level variance in `x`. Strong signal -> `sd_x` large relative to
`sigma_x` -> the GMRF prior pulls a missing species toward its phylogenetic
neighbours (informative borrowing). Weak signal -> `sd_x` -> 0 -> the
phylogenetic field flattens and the covariate model collapses to the
independent Gaussian of Phase 2a/2c (the missing `x` is imputed from the fixed
part `W alpha` plus residual, no borrowing). So the model AUTOMATICALLY degrades
to independence when signal is weak -- there is no separate code path; the
degradation is the estimated `sd_x` going to the boundary. The gate's job is to
(a) verify this happens in simulation and (b) WARN the user when it does, so a
weak-signal imputation is not mistaken for an informative one.

### 6.2 The recovery test must vary signal (high vs low)

The Phase-3 recovery simulation (Curie; Design 59 section 9 "Recovery sims")
must be run at (at least) TWO phylogenetic-signal regimes on the SAME tree and
the SAME missingness pattern:

- **High signal:** simulate `x_species` with large `sd_x` relative to
  `sigma_x` (e.g. Pagel's lambda near 1 / Brownian). Expectation: the
  phylogenetic covariate model recovers missing `x` with SMALLER error and
  TIGHTER SE than an independent (Phase-2c, no-phylo) covariate model on the
  same data -- borrowing helps. `sd_x` recovered well away from zero.
- **Low signal:** simulate `x_species` with `sd_x` near zero (trait
  phylogenetically unstructured, lambda near 0). Expectation: the phylogenetic
  covariate model performs NO WORSE than the independent model (it degrades to
  approximately independent -- recovered `sd_x` near the boundary, missing-`x`
  recovery comparable to Phase 2c), and does NOT inject spurious phylogenetic
  structure. This is the "degrades to approximately independent when weak"
  half of the Design 59 section 9 gate.

Both regimes also check the standard recovery targets (Design 59 section 9):
recover the analysis-model `beta` (including `b_fix(mi_col)`, the `y`-on-`x`
slope), the covariate coefficients `alpha`, `sd_x`, `sigma_x`, and the
missing-`x` EBLUP within band with SE/interval coverage at nominal level.

### 6.3 The diagnostic must flag weak signal

The phylo-signal gate (Design 59 section 9, "the phylo-signal gate flags the
weak case"; a verification gate, NOT v1 surface -- Design 59 section 4) computes
a phylogenetic-signal / reliability statistic for the covariate model and warns
when it is weak. Reuse, do not reinvent (Design 59 section 1b): pigauto's
`phylo_signal.R` / `pagel_lambda.R` are the existing signal tools; the gate
estimates the covariate's phylogenetic signal (e.g. an effective Pagel lambda
from `sd_x^2 / (sd_x^2 + sigma_x^2)`, or Blomberg's K via the pigauto helper)
and, below a documented threshold, emits an EBLUP-language warning of the form
"phylogenetic signal in `x` is weak (lambda_hat approximately L); the
phylogenetic covariate model is approximately equivalent to an independent model
and the borrowed imputation should not be over-interpreted." The warning is
informational; it does not change the fit. It pairs with the Design 59 section 3
circularity caution (do not feed a borrowed imputation back into a downstream
phylogenetic analysis as if observed). This diagnostic is the Phase-3 instance
of the general "weak-identifiability warning" family (Design 67 section 2.3).

---

## 7. Borrow-map: drmTMB MD4 structured -> gllvmTMB Phase 3 (PORT/ADAPT/NEW)

Legend (Design 67 section 3): **PORT** = lift with minimal change; **ADAPT** =
same idea, real rework for species-level / stacked-long / multivariate;
**NEW** = no drmTMB precedent. Targets use gllvmTMB names; Phase 3 ADDS the
structured term to the Phase 2c builders rather than introducing a parallel
stack.

### 7.1 R surface / parsing

| drmTMB (`R/missing-data.R`) | gllvmTMB target | port? | difference |
|---|---|---|---|
| `drm_extract_impute_structured_intercept()` (`:613-672`): pull `phylo/spatial/animal/relmat` marker from the `impute` formula; intercept-only guard; one-structured-term guard | `gll_extract_impute_phylo_intercept()` | ADAPT | gllvmTMB reuses its OWN phylo grammar tokens (`phylo(1|species, tree=)` / `phylo_unique`), not drmTMB's marker extractors; same guards (intercept-only, one structured term). Phase 3 restricts to `phylo()` only (spatial/animal/relmat are Phase 4). |
| `drm_standardize_impute_model()` / `drm_validate_single_impute_formula()` | reuse Phase 2a ports | PORT | unchanged from Phase 2a (LHS=var, name match, no nested `mi`, no `.`) |
| MD4 boundary guards (`test:202-257`): reject non-intercept structured slope (`relmat(1+z|line)`); reject structured + extra `(1|group)` ("cannot combine"); reject `phylo_interaction` ("does not support"); reject structured grouping var with NA / outside levels ("outside explicit") | port the guard SET to gllvmTMB phylo grammar | ADAPT | same boundary semantics; gllvmTMB messages reference `phylo()` and its own keyword validator. `phylo_interaction` is the cross-lineage co-evolution kernel (Design 65) -- explicitly out of Phase 3 scope. |

### 7.2 R model-build

| drmTMB | gllvmTMB target | port? | difference |
|---|---|---|---|
| `drm_build_gaussian_mi_structured_intercept()` (`:1854-1900`): build the structured field, extract `precision` + `log_det_precision`, scalar/intercept-only checks | `gll_build_gaussian_mi_phylo_intercept()` | ADAPT | does NOT build a new precision -- POINTS the covariate field at the existing `Ainv_phy_rr` / `log_det_A_phy_rr` (section 2.2). Confirms covariate tree == response tree (or builds `Ainv_phy_rr` from the covariate tree via `R/fit-multi.R:1340-1350`). Returns `mi_species_node_id`, `n_aug_phy`, the standardized-field flag. |
| `build_structured_mu_structure()` -> `build_phylo_mu_structure()` -> `drm_phylo_augmented_precision()` (`R/drmTMB.R:6190-6290`) | reuse gllvmTMB's existing `Ainv_phy_rr` builder (`R/fit-multi.R:1313-1386`) | ADAPT | gllvmTMB already has the augmented-precision builder; the covariate model calls the SAME path. No second `MCMCglmm::inverseA`. |
| `drm_build_gaussian_mi_random_intercept()` (2b, `:1816-1852`) | (already ported in Phase 2b) | -- | Phase 3 does not add a grouped intercept; the phylo intercept REPLACES it for this slice. |
| `drm_build_gaussian_missing_predictor_model()` Gaussian branch (`:811`) | `gll_build_gaussian_mi_model()` (Phase 2a/2c) + phylo hook | ADAPT | Phase 3 = Phase 2c builder (species-level `x_full`, `mi_species_id`) PLUS the phylo structured hook from `gll_build_gaussian_mi_phylo_intercept()`. |
| `drm_missing_predictor_metadata()` (`:1902`): populate `structured$enabled/type/group/levels/n_re` | `gll_mi_metadata()` (extend) | PORT (extend) | add `structured$type = "phylo"`, `group = species`, `n_re = n_aug_phy`, `levels` = tip labels; mirrors the MD4 metadata block (`:1928-1935`). Feeds `fit$missing_data$predictors$x$structured` (Design 59 section 4b). |
| `drm_tmb_missing_predictor_data()` | `gll_tmb_mi_data()` (extend) | ADAPT | pack `has_mi_struct`-analogue flag, `mi_species_node_id`, and -- crucially -- DO NOT add a second sparse matrix; reference the existing `Ainv_phy_rr` slot. |

### 7.3 C++ likelihood (`src/drmTMB.cpp` -> `src/gllvmTMB.cpp`)

| drmTMB C++ | gllvmTMB target | port? | difference |
|---|---|---|---|
| DATA `Q_mi_struct`, `log_det_Q_mi_struct`, `mi_struct_index`, `mi_struct_value`, `has_mi_struct` (`:32-36`) | REUSE existing `Ainv_phy_rr` / `log_det_A_phy_rr` / `n_aug_phy` (`:208-211`) + add `has_mi_phylo`, `mi_species_node_id` | ADAPT | NO new sparse-matrix DATA slot -- the precision already exists. Only a flag and a species->node index are new. |
| PARAMETER `u_mi_struct`, `log_sd_mi_struct` (`:149-150`) | `g_x` (or `u_x`), `log_sd_x` | ADAPT | new latent field + its log-SD; joins `random`. Named to parallel `g_phy_diag` / `log_sd_phy_diag`. |
| `has_mi_struct` GMRF penalty + field-into-mean (`:776-793`) | NEW block modelled on `phylo_diag` (`:644-647`) | ADAPT | use gllvmTMB's STANDARDIZED-field penalty shape (section 3.2): `g_x ~ N(0,A)` unit-variance penalty through `Ainv_phy_rr`, then `eta_x(s) += sd_x * g_x(node(s))`. Re-express drmTMB's unstandardized form into gllvmTMB's convention. |
| `mi_family==0` Gaussian latent + `x_full` + covariate nll (`:794-804`) | gllvmTMB Gaussian block (Phase 2a/2c) | ADAPT | `x_full` and the covariate nll are SPECIES-level (summed over species, not long rows). `eta_x(s)` now includes `sd_x * g_x(node(s))`. |
| response delta correction `mu(i) += beta(mi_col)*(mi_x_full(i)-X_mu(i,mi_col))` (`:806`) | `eta(o) += b_fix(mi_col)*(x_full(mi_species_id(o)) - X_fix(o,mi_col))` | ADAPT | broadcast through `mi_species_id` to long rows (section 4); the existing `X_fix %*% b_fix` term stands. |
| REPORT/ADREPORT `u_mi_struct`, `log_sd_mi_struct`, `sd_mi_struct` (`:820-825`) | REPORT/ADREPORT `g_x`, `log_sd_x`, `sd_x` | PORT | EBLUP outputs + the phylogenetic SD of the covariate. |

Note: the discrete-row response gate (drmTMB `:1059-1066`; Design 67 section 2.2)
is NOT relevant to Phase 3 -- it is a Phase 5 (discrete SUM) concern. Phase 3 is
Gaussian-Laplace and adds its covariate density without gating off the response
term.

### 7.4 Extractors / output

| drmTMB | gllvmTMB target | port? | difference |
|---|---|---|---|
| `imputed.drmTMB` + `drm_imputed_missing_predictor_se()` (Gaussian: `sdr$diag.cov.random` at `x_miss`) | `imputed.gllvmTMB` (Phase 2a port) | PORT | identical SE logic; `x_mis` SE from the joint Hessian block. EBLUP language only. Phase 3 adds no new SE path. |
| MD4 `structured` metadata in `fit$missing_data$predictors$x` | same slot in gllvmTMB | PORT | already covered by `gll_mi_metadata()` extension (7.2). |
| (no drmTMB analogue) phylo-signal diagnostic / warning | NEW gate helper (section 6.3) | NEW | reuse pigauto `phylo_signal.R` / `pagel_lambda.R`; verification gate, not v1 surface. |

### 7.5 Concrete Phase-3 porting order (do AFTER Phase 2c lands)

1. `gll_extract_impute_phylo_intercept()` -- detect `phylo()` in the `impute`
   formula; port the MD4 intercept-only / one-structured-term / boundary guards
   (7.1) to the gllvmTMB phylo grammar (Boole confirms the parser slot,
   Design 59 section 8).
2. `gll_build_gaussian_mi_phylo_intercept()` -- point the covariate field at the
   existing `Ainv_phy_rr`; build `mi_species_node_id`; confirm one-tree (7.2,
   section 2.2).
3. C++: add `g_x`, `log_sd_x`, `has_mi_phylo`, `mi_species_node_id`; the
   standardized GMRF penalty block (modelled on `phylo_diag` `:644-647`); fold
   `sd_x * g_x(node(s))` into `eta_x(s)` (7.3, section 3.2).
4. `random` append (`g_x`, `log_sd_x`) + `MakeADFun` (Design 59 section 5 hooks
   `R/fit-multi.R:2416-2435`, `:2456-2460`).
5. `gll_mi_metadata()` structured-slot extension; `imputed.gllvmTMB` unchanged
   (Phase 2a port already returns `x_mis` EBLUP + SE).
6. Phase-3 section 9 tests written FIRST (section 8): high-vs-low signal recovery;
   broadcast correctness; independence from the response phylo field; no-op.

---

## 8. Phase-3 verification gates (Design 59 section 9; section 6 of Design 67)

Tests-as-binding-contract (Design 59 sections 4b / 8): these are written BEFORE the
Phase-3 engine code. They are the Phase-3 row of the Design 67 section 6 table,
expanded.

1. **Recovery, HIGH phylogenetic signal.** Known tree, known missingness,
   `sd_x` large relative to `sigma_x`. Recover `beta` (incl. `b_fix(mi_col)`),
   `alpha`, `sd_x`, `sigma_x`, and the missing-`x` EBLUP within band with SE /
   interval coverage at nominal level. The phylogenetic covariate model beats an
   independent (Phase-2c, no-phylo) model on missing-`x` error and SE width
   ("borrowing helps when strong"). `sd_x` recovered away from zero.

2. **Recovery, LOW phylogenetic signal.** Same tree / missingness, `sd_x` near
   zero (trait phylogenetically unstructured). The phylogenetic model performs
   NO WORSE than the independent model and injects no spurious structure; `sd_x`
   recovered near the boundary ("degrades to approximately independent when
   weak"). The phylo-signal diagnostic (section 6.3) FIRES a weak-signal warning.

3. **Level-mismatch / broadcast correctness.** Species-level `x` with one value
   per species, broadcast to all (species, trait) long rows. Validate: one
   observed value per species enforced (a species with two different observed
   `x` errors; section 4.2); the imputed `x_mis(j)` is a single per-species value
   feeding every trait row of that species; `mi_species_id` maps every long row
   to the correct species. A multi-trait fixture confirms one `x_mis` per
   missing species (not one per long row), reusing the Phase 2c broadcast check.

4. **Independence from the response phylo field.** The covariate phylogenetic
   field `g_x` (with its own `sd_x`) is statistically independent of any
   response-side phylo field (`g_phy`, `g_phy_diag`): no shared field, no
   cross-covariance parameter (section 5.4). Operationally, on a fixture WITH a
   response phylo term and a phylo covariate model, confirm `g_x` / `sd_x`
   estimates and `b_fix(mi_col)` are unbiased and that the covariate field is a
   separate `random` block (perturbation / re-fit check). This is the Phase-3
   guard that the Level-2 joint field is genuinely absent and `beta_x` is
   identified (Design 59 section 6).

5. **No-op / non-regression.** A fit with no `mi()` and no phylo covariate model
   is byte-identical to the pre-Phase-3 fit (logLik, coefficients, gradient).
   The `has_mi_phylo` flag and the `g_x` block are mapped off and contribute
   nothing (Design 59 section 9 "Non-regression"; the `phylo_diag` mapping-off
   pattern, `src/gllvmTMB.cpp:222`).

6. **(Carried) cross-package contract check (Design 67 section 6).** For the
   SAME small single-missing-predictor dataset with a phylo covariate model,
   gllvmTMB-with-one-trait and the drmTMB MD4 univariate structured fit agree on
   the imputed value and `beta_x` (collapses the multivariate engine to the
   drmTMB case) -- a strong test that the borrow is faithful. Requires a shared
   tree / `Q` both lanes accept.

---

## 9. Key decisions (summary for reviewers)

1. **Same prior, reuse the existing precision.** The covariate prior is
   `x_species ~ N(W alpha + u_x, sigma_x^2)`, `u_x ~ N(0, sd_x^2 A) = GMRF(Q_A)`,
   `Q_A = A^{-1} = Ainv_phy_rr`. gllvmTMB POINTS the covariate field at the
   EXISTING sparse `Ainv_phy_rr` / `log_det_A_phy_rr` (`src/gllvmTMB.cpp:208-211`,
   built `R/fit-multi.R:1340-1350`) -- no dense `n^2`, no second `inverseA`,
   one tree per fit.

2. **Standardized-field parametrization (house style).** Follow gllvmTMB's
   `phylo_diag` convention (`g_x ~ N(0,A)` unit-variance penalty `:644-647`;
   `eta_x += sd_x * g_x`) rather than drmTMB's unstandardized penalty
   (`src/drmTMB.cpp:787-791`); the two are equivalent, the gllvmTMB form reuses
   the in-house penalty and keeps `sd_x` interpretable. (Open question Q1.)

3. **Still Laplace, not a SUM.** Continuous `x` -> `x_mis` is a Laplace latent
   composed WITH the phylogenetic field: `g_x` is the smooth species-level mean
   surface, `x_mis(j)` the missing species' conditional modes around it. Three
   latent vectors integrated by Laplace; the SUM (Phase 5) is not involved.

4. **Species-level, broadcast to long.** One `x_mis` per missing SPECIES (not
   per long row), broadcast to every (species, trait) cell via `mi_species_id`;
   one observed value per species enforced; the phylogenetic prior is evaluated
   once per species, so the broadcast does not double-count it (section 4).

5. **Independent-only in Phase 3 (load-bearing).** The covariate phylo field is
   its OWN field, NOT shared with the response phylo field; the joint /
   `correlate_with="response"` eigenvector-orthogonalized field is DEFERRED to
   Phase 4 because the confounding is SHARPER in the multivariate engine (a
   shared field would feed the covariate model AND every trait's eta), Design 59
   sections 3 / 6 / 10 decision 3 (section 5).

6. **Phylo-signal gate.** Recovery tested at high AND low signal; borrowing
   helps when strong, degrades to approximately independent when weak (the model
   does this automatically as `sd_x -> 0`); the diagnostic FLAGS weak signal
   (Penone 2014 / Goolsby 2017 Rphylopars / Molina-Venegas 2024; reuse pigauto
   `phylo_signal.R` / `pagel_lambda.R`), Design 59 sections 3 / 9 (section 6).

7. **Doc number 69** (66 = open PR #369; 67 = predictor umbrella; 68 free; 69
   requested and free).

---

## 10. Open questions for the maintainer

- **Q1 (parametrization).** Confirm Phase 3 uses gllvmTMB's STANDARDIZED-field
  convention (`g_x ~ N(0,A)`, `eta_x += sd_x * g_x`, reusing the `phylo_diag`
  penalty `src/gllvmTMB.cpp:644-647`) rather than literally porting drmTMB's
  unstandardized GMRF penalty (`src/drmTMB.cpp:787-791`). The distributions are
  identical; the recommendation is the standardized form for in-house penalty
  reuse and `sd_x` interpretability (section 3.2). [NEW question, raised by this
  doc; not in Design 67.]

- **Q2 (Pagel partition vs pure-Brownian covariate prior).** The model in
  section 1.1 includes BOTH a phylogenetic field (`sd_x^2 A`) and an i.i.d.
  species residual (`sigma_x^2 I`) -- a Pagel-style partition that lets `sd_x`
  shrink to zero under weak signal (the section 6 degradation). drmTMB's
  `mi_family==0` always carries `sigma_mi` (the residual), so this matches. But
  some phylogenetic-imputation references assume a PURE Brownian covariate
  (`sigma_x = 0`, all species variance phylogenetic). Confirm Phase 3 keeps the
  residual `sigma_x` (recommended -- it is what makes the weak-signal
  degradation continuous and identifiable). [Refinement of Design 67
  section 2.1.]

- **Q3 (one tree, covariate vs response).** Section 2.2: when the response side
  ALSO has a phylo term, the covariate model must use the SAME tree / precision
  (`Ainv_phy_rr`). Confirm Phase 3 requires one tree per fit and errors if the
  covariate `phylo(tree=)` differs in topology from the response phylo term
  (multi-tree is Phase 4; matches the existing "one phylo term" guard
  `R/fit-multi.R:547-550`). [Refinement of Design 67 section 5 Q1's
  surface-alignment spirit, applied to trees.]

- **Q4 (deferred joint field, carried from Design 67 section 5 Q3).** Re-confirm
  the Level-2 joint / `correlate_with="response"` eigenvector-orthogonalized
  field is deferred to Phase 4 (Design 59 section 10 decision 3) and that the
  sharper multivariate confounding (section 5.3) is the reason. [Carried, not
  new.]
