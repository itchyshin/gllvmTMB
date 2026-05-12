# Data Shape And Weights Contract

This document specifies the contract for the two public data shapes
and the three engine entry paths into `gllvmTMB`: `gllvmTMB()`
(long-format, canonical), `traits(...)` (wide data-frame formula
shorthand inside a `gllvmTMB()` call), and `gllvmTMB_wide()` (wide
matrix/data-frame wrapper). It is the design input for `ROADMAP.md`
Phase 3 -- "Unify Data Shapes and Weights" -- and is paired with
`docs/design/11-task-allocation.md` Phase 3.

## Status

Implemented in the Phase 3 Codex branch
`codex/phase3-weights-unified`. The implementation adds
`R/weights-shape.R`, refactors the three entry points to call the
shared normalisation helper, and adds
`tests/testthat/test-weights-unified.R` for the paired long/wide
weight-shape contract. Existing long-engine tests continue to own the
binomial `cbind(successes, failures)` versus `weights = n_trials`
contract.

## Goal

Most ecological, evolutionary, behavioural, and morphometric
datasets arrive in **wide format** -- one column per response
trait. The user shouldn't have to long-pivot by hand and write
`0 + trait + (0 + trait):x` boilerplate for every fixed effect
before they can fit a multivariate GLLVM. (`brms` solves the
analogous problem via `mvbind()`; `metafor` via
`rma.mv(yi ~ ..., V = V)`; the `gllvm` package takes a
wide-format matrix.) The two `gllvmTMB` entry points -- long
format (`gllvmTMB(value ~ ..., data = df_long)`) and wide format
(`gllvmTMB_wide(Y, ...)` accepting matrix or wide data frame) --
should feel like two views of one model.

The user picks the shape that matches their mental model -- long
tibble (`(unit, trait)` per row) or wide matrix / data frame
(`row = unit`, `col = trait`) -- and gets the same fit. The
wide data-frame path is intentionally easier to write: because
`traits(...)` names the response columns on the LHS, the RHS can
use `1`, ordinary predictor names, `latent(1 | unit)`, and
`spatial_unique(1 | coords)` instead of spelling out
`0 + trait`, `(0 + trait):x`, `latent(0 + trait | unit)`, and
`spatial_unique(0 + trait | coords)`. Ordinary random intercepts
such as `(1 | batch)` stay ordinary random intercepts. The
engine still reasons in long format.

Concretely:

- `gllvmTMB()` is canonical and never special-cases wide input.
- `gllvmTMB_wide(Y, X, ...)` pivots `Y` to long and dispatches to
  `gllvmTMB()`.
- `gllvmTMB(traits(t1, t2, ...) ~ rhs, data = wide_df, ...)`
  pivots `wide_df[, traits]` to long, expands compact wide RHS syntax
  to the long trait-stacked grammar, and dispatches to the long-format
  path of `gllvmTMB()`.
- The weights, identifier, trait-order, and reshaping rules are
  shared. A single helper (`R/weights-shape.R`) normalises every
  case to the long-format representation before the engine starts
  building the model matrix.

## The Three Engine Paths

| Property | `gllvmTMB()` (long) | `gllvmTMB_wide()` (wide matrix) | `gllvmTMB(traits(...) ~ rhs, data = wide_df)` (wide data frame) |
|---|---|---|---|
| Response shape | one column of `data`, length `n_obs` | matrix `Y` with `dim(Y) = c(n_units, n_traits)` | wide data frame with one column per trait |
| Identifier columns | `unit`, `trait`, `unit_obs`, `cluster` named in `data` | `unit` = rownames(Y); `trait` = colnames(Y); `unit_obs`, `cluster` optional via `...` to `gllvmTMB()` | `unit` named explicitly; `trait` synthesised from `traits()` call; `unit_obs`, `cluster` named explicitly |
| Predictor input | columns of `data` referenced in `formula` RHS | rows of `X` (one row per unit) plus `formula_extra` | columns of `wide_df` referenced in `formula` RHS |
| Weights shape | numeric vector of length `n_obs` (one per `(unit, trait)` row) | NULL / scalar / numeric vector of length `nrow(Y)` / matrix of `dim(Y)` | NULL / numeric vector of length `nrow(wide_df)` (row-broadcast) |
| Trait ordering | factor levels of `data[[trait]]` (or first-encountered for character) | `colnames(Y)` in column order | order of names supplied to `traits()` |
| NA handling | each row is a `(unit, trait)` observation; `NA` in response drops that row | `NA` cells in `Y` drop those `(i, j)` cells; weights must match | `pivot_longer(values_drop_na = TRUE)` drops `NA` cells |

Every cell of the table above is either implemented in the current
source or specified by this doc; the unification target is to make
all three columns reach the engine through one normalisation
helper.

## The Byte-Identical Contract

For any model that can be expressed in both long and wide form, the
following fields must match exactly between the long and wide
calls:

1. The engine fixed-effect matrix `X_fix` after reshaping and
   weight normalisation.
2. The trait factor: same levels, in the same order.
3. The weights vector after normalisation -- same length, same
   values, same column-major alignment with the long-format
   response.
4. The family-id vector handed to the engine.
5. The negative log-likelihood evaluated at the engine initial
   parameter vector, within `sqrt(.Machine$double.eps)`.

What does NOT need to match:

- The user-visible call signature (long vs wide -- that is the
  point of having two entry points).
- The internal data frame's row order, provided the response,
  predictor, and weight vectors are aligned to the same
  permutation. The byte-identical contract is at the engine input
  layer, not at the user data layer.
- The optimisation trajectory (BFGS / L-BFGS-B may visit
  different intermediate points if starting values differ by
  numerical noise). Convergence target is the same; intermediate
  steps are not.

Concretely, the paired test compares the engine input objects, not
the fitted output trajectories. See "Paired-Test Contract" below.

## Identifiers

Long-format requires four named columns (or three if no `cluster`
applies):

- `unit`: the between-unit grouping factor (e.g. `"site"`,
  `"individual"`, `"species"`, `"paper"`).
- `trait`: the trait factor (e.g. `"trait"`, `"species"`,
  `"response"`).
- `unit_obs`: the within-unit grouping factor, one level per
  `(unit, replicate)` cell, used by `latent(0 + trait | unit_obs,
  ...)` and `unique(0 + trait | unit_obs)`.
- `cluster`: an optional third grouping factor (phylogenetic tip,
  study, population). When absent from `data`, the engine
  synthesises a placeholder.

Wide-format derivations:

- `gllvmTMB_wide(Y, ...)`: `unit` levels come from `rownames(Y)`
  (synthesised as `site_1`, ..., `site_n` if missing). `trait`
  levels come from `colnames(Y)` (synthesised as `sp1`, ..., `spJ`
  if missing). `unit_obs` and `cluster` are passed through `...`
  to `gllvmTMB()` and refer to columns of the post-pivot long
  data; for the standard joint-SDM case, `unit_obs` defaults to
  the `(unit, trait)` cell index (i.e. each cell is its own
  observation).
- `traits(...)` inside `gllvmTMB()`: the user names `unit` (and
  optionally `unit_obs`, `cluster`) explicitly in the
  `gllvmTMB()` call. `trait` is synthesised by `pivot_longer()` --
  levels are the names supplied to `traits()`, in supplied order.

## Trait Ordering

The trait factor's `levels` attribute fixes the order in every
downstream operation (model matrix columns, `Lambda` row order,
`s` index, extractor outputs). The order is determined by:

1. If `data[[trait]]` is already a factor: keep its levels.
2. Else if `traits(t1, t2, ...)` was used: the names supplied in
   `traits()`, in supplied order, become the levels.
3. Else if `gllvmTMB_wide(Y, ...)` was used: `colnames(Y)`, in
   column order, become the levels.
4. Else (long-format with character `trait`): first-encountered
   order in `data[[trait]]`, the standard `as.factor()` behaviour
   under the C locale.

The Phase 3 implementation keeps `R/weights-shape.R` focused on the
weights vector. Trait-order preservation remains owned by the three
entry-point reshaping paths: long-format factor levels are preserved,
`gllvmTMB_wide()` uses `colnames(Y)`, and `traits()` uses the order
supplied in the `traits(...)` call. The paired tests compare the
resulting factor levels as an invariant.

Ties are resolved deterministically (rule 1 wins over 2, etc.).
When the user passes a factor whose levels disagree with their
supplied order, the factor wins -- this preserves user intent
when the user has already encoded an ordering.

## Reshaping Rules

`gllvmTMB_wide(Y, X, weights, ...)` is implemented as:

```r
df_long <- tibble::tibble(
  unit  = rep(rownames(Y), times = ncol(Y)),
  trait = rep(colnames(Y), each  = nrow(Y)),
  value = as.numeric(Y)
)
# X is broadcast on `unit`; weights normalised column-major
# (matrix(Y) and as.numeric(Y) share column-major order).
gllvmTMB(value ~ rhs, data = df_long, ...)
```

`gllvmTMB(traits(...) ~ rhs, data = wide_df, ...)` is implemented
as:

```r
df_long <- tidyr::pivot_longer(
  wide_df,
  cols           = <tidyselect from traits(...)>,
  names_to       = "trait",
  values_to      = ".y_wide_",
  values_drop_na = TRUE
)
df_long$trait <- factor(df_long$trait, levels = <supplied order>)
# weights of length nrow(wide_df) are replicated across traits
rhs_long <- expand_traits_rhs(rhs)
gllvmTMB(.y_wide_ ~ rhs_long, data = df_long, ...)
```

The RHS expansion is the user-facing reason for the data-frame wide
path:

| Wide RHS | Long RHS handed to the engine |
|---|---|
| `1` | `0 + trait` |
| `x` | `(0 + trait):x` |
| `latent(1 \| unit, d = K)` | `latent(0 + trait \| unit, d = K)` |
| `unique(1 \| unit)` | `unique(0 + trait \| unit)` |
| `indep(1 \| unit)` / `dep(1 \| unit)` | `indep(0 + trait \| unit)` / `dep(0 + trait \| unit)` |
| `spatial_unique(1 \| coords)` | `spatial_unique(0 + trait \| coords)` |
| `spatial_scalar(1 \| coords)` / `spatial_latent(1 \| coords, d = K)` / `spatial_dep(1 \| coords)` | corresponding `spatial_*(0 + trait \| coords, ...)` call |
| `phylo_indep(1 \| species)` / `phylo_dep(1 \| species)` | `phylo_indep(0 + trait \| species)` / `phylo_dep(0 + trait \| species)` |
| `phylo_latent(species, d = K)` / `phylo_unique(species)` | unchanged; these keywords already name their species axis |
| `(1 \| batch)` | unchanged; the regular random-intercept parser handles it |

Explicit long RHS syntax remains accepted. If a user writes
`traits(t1, t2) ~ 0 + trait + latent(0 + trait | unit, d = K)`, the
expander leaves those trait-stacked terms unchanged.

NA handling:

- `gllvmTMB_wide(Y, ...)`: `NA` cells in `Y` are dropped
  post-pivot. If `weights` is a matrix, `NA` cells in `weights`
  must align exactly with `NA` cells in `Y`; mismatch errors.
- `traits(...)`: `pivot_longer(values_drop_na = TRUE)` drops
  `NA` cells. Users who want strict listwise drop (any `NA` in any
  trait drops the whole row) should pre-filter `wide_df`.
- `gllvmTMB()` (long): `NA` in the response column drops the row.

## The Weights Contract

`weights` is the per-observation likelihood-multiplier vector.
Engine semantics (from `R/fit-multi.R`):

- For non-binomial / non-betabinomial families:
  `log L_i  ←  weights[i] * log L_i`. Default `weights[i] = 1`
  gives the unweighted log-likelihood.
- For binomial / betabinomial rows: `weights` is overloaded as
  `n_trials` (the binomial size) **only** when the LHS of the
  formula is a single column (not `cbind(succ, fail)`) and
  `length(weights) == nrow(data)`. The
  likelihood-multiplier `weights_i` is then forced to `1.0` for
  those rows.

This binomial overload is a glmmTMB / lme4 convention that the
engine preserves; the contract below is identical to glmmTMB for
the single-trait case.

Accepted shapes for the three entry points:

| Shape | `gllvmTMB()` | `gllvmTMB_wide()` | `traits()` |
|---|---|---|---|
| `NULL` | unit weights | unit weights | unit weights |
| scalar | not accepted (use a length-`n_obs` vector) | broadcast to `n_sites × n_species` | not accepted |
| length-`nrow(Y)` (or `nrow(wide_df)`) vector | not accepted (use `nrow(data)`) | row-broadcast: cell `(i, j)` gets `weights[i]` | row-broadcast: cell `(i, j)` gets `weights[i]` |
| length-`nrow(data)` vector | accepted (the standard case) | not accepted (use the matrix shape) | not accepted (use `gllvmTMB_wide()` for per-cell) |
| matrix of `dim(Y)` | not accepted (long format has no shape concept) | per-cell weights; `NA` cells in `Y` must align with `NA` cells in `weights` | not accepted (use `gllvmTMB_wide()`) |

Validation rules (every entry point):

1. `weights` (after normalisation) is numeric, finite, and
   non-negative.
2. Length after normalisation equals `n_obs` (long-format engine
   input).
3. For binomial / betabinomial rows when `weights` is the trial
   count: also strictly positive.
4. `NA` weights are permitted only where the response is also
   `NA` (those rows are dropped before the engine sees them).

Disambiguation:

- The matrix shape is detected by `length(dim(weights)) == 2L`.
  A 1-D R object (vector or scalar) has `dim() = NULL`.
- The scalar shape is detected by `length(weights) == 1L`
  inside the wide entry point only.
- In long format, `weights` is always a length-`nrow(data)`
  vector; matrices and scalars are rejected with a hint to use
  the wide entry point.

Implementation note: the Phase 3 branch extracted the former
`gllvmTMB_wide()` shape handler into `R/weights-shape.R` as
`normalise_weights(weights, response_shape, n_obs, n_units, n_traits,
na_mask)`. The helper returns either `NULL` for unit weights or a
length-`n_obs` numeric vector aligned with the long-format response
that reaches the engine.

## Error Messages

All weight-shape errors use `cli::cli_abort()` with both the
problem statement and an `"i"` hint that names the alternative
entry point. Examples:

```r
# Long-format: matrix weights rejected with a hint.
cli::cli_abort(c(
  "{.arg weights} must be a length-{nrow(data)} numeric vector in the long-format API.",
  "i" = "Got {.code dim(weights)} = c({nrow}, {ncol}).",
  "i" = "For per-cell weights aligned with a wide response matrix, use {.fn gllvmTMB_wide}."
))

# Wide-format: length-mismatch vector rejected with a hint.
cli::cli_abort(c(
  "{.arg weights} length does not match {.arg Y} shape.",
  "i" = "Vector {.arg weights} must have length {.code nrow(Y)} ({n_sites}); got length {length(weights)}.",
  "i" = "For per-cell weights pass a matrix of {.code dim(Y)}; for a single broadcast value pass a scalar."
))

# traits(): per-cell weights rejected with a hint at the matrix-in entry point.
cli::cli_abort(c(
  "{.arg weights} must be NULL or a length-{nrow(data)} numeric vector when using {.fn traits} on the formula LHS.",
  "i" = "For per-cell weight matrices use {.fn gllvmTMB_wide}; the matrix-in entry point is the only place per-cell weights are supported."
))
```

The principle: every reject names the legal alternative. The user
should never have to guess which entry point accepts their data.

## Paired-Test Contract

`tests/testthat/test-weights-unified.R` holds the canonical paired
tests for the Phase 3 shape layer. The implemented cases are:

1. **Plain Gaussian, no weights, no covariates** -- long call and
   wide call produce byte-identical engine inputs.
2. **Plain Gaussian, row-broadcast weights** -- long
   `weights = rep(w, each = J)` matches wide
   `weights = w` (vector).
3. **Plain Gaussian, per-cell weights** -- long
   `weights = as.numeric(W)` matches wide `weights = W`
   (matrix), with `W` having the same column-major order as
   `as.numeric(Y)`.
4. **Wide matrix with site-level predictors** -- long `X` broadcast
   by unit matches `gllvmTMB_wide(Y, X = ..., weights = w)`, guarding
   the row-order bug that originally motivated the refactor.
5. **`traits()` round-trip** -- a wide data frame with explicit trait
   columns, `traits()` LHS, and a long-format equivalent produce
   byte-identical engine inputs.

The binomial `cbind(successes, failures)` versus
`weights = n_trials` contract is deliberately tested in the
long-format engine tests (`test-lme4-style-weights.R` and
`test-multi-trial-binomial.R`). `gllvmTMB_wide()` does not accept
two-layer binomial response arrays in Phase 3; adding that would be a
new wide-response API, not a weight-shape normalisation refactor.

For each paired engine case, the test compares (using
`testthat::expect_equal(..., tolerance = sqrt(.Machine$double.eps))`):

- `tmb_data$X_fix` rows and columns;
- `levels(data[[trait]])`;
- `tmb_data$weights_i` (the normalised per-row weights);
- `tmb_data$family_id_vec`;
- the negative log-likelihood at the engine initial parameter
  vector.

Convergence is **not** part of the paired test. The contract is on
the engine input, not on optimisation trajectories.

## User-Facing Examples

The README and Tier-1 articles use the two-shape framing: long
`gllvmTMB()` beside wide data-frame `traits(...)` syntax, with
`gllvmTMB_wide()` shown when the reader naturally has a response
matrix.

```r
library(gllvmTMB)

# Long form (canonical): one row per (individual, trait)
fit_long <- gllvmTMB(
  value ~ 0 + trait +
    latent(0 + trait | individual, d = 2) +
    unique(0 + trait | individual),
  data = df_long,
  unit = "individual"
)

# Wide data-frame form: one row per individual, one column per trait
fit_wide <- gllvmTMB(
  traits(length, mass, wing, tarsus, bill) ~ 1 +
    latent(1 | individual, d = 2) +
    unique(1 | individual),
  data = df_wide,
  unit = "individual"
)

abs(as.numeric(logLik(fit_long)) - as.numeric(logLik(fit_wide)))
```

The example serves two readers: matrix-thinkers (rows × columns) and
tibble-thinkers (long-format rows). It is the same model expressed in
the two public shapes. The matrix wrapper is the same wide shape for
matrix-first workflows:

```r
fit_wide_matrix <- gllvmTMB_wide(Y, d = 2, family = gaussian())
```

Per-cell weights example (matrix only):

```r
W <- matrix(1 / measurement_se^2,
            nrow = nrow(Y), ncol = ncol(Y),
            dimnames = dimnames(Y))
fit_weighted <- gllvmTMB_wide(Y, X, weights = W, d = 2,
                              family = gaussian())
```

## Implementation Notes For Codex

The Phase 3 implementation:

1. **Adds `R/weights-shape.R`** with one exported-internal helper:

   ```r
   normalise_weights <- function(weights,
                                 response_shape = c("long", "wide_matrix", "wide_df"),
                                 n_obs,
                                 n_units   = NULL,
                                 n_traits  = NULL,
                                 na_mask   = NULL) {
     # returns a length-n_obs numeric vector aligned with the
     # column-major long-format response, or NULL for unit weights.
     # All shape rejections live here.
   }
   ```

2. **Refactors the three entry points** to call
   `normalise_weights()` exactly once, just before passing the
   long-format data to `R/fit-multi.R`. Keep the binomial
   `n_trials` overload in `R/fit-multi.R` -- that lives at the
   engine level, not at the shape level.

3. **Adds `tests/testthat/test-weights-unified.R`** with the shape-layer
   cases listed above. Each `test_that()` block invokes the helper or
   paired engine entries, compares the byte-identical fields, and
   asserts the contract.

4. **Updates `man/*.Rd`** for `gllvmTMB()`, `traits()`, and
   `gllvmTMB_wide()` to point at this design doc and to the two public
   shapes.

5. **Adds one article-level example** to the morphometrics article.
   The example is the two-shape fit shown above.

6. **Does not introduce per-cell weights for `traits()`**. Keep that
   out of scope so the helper's surface stays small.

## Out Of Scope

- Per-cell weights inside the `traits()` formula LHS path.
- Ragged wide formats with semantically meaningful `NA` cells
  (e.g. trait-specific missingness patterns the engine should
  exploit). The current drop-and-fit behaviour is preserved.
- A new wide-format predictor API. `X` in `gllvmTMB_wide()` and
  RHS columns in `traits()` continue to work as today.
- Changing the binomial `weights = n_trials` overload. That is a
  glmmTMB convention preserved here. **Future direction** (decided
  2026-05-11 by the maintainer, recorded in `decisions.md`): when
  this is revisited, the preferred path is docs-only --
  recommend `cbind(succ, fail)` as canonical in articles and
  roxygen `@examples`, keep both APIs available. The overload
  survives at the code level; tutorials standardise on `cbind()`
  to avoid the family-dependent meaning of `weights`.
- Lifting the `nrow(Y) == ncol(Y)` ambiguity rule. The current
  `length(dim(weights))` disambiguation is precise and
  documented; no change.
- Performance work on the pivot step. `tidyr::pivot_longer()` is
  fast enough for the expected dataset sizes; if it ever
  bottlenecks, that is a Phase 4 concern.
