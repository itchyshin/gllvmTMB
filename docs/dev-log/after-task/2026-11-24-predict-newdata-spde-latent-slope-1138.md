# After-task: `predict(newdata = )` re-adds the `spde_latent_slope` tier (#1138)

## Scope

One tier of #1138: the reduced-rank SPDE slope block,
`use_spde_latent_slope`. It is the `K` shared intercept fields and `K` shared
slope fields of `spatial_latent(1 + x | coords, d = K)`, each set with its own
trait loadings.

Out of scope, and still named in the `gllvmTMB_predict_newdata_re_dropped`
warning: `spde_slope` (including the companion block that
`spatial_latent(1 + x | coords, unique = TRUE)` adds), `spde_dep_slope`, and
`spatial_column_slope`. The first two are separate pull requests.

## Reshape convention used

Read from the template, not inferred:

| Block | Layout | Where |
|---|---|---|
| `g_spde_slope` | `n_mesh x d_spde_slope x n_lhs_cols_spde_lat` | `src/gllvmTMB.cpp:1604` |
| `Lambda_spde_slope` (reported) | `n_traits x d_spde_slope x n_lhs_cols_spde_lat` | `src/gllvmTMB.cpp:3250`, `:3296` |
| `Z_spde_lat` | `n_obs x n_lhs_cols_spde_lat`; column 0 ones, column 1 the covariate | `src/gllvmTMB.cpp:1116`, built by `.spde_latent_slope_design()` |
| projection | `A_g(o, f, k) = (A_proj %*% g_spde_slope[, f, k])(o)` | `src/gllvmTMB.cpp:3393-3408` |
| eta | `eta(o) += sum_k Z_spde_lat(o, k) * sum_f Lambda_spde_slope(t(o), f, k) * A_g(o, f, k)` | `src/gllvmTMB.cpp:3495-3507` |

The mesh projector is the one #1132 established for the intercept-only SPDE
tier: `fmesher::fm_basis()` on the stored mesh. On the training rows of the
test fixture it is identical to the fitted `A_proj`.

## Outcome

- `R/methods-gllvmTMB.R`
  - `.gllvmTMB_spde_newdata_projector()`: the projector and its outside-hull
    warning, moved out of `.gllvmTMB_spde_newdata_contrib()` unchanged so every
    SPDE tier projects through one function. This hunk is identical in the
    three per-tier pull requests.
  - `.gllvmTMB_spde_latent_slope_newdata_contrib()`: the tier. Returns `NULL`
    (tier stays named in the warning) when `newdata` lacks the covariate or
    the coordinates, or when a parameter block does not have the documented
    size.
  - `predict.gllvmTMB_multi()`: adds the contribution as the last spatial
    term, the template's order.
- `tests/testthat/test-spde_latent_slope-predict-newdata-1138.R`: new, 5 tests.
- `NEWS.md`: one entry.
- `src/gllvmTMB.cpp`: untouched. No default, estimand, standard error, or
  public API changed. No existing test expectation changed.

## Decisions

- **The exact pin is on a `d = 1` fit with a covariate in `{0, +-2^k}`.** With
  one factor the template's inner sum is a single product, and with `x` a
  signed power of two the outer product is exact, so `max|diff| == 0` does not
  depend on whether the compiler fuses a multiply-add into one rounding (clang
  on arm64 does by default).
- **The `d = 2` test is bounded at 8 units in the last place, not exact.** With
  two factors the inner sum is a genuine multiply-add. On x86-64 Linux the
  measured gap is exactly 0; the bound is there so the test states what is
  guaranteed everywhere. The same test checks that swapping the factor and
  design-column axes of `g_spde_slope` is wrong by more than `1e-3`, so the
  bound cannot be met by a different reshape.
- **Missing covariate value gives `NA`.** The other rows are unchanged.
- **Placement inside `predict()`.** The block sits between the `lv_B` note and
  `handled <-` so this pull request and the `spde_slope` one merge without a
  conflict, and so the reduced-rank term is added after its `unique = TRUE`
  companion, as in the template.
- **Not edited, to keep the per-tier pull requests free of conflicts with each
  other and with the parallel B-slope / phylo lanes:** the `getREsd()` roxygen
  inventory, the `predict()` roxygen sentence listing re-added tiers, the
  comment block in `test-isdm-predict.R`, the validation-debt register, and
  `docs/dev-log/check-log.md`. The commands are recorded below instead.

## Checks

```sh
export NOT_CRAN=true   # without it every test in the file skips
Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-spde_latent_slope-predict-newdata-1138.R")'
```

- New file on this branch: FAIL 0 / WARN 0 / SKIP 0 / PASS 26.
- New file against `origin/main` `R/` (change stashed): the exact-identity,
  row-order, covariate and two-factor tests fail.
- Neighbouring predict / spatial files on this branch: see the pull request
  body for the list and counts.
- Measured, not pinned: on `spatial_latent(1 + x | coords, d = 1, unique =
  TRUE)` this branch re-adds `spde_latent_slope` and the warning names only
  `spde_slope`.

Not run: `devtools::check()`, the full test suite, macOS, Windows.

## Follow-up

- `spatial_latent(1 + x | coords, unique = TRUE)` carries `spde_slope` and
  `spde_latent_slope` together; its exact identity can be pinned only once
  both tiers are on `main`.
- After the tier pull requests land, update the `getREsd()` and `predict()`
  roxygen inventories and the `*_slope` comment in `test-isdm-predict.R` in
  one pass.
