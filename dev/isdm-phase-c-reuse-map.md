# Phase C reuse map — spatially structured / covariate-correlated PO bias

Read: `dev/isdm-gate-harness.R` (330 lines), `dev/isdm-gate-campaign.R` (620 lines),
`dev/isdm-gate-analyse.R` (482 lines, not detailed below — post-processing only),
`dev/isdm-plumbing.R` (407 lines), `dev/isdm-probe.R` (264 lines, exploratory, no
reusable functions — family-mixing probes only).

**IMPORTANT CAVEAT:** `isdm-gate-harness.R`'s `simulate_cell()`/`fit_cell()`/`score_fit()`/
`run_grid()` are the **mixed-curvature loading gate** (T=6 species sharing one latent
factor across Poisson/Bernoulli blocks) — NOT an ISDM PO/PA bias-recovery harness. There is
**no `gamma[d,j]` bias term anywhere in this file.** The actual PO/PA generative bias
mechanism the task brief asks about lives in `dev/isdm-plumbing.R::sim_isdm()`, which has
no harness wrapper (`run_grid` etc.) at all — it's a standalone script with inline T1–T4
blocks. Phase C needs to either (a) port `sim_isdm()`'s bias generation into a new
`simulate_cell()`-shaped function reusing the harness's `fit_cell`/`score_fit`/`run_grid`
skeleton, or (b) harness-ify `isdm-plumbing.R` directly. Recommendation: (a) — the harness
in isdm-gate-harness.R already has the run_grid/score_fit machinery Phase C needs; the ISDM
bias generative process from isdm-plumbing.R needs to be spliced in.

## 1. `simulate_cell()` bias mechanism — `isdm-gate-harness.R` and `isdm-plumbing.R`

- **`isdm-gate-harness.R::simulate_cell()`** (lines 75–124): no bias term at all. This is
  the species-loading gate, not the ISDM PO/PA study. `eta = log_t + Lambda[j]*u + delta`;
  `delta ~ N(0, psi_j)` is a per-species nugget, not a PO-specific bias.
- **`isdm-plumbing.R::sim_isdm()`** (lines 53–81): this is the file with the actual PO bias.
  ```r
  sim_isdm <- function(seed, n_cell = 400, b0 = TRUE_B0, b = TRUE_B, a0 = TRUE_A0,
                        alpha = TRUE_ALPHA, lambda_load = TRUE_LAMBDA, sigma_u = TRUE_SIGU)
  ```
  Bias generation (lines 56–63):
  ```r
  w <- rnorm(n_cell)             # PO-only bias covariate, i.i.d. N(0,1)
  ...
  eta_po <- log(A) + b0 + x*b + xi + a0 + w*alpha
  ```
  **Answer to Q1: the bias is `a0 + w*alpha`, a per-site (not per-source-constant, not
  per-species) LINEAR term** — `a0` is a scalar intercept shift and `alpha` is a scalar
  slope on `w`, a covariate drawn **independently of `x`** (`w <- rnorm(n_cell)`, no
  correlation with `x <- rnorm(n_cell)` built in). It is not "gamma[d,j]" (there is no
  species/source index on the bias — only one species `sp1` exists in this file) and it is
  not literally a constant either — it varies per site through `w`, but `w` itself has no
  spatial structure (no coordinates, no smooth field, no correlation with the environmental
  covariate `x`).

## 2. Where to inject spatial structure / covariate correlation

- Target function: `sim_isdm()` in `isdm-plumbing.R`, specifically line 57
  (`w <- rnorm(n_cell)`) and line 63 (`eta_po <- ... + a0 + w * alpha`).
- **New arguments needed** on `sim_isdm()` (or its ported `simulate_cell()`-shaped
  successor):
  - `bias_mode = c("iid", "spatial", "covariate_correlated")`
  - `bias_strength` (replaces/scales `alpha`) — numeric, the effect size of the bias term
  - for `"spatial"`: cell coordinates do not currently exist anywhere in the harness or
    plumbing file — `n_cell` sites are indexed 1..n_cell with no (s1,s2) location. Would
    need to add `coords <- cbind(runif(n_cell), runif(n_cell))` and generate `w` as a
    Gaussian-process / Matern draw over those coordinates (e.g. via `fields::rmvn` or a
    cheap kernel-matrix Cholesky) — nothing in this harness currently builds a spatial
    covariance matrix; `R/mesh.R`/`R/crs.R` (package-level SPDE helpers, out of scope for
    dev/) are the only spatial machinery that exists in the repo.
  - for `"covariate_correlated"`: simplest — replace `w <- rnorm(n_cell)` with
    `w <- rho * x + sqrt(1 - rho^2) * rnorm(n_cell)` and add a `rho` (correlation with `x`)
    argument. This is a small, local change and needs no new dependency.
- Everything downstream (`eta_po`, `y_po`, `df_po`) is unchanged in shape — `w` is already
  threaded through to `df_po$w` (line 70) and into the fitted model via `w * alpha`, so as
  long as the new `w` is still an `n_cell`-length numeric vector, `fit_cell`-equivalent code
  needs no change beyond passing the new args through.

## 3. Does `score_fit()` compute R and compare to planted? Which columns?

- **In `isdm-gate-harness.R::score_fit()`** (lines 184–285) and its override in
  `isdm-gate-campaign.R::score_fit()` (lines 89–175): **yes**, both compute the estimated
  correlation matrix and compare to planted, via:
  ```r
  Sigma_res <- extract_Sigma(fit, level = "unit", part = "total", link_residual = "none")
  Sigma_hat <- Sigma_res$Sigma;  R_hat <- Sigma_res$R
  ```
  compared against `R_true <- stats::cov2cor(Sigma_true)` with
  `Sigma_true <- outer(Lambda_true, Lambda_true) + diag(psi_true)`.
  Reported columns: `off_diag_rmse`, `off_diag_cor` (both computed over
  `R[upper.tri(R)]`), `diag_rmse` (over `diag(Sigma)`), plus `lambda_rmse`/`lambda_cor`/
  `lambda_sign` (loadings), `comm_rmse`/`comm_cor` (communality, U1 arm only),
  `n_heywood_psi`, `n_heywood_loading` (boundary/runaway counts), `nll`, `convergence`,
  `pdHess`, `diag_B_skip`, `fit_error`.
  **This machinery is species-loading-oriented (T=6 species, one Sigma).** For an ISDM
  bias study there is only ONE species (`sp1`) and the quantity of interest is bias in
  `b0`/`b` (fixed effects), not a T x T correlation matrix — this scoring function is
  **not directly applicable** to the PO/PA bias question; it would need a different
  scorer modeled on `isdm-probe.R`'s `bias <- mean(b_hat) - TRUE_B` pattern (see
  `isdm-plumbing.R` lines 253/260 area) rather than reused as-is. `extract_Sigma`/
  `extract_loadings` calls themselves are reusable utility calls, just scored against a
  different target.

## 4. `run_grid()` contract — arbitrary config columns?

- Signature (harness lines 318–330):
  ```r
  run_grid(config_df, planted = PLANTED, control = NULL, n_cores = 1L,
           backend = c("serial", "mclapply"))
  ```
  It **only** does `cfgs <- split(config_df, seq_len(nrow(config_df)))` then
  `lapply/mclapply(cfgs, run_one, planted = planted, control = control)` — it does not
  inspect or validate `config_df`'s columns itself.
- **BUT `run_one()`** (lines 296–310) is NOT arbitrary — it hard-codes reading
  `cfg$cell, cfg$n_units, cfg$prevalence, cfg$seed, cfg$arm` and passes them positionally to
  `simulate_cell()` and `fit_cell()`. **Adding a new column like `bias_strength` to
  `config_df` requires editing `run_one()`** to read `cfg$bias_strength` and thread it into
  `simulate_cell(...)`/`sim_isdm(...)`. `run_grid()` itself needs no change (it's a generic
  dispatcher), but `run_one()` is the choke point that must be extended — it is NOT already
  parametrised to forward arbitrary extra config columns.

## 5. Hard-coded d=1 / T=6 in the harness

- **T=6 (`T_SP <- 6L`, harness line 43)** is hard-coded as a module-level constant and used
  throughout: `PLANTED$Lambda`/`PLANTED$psi` are length-6 named vectors (line 48–51), loops
  `for (j in seq_len(Tn))` in `simulate_cell` derive `Tn <- length(planted$Lambda)` so
  changing `PLANTED` to a different length *would* propagate through `simulate_cell`, but
  `isdm-gate-campaign.R`'s `par_psi()` (line 69–73) does `rep(NA_real_, T_SP)` directly
  against the global constant, not `length(planted$psi)` — so T_SP and `planted` must stay
  in sync manually if T changes.
- **d=1 is hard-coded** in `fit_cell()`'s formula string (harness line 149):
  `"value ~ 0 + trait + latent(0 + trait | cell, d = 1, unique = %s)"` — literal `d = 1`,
  not parametrised. Changing d requires editing the sprintf string or adding a `d` argument
  to `fit_cell()`. Several downstream analyses assume d=1 explicitly: `align_sign()` /
  `lambda_rmse_aligned()` (campaign lines 43–55) do a **sign flip only** ("at d = 1 the
  optimal orthogonal transform is a sign") — these would need a real Procrustes rotation
  fix for d>1, not just a sign. `idx_lam <- which(names(p_hat) == "theta_rr_B")` assumes a
  single loading vector per species (works for any d>1 too since theta_rr_B would just be
  longer per species, but the sign-only alignment breaks).
- **For the ISDM bias study specifically**: since it is single-species (`sp1` only, no
  `latent()` term needed at all in `isdm-plumbing.R`'s T1 fixed-effects-only cross-check,
  and a `latent(1 | cell)` scalar random intercept in later T-blocks), T=6/d=1 hard-coding
  in `isdm-gate-harness.R` is **irrelevant** — Phase C should build its own small
  `simulate_cell`/`fit_cell`/`score_fit` trio modeled on `isdm-plumbing.R::sim_isdm()`
  rather than force-fit the T=6 species-loading harness.
