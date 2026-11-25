# After-task: `predict(newdata = )` re-adds the `spde_dep_slope` tier (#1138)

## Scope

One tier of #1138: the per-trait augmented SPDE slope block,
`use_spde_dep_slope`. Every trait has its own intercept field and its own
slope field on the covariate. `spatial_dep(1 + x | coords)` and
`spatial_indep(1 + x | coords)` both fit through it. The engine adds it to eta
in its `use_spde_slope` block, so that switch is on too and is accounted for
by the same rebuild.

Out of scope, and still named in the `gllvmTMB_predict_newdata_re_dropped`
warning: the two-column `spde_slope` channel of
`spatial_unique(1 + x | coords)`, `spde_latent_slope` (both separate pull
requests), and `spatial_column_slope` (`spatial_slope()` response-column
slopes).

## Reshape convention used

Read from the template and the R-side builder, not inferred:

| Block | Layout | Where |
|---|---|---|
| `omega_spde_aug` | `n_mesh x n_lhs_cols_spde`, `n_lhs_cols_spde = 2 * n_traits` | `src/gllvmTMB.cpp:1585` |
| column order | INTERLEAVED: `(alpha_t0, beta_t0, alpha_t1, beta_t1, ...)` | `src/gllvmTMB.cpp:1093`, `R/fit-multi.R:5815-5823` |
| `Z_spde_aug` | for a row of zero-based trait `t0`: column `2 * t0` is 1, column `2 * t0 + 1` is the covariate, the rest 0 | `R/fit-multi.R:5819-5823` |
| projection | `A_omega_aug(o, j) = (A_proj %*% omega_spde_aug[, j])(o)` | `src/gllvmTMB.cpp:3376-3391` |
| eta | `eta(o) += sum_j A_omega_aug(o, j) * Z_spde_aug(o, j)` | `src/gllvmTMB.cpp:3486-3494` |

Because every other column of `Z_spde_aug` is zero for the row, the template's
sum is the row's intercept field plus `x` times its slope field, in that
order. The rebuild forms exactly that and does not build the `n_obs x 2T`
design matrix.

The mesh projector is the one #1132 established for the intercept-only SPDE
tier: `fmesher::fm_basis()` on the stored mesh.

## Outcome

- `R/methods-gllvmTMB.R`
  - `.gllvmTMB_spde_newdata_projector()`: the projector and its outside-hull
    warning, moved out of `.gllvmTMB_spde_newdata_contrib()` unchanged. This
    hunk is identical in the three per-tier pull requests.
  - `.gllvmTMB_spde_dep_slope_newdata_contrib()`: the tier. Returns `NULL`
    (tier stays named in the warning) when `newdata` lacks the covariate or
    the coordinates, when the field matrix is not `2 * n_traits` wide, and on
    the response-column slope.
  - `predict.gllvmTMB_multi()`: adds the contribution and records both
    `spde_slope` and `spde_dep_slope` as re-added.
- `tests/testthat/test-spde_dep_slope-predict-newdata-1138.R`: new, 5 tests.
- `NEWS.md`: one entry.
- `src/gllvmTMB.cpp`: untouched. No default, estimand, standard error, or
  public API changed. No existing test expectation changed.

## Decisions

- **The test covariate takes values in `{0, +-2^k}`.** The product with `x`
  is then exact, so `max|diff| == 0` does not depend on whether the compiler
  fuses the template's multiply-add into one rounding (clang on arm64 does by
  default).
- **The fixture is 70 sites, seed 5.** At 40 sites the unstructured 6 x 6
  field covariance stopped with `false convergence (8)` on three seeds out of
  three; at 70 sites it converged on three out of three.
- **Missing covariate value gives `NA`.** The other rows are unchanged.
- **Response-column slopes are refused by the helper.** A `spatial_slope()`
  fit raises `use_spde_slope` and `use_spde_dep_slope` as well, but projects
  by response-column label and rescales each field per trait. Measured on the
  fixture of `test-spatial-column-slope.R`: the warning still names
  `spatial_column_slope`, `spde_dep_slope` and `spde_slope`. Not pinned by a
  test here.
- **Not edited, to keep the per-tier pull requests free of conflicts with each
  other and with the parallel B-slope / phylo lanes:** the `getREsd()` roxygen
  inventory, the `predict()` roxygen sentence listing re-added tiers, the
  comment block in `test-isdm-predict.R`, the validation-debt register, and
  `docs/dev-log/check-log.md`. The commands are recorded below instead.

## Found while testing, not changed

On some fits that stop without converging, `fit$report$eta` is not the report
at `tmb_obj$env$last.par.best`, which is the parameter vector
`predict(newdata = )` reads for every tier. Measured on
`value ~ 0 + trait + (0 + trait):xc + spatial_dep(1 + xc | coords)` with a
standard-normal `xc`, 12 covariate seeds: 11 fits stopped with convergence
code 1, and on 3 of those `max|predict(newdata) - fit$report$eta|` was
`2.4e-9` to `1.3e-8`. In all 12 the rebuilt predictor equals
`tmb_obj$report(last.par.best)$eta` with `max|diff| == 0`, and the gap is
exactly `max|fit$report$eta - report(last.par.best)$eta|`. So the difference
is between two parameter vectors, not in the reshape. Whether it also occurs
with the tiers restored earlier was not measured.

## Checks

```sh
export NOT_CRAN=true   # without it every test in the file skips
Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-spde_dep_slope-predict-newdata-1138.R")'
```

- New file on this branch: FAIL 0 / WARN 0 / SKIP 0 / PASS 28.
- New file against `origin/main` `R/` (change stashed): FAIL 14.
- Neighbouring predict / spatial files on this branch: see the pull request
  body for the list and counts.
- Measured, not pinned: exact 0 on training rows for the long spelling
  `spatial_dep(0 + trait + (0 + trait):x | coords)`.

Not run: `devtools::check()`, the full test suite, macOS, Windows.

## Follow-up

- After the tier pull requests land, update the `getREsd()` and `predict()`
  roxygen inventories and the `*_slope` comment in `test-isdm-predict.R` in
  one pass.
- The `fit$report` versus `last.par.best` difference on non-converged fits
  needs an owner.
