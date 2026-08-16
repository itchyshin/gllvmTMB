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

---

# Arc0b: binomial, ordinal_probit, delta_lognormal, multinomial

Follow-up slice, approved scope: {gaussian, poisson, binomial, ordinal, delta,
multinomial}; Arc0 covered gaussian/poisson above. This section covers the
remaining four.

**Provenance / engine change from Arc0.** This slice uses
`devtools::load_all(".")` in the worktree, NOT the installed package. The
installed `gllvmTMB` 0.6.0 refuses `multinomial()` NA responses
(`"multinomial(): missing categorical responses are not supported in this
release."`, confirmed by direct smoke test); the lane's multinomial NA
admission exists only in this worktree's source. The worktree's `src/`
`.so`/`.o` were already built (mtime 13:41, no concurrent compile running,
confirmed via `ps`), so `load_all()` was a pure R-source reload (~3s), no
recompilation.

## Design (pre-registered, written before running the Arc0b grid)

Same binding protocol as Arc0: `missing = miss_control(response = "include")`;
`predict_missing()`; failure-inclusive accounting; join by cell identity, not
row alone; a reproducibility re-run of one seed. Grammar for each family is
copied from the tests named below (wide `traits()` shorthand where it exists
for that family; long explicit formula for multinomial, which has no
multi-trait wide structure in the reference test).

**Families, grammar source, and metrics.**

1. **binomial** (Bernoulli, logit). Wide `traits(...) ~ 1 + latent(1 | unit,
   d = 1, unique = FALSE)`, `family = binomial()` -- the loadings-only
   spelling from `test-missing-response-nongaussian.R`'s long-format analogue,
   applied through the wide shorthand validated for gaussian/poisson in Arc0.
   `n_units = 60`, `p_traits = 8`, `q = 1`. DGP: `eta = b0 + U %*% t(Lambda)`,
   `Lambda ~ N(0, 0.7^2)`, `b0 ~ N(0, 0.5^2)`, `p = plogis(eta)`, `y ~
   Bernoulli(p)`. Metrics: AUC (`gllvmTMB:::.cv_auc`, Mann-Whitney closed
   form) + Brier score (`mean((p_hat - y)^2)`), both vs a trait-prevalence-fill
   baseline (`mean(observed y)` per trait, used as the constant score/
   probability for that trait's masked cells).
2. **ordinal_probit** (K = 4 ordered categories, taus fixed at DGP truth `(0,
   0.6, 1.3)`, matching `test-tiers-ordinal.R`'s convention that `tau_1 = 0`
   is the identification anchor). Wide `traits(...) ~ 1 + unique(1 | unit)`
   -- the plain per-trait, per-unit diagonal random intercept, matching the
   `unique(0 + trait | unit)` "B tier" of `test-tiers-ordinal.R` through the
   wide shorthand (`unique(1 | unit)` validated directly by a pre-flight
   smoke test in this session). `n_units = 60`, `p_traits = 6`. DGP:
   `b0 ~ N(0, 0.3^2)` per trait, `u ~ N(0, 0.5^2)` per (unit, trait), `y* = b0
   + u + N(0,1)`, cut at the fixed taus.
   **Metric choice -- documented per the brief's instruction to inspect
   `predict_missing()` for ordinal FIRST.** `predict_missing(fit, type =
   "response")` for an `ordinal_probit` fit does NOT error, but it applies
   the scalar link-inverse (`pnorm(eta)`) elementwise -- a single number that
   is not a real category probability or expected category for a K > 2
   response, so it is not an honest quantity here and is NOT used. Instead:
   `predict_missing(fit, type = "link")` gives the fitted liability `eta`,
   and `extract_cutpoints(fit)` gives the fitted free cutpoints `tau_2,
   tau_3` per trait (the engine fixes `tau_1 = 0`, confirmed by inspecting
   `extract_cutpoints()`'s output on a fitted model: only `cutpoint_index in
   {2,3}` rows are returned). Category probabilities are computed by hand as
   `P(k) = Phi(tau_k - eta) - Phi(tau_{k-1} - eta)` with `tau_0 = -Inf, tau_K
   = +Inf`; the modal category is `argmax_k P(k)`. Metrics: Spearman rho of
   `eta_hat` vs the true category (no baseline pairing -- a constant baseline
   score has undefined rank correlation, so this metric is reported without a
   baseline column) + modal-category accuracy vs the trait's modal-category
   baseline (the most frequent OBSERVED category for that trait).
3. **delta_lognormal** (fixed-effects only, shared-predictor hurdle). Wide
   `traits(...) ~ 1` -- no random/latent term, matching
   `test-delta-lognormal-recovery.R`'s `value ~ 0 + trait` fixed-effects-only
   formula through the wide shorthand (validated by pre-flight smoke test).
   `n_units = 100`, `p_traits = 6`. DGP: per-trait `mu_t = seq(0.3, 2.0,
   length.out = 6)`, `p_pres = plogis(mu_t)`, presence ~ Bernoulli, positive
   part ~ `rlnorm(meanlog = mu_t, sdlog = 0.6)` -- the exact shared-predictor
   recipe of the recovery test. Metrics: response-scale RMSE vs a trait-mean
   fill baseline (mean of the OBSERVED response, zeros included) + occurrence
   AUC (zero vs nonzero), where the model's presence-probability score is
   `plogis(eta_hat)` from `predict_missing(type = "link")` (matching the
   recovery test's own `mean(1/(1+exp(-eta)))` presence-rate check) against a
   trait-prevalence-fill baseline score.
4. **multinomial** (K = 3, n = 250, fixed effects + x). Long format `value ~
   0 + trait + (0 + trait):x`, `trait = "trait"`, `unit = "unit"`, `family =
   multinomial()` -- copied verbatim from
   `tests/testthat/test-multinomial-missing-response.R`'s `.make_multinomial_missing()`
   (`b0 = c(0.5, -0.4)`, `b1 = c(1.0, -0.8)`). Masking is applied to the
   ORIGINAL long response column before the engine's internal K-1 pseudo-row
   expansion, so the group-uniform mask invariant (an NA categorical value
   masks every one of its K-1 contrast rows together) holds automatically.
   **Finding, documented per the same "inspect first" discipline.**
   `predict_missing()`'s `original_row` column for a multinomial fit does
   NOT map back to the user's original per-unit row: `fit$missing_data$original_row`
   either does not exist or has the wrong length for this family's internal
   expansion, so the extractor's length-mismatch fallback fires and
   `original_row` silently equals `model_row` (the internal, expanded
   pseudo-row index) instead -- confirmed by a pre-flight smoke test (masked
   original rows 3/10/25 in a 40-row fixture returned `original_row =
   5,6/19,20/49,50`, i.e. `2*row - 1, 2*row`, not `3,10,25`). The RELIABLE
   cell-identity key for multinomial is instead the `unit` column (which does
   correctly carry the user's original unit label) plus the category parsed
   from the `trait` column suffix (`"morph:2"` -> category 2; category 1 is
   the implicit reference and never appears as its own row). The join and
   accounting assertions below use `unit`, not `original_row`. Per-unit
   category probabilities are computed by hand: softmax over `(0, eta_2,
   eta_3)` (the reference category's contrast fixed at 0). Metrics:
   modal-category accuracy (`argmax` of the softmax) vs a marginal-frequency
   baseline (`argmax` of the observed marginal category frequency, the same
   constant prediction for every masked unit) + multiclass Brier score
   (`sum_k (p_hat_k - 1{y=k})^2`, averaged over masked units) vs the same
   marginal-frequency baseline used as a constant probability vector.

**Mechanisms (2, per the approved reduced scope): `mcar20` (20% of cells,
uniform) and `unit_clustered` (10% overall, 60% concentrated in a block of
units, 40% scattered) -- both reusing Arc0's `make_mask()` generator
unchanged in its default behaviour. The generator gained two new, additive,
backward-compatible parameters (`n_cluster_units`, `n_cluster_traits`,
defaults 10/5 identical to Arc0's hardcoded values) purely to support
multinomial's single-trait (`p_traits = 1`) grid: `unit_clustered` there uses
`n_cluster_units = 25` (so the cluster pool can hold the designed cluster
count) and `min_obs_unit = 0` (the "keep >= 3 observed cells per unit" guard
is structurally inapplicable when a unit has only 1 possible cell). Arc0's
own call sites and reproducibility check are unaffected by this addition
(same defaults, same call sites).

**Seeds.** `seed = 1000*family_idx + 100*mech_idx + rep`, mirroring Arc0's
scheme (`family_idx`: binomial = 1, ordinal_probit = 2, delta_lognormal = 3,
multinomial = 4; `mech_idx`: mcar20 = 1, unit_clustered = 2; `rep` = 1..10).
4 families x 2 mechanisms x 10 reps = 80 fits (no oracle refit in this slice
-- the brief's per-family metric spec pairs each metric with exactly one
baseline, unlike Arc0's gaussian/poisson which also fit a complete-data
oracle; this is a deliberate scope reduction, not a deviation).

**Failure-inclusive accounting / join asserts / reproducibility, same
discipline as Arc0**: every fit records `converged`; `nrow(predict_missing())`
is asserted equal to the designed mask size (or, for multinomial, to
`n_masked_units * (K-1)`) with a hard `stopifnot`; cell identity is asserted
by `setequal()` on the join key (`original_row + trait`, or for multinomial
the `unit` set) before any metric is computed. One seed
(binomial/mcar20/seed 1101) is re-run after the grid and its CSV row compared
for exact reproducibility.

**Deviation discovered live (fixed before the reported run).** The first
Arc0b driver run errored on `delta_lognormal`/`unit_clustered` with
`make_mask: could not satisfy guards after 200 attempts`. Cause: `delta_lognormal`
uses `n_units = 100` (larger than binomial's/ordinal's 60) with the same
`p_traits = 6`, so Arc0's fixed 10-unit cluster block concentrated 60% of
that block's 60 cells under mask -- far denser than binomial's/ordinal's
~36% -- and tripped the "each unit keeps >= 3 observed" guard. Fixed by
widening `delta_lognormal`'s `n_cluster_units` to 20 (comparable block
density to the other three families, ~30%). No other family needed this
override. The reported run below is the one AFTER this fix.

**Stop rules.** D-139: estimated total < 25 min (these are small,
seconds-per-fit fixtures, matching Arc0's own experience that fits ran far
faster than estimated); if the run exceeds ~40 min, STOP and report rather
than continuing.

## Arc0b results

Fits attempted (unique): 80. Converged: 80.
Grid wall time: 1.2 min.
Stop rule fired: none
Reproducibility check (seed 1101): PASS

### Per-cell summary (converged fits only)

| family | mechanism | n_attempt | n_converged | metric1 | mean | baseline | metric2 | mean | baseline |
|---|---|---|---|---|---|---|---|---|---|
| binomial | mcar20 | 10 | 10 | AUC | 0.629 (se 0.020) | 0.624 | Brier | 0.249 | 0.236 |
| binomial | unit_clustered | 10 | 10 | AUC | 0.573 (se 0.026) | 0.531 | Brier | 0.261 | 0.256 |
| ordinal_probit | mcar20 | 10 | 10 | Spearman_rho | 0.120 (se 0.063) | NA | modal_accuracy | 0.479 | 0.481 |
| ordinal_probit | unit_clustered | 10 | 10 | Spearman_rho | 0.195 (se 0.062) | NA | modal_accuracy | 0.514 | 0.514 |
| delta_lognormal | mcar20 | 10 | 10 | RMSE | 3.464 (se 0.227) | 3.434 | occurrence_AUC | 0.643 | 0.645 |
| delta_lognormal | unit_clustered | 10 | 10 | RMSE | 3.277 (se 0.166) | 3.271 | occurrence_AUC | 0.702 | 0.680 |
| multinomial | mcar20 | 10 | 10 | modal_accuracy | 0.612 (se 0.023) | 0.524 | multiclass_Brier | 0.500 | 0.619 |
| multinomial | unit_clustered | 10 | 10 | modal_accuracy | 0.616 (se 0.017) | 0.504 | multiclass_Brier | 0.510 | 0.624 |
