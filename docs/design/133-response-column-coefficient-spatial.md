# Design 133 — Spatial response-column coefficients

**Reader:** formula/API contributors, TMB reviewers, and maintainers of the
response-column coefficient family.
**Status:** bounded public candidate, 2026-08-29. Local parser, endpoint,
long/wide, edge, recovery, and released-slope regression gates pass. Exact-head
three-OS and exact-main evidence remain landing gates.
**Parent contracts:** Design 130 defines the normalized response-column SPDE
source; Design 131 defines the coefficient basis, overlap rule, long/wide
surface, and extractor.

## 1. Scientific model

For sampled row `i`, response column `t`, and coefficient basis `z_i`,

```text
eta_it,coef = z_i^T b_t,
B = [b_1^T; ...; b_T^T],
vec(B^T) ~ N(0, K_spatial(kappa) (x) Sigma_coef).
```

Equivalently,

```text
Cov(b_t,p, b_u,q) = K_spatial(kappa)[t,u] Sigma_coef[p,q].
```

`K_spatial(kappa)` is the exact projected and unit-diagonal-normalized SPDE
correlation from Design 130:

```text
Q(kappa) = kappa^4 M0 + 2 kappa^2 M1 + M2,
C_raw = A_column Q(kappa)^(-1) A_column^T,
K_spatial = D^(-1/2) C_raw D^(-1/2),
D = diag(diag(C_raw)).
```

The normalization assigns marginal coefficient variance to `Sigma_coef` and
spatial range to `kappa`. The implementation factorizes sparse `Q(kappa)` and
forms only the required projected `T x T` covariance.

## 2. Public grammar and boundary

```r
spatial_coef(1 + moisture | trait, mesh = column_mesh, rho = 1)
spatial_coef(1 + moisture || trait, mesh = column_mesh)
```

The helper signature is `spatial_coef(formula, mesh, rho = 1)`. It requires:

- one labelled `gllvmTMBmesh` built with exactly one unique coordinate pair per
  response column and `id_col` equal to the resolved response-column factor;
- an explicit basis `1`, `0 + x`, or `1 + x` containing only distinct bare
  numeric row-data predictors;
- `|` for full `Sigma_coef` or `||` for diagonal `Sigma_coef`;
- Gaussian native-Laplace point estimation; and
- one coefficient source and one spatial axis per fit.

The first public version accepts only `rho = 1`. A literal or evaluated
`rho = NULL`, and every numeric value below one, produces the typed
`gllvmTMB_column_coef_rho_not_admitted` error. Values outside `[0,1]` remain
invalid syntax. An IID-spatial mixture would require an additional coefficient
field tied to the same `Sigma_coef`, plus joint `rho`-range identifiability and
recovery evidence. It is not approximated by fixing or dropping `kappa`.

## 3. Exact compatibility seam

For a no-intercept basis, the public endpoint is a literal pre-sugar rewrite:

```text
spatial_coef(0 + x1 + x2 <bar> trait, mesh = M, rho = 1)
==
spatial_slope(x1 + x2 <bar> trait, mesh = M).
```

The gate requires identical TMB data, random indices, parameter names and maps,
objective and gradient at common parameters, optimum, report, and fitted values,
with no warning from either call. The intercept-bearing route uses the same
internal projected-SPDE marker with ordered basis
`c("(Intercept)", predictors)` and builds the first design column as literal
ones. It does not change the C++ likelihood or the released slope-only route.

## 4. Long/wide biological teaching model

For plant species `j` in pathway `g(j)`, the teaching model is

```text
E(y_ij | a_j, b_j) = alpha_g(j) + a_j
                    + [beta_g(j) + b_j] moisture_i.
```

The fixed formula `0 + pathway + moisture:pathway` estimates separate C3/C4
grand intercepts and slopes. `spatial_coef(1 + moisture | trait, ...)` gives
each plant its own intercept and slope deviations around those pathway means.
The exact long/wide gate compares:

```r
value ~ 0 + pathway + moisture:pathway +
  spatial_coef(1 + moisture | trait, mesh = column_mesh)

traits(...) ~ 0 + pathway + moisture:pathway +
  spatial_coef(1 + moisture | trait, mesh = column_mesh)
```

with keyed `column_data`. It requires identical TMB data, random block, maps,
objective and gradient at a common parameter vector, optimized parameters,
report, fitted values, and extracted coefficient covariance.

## 5. Extraction

`extract_Sigma(fit, level = "column_coef")` returns the Design 131 fields plus:

- `source$type = "spatial"`;
- label-aligned coordinates and coordinate-column names;
- `coordinate_units = "as_supplied"`;
- fitted `kappa` and `practical_range = sqrt(8) / kappa`;
- `normalization = "exact_projected_unit_diagonal"`;
- `source$K_column`; and
- `rho = 1`, `rho_status = "fixed"`, and `K_rho = K_column`.

## 6. Evidence and exclusions

The local fail-closed gate covers parser/formals, typed rho refusals, exact
endpoint identity under both bars, intercept/full/diagonal maps, exact C3/C4
long/wide parity, source-label permutation, malformed meshes, fixed-space
overlap, missing responses, a rare fixed pathway level, the one-spatial-axis
fence, extractor metadata, finite gradients, and one CRAN-safe five-column DGP
integration cell. The retained `data-raw/spatial-coef-recovery.R` campaign adds
one claim-bearing 25-column point-recovery cell plus near-zero, +/-0.8, and
near-boundary coefficient correlations, low and mesh-extent-limited spatial
ranges, and small and large coefficient variances. The extent-limited large-range cell checks
only qualitative ordering because the mesh does not identify its planted range
precisely. The existing `test-spatial-column-slope.R` suite remains green and
is extended by a regression for a real predictor literally named
`(Intercept)`.

This evidence does **not** establish non-Gaussian or mixed-family coefficients,
interval calibration, spatial-plus-IID rho mixtures, estimated spatial rho,
multiple coefficient sources, simultaneous spatial axes, latent coefficient
covariance, transformed/factor coefficient bases, or prediction on new
response-column locations. `spatial_slope()` remains exported, current,
warning-free, and non-deprecated.
