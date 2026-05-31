# Design 64 -- Derivation: `spatial_dep` / `spatial_latent` augmented random-slope priors (Gaussian)

**Status:** Active engine-derivation contract for the `agent/spatial-dep-latent-slope`
worktree (cut from main `5219d3e`, after the SPDE-slope base PR #326).
**Scope:** the two remaining hard spatial random-slope cells of Design 55 sec.5 ---
`spatial_dep(1 + x | coords)` and `spatial_latent(1 + x | coords, d)` --- Gaussian
response only (non-Gaussian deferred, fail-loud).
**Parent designs:** Design 56 sec.5.3 (per-keyword Sigma variants),
Design 60 sec.3.2/3.4/3.5 (scoping), Design 55 sec.5 (APPLICABLE matrix) /
sec.7.3 (the `dep` 2T x 2T reservation).

This memo derives, for EACH mode, the exact prior: the nll formula, the
Kronecker structure, the parameter names, the column order, the marginal-variance
normalization, and the identifiability guard. It is written BEFORE the C++ so the
panel can re-derive the densities independently. Every claim is tied to the
shipped precedents below.

Throughout, ASCII-only: `(x)` denotes the Kronecker product, `Q` the SPDE
precision, `A = Q^{-1}` the SPDE field covariance, `T` the number of traits,
`C = 2T`, `N = n_mesh`, `n = n_obs`.

---

## 0. The four shipped precedents this extends

| Precedent | Symbol | C++ location (this worktree) |
|---|---|---|
| SPDE-slope base (the GMRF-reuse formula) | `omega_spde_aug`, `use_spde_slope` | `src/gllvmTMB.cpp:910-989` (prior), `:1041-1053`+`:1090-1096` (eta) |
| phylo_dep (the 2T x 2T template) | `theta_dep_chol`, `use_phylo_dep_slope` | `src/gllvmTMB.cpp:654-716` (prior), `:1107-1112` (eta) |
| phylo_latent (the reduced-rank template) | `theta_rr_phy_slope`, `g_phy_slope` | `src/gllvmTMB.cpp:772-846` (prior), `:1117-1130` (eta) |
| per-trait SPDE (Q_base construction) | `omega_spde`, `Q_base` | `src/gllvmTMB.cpp:862-908` |

**The structural identity (Design 60 sec.3.5, restated):**

> `spatial_dep` is to `spatial_unique` *exactly* what `phylo_dep` is to
> `phylo_unique`, with the species covariance `A_phy` replaced by the SPDE field
> covariance `Q^{-1}`. The field lives on `N = n_mesh` GMRF nodes (not `n_aug_phy`
> species), and the observation reads the field through the sparse projection
> `A_proj` (not through the species index `species_aug_id`).

The base SPDE-slope nll (PR #326) is the `C = 2` closed-form special case of the
`spatial_dep` derivation below; `spatial_dep` lifts the `C in {1,2}` cap to
`C = 2T` with a full unstructured `Sigma_field` (a `theta_spde_dep_chol`
Cholesky factor), exactly as `phylo_dep` lifted the closed-form `b_phy_aug` cap.

---

## 1. Common SPDE field structure (shared by both modes)

Both modes draw spatial fields on the SAME mesh / SAME `Q_base` (same `kappa`)
as the intercept-only per-trait path. The precision is the Matern-nu=1, d=2 SPDE
operator (Lindgren et al. 2011):

```
Q_base = kappa^4 * M0 + 2 * kappa^2 * M1 + M2          (N x N, sparse)
```

with `kappa = exp(log_kappa_spde)` (the existing shared parameter,
`src/gllvmTMB.cpp:307`). `M0, M1, M2` are the FEM mass/stiffness matrices from
`make_mesh()` (`spde_M0/M1/M2`). The field covariance is `A = Q_base^{-1}`.

**Marginal-variance normalization (identical to the base, Design 60 sec.3.4).**
The SPDE field's *pointwise* marginal variance under `N(0, sd_param^2 * Q^{-1})`
is, for nu=1, d=2,

```
sigma2_marg = sd_param^2 / (4 * pi * kappa^2)     =>     sd_marg = sd_param / (sqrt(4*pi) * kappa).
```

So the IDENTIFIABLE marginal field SD is `sd_marg`; the engine's covariance
SD-parameter is `sd_param = sd_marg * sqrt(4*pi) * kappa`. Both modes inherit
this normalization for any per-field SD reported to the user/extractor. The
cross-field CORRELATIONS are invariant to this scalar normalization (it cancels
in `cov / (sd_i sd_j)`), so correlation recovery needs no rescaling.

**Projection.** Each field column `omega_j` (length `N`) enters `eta` only
through `A_proj omega_j` (length `n`), exactly as the base
(`src/gllvmTMB.cpp:1041-1053`). `A_proj` is `n x N` sparse.

---

## 2. `spatial_dep(1 + x | coords)` -- full unstructured `2T x 2T` field covariance

### 2.1 Model statement

- **Response:** Gaussian, identity link (this release).
- **Random effect:** `2T` spatial GMRF fields on the mesh --- one
  intercept-field `omega_{alpha,t}` and one slope-field `omega_{beta,t}` per
  trait `t = 0..T-1`. Stack them column-wise into

  ```
  Omega = [ omega_0 | omega_1 | ... | omega_{C-1} ]    (N x C,  C = 2T)
  ```

  with the **INTERLEAVED** column order (matching phylo_dep,
  `src/gllvmTMB.cpp` dep comment `:283-285` and Design 56 sec.3.1 `:147-149`):

  ```
  col 0 = alpha_{t0}, col 1 = beta_{t0}, col 2 = alpha_{t1}, col 3 = beta_{t1}, ...
  i.e. column (2*t + 0) = intercept-field of trait t,
       column (2*t + 1) = slope-field   of trait t.
  ```

- **Prior (the defining object):** the full matrix-normal

  ```
  vec(Omega) ~ N( 0,  Sigma_field (x) Q^{-1} ),     Sigma_field is C x C, C = 2T,
  ```

  where `Sigma_field` is FULL UNSTRUCTURED, parameterised by a free lower-
  triangular Cholesky factor `L` (new parameter `theta_spde_dep_chol`, mirroring
  `theta_dep_chol`): `Sigma_field = L L^T`. `vec` stacks columns of `Omega`.

  This is the spatial analogue of the phylo_dep prior
  `vec(B) ~ N(0, Sigma_b (x) A_phy)` (`src/gllvmTMB.cpp:698-715`) with
  `A_phy -> Q^{-1}` and `n_aug_phy -> N`.

- **Linear predictor:** observation `o` (trait `t(o)`, covariate `x(o)`) reads
  ONLY its own trait's intercept- and slope-field:

  ```
  eta(o) += (A_proj omega_{alpha,t(o)})(o) + x(o) * (A_proj omega_{beta,t(o)})(o)
          = sum_{j=0}^{C-1} (A_proj omega_j)(o) * Z_spde_dep(o, j),
  ```

  where the design array `Z_spde_dep` (`n x C`) activates exactly the pair
  `(2*t(o), 2*t(o)+1)` for row `o`:

  ```
  Z_spde_dep(o, 2*t(o))     = 1         (intercept)
  Z_spde_dep(o, 2*t(o) + 1) = x(o)      (slope)
  all other columns        = 0.
  ```

  This is identical in spirit to the interleaved `Z_phy_aug`
  (`R/fit-multi.R:1438-1442`); the only difference is the field is projected by
  `A_proj` and indexed by mesh node, not species.

### 2.2 The nll formula (as it will be implemented)

Let `A = Q_base^{-1}`, `Sigma = Sigma_field` (`C x C`), `Sinv = Sigma^{-1}`.
For the matrix-normal `vec(Omega) ~ N(0, Sigma (x) A)`, the standard density
(Dawid 1981; Pinheiro & Bates 1996) has negative log

```
-log p(vec(Omega))
  = 0.5 * [ N*C*log(2*pi)  +  C*log|A|  +  N*log|Sigma|  +  tr( Sinv * Omega^T A^{-1} Omega ) ].
```

Because `A = Q_base^{-1}`, we have `A^{-1} = Q_base` and `log|A| = -log|Q_base|`.
Substituting:

```
nll_dep
  = 0.5 * [ N*C*log(2*pi)  -  C*log|Q_base|  +  N*log|Sigma_field|  +  tr( Sinv * Q ) ],
  with Q (C x C) defined by   Q(j,l) = omega_j^T Q_base omega_l.                 (*)
```

This is term-for-term the phylo_dep formula `src/gllvmTMB.cpp:712-715`

```
0.5 * ( n_aug_phy*C*log(2pi) + n_aug_phy*logdet(Sigma_b) + C*logdet(A) + tr(Sigma_b^{-1} Q) )
```

with the substitutions `n_aug_phy -> N`, `A^{-1} = Ainv_phy_rr -> Q_base`,
`logdet(A) = log_det_A_phy_rr -> -log|Q_base|`, and `Q(j,l) = b_j^T Ainv b_l ->
omega_j^T Q_base omega_l`. The sign on the `log|Q_base|` term differs from
phylo_dep's `+C*logdet(A)` precisely because here the relatedness object is the
PRECISION `Q_base` (so `logdet(A) = -logdet(Q_base)`), whereas phylo_dep is fed
`A^{-1}` and a precomputed `log_det_A_phy_rr = +logdet(A)`. See sec.2.3 for how
`-C*log|Q_base|` is obtained for free from `density::GMRF`.

**Cholesky packing (mirrors `theta_dep_chol`, `src/gllvmTMB.cpp:656-687`).**
`L` (`C x C`, lower-triangular) is packed in `theta_spde_dep_chol` (length
`C(C+1)/2`) as:

```
entries [0 .. C-1]     : the C log-diagonal entries; L(j,j) = exp(theta[j]) > 0 (identified),
entries [C .. C(C+1)/2): the strictly-lower entries L(i,j), i>j, column-major.
Sigma_field = L L^T (symmetric PD by construction);  log|Sigma_field| = 2 * sum_j log L(j,j).
```

### 2.3 GMRF reuse -- no new sparse op (Windows-safe)

`density::GMRF(Q_base)` evaluated at a single field column `om` returns, by the
TMB convention,

```
GMRF(Q_base)(om) = 0.5 * ( N*log(2*pi) - log|Q_base| + om^T Q_base om ).
```

Summing over the `C` columns of `Omega` gives

```
sum_{j} GMRF(Q_base)(omega_j)
  = 0.5 * ( N*C*log(2*pi) - C*log|Q_base| + sum_j omega_j^T Q_base omega_j )
  = 0.5 * ( N*C*log(2*pi) - C*log|Q_base| + tr(Q) ),                          (with Q from (*))
```

which supplies the `N*C*log(2*pi)`, the `-C*log|Q_base|`, AND the `tr(I * Q)`
baseline. The remaining nll is the unstructured-`Sigma_field` correction:

```
nll_dep = sum_{j} GMRF(Q_base)(omega_j)
        + 0.5 * N * log|Sigma_field|
        + 0.5 * ( tr(Sinv * Q) - tr(Q) ).                                      (**)
```

`tr(Q)` is computed once; `Q(j,l) = omega_j^T (Q_base omega_l)` uses ONLY sparse
matrix-vector products `Q_base omega_l` (the same op the base uses for `q01`,
`src/gllvmTMB.cpp:977`). `tr(Sinv*Q) = sum_{j,l} Sinv(j,l) Q(l,j)`. `Sinv` and
`log|Sigma_field|` come from the dense `C x C` Cholesky `L` --- `C = 2T` is small
(traits), so `atomic::matinv(Sigma_field)` on a `C x C` dense matrix is the same
cheap dense inverse phylo_dep already performs (`src/gllvmTMB.cpp:684`). **No new
atomic op, no sparse solve, no `GMRF` constructor beyond the one already built.**

Formula (**) reduces EXACTLY to the shipped base `C = 2` block
(`src/gllvmTMB.cpp:980-986`): there `gmrf_slope(om0)+gmrf_slope(om1)` is the
`sum_j GMRF` term, and `0.5*N*logdet_Sigma_field + 0.5*((Sinv00-1)q00 +
(Sinv11-1)q11 + 2 Sinv01 q01)` is precisely `0.5*N*log|Sigma| + 0.5*(tr(Sinv Q)
- tr(Q))` written out for `C=2`. This is the algebraic continuity check the panel
should verify first.

### 2.4 Parameters, column order, normalization, guard (summary)

- **New parameter:** `theta_spde_dep_chol` (length `C(C+1)/2`, `C=2T`), free only
  on the dep path; mapped off (length-0 stub) otherwise. `log_sd_spde_b` /
  `atanh_cor_spde_b` are mapped OFF on the dep path (the unstructured
  `Sigma_field` replaces the closed-form `2x2`), mirroring how phylo_dep maps off
  `log_sd_b`/`atanh_cor_b` (`R/fit-multi.R:1956-1965`).
- **Field array:** `omega_spde_aug` widened from `N x 2` to `N x C` (`C = 2T`),
  reusing the SAME array name / projection / eta path. `n_lhs_cols_spde = C`.
- **Column order:** interleaved `(alpha_t0, beta_t0, alpha_t1, beta_t1, ...)`.
- **Normalization:** per-field reported SDs use `sd_marg = sd_param /
  (sqrt(4*pi)*kappa)`; reported `Sigma_field` and its correlation matrix are the
  `C x C` `L L^T` (the diagonal carries `sd_param^2`; extractors convert to
  marginal scale where a user-facing SD is shown, sec.5).
- **Identifiability guard:** the dep path requires `n_lhs_cols_spde == C ==
  2*n_traits` and `omega_spde_aug.cols() == Z_spde_aug.cols() == C` (fail-loud
  `error()`), plus the Cholesky-length check `theta_spde_dep_chol.size() ==
  C(C+1)/2`. The diagonal `exp()` keeps `L(j,j)>0` so `Sigma_field` is strictly
  PD (identified) at every parameter value. Non-Gaussian aborts at construction
  (sec.6).

---

## 3. `spatial_latent(1 + x | coords, d)` -- reduced-rank factor-analytic over the fields

### 3.1 Model statement

- **Response:** Gaussian, identity link (this release).
- **Random effect:** block-diagonal reduced-rank random regression on the SPDE
  field, Design 56 sec.5.3 option-a (NO rho). For each LHS column
  `k in {0 = intercept, 1 = slope}`, an INDEPENDENT rank-`d` factor structure:

  ```
  per LHS column k:  d shared spatial GMRF fields  omega^{(k)}_f  (f = 0..d-1),
                     each   omega^{(k)}_f ~ N(0, Q_base^{-1})  i.i.d. across f and k,
                     and a per-column loading matrix  Lambda_k  (T x d, rr() lower-triangular).
  ```

  The implied per-column cross-trait field covariance is
  `Sigma_k = Lambda_k Lambda_k^T` (`T x T`, rank `d`). There is NO intercept-
  slope correlation: the cross-column (k != k') blocks are exactly zero (the
  Design 56 sec.5.3 "block-diagonal across LHS columns" semantics, identical to
  `phylo_latent`).

- **Linear predictor:** observation `o` (trait `t(o)`, covariate `x(o)`):

  ```
  eta(o) += sum_{k} Z_spde_lat(o, k) * sum_{f} Lambda_k(t(o), f) * (A_proj omega^{(k)}_f)(o),
  Z_spde_lat(o, 0) = 1,   Z_spde_lat(o, 1) = x(o).
  ```

  This is the `phylo_latent` eta term (`src/gllvmTMB.cpp:1117-1130`) with the
  species-indexed score `g_phy_slope(species_aug_id(o), f, k)` replaced by the
  PROJECTED field `(A_proj omega^{(k)}_f)(o)`, and `Z_phy_lat -> Z_spde_lat`.

### 3.2 The nll formula (as it will be implemented)

Each shared field column has prior `N(0, Q_base^{-1})`, i.e. a single
`GMRF(Q_base)` evaluation. The scale is absorbed into `Lambda_k` for
identifiability (the rr() convention, identical to the spatial_latent
intercept-only path `src/gllvmTMB.cpp:897-901` and to phylo_latent
`src/gllvmTMB.cpp:823-832`). The total field prior is the sum over the
`n_lhs_cols_lat * d` INDEPENDENT shared fields:

```
nll_lat = sum_{k=0}^{n_lhs_cols_lat - 1}  sum_{f=0}^{d-1}  GMRF(Q_base)( omega^{(k)}_f )
        = sum_{k,f} 0.5 * ( N*log(2*pi) - log|Q_base| + (omega^{(k)}_f)^T Q_base omega^{(k)}_f ).
```

There is NO `Sigma`-determinant term and NO cross-field quadratic, because the
shared fields are unit-scale i.i.d. `GMRF(Q_base)` and ALL covariance structure
is carried by the (fixed-effect-like) loadings `Lambda_k`. This is exactly the
phylo_latent prior loop (`src/gllvmTMB.cpp:824-832`) with `g_phy_slope ->
omega_spde_lat` and `Ainv_phy_rr -> Q_base` (and the score columns living on `N`
mesh nodes, not `n_aug_phy` species). The reported per-column covariance is
`Sigma_k = Lambda_k Lambda_k^T` (`T x T`).

### 3.3 Parameters, column order, normalization, guard (summary)

- **New parameters (mirror `theta_rr_phy_slope` / `g_phy_slope`):**
  - `theta_rr_spde_slope`: packs `n_lhs_cols_lat` lower-triangular `Lambda_k`
    blocks back-to-back, each of length `T*d - d*(d-1)/2` (the rr() packed
    layout, identical to `theta_rr_phy_slope`, `src/gllvmTMB.cpp:802-808`).
  - `g_spde_slope`: the shared spatial field scores, an array `N x d x
    n_lhs_cols_lat` (the spatial analogue of `g_phy_slope`, with `N` mesh nodes
    on axis 0 instead of `n_aug_phy` species).
- **Column order:** the two LHS columns are `(intercept, slope)`; within each
  column the `d` factors follow the rr() identity-diagonal convention.
- **Normalization:** scale is absorbed into `Lambda_k`; the user-facing `Sigma_k`
  is `Lambda_k Lambda_k^T`. (Because the field is unit-scale `GMRF(Q_base)`, the
  marginal field variance contributed by factor `f` to trait `t` is
  `Lambda_k(t,f)^2 / (4*pi*kappa^2)`; the extractor reports `Sigma_k = Lambda_k
  Lambda_k^T` on the field-covariance scale, mirroring phylo_latent which reports
  `Lambda Lambda^T` directly. The kappa normalization is a per-fit constant and
  the recovery test targets the field-BLUP correlation + the loading-implied
  `Sigma_k` structure, sec.5.)
- **Identifiability guard:** `d <= n_traits` (fail-loud `cli_abort` on the R
  side, mirroring `R/fit-multi.R:719-728` for phylo_latent), and the C++ shape
  asserts `g_spde_slope.dim == (N, d, n_lhs_cols_lat)`,
  `theta_rr_spde_slope.size() == n_lhs_cols_lat * (T*d - d*(d-1)/2)`,
  `n_lhs_cols_lat in {1,2}`. Non-Gaussian aborts at construction (sec.6).

---

## 4. Cross-check against the phylo precedents (the panel's re-derivation map)

| Quantity | phylo_dep (shipped) | spatial_dep (this design) |
|---|---|---|
| relatedness object | `A_phy^{-1} = Ainv_phy_rr` (sparse) | `Q_base` (sparse precision = `A^{-1}`) |
| field/effect index | `species_aug_id(o)` | `A_proj` projection of mesh node |
| node count | `n_aug_phy` | `N = n_mesh` |
| effect array | `b_phy_aug` (`n_aug_phy x C x 1`) | `omega_spde_aug` (`N x C`) |
| unstructured factor | `theta_dep_chol`, `Sigma_b = L L^T` | `theta_spde_dep_chol`, `Sigma_field = L L^T` |
| `log|A|` term in nll | `+C*log_det_A_phy_rr` (fed `+logdet A`) | `-C*log|Q_base|` (from `GMRF`, since `A=Q^{-1}`) |
| quadratic `Q(j,l)` | `b_j^T Ainv_phy_rr b_l` | `omega_j^T Q_base omega_l` |

| Quantity | phylo_latent (shipped) | spatial_latent (this design) |
|---|---|---|
| score prior | `g_phy_slope(.,f,k) ~ N(0,A_phy)` via `Ainv_phy_rr` | `omega^{(k)}_f ~ N(0,Q_base^{-1})` via `GMRF(Q_base)` |
| loadings | `theta_rr_phy_slope` -> `Lambda_k` | `theta_rr_spde_slope` -> `Lambda_k` |
| eta read | `g_phy_slope(species_aug_id(o),f,k)` | `(A_proj omega^{(k)}_f)(o)` |
| per-column Sigma | `Lambda_k Lambda_k^T` | `Lambda_k Lambda_k^T` |
| rank guard | `d <= n_traits` (`fit-multi.R:719-728`) | `d <= n_traits` (same) |

The two derivations are obtained from the phylo precedents by a single,
mechanical substitution (species covariance `A_phy` -> SPDE field covariance
`Q^{-1}`; species index -> `A_proj`). No new math is introduced beyond what the
SPDE-slope base already validated.

---

## 5. Extractor contract (Design 06)

- **`spatial_dep`** surfaces under `level = "spatial"` (the spatial tier), keyed
  on `fit$use$spde_dep_slope`. Returns the reported `Sigma_field` (`C x C`) with
  INTERLEAVED dimnames `(intercept.<trait>, slope.<trait>, ...)` plus its
  correlation matrix `R`, a `level = "spde_dep"` tag, `part = "dep"`, and a
  `note`. Mirrors the phylo_dep extractor (`R/extract-sigma.R:600-627`). Plain
  list return --- NO new print class (reuses default list print, exactly as
  phy_dep does).
- **`spatial_latent`** surfaces under `level = "spde_slope"`, keyed on
  `fit$use$spde_latent_slope`. Returns a per-column list
  `{intercept = Sigma_0, slope = Sigma_1, Lambda_intercept, Lambda_slope, ...}`,
  mirroring the phylo_latent extractor (`R/extract-sigma.R:680-719`). Reuses the
  existing `print.gllvmTMB_Sigma_phy_slope` method, GENERALISED to read a
  `header`/`label` field from the object so it prints "spatial_latent ..." for a
  spatial fit (NO new exported print method --- avoids the
  `_pkgdown.yml`/NAMESPACE export gap that broke the site once).

---

## 6. Guards that MUST fire (fail-loud invariant, Design 56 sec.7)

1. **`d > n_traits`** (latent): `cli_abort` on the R side before MakeADFun, message
   names the rank and trait count (mirrors phylo_latent).
2. **Non-Gaussian family** (both modes): `cli_abort` at construction (R side,
   where `family_id_vec` exists), keeping the matrix-slope reservation tests
   (`test-matrix-slope-spatial-dep.R`, `test-matrix-slope-spatial-latent.R`)
   honest-skipping. gaussian() only this release.
3. **Malformed RHS / unsupported LHS form** (both modes): the parser's
   `normalise_spatial_orientation` malformed-bar abort and the
   non-`{wide,long}_intercept_slope` LHS abort remain in force; only the
   `{wide_intercept_slope, long_intercept_slope}` forms are routed.
4. **C++ dimension asserts** (both modes): `error()` on any
   `n_lhs_cols`/array-shape/Cholesky-length mismatch --- the runtime backstop
   that prevents the Sokal 2026-05-09 silent-collapse.

Guard line refs to LIFT (Design 60 sec.2.3 / sec.3.5, verified post-#326 in
this worktree): the `spatial_dep` construction abort is `.assert_no_augmented_lhs`
at `R/brms-sugar.R:2842`; `spatial_latent` augmented LHS currently dies in
`normalise_spatial_orientation` (`R/brms-sugar.R:1690-1697` whitelists only
`spatial_unique`/`spatial_indep`; `spatial_latent` falls through to the malformed
abort `:1736`). Both are lifted ONLY for `{wide,long}_intercept_slope` +
gaussian(); every other path keeps aborting.

---

*Derivation memo. The nll formulas in sec.2.2/2.3 (eq. **) and sec.3.2 are the
exact objects implemented in `src/gllvmTMB.cpp`; the density self-checks in
`tests/testthat/test-spatial-dep-slope-gaussian.R` and
`test-spatial-latent-slope-gaussian.R` compare them to a dense
`kronecker(Sigma, solve(Q))` reference to < 1e-9.*
