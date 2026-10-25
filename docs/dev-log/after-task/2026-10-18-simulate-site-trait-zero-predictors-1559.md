# simulate_site_trait(n_predictors = 0) — #1559

## Scope
`R/simulate-site-trait.R` only (plus its Rd line and test). No `src/`, no
likelihood, no grammar, no exports.

## Outcome
- `n_predictors = 0` now returns a covariate-free dataset (no `env_*` columns,
  `truth$beta` is `n_traits x 0`). Root cause: `paste0("env_", integer(0))`
  is `"env_"`, not `character(0)`, so the `dimnames` had length 1 against 0
  columns. The dimnames are now `NULL` when there are no predictors.
- `n_predictors` is validated up front (single non-negative whole number) with
  a `cli` message that points at `n_predictors = 0`; before, `-1` surfaced as
  an opaque `rnorm()` "invalid arguments".
- Random draws are unchanged for `n_predictors >= 1`; for `0` the RNG stream is
  the same as passing `beta = matrix(0, n_traits, 0)`.

## Checks
- RED: new test failed on base with the reported dimnames error (and the
  `-1` case failed with the `rnorm` error).
- GREEN: `test-simulate-site-trait.R` passes (44 expectations) with the fix.
- Run by sourcing the single function file under R 4.3.3 (apt); the full
  package (TMB compile, `document()`, `R CMD check`) was NOT run locally
  because this session has no CRAN/conda route. The Rd line was edited by hand
  to match the roxygen text; CI is the full-suite check.

## Follow-up
None.
