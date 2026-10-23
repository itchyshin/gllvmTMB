## #1379 (remainder): the Wald readers other than extract_repeatability()
## must not hand back NA / NaN intervals, or ordinary-looking ones, from a
## covariance that is non-finite or from a Hessian that is not
## positive-definite. Same contract as test-extract-repeatability-wald-pdhess.R:
## fit once, then overwrite sd_report$cov.fixed / pdHess on the fit, so the
## cases do not depend on what the optimiser or BLAS returns.

finite_cov <- function(fit) {
  diag(1e-3, nrow(fit$sd_report$cov.fixed))
}

## ---- communality -------------------------------------------------------

.w1379 <- new.env(parent = emptyenv())

communality_fit_1379 <- function() {
  if (is.null(.w1379$comm)) {
    set.seed(2026002L)
    T_n <- 6L
    sim <- gllvmTMB::simulate_site_trait(
      n_sites = 40L, n_species = 1L, n_traits = T_n,
      mean_species_per_site = 1, n_predictors = 1,
      alpha = rep(0, T_n), beta = matrix(0, nrow = T_n, ncol = 1L),
      Lambda_B = matrix(c(1.5, 1.2, 0.9, 0.6, 0.3, 0.0), T_n, 1L),
      psi_B = rep(1.0, T_n), sigma2_eps = 0, seed = 2026002L
    )
    df <- sim$data
    df$value <- stats::rbinom(nrow(df), 1L, stats::pnorm(df$value))
    .w1379$comm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 1) +
        unique(0 + trait | site),
      data = df, family = stats::binomial(link = "probit")
    )))
  }
  .w1379$comm
}

test_that("Wald communality errors when the covariance is all non-finite", {
  skip_on_cran()
  fit <- communality_fit_1379()
  fit$sd_report$cov.fixed[] <- NaN
  expect_error(
    gllvmTMB:::.communality_wald_ci(fit, tier = "unit", trait_idx = 1L),
    class = "gllvmTMB_confint_nonfinite_se"
  )
  expect_error(
    extract_communality(fit, level = "unit", ci = TRUE, method = "wald"),
    class = "gllvmTMB_confint_nonfinite_se"
  )
})

test_that("Wald communality warns, naming pdHess, on a finite non-PD Hessian", {
  skip_on_cran()
  fit <- communality_fit_1379()
  fit$sd_report$cov.fixed <- finite_cov(fit)
  fit$sd_report$pdHess <- FALSE
  expect_warning(
    ci <- gllvmTMB:::.communality_wald_ci(fit, tier = "unit", trait_idx = 1L),
    class = "gllvmTMB_wald_nonpd_hessian"
  )
  expect_warning(
    gllvmTMB:::.communality_wald_ci(fit, tier = "unit", trait_idx = 1L),
    "pdHess"
  )
  expect_named(ci, c("estimate", "lower", "upper"))
})

test_that("Wald communality is silent when the Hessian is positive-definite", {
  skip_on_cran()
  fit <- communality_fit_1379()
  fit$sd_report$cov.fixed <- finite_cov(fit)
  fit$sd_report$pdHess <- TRUE
  expect_no_warning(
    gllvmTMB:::.communality_wald_ci(fit, tier = "unit", trait_idx = 1L)
  )
})

## ---- phylogenetic signal ----------------------------------------------

phylo_signal_fit_1379 <- function() {
  if (is.null(.w1379$phy)) {
    testthat::skip_if_not_installed("ape")
    set.seed(7L)
    n_sp <- 40L; Tn <- 4L
    tree <- ape::rcoal(n_sp)
    tree$tip.label <- paste0("sp", seq_len(n_sp))
    sim <- gllvmTMB::simulate_site_trait(
      n_sites = 30L, n_species = n_sp, n_traits = Tn,
      mean_species_per_site = n_sp, Cphy = ape::vcv(tree, corr = TRUE),
      sigma2_phy = rep(1.5, Tn), sigma2_sp = rep(0.7, Tn),
      Lambda_B = matrix(0, Tn, 1L), psi_B = rep(0, Tn),
      sigma2_eps = 0, seed = 7L
    )
    df <- sim$data
    levels(df$species) <- tree$tip.label
    df$value <- stats::rbinom(nrow(df), 1L, stats::pnorm(df$value))
    .w1379$phy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_unique(species) + unique(0 + trait | species),
      data = df, phylo_tree = tree, cluster = "species",
      family = stats::binomial(link = "probit"), silent = TRUE
    )))
  }
  .w1379$phy
}

test_that("Wald phylo signal errors when the covariance is all non-finite", {
  skip_on_cran()
  fit <- phylo_signal_fit_1379()
  fit$sd_report$cov.fixed[] <- NaN
  expect_error(
    gllvmTMB:::.phylo_signal_wald_ci(fit),
    class = "gllvmTMB_confint_nonfinite_se"
  )
})

test_that("Wald phylo signal warns, naming pdHess, on a finite non-PD Hessian", {
  skip_on_cran()
  fit <- phylo_signal_fit_1379()
  fit$sd_report$cov.fixed <- finite_cov(fit)
  fit$sd_report$pdHess <- FALSE
  expect_warning(
    out <- gllvmTMB:::.phylo_signal_wald_ci(fit),
    class = "gllvmTMB_wald_nonpd_hessian"
  )
  expect_warning(gllvmTMB:::.phylo_signal_wald_ci(fit), "pdHess")
  expect_true(all(c("H2", "lower", "upper") %in% names(out)))
})

test_that("Wald phylo signal is silent when the Hessian is positive-definite", {
  skip_on_cran()
  fit <- phylo_signal_fit_1379()
  fit$sd_report$cov.fixed <- finite_cov(fit)
  fit$sd_report$pdHess <- TRUE
  expect_no_warning(gllvmTMB:::.phylo_signal_wald_ci(fit))
})
