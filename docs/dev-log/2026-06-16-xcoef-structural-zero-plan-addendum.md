# Twin Finish Addendum: Structural-Zero Fixed-Effect Coefficients

Date: 2026-06-16

Source: maintainer-supplied GLLVM team note, read into the Codex plan on
2026-06-16.

## Decision

Add a new future design lane for structural-zero constraints in the
species- or trait-specific fixed-effect coefficient matrix. This is not
already covered by the bridge gate registry, response-mask work, per-trait
dispersion/cutpoint parity, or missing-data lanes.

Working lane name:

```text
codex/xcoef-structural-zero-spec
```

Primary owner perspectives:

- Boole: API and formula/design-matrix grammar.
- Noether: equation-to-implementation alignment.
- Gauss: TMB map / Julia parameterization and optimizer behaviour.
- Fisher: parameter count, likelihood comparison, and inference status.
- Curie: no-mask equivalence, all-zero-term equivalence, prediction, and
  naming/order tests.
- Pat/Darwin: applied biological interpretation of structural absence.
- Jason: source-map against `gllvm`, `gllvmTMB`, `GLLVM.jl`, `glmmTMB`,
  `brms`, `MCMCglmm`, `boral`, `Hmsc`, and `mirt` where relevant.
- Rose: claim boundary and distinction from observation-by-response
  covariates.

## Scope

For a GLLVM with site-level covariates,

```text
g(mu_ij) = alpha_i + beta_0j + x_i' beta_j + u_i' theta_j,
```

let `B` be the `p x m` fixed-effect coefficient matrix, with rows for
expanded covariate columns and columns for response variables / traits.
Introduce a logical mask `M` of the same shape:

```text
M[k, j] = TRUE   -> estimate beta[k, j]
M[k, j] = FALSE  -> fix beta[k, j] exactly at zero
```

The fixed-effect contribution becomes:

```text
sum_k M[k, j] * x[i, k] * beta[k, j]
```

This is a structural-zero constraint on `B`, analogous in spirit to
`lambda_constraint` for loading matrices, but applied to fixed-effect
coefficients.

## Non-Scope

This lane does not solve observation-by-response covariates:

```text
z[i, j, k] * gamma[k]
```

where the predictor value itself changes across both observation and
response column. That is a long-format / array-style design-matrix
problem and must be planned separately. The X-coefficient mask only says
that a shared site-level covariate column is active for some responses and
structurally absent for others.

## Candidate API

The first design pass should compare at least three API shapes:

1. `Xcoef_mask = mask`
   - logical matrix;
   - `TRUE` means estimate;
   - `FALSE` means fix to zero;
   - rows match expanded design-matrix columns;
   - columns match response / trait names.
2. `Xcoef_fixed = fixed`
   - matrix with `NA` meaning estimate and `0` meaning fixed zero;
   - leaves room for later fixed nonzero values, but should initially allow
     only zero constraints.
3. Formula-side helper for `gllvmTMB`
   - a future helper may be more natural than exposing design-matrix column
     names directly, but only after Boole maps the long-format and
     `traits(...)` formula routes.

The design should prefer explicit names over positional matching. Factor
expansion is part of the API contract: users must constrain expanded model
matrix columns, not only raw variable names, unless a higher-level helper
is deliberately introduced.

## Implementation Questions

For native `gllvmTMB`, the likely implementation route is a TMB parameter
map:

- fixed entries start exactly at zero;
- fixed entries are mapped to `NA` so the optimizer does not estimate them;
- the fitted object returns the full coefficient matrix, including fixed
  zeros;
- standard errors, z statistics, and p values for fixed entries are `NA`
  or marked with `status = "fixed"`;
- the effective parameter count uses `sum(M)`, not `p * m`.

For `GLLVM.jl`, the equivalent design should be explicit rather than a
hidden R-side post-processing trick:

- parameter vectors should be built only for free entries, or the AD
  objective should treat fixed entries as constants;
- the bridge payload must carry trait-labelled row/column names and the
  mask itself;
- `df`, `logLik`, `coef`, `predict`, and summary accessors must agree with
  the native oracle before the row is advertised.

Open design questions:

- How should user-supplied starts interact with fixed-zero entries:
  overwrite with a warning, or reject nonzero starts?
- How should this interact with an existing user-supplied `map` /
  `setMap` mechanism?
- Should equality constraints between coefficients be postponed until after
  zero constraints are stable?
- Which public accessor should expose the fixed/estimated status per
  coefficient?

## Minimum Evidence Before Promotion

The lane is not complete until tests cover:

1. all-`TRUE` mask equals current behaviour;
2. all-zero mask for one covariate equals omitting that expanded covariate,
   within numerical tolerance;
3. selected fixed coefficients remain exactly zero after optimization;
4. effective parameter count decreases by the number of fixed coefficients;
5. predictions do not change for response columns whose coefficient is
   fixed to zero when the masked covariate changes;
6. factor expansion applies constraints to expanded design-matrix columns;
7. mask names and ordering are checked explicitly;
8. summaries, standard errors, and tidy output mark fixed entries without
   treating them as free parameters.

## Claim Boundary

This topic should be described as **planned design work** until a source
map, implementation, tests, documentation, and validation-debt row exist.
Do not advertise it as an implemented bridge or native feature. Do not
fold it into response-mask, missing-data, or fixed-effect-X parity rows:
those rows concern data inclusion and existing free coefficients, not
structural-zero constraints on the coefficient matrix.
