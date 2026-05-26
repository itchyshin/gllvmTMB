## Design 55 §A1 + Design 56 §9.4 — phylo_unique(1 + x | sp) Gaussian recovery
##
## **SKELETON TEST**, gated by `testthat::skip()` until Design 56 Stage 3
## engine work lands (Phases 56.1 → 56.4). Records the test contract in
## code so the recovery target is durable evidence, not just design-doc
## prose. When Phase 56.4 activates, remove the `skip()` calls and run.
##
## What the activated test verifies (per Design 55 §A1):
##
##   1. `phylo_unique(1 + x | sp)` parser accepts the augmented LHS (wide).
##   2. `phylo_unique(0 + trait + (0 + trait):x | sp)` parser accepts the
##      augmented LHS (long).
##   3. Both surfaces produce byte-identical fits (logLik to the unit;
##      Sigma to 1e-6) — the wide↔long contract from Design 55 §3.
##   4. Recovery of σ²_intercept, σ²_slope, and cov(intercept, slope) is
##      within tolerance of the simulated truth (Hadfield A^-1 prior).
##   5. Negative test (Design 56 §7.3): forcing `n_lhs_cols = 1` while
##      the formula carries `(1 + x | sp)` triggers `Rcpp::stop()`
##      rather than silent truncation.
##
## Until the engine work lands, all `test_that()` blocks below
## `skip("Stage 3 engine work in progress; see Design 56 §9")`.

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

skip_until_stage3 <- function() {
  ## Remove this when Phase 56.1 + 56.2 + 56.3 + 56.4 all land.
  testthat::skip(
    "Stage 3 engine work in progress; see docs/design/56-augmented-lhs-engine-stage3.md §9.1-§9.4"
  )
}

## ---- shared simulation fixture ---------------------------------------
##
## Reusable across the four test_that blocks below. Simulates from a
## bivariate (intercept, slope) DGP on a phylogeny: for each species,
## draw (α_sp, β_sp) ~ N(0, Σ_b ⊗ A_phy) where Σ_b is a 2×2 covariance
## and A_phy is the tree-based VCV.
##
## Parameters chosen to give:
##   - σ²_intercept = 0.4
##   - σ²_slope = 0.3
##   - ρ(intercept, slope) = 0.5 → cov = 0.5 * sqrt(0.4 * 0.3) ≈ 0.173
## Mirror the pattern of test-phylo-slope.R for n_sp + n_rep + T choices.

make_phylo_unique_slope_fixture <- function(seed = 2026, n_sp = 60, T = 3, n_rep = 4) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  ## True 2x2 covariance: σ²_α = 0.4, σ²_β = 0.3, ρ = 0.5.
  sigma2_int_true <- 0.4
  sigma2_slope_true <- 0.3
  rho_true <- 0.5
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2, ncol = 2
  )

  ## Draw per-species (α, β) jointly from N(0, Σ_b ⊗ A_phy).
  Sigma_b_chol <- chol(Sigma_b_true)
  raw <- matrix(rnorm(n_sp * 2), nrow = n_sp, ncol = 2)
  ab <- (Lphy_chol %*% raw) %*% Sigma_b_chol
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

  ## Long-format data: one row per (species, trait, rep).
  df_long <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait = factor(paste0("t", seq_len(T)), levels = paste0("t", seq_len(T))),
    rep = seq_len(n_rep)
  )
  df_long$x <- rnorm(nrow(df_long))
  mu_t <- c(2, 1, 0.5)[as.integer(df_long$trait)]
  alpha_sp <- ab[as.character(df_long$species), "alpha"]
  beta_sp <- ab[as.character(df_long$species), "beta"]
  df_long$value <- mu_t + alpha_sp + beta_sp * df_long$x +
    rnorm(nrow(df_long), sd = 0.4)

  list(
    df_long = df_long,
    tree = tree,
    Sigma_b_true = Sigma_b_true,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true,
    cov_true = cov_true,
    ab_true = ab
  )
}

## ---- (1) wide-format LHS: (1 + x | sp) recovery ----------------------

test_that(
  "phylo_unique(1 + x | sp) wide-format: σ²_int, σ²_slope, cov recovered on Gaussian", {
  skip_if_not_ape()
  skip_until_stage3()

  fx <- make_phylo_unique_slope_fixture(seed = 2026)
  ## NOTE: wide-format requires pivoting to traits(...) form. The wide
  ## fixture build is left as part of Phase 56.4 implementation; the
  ## long-format test below is the primary recovery test and the wide
  ## case is verified through the byte-identity test (4) below.

  fit_wide <- gllvmTMB::gllvmTMB(
    ## traits(t1, t2, t3) ~ 0 + trait + phylo_unique(1 + x | species),
    ## data = df_wide, ...  (Phase 56.4 fills in the wide-format build)
    stop("Phase 56.4: wide-format fixture build")
  )

  ## Convergence + diagnostic checks.
  expect_equal(fit_wide$opt$convergence, 0L)

  ## Recovery: pull Σ_b estimate from the report block.
  sd_int_hat <- exp(fit_wide$opt$par[grepl("log_sd_b_intercept", names(fit_wide$opt$par))])
  sd_slope_hat <- exp(fit_wide$opt$par[grepl("log_sd_b_slope", names(fit_wide$opt$par))])
  cor_hat <- tanh(fit_wide$opt$par[grepl("atanh_cor_b", names(fit_wide$opt$par))])
  expect_equal(unname(sd_int_hat^2), fx$sigma2_int_true, tolerance = 0.20)
  expect_equal(unname(sd_slope_hat^2), fx$sigma2_slope_true, tolerance = 0.20)
  expect_equal(unname(cor_hat), fx$rho_true, tolerance = 0.30)
})

## ---- (2) long-format LHS: (0 + trait + (0 + trait):x | sp) recovery ---

test_that(
  "phylo_unique(0 + trait + (0+trait):x | sp) long-format: per-trait σ² recovered on Gaussian", {
  skip_if_not_ape()
  skip_until_stage3()

  fx <- make_phylo_unique_slope_fixture(seed = 2026)

  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species),
    data       = fx$df_long,
    phylo_tree = fx$tree,
    unit       = "species"
  )))

  expect_equal(fit_long$opt$convergence, 0L)

  ## Per-trait Σ_b (T copies stacked). For this DGP all T traits share
  ## the same (α, β) per species, so the per-trait variances should all
  ## be approximately equal — implicit identity check.
  Sigma_hat <- gllvmTMB::extract_Sigma(fit_long, level = "unit", part = "phylo")
  expect_true(!is.null(Sigma_hat))
  ## Phase 56.4: verify the trait-stacked Σ recovers the bivariate
  ## structure (intercept rows + slope rows).
})

## ---- (3) byte-identity check: wide↔long produce identical fits -------

test_that(
  "phylo_unique wide (1 + x | sp) ≡ long (0 + trait + (0+trait):x | sp) byte-identical", {
  skip_if_not_ape()
  skip_until_stage3()

  fx <- make_phylo_unique_slope_fixture(seed = 2026)

  ## Build df_wide from df_long by pivoting trait → columns.
  ## (Phase 56.4 implements the pivot helper; for now this is a sketch.)
  fit_wide <- gllvmTMB::gllvmTMB(
    ## traits(t1, t2, t3) ~ 0 + trait + phylo_unique(1 + x | species), ...
    stop("Phase 56.4: wide-format fixture")
  )
  fit_long <- gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species),
    data       = fx$df_long,
    phylo_tree = fx$tree,
    unit       = "species"
  )

  ## Byte-identity per Design 55 §3 (tolerance 1e-6).
  expect_equal(
    as.numeric(logLik(fit_wide)),
    as.numeric(logLik(fit_long)),
    tolerance = 1e-6
  )
  Sigma_wide <- gllvmTMB::extract_Sigma(fit_wide, level = "unit")
  Sigma_long <- gllvmTMB::extract_Sigma(fit_long, level = "unit")
  ## Compare on the rotation-invariant target Sigma_unit.
  expect_equal(Sigma_wide$Sigma, Sigma_long$Sigma, tolerance = 1e-6)
})

## ---- (4) negative test: silent-collapse prevention (Design 56 §7.3) ---

test_that(
  "phylo_unique(1 + x | sp) with n_lhs_cols=1 forced triggers Rcpp::stop (no silent collapse)", {
  skip_if_not_ape()
  skip_until_stage3()

  fx <- make_phylo_unique_slope_fixture(seed = 2026)

  ## Forced mismatch: the formula carries augmented LHS, but the TMB
  ## data list is hand-edited to set n_lhs_cols = 1. Engine must
  ## Rcpp::stop() rather than silently truncate per Design 56 §7.3.
  expect_error(
    {
      ## Phase 56.4: build the misconfigured TMB data list and force
      ## the fit through the augmented-LHS engine path. The runtime
      ## assertion at the top of the augmented block must abort.
      stop("Phase 56.4: build mismatched n_lhs_cols fixture")
    },
    regexp = "(n_lhs_cols|silent|truncation|aug)"  # exact message TBD
  )
})

## ---- Test contract summary --------------------------------------------
##
## When Phase 56.4 lands (Design 56 §9.4), this file becomes the canonical
## small-simulation check for `phylo_unique(1 + x | sp)` Gaussian, per
## Design 55 §A1 + Design 56 §9.4. It is the first cell of the (4×4×Gaussian)
## APPLICABLE matrix from Design 55 §5. Mirror this file's structure for:
##
##   - tests/testthat/test-phylo-{latent,indep,dep}-slope-gaussian.R
##     (A2 — generalise within phylo for Gaussian, per Design 55 §A2)
##   - tests/testthat/test-animal-slope-gaussian.R
##     (A3 — animal_* byte-equivalence per Design 14 §5; per Design 55 §A3)
##   - tests/testthat/test-spatial-slope-gaussian.R
##     (A4 — spatial_* via SPDE precision; per Design 55 §A4)
##   - tests/testthat/test-relmat-slope-gaussian.R
##     (A5 — user-supplied A; per Design 55 §A5)
##
## Phase B tests follow the same template with `family = binomial()`,
## `family = nbinom2()`, etc.
