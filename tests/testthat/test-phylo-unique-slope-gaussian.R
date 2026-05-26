## Design 55 A1 + Design 56 9.4 -- phylo_unique(1 + x | sp)
## Gaussian recovery for the Phase 56.4 anchor cell.
##
## Alignment table:
##
## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
## | alpha_sp | phylo_unique augmented intercept | alpha,beta ~ N(0, Sigma_b x A_phy) | report$sd_b[1]^2 | 0.4 |
## | beta_sp  | phylo_unique augmented slope     | alpha,beta ~ N(0, Sigma_b x A_phy) | report$sd_b[2]^2 | 0.3 |
## | rho_ab   | phylo_unique augmented covariance | Sigma_b[1,2] via rho = 0.5        | report$cor_b[1]   | 0.5 |
##
## The fixture keeps x identical across traits within each (species, rep)
## cell so the wide traits(...) surface and explicit long surface are the
## same likelihood problem.

skip_if_not_phylo_unique_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  testthat::skip_if_not_installed("tidyr")
}

make_phylo_unique_slope_fixture <- function(
  seed = 5640,
  n_sp = 60L,
  n_traits = 3L,
  n_rep = 4L
) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  sigma2_int_true <- 0.4
  sigma2_slope_true <- 0.3
  rho_true <- 0.5
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L,
    ncol = 2L
  )

  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))

  trait_levels <- paste0("t", seq_len(n_traits))
  df_long <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]

  mu_t <- c(2, 1, 0.5)[as.integer(df_long$trait)]
  alpha_sp <- ab[as.character(df_long$species), "alpha"]
  beta_sp <- ab[as.character(df_long$species), "beta"]
  df_long$value <- mu_t + alpha_sp + beta_sp * df_long$x +
    stats::rnorm(nrow(df_long), sd = 0.3)

  df_wide <- tidyr::pivot_wider(
    df_long,
    id_cols = c(species, rep, x),
    names_from = trait,
    values_from = value
  )
  df_wide <- as.data.frame(df_wide, stringsAsFactors = FALSE)

  list(
    df_long = df_long,
    df_wide = df_wide,
    tree = tree,
    Sigma_b_true = Sigma_b_true,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true,
    cov_true = cov_true,
    ab_true = ab
  )
}

fit_phylo_unique_slope_pair <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species),
    data = fx$df_long,
    phylo_tree = fx$tree,
    unit = "species",
    control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3) ~ 1 + phylo_unique(1 + x | species),
    data = fx$df_wide,
    phylo_tree = fx$tree,
    unit = "species",
    control = ctl
  )))
  list(long = fit_long, wide = fit_wide)
}

expect_phase56_4_fit_health <- function(fit) {
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_lt(fit$fit_health$max_gradient, 1e-2)
  expect_true(isTRUE(fit$fit_health$sdreport_ok))
  expect_true(isTRUE(fit$fit_health$pd_hessian))
}

phase56_4_Sigma_b <- function(fit) {
  sd_b <- as.numeric(fit$report$sd_b)
  rho <- as.numeric(fit$report$cor_b)
  matrix(
    c(
      sd_b[1L]^2,
      rho * sd_b[1L] * sd_b[2L],
      rho * sd_b[1L] * sd_b[2L],
      sd_b[2L]^2
    ),
    nrow = 2L,
    ncol = 2L,
    dimnames = list(c("intercept", "slope"), c("intercept", "slope"))
  )
}

test_that("phylo_unique augmented wide and long fits are byte-identical", {
  skip_if_not_phylo_unique_slope_deps()

  fx <- make_phylo_unique_slope_fixture()
  fits <- fit_phylo_unique_slope_pair(fx)

  expect_phase56_4_fit_health(fits$long)
  expect_phase56_4_fit_health(fits$wide)
  expect_equal(
    as.numeric(logLik(fits$wide)),
    as.numeric(logLik(fits$long)),
    tolerance = 1e-6
  )
  expect_equal(fits$wide$opt$objective, fits$long$opt$objective, tolerance = 1e-8)
  expect_identical(fits$wide$tmb_data$y, fits$long$tmb_data$y)
  expect_identical(fits$wide$tmb_data$trait_id, fits$long$tmb_data$trait_id)
  expect_identical(
    fits$wide$tmb_data$species_aug_id,
    fits$long$tmb_data$species_aug_id
  )
  expect_identical(fits$wide$tmb_data$Z_phy_aug, fits$long$tmb_data$Z_phy_aug)
  expect_equal(fits$wide$report$sd_b, fits$long$report$sd_b, tolerance = 1e-8)
  expect_equal(fits$wide$report$cor_b, fits$long$report$cor_b, tolerance = 1e-8)
})

test_that("phylo_unique augmented Gaussian fit recovers Sigma_b", {
  skip_if_not_phylo_unique_slope_deps()

  fx <- make_phylo_unique_slope_fixture()
  fit <- fit_phylo_unique_slope_pair(fx)$long
  Sigma_hat <- phase56_4_Sigma_b(fit)
  sigma2_int_hat <- unname(Sigma_hat["intercept", "intercept"])
  sigma2_slope_hat <- unname(Sigma_hat["slope", "slope"])
  rho_hat <- unname(stats::cov2cor(Sigma_hat)["intercept", "slope"])

  expect_phase56_4_fit_health(fit)
  expect_lte(
    abs(sigma2_int_hat - fx$sigma2_int_true) / fx$sigma2_int_true,
    0.20
  )
  expect_lte(
    abs(sigma2_slope_hat - fx$sigma2_slope_true) / fx$sigma2_slope_true,
    0.20
  )
  expect_lte(abs(rho_hat - fx$rho_true), 0.30)
})

test_that("phylo_unique augmented fit aborts when n_lhs_cols is forced to 1", {
  skip_if_not_phylo_unique_slope_deps()

  fx <- make_phylo_unique_slope_fixture(n_sp = 10L, n_rep = 2L)
  fit <- fit_phylo_unique_slope_pair(fx)$long
  tmb_data <- fit$tmb_data
  tmb_data$n_lhs_cols <- 1L

  expect_error(
    TMB::MakeADFun(
      data = tmb_data,
      parameters = fit$tmb_params,
      map = fit$tmb_map,
      random = "b_phy_aug",
      DLL = "gllvmTMB",
      silent = TRUE
    ),
    regexp = "n_lhs_cols does not match augmented phylo arrays"
  )
})
