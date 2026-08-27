# Design 131 — Response-column coefficient foundation

**Reader:** formula/API contributors, statistical-method developers, and
reviewers preparing the successor to the response-column `*_slope()` family.
**Status:** Arc 2 internal IID engine contract, 2026-08-26. The Arc 1 parser,
metadata, and fixed-effect groundwork now admits fitted Gaussian
`column_coef()` point models through the existing matrix-normal coefficient
engine. Structured `*_coef()` engines, exported helpers, public teaching, and
interval claims remain unadmitted.
**Relationship to Design 130:** Design 130 remains the active contract for the
released slope-only helpers. The future `*_coef()` family generalises their
coefficient basis to include response-column intercepts. Existing fits and
`*_slope()` spellings remain unchanged.

## 1. Scientific question and coefficient block

Let rows `i = 1, ..., N` be sampled units and response columns
`t = 1, ..., T` be species or traits. Let `z_i` be a `P`-vector selected by a
coefficient helper. The coefficient contribution is

```text
eta_it,coef = z_i^T b_t,
B = [b_1^T; ...; b_T^T],
B ~ MN(0, K_rho, Sigma_coef).
```

Rows of `B` are response columns. Columns of `B` are the selected coefficient
basis: an intercept, row-varying predictors, or both. Therefore a predictor in
`*_coef(latitude | trait)` is still measured across sampled rows; its
coefficient varies across response columns. A species attribute such as
photosynthetic pathway belongs in keyed `column_data` and fixed-effect
interactions, not in the random-coefficient basis.

For trait-major vectorisation (all coefficients for response column 1, then
all coefficients for response column 2, and so on),

```text
Cov(vec_trait-major(B)) = Cov(vec(B^T)) = K_rho (x) Sigma_coef,
Cov(b_t,p, b_u,q) = K_rho[t,u] Sigma_coef[p,q].
```

This is a random-coefficient block. Fixed response-column means and observed
group differences remain ordinary formula terms.

## 2. Locked family and grammar

The locked coefficient-family contract is:

```r
column_coef(1 + latitude | trait)
phylo_coef(1 + latitude | trait, tree = tree)
animal_coef(1 + latitude | trait, pedigree = pedigree)
kernel_coef(1 + latitude | trait, K = K, name = "environment")
spatial_coef(1 + latitude | trait, mesh = column_mesh)
```

The right side of the bar must be exactly the resolved response-column factor
named by `trait =`. The left side accepts only:

| basis | meaning |
|---|---|
| `1` | response-column random intercepts |
| `0 + x` | response-column random slopes for `x` |
| `1 + x` | response-column random intercepts and slopes |

The first slice accepts bare, distinct numeric row-data columns only. It
rejects transformations, interactions, factors, offsets, response variables,
`column_data` variables, and covariance/random-effect calls inside the basis.
Exactly one response-column coefficient source is allowed in a model.

Single bar `|` estimates a full positive-definite `Sigma_coef`. Double bar
`||` constrains `Sigma_coef` to be diagonal. For a one-coefficient basis the
models coincide, but the parser retains the written bar so diagnostics can
report user intent.

The admitted IID equivalence is exact:

```text
slope(x | trait)  == column_coef(0 + x | trait)
slope(x || trait) == column_coef(0 + x || trait)
```

Each structured extension must pass the corresponding
`source_slope(...) == source_coef(..., rho = 1)` gate before admission. The
released `*_slope()` grammar omits the explicit `0 +`; that spelling stays
supported without a warning. The IID route reuses its engine without aliasing,
deprecating, or rerouting the released helper.

## 3. Structured source mixture

For a supplied positive-definite source covariance `K`, define

```text
D = diag(sqrt(diag(K))),
R = D^(-1) K D^(-1),
K_rho = D [rho R + (1 - rho) I] D
      = rho K + (1 - rho) diag(K),  0 <= rho <= 1.
```

Thus `rho` is the strength of source correlation after preserving the supplied
marginal scale. It is a variance share only when `diag(K) = 1`. `rho = 1`
uses the supplied structure; `rho = 0` retains its marginal scale but removes
between-column correlation.

- `column_coef()` uses `K_rho = I`, reports source `iid`, and has no `rho`
  argument.
- `phylo_coef()`, `animal_coef()`, and `kernel_coef()` will use `rho = NULL`
  for an estimated value and a numeric scalar in `[0, 1]` for a fixed value.
- `spatial_coef()` has the stable first-release default `rho = 1`. The
  estimable `rho = NULL` route is admitted only after a joint `rho`-range
  identifiability gate. A fixed `rho = 0` must map the spatial range parameter
  off because the likelihood is then independent of range.

The IID `column_coef()` route now estimates the `K_rho = I` case. The
structured helpers continue to store and validate their source and `rho`
intentions but remain fenced before optimisation.

## 4. Keyed response-column metadata

The Arc 1 `gllvmTMB()` interface has optional `column_data`. It is a data
frame with exactly one row per response column. Long input keys on the
resolved `trait =` column; wide `traits(...)` input keys on the synthetic
literal column name `trait` and rejects a non-default `trait =` value.

The key contract is exact:

- key order is irrelevant and alignment is by character value;
- key sets must exactly match the fitted response-column levels;
- missing, extra, duplicate, empty-string, and `NA` keys fail before fitting;
- non-key `column_data` names must not collide with row-data names;
- non-key names cannot use the internal carrier names `.y_wide_`,
  `.offset_wide_`, `.multinom_group_`, or `.multinom_L_`;
- joined variables are fixed-effect metadata only; they cannot be coefficient
  bases, grouping factors, or covariance sources.

Long input joins metadata to every row by the resolved response-column key.
Wide `traits(...)` input uses its existing synthetic factor name `trait`:
callers omit the `trait =` argument and key `column_data` by a column named
`trait`. A non-default `trait =` value with wide input fails clearly rather
than being ignored. Wide input resolves the response-column names first,
aligns `column_data`, then performs the same join after stacking. Permuting
metadata rows must leave prepared data and model matrices unchanged.

In a wide formula, an ordinary fixed expression containing at least one
`column_data` variable is preserved as written rather than expanded again by
`trait`. The metadata already vary on the response-column axis. Thus
`pathway` fits pathway-group means and `latitude:pathway` fits pathway-group
latitude slopes. Expressions containing only row-data predictors retain the
existing response-column-specific wide expansion unless wrapped in
`shared()`.

A C3/C4 example therefore uses an observed pathway column from `column_data`
and a fixed interaction such as `latitude:pathway`. It does not pretend that
pathway varies over sampled sites.

## 5. Shared fixed effects in wide formulas

Existing wide shorthand remains response-column-specific:

```r
traits(...) ~ 1 + latitude
```

continues to expand to response-column intercepts and response-column-specific
latitude effects. No existing model matrix changes.

The internal Arc 1 marker

```r
traits(...) ~ 0 + shared(1 + latitude)
```

unwraps to one common intercept and one common latitude effect. `shared()` is
accepted in long and wide preprocessing, but Arc 1 does not export or
advertise it. The marker must be a top-level additive RHS term and accepts
ordinary fixed expressions from row data. It rejects nested placement,
random-effect/covariance calls, offsets, response variables,
`column_data`-only variables, and nesting inside `*_coef()`. Column metadata
do not need `shared()` because §4 gives them their own data-aware expansion.
A user-defined function named `shared` in the formula environment retains its
ordinary meaning rather than being captured as this internal marker.

## 6. Fixed/random overlap gate

Let `X_fixed` be the fixed-effect design. For each coefficient-basis column
`p`, let `Z_p` be its saturated response-column design and let `G_p` contain
the allowed coarser fixed means for that coefficient, including a shared mean
or a pathway-group mean. The oracle projects both `X_fixed` and `Z_p` off
`G_p`, then asks whether the residual fixed design spans every residual
response-column contrast in `Z_p`. The model is rejected if this saturation
occurs for any selected coefficient. A mere nonzero intersection is not
enough: shared and group means intentionally overlap the random block's grand
mean direction while leaving response-column deviations estimable. The oracle
compares matrix ranks separately for every basis column, not printed terms.

Required first-slice behaviour:

```r
0 + trait + phylo_coef(1 | trait, tree = tree)          # reject
(0 + trait):latitude + phylo_coef(0 + latitude | trait) # reject
traits(...) ~ 1 + phylo_coef(1 | trait)                 # reject
latitude:pathway + phylo_coef(0 + latitude | trait)     # allow
```

Coarser fixed means, including pathway-group contrasts, are allowed because
they do not span all response-column coefficients. The eventual random block
represents residual response-column deviations around those means.

## 7. Parser and IID-engine state

The parser recognises all five marker names, validates the bar,
response-column factor, basis, source count, metadata restrictions, and
fixed/random overlap, and requires every marker to be a top-level additive RHS
term. A valid `column_coef()` term continues into the existing matrix-normal
coefficient engine with identity response-column covariance. A valid
`phylo_coef()`, `animal_coef()`, `kernel_coef()`, or `spatial_coef()` term still
stops with class `gllvmTMB_column_coef_engine_not_admitted` before optimisation
or TMB assembly. Malformed syntax uses narrower validation classes and must
not be disguised as the engine fence.

The literal predictor name `(Intercept)` is reserved. Users request the
synthetic intercept with `1`; accepting the literal name would make the design
column ambiguous.

The marker names remain absent from `NAMESPACE`, `_pkgdown.yml`, reference
topics, and public articles. Internal tests may call parser helpers directly.

## 8. Independent oracles

Arc 1 evidence is pure data/parser evidence:

1. metadata permutation invariance and exact-key failures;
2. long/wide metadata alignment parity;
3. old wide expansion unchanged without `shared()`;
4. `shared()` common-effect model matrices and invalid-expression failures;
5. exact coefficient bases for every source and both bars;
6. matrix-rank overlap rejection with a coarser pathway exception;
7. deliberate structured-engine fence failure for syntactically valid fits;
8. existing `traits()` and `*_slope()` regression tests.

The IID-engine slice adds independent gates for:

1. exact intercept-first design construction for `1`, `0 + x`, and `1 + x`;
2. full versus diagonal coefficient covariance under `|` and `||`;
3. exact objective, parameter-map, covariance-report, and fitted-value
   equivalence between `column_coef(0 + x | trait)` and the released
   identity-source `slope(x | trait)` route;
4. exact long/wide fitted-object parity; and
5. a known-DGP Gaussian intercept/slope recovery fit with finite gradients at
   both truth and optimum.

This slice reuses the released matrix-normal coefficient arithmetic and does
not change TMB code. Source-specific implementation, public extractor
contracts, and the three-OS public release gate remain required before any
helper is exported or taught.

## 9. Explicitly deferred

This slice defers structured `*_coef()` likelihood routing, fixed and estimated
`rho`, TMB edits, public exports, extractors, wide parser advertisement,
interval inference, non-Gaussian multi-predictor recovery, latent predictor
covariance, and the public `col_data`/`column_data` tutorial. The general `rho`
extension for the existing 5 x 3 grid remains a separate model-family decision,
not a side effect of this coefficient programme.
