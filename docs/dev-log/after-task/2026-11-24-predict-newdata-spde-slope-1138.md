# After-task: `predict(newdata = )` re-adds the `spde_slope` tier (#1138)

## Scope

One tier of #1138: the base augmented SPDE slope block, `use_spde_slope`
without `use_spde_dep_slope`. It is the intercept field plus the slope field of
`spatial_unique(1 + x | coords)`, and the companion block of
`spatial_latent(1 + x | coords, unique = TRUE)`.

Out of scope, and still named in the `gllvmTMB_predict_newdata_re_dropped`
warning: `spde_dep_slope` (`spatial_dep` / `spatial_indep` slopes, `2T`
interleaved fields), `spde_latent_slope`, and `spatial_column_slope`.

## Reshape convention used

Read from the template, not inferred:

| Block | Layout | Where |
|---|---|---|
| `omega_spde_aug` | `n_mesh x n_lhs_cols_spde`; column 0 intercept field, column 1 slope field | `src/gllvmTMB.cpp:1585` |
| `Z_spde_aug` | `n_obs x n_lhs_cols_spde`; column 0 ones, column 1 the covariate | `src/gllvmTMB.cpp:1093`, built at `R/fit-multi.R:5825-5828` |
| projection | `A_omega_aug(o, j) = (A_proj %*% omega_spde_aug[, j])(o)` | `src/gllvmTMB.cpp:3376-3391` |
| eta | `eta(o) += sum_j A_omega_aug(o, j) * Z_spde_aug(o, j)` | `src/gllvmTMB.cpp:3486-3494` |

The mesh projector is the one #1132 established for the intercept-only SPDE
tier: `fmesher::fm_basis()` on the stored mesh. On the training rows of the
test fixture it is identical to the fitted `A_proj`.

## Outcome

- `R/methods-gllvmTMB.R`
  - `.gllvmTMB_spde_newdata_projector()`: the projector and its outside-hull
    warning, moved out of `.gllvmTMB_spde_newdata_contrib()` unchanged so every
    SPDE tier projects through one function.
  - `.gllvmTMB_spde_slope_newdata_contrib()`: the tier. Returns `NULL` (tier
    stays named in the warning) on the `2T`-field channel, on the
    response-column slope, and when `newdata` lacks the covariate or the
    coordinates.
  - `predict.gllvmTMB_multi()`: adds the contribution straight after the
    intercept-only SPDE field, the template's order.
- `tests/testthat/test-spde_slope-predict-newdata-1138.R`: new, 6 tests.
- `NEWS.md`: one entry.
- `src/gllvmTMB.cpp`: untouched. No default, estimand, standard error, or
  public API changed. No existing test expectation changed.

## Decisions

- **Missing covariate value gives `NA`.** A row whose `x` is `NA` has no
  defined slope term, so its prediction is `NA`; the other rows are unchanged.
- **The test covariate takes values in `{0, +-2^k}`.** The template adds
  `A_alpha + x * A_beta` per row. With `x` a signed power of two the product is
  exact, so `max|diff| == 0` holds whether or not the compiler fuses the
  multiply-add into one rounding (clang on arm64 does by default). With a
  continuous covariate the identity was also exactly 0 on x86-64 Linux, but it
  is not guaranteed where the template's arithmetic is fused.
- **`spatial_dep` / `spatial_indep` slopes are refused by the helper, not
  reinterpreted.** They raise `use_spde_slope` too, with a `2T`-column
  `omega_spde_aug`. A test pins that the two-column rebuild returns `NULL`
  there.
- **Not edited, to keep the per-tier pull requests free of conflicts with each
  other and with the parallel B-slope / phylo lanes:** the `getREsd()` roxygen
  inventory, the `predict()` roxygen sentence listing re-added tiers, the
  comment block in `test-isdm-predict.R`, the validation-debt register, and
  `docs/dev-log/check-log.md`. The commands are recorded below instead.

## Checks

```sh
export NOT_CRAN=true   # without it every test in the file skips
Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-spde_slope-predict-newdata-1138.R")'
```

- New file on this branch: FAIL 0 / WARN 0 / SKIP 0 / PASS 28.
- New file against `origin/main` `R/` (change stashed): FAIL 12, including
  `max(abs(on_newdata$est - fit$report$eta))` not identical to 0.
- Neighbouring files, all FAIL 0 on this branch: `test-isdm-predict.R`
  (PASS 70, covers the moved projector), `test-predict-newdata-alignment.R`,
  `test-predict-simulate-refusal-classes.R`,
  `test-select-lv-refusal-classes.R`,
  `test-fix-1791-predict-phylo-re-added.R`,
  `test-1782-predict-missing-unit.R`, `test-1787-predict-missing-species.R`,
  `test-fix-1788-predict-missing-cluster2.R`, `test-predict-unused-args.R`,
  `test-predict-sentinel-leak.R`.
- Also measured, not pinned: exact 0 on training rows for a binomial fit
  (link and response scale), for a fit that also has `x` as a fixed effect,
  and for a continuous covariate (x86-64 Linux, R 4.6.2).

Not run: `devtools::check()`, the full test suite, macOS, Windows.

## Follow-up

- `spde_dep_slope` and `spde_latent_slope` are separate pull requests.
- `spatial_latent(1 + x | coords, unique = TRUE)` carries `spde_slope` and
  `spde_latent_slope` together; its exact identity can be pinned only once
  both tiers are on `main`.
- `spatial_column_slope` projects by response-column label and rescales each
  field per trait (`src/gllvmTMB.cpp:3093-3120`, `:3387-3388`). It was outside
  this task and is still named in the warning.
