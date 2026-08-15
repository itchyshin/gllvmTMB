# Arc0 masked-cell accuracy probe for `predict_missing()`

First masked-cell accuracy probe. Uses the INSTALLED `gllvmTMB` package
(no `devtools::load_all` -- a DLL compile runs concurrently in this
worktree). Scripts: `dev/missing-accuracy-dgp.R` (DGP + mask generators),
`dev/missing-accuracy-arc0-recovery.R` (driver). Output:
`dev/missing-accuracy/arc0-cells.csv`.

## Design (pre-registered, written before running the grid)

**Binding protocol.** Fits use `missing = gllvmTMB::miss_control(response =
"include")` (under `"drop"`, masked cells are removed and `predict_missing()`
returns zero rows). The fit-shape grammar is copied from
`tests/testthat/test-missing-response-nongaussian.R` and
`tests/testthat/test-missing-response-cellwise.R`: wide `traits(...)`
left-hand side, `unit = <site column>`, `latent(1 | unit, d = K, unique =
FALSE)` for the loadings-only wide-shorthand spelling (the long-format
analogue is `latent(0 + trait | unit, d = 1, unique = FALSE)` in the
nongaussian test file). The truth join is by `original_row` **plus** trait
id (never row alone), and the joined row count is asserted equal to the
designed mask size (no silent join loss). `predict_missing(fit, type =
"response")`; all metrics are on the response scale.

**DGP.** Wide then stacked long, as the tests do. `n_units = 50`, `p_traits
= 25`, `q_true = 2`. Loadings `Lambda[j,k] ~ N(0, 0.7^2)`; latent scores `U ~
N(0,1)`; both draws shared between the two families' generative recipes
(same latent contribution `UL = U %*% t(Lambda)`).

- **Gaussian**: per-trait intercept `b0 ~ N(0, 0.5^2)`; `eta = b0 + UL`;
  per-trait residual sd `sigma_j ~ lognormal(meanlog = log(0.5), sdlog =
  0.3)` (an ANISOTROPIC, per-trait DGP). The model we FIT uses ordinary
  loadings-only `latent(..., unique = FALSE)` -- no `diag(psi)` term -- so
  its residual noise comes from the family's own (isotropic, single-scalar)
  gaussian dispersion. **This DGP/fit mismatch is deliberate, as-shipped
  honesty**: the shipped gaussian fit cannot represent anisotropic residual
  variance, and this probe does not paper over that by fitting a
  richer-than-shipped model.
- **Poisson**: same latent contribution `UL`; the per-trait intercept is
  solved directly (`b0_pois[j] = log(target_j) - log(mean(exp(UL[,j])))`)
  so that per-trait mean counts span roughly 1-12 on the log link
  (`target_j = seq(1, 12, length.out = 25)`).

**Missingness mechanisms (4).**

1. `mcar05` -- 5% of cells, uniform at random.
2. `mcar20` -- 20% of cells, uniform at random.
3. `trait_clustered` -- 10% overall mass; 60% of it concentrated inside 5
   randomly chosen trait columns, the remaining 40% scattered (MCAR-like)
   over the rest of the grid.
4. `unit_clustered` -- 10% overall mass; 60% of it concentrated inside a
   block of 10 randomly chosen units, the remaining 40% scattered.

Guard (enforced by retry, up to 200 attempts per mask draw): every trait
keeps >= 5 observed cells; every unit keeps >= 3 observed cells.

**Seeds.** 10 reps per cell, `seed = 1000*family_idx + 100*mech_idx + rep`
(`family_idx`: gaussian = 1, poisson = 2; `mech_idx`: mcar05 = 1, mcar20 =
2, trait_clustered = 3, unit_clustered = 4). 2 families x 4 mechanisms x 10
reps = 80 fits (main include-fits; each cell also fits a complete-data
oracle refit for the upper-bound baseline, so up to 160 `gllvmTMB()` calls
total).

**Baselines per cell.**

- (a) trait-mean fill from observed cells (the must-beat baseline):
  `mean(wide_masked[[trait]], na.rm = TRUE)`, looked up per masked cell.
- (b) complete-data oracle refit: the same spec fit on the UNMASKED data,
  read off at the same cells via `predict(oracle_fit, type =
  "response")$est[model_row]` (the upper bound).

**Metrics, failure-inclusive.** Every fit records `converged` (nlminb
`opt$convergence == 0` AND finite `logLik`); denominators for aggregate
summaries include only converged fits, but the attempted/converged counts
themselves are reported so failures are visible, not hidden by the
denominator. Per fit, per-trait RMSE and correlation are computed over that
trait's masked cells, then averaged (unweighted) across traits present to
give one fit-level `r` and `rmse` (Pearson r for gaussian, Spearman rho for
poisson; response-scale RMSE for both). `rmse_meanfill` and `rmse_oracle`
are computed by the identical per-trait-then-averaged procedure, for an
apples-to-apples RMSE ratio. Across the 10 replicate seeds in a cell, the
summary table reports the mean and Monte-Carlo SE (`sd / sqrt(n)`) of the
fit-level metrics.

**Stop rules.**

1. Sanity pre-run FIRST: 2 fits (gaussian mcar20 seed 1201; poisson mcar20
   seed 2201). Confirm each takes < 2 min wall, mask accounting is exact,
   and estimates are finite. Abort and report if broken.
2. If gaussian MCAR cells (mcar05, mcar20) do NOT beat trait-mean fill
   (mean RMSE across converged reps not strictly less than mean
   RMSE-meanfill), STOP after that cell and report -- diagnose before
   running the rest of the grid.
3. D-139: estimated core wall time ~18 min. If the total run exceeds ~40
   min, STOP and report rather than quietly continuing.

**Reproducibility check.** Re-run the seed-1201 fit after the grid and
confirm the metrics columns of its CSV row are identical (within `1e-8`)
to the row produced during the grid.

## Arc0 results

Fits attempted (unique, main include-fits): 80. Converged: 80.
Total wall time: 1.0 min.
Stop rule fired: none
Reproducibility check (seed 1201): PASS

### Per-cell summary (converged fits only; metric = Pearson r for gaussian, Spearman rho for poisson)

| family | mechanism | n_attempt | n_converged | mean metric | se metric | mean RMSE | se RMSE | RMSE meanfill | RMSE oracle | RMSE ratio vs meanfill |
|---|---|---|---|---|---|---|---|---|---|---|
| gaussian | mcar05 | 10 | 10 | 0.658 | 0.043 | 0.471 | 0.018 | 0.979 | 0.405 | 0.482 |
| gaussian | mcar20 | 10 | 10 | 0.738 | 0.020 | 0.540 | 0.013 | 1.029 | 0.454 | 0.525 |
| gaussian | trait_clustered | 10 | 10 | 0.655 | 0.036 | 0.509 | 0.015 | 0.907 | 0.434 | 0.562 |
| gaussian | unit_clustered | 10 | 10 | 0.718 | 0.027 | 0.561 | 0.020 | 0.985 | 0.461 | 0.569 |
| poisson | mcar05 | 10 | 10 | 0.623 | 0.046 | 3.052 | 0.694 | 6.942 | 1.813 | 0.440 |
| poisson | mcar20 | 10 | 10 | 0.680 | 0.013 | 2.774 | 0.096 | 6.100 | 1.962 | 0.455 |
| poisson | trait_clustered | 10 | 10 | 0.610 | 0.052 | 2.541 | 0.138 | 5.484 | 1.846 | 0.463 |
| poisson | unit_clustered | 10 | 10 | 0.604 | 0.031 | 2.832 | 0.124 | 6.306 | 1.977 | 0.449 |

## Session info

```
packageVersion(gllvmTMB): 0.6.0
R version 4.6.0 (2026-04-24)
Platform: aarch64-apple-darwin23
Running under: macOS Tahoe 26.6.1

Matrix products: default
BLAS:   /Library/Frameworks/R.framework/Versions/4.6/Resources/lib/libRblas.0.dylib 
LAPACK: /Library/Frameworks/R.framework/Versions/4.6/Resources/lib/libRlapack.dylib;  LAPACK version 3.12.1

locale:
[1] en_AU/en_AU/en_AU/C/en_AU/en_AU

time zone: America/Edmonton
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
[1] gllvmTMB_0.6.0

loaded via a namespace (and not attached):
 [1] assertthat_0.2.1 tidyr_1.3.2      R6_2.6.1         Matrix_1.7-5    
 [5] tidyselect_1.2.1 lattice_0.22-9   magrittr_2.0.5   glue_1.8.1      
 [9] tibble_3.3.1     pkgconfig_2.0.3  dplyr_1.2.1      generics_0.1.4  
[13] lifecycle_1.0.5  TMB_1.9.21       cli_3.6.6        grid_4.6.0      
[17] vctrs_0.7.3      withr_3.0.3      compiler_4.6.0   purrr_1.2.2     
[21] pillar_1.11.1    rlang_1.2.0     
```
