# Symbolic <-> implementation alignment for the CRAN-safe DGP cell:
#
# | Symbol | Formula term | DGP draw | Extractor | Truth |
# |--------|--------------|----------|-----------|-------|
# | alpha_C3, alpha_C4 | 0 + pathway | fixed pathway means | coef() | 0.35, 0.75 |
# | beta_C3, beta_C4 | moisture:pathway | fixed pathway slopes | coef() | -0.25, 0.30 |
# | K_spatial(kappa) | spatial_coef(..., mesh, rho=1) | projected SPDE correlation | source$K_column | unit diagonal |
# | Sigma_coef | spatial_coef(1 + moisture | trait) | B = L_K Z L_Sigma' | extract_Sigma()$Sigma | finite positive definite |
#
# The routine cell deliberately uses at most 5 response columns and 30 units.
# Claim-bearing covariance/range recovery and edge regimes live in
# data-raw/spatial-coef-recovery.R.

test_that("a small Gaussian DGP exercises spatial random intercepts and slopes", {
  skip_if_not_installed("fmesher")
  set.seed(13330L)
  locations <- data.frame(
    trait = paste0("plant_", sprintf("%02d", 1:5)),
    pathway = factor(c("C3", "C3", "C3", "C4", "C4"),
                     levels = c("C3", "C4")),
    east_km = c(0, 1, 2, 0.5, 1.5),
    north_km = c(0, 0.25, 0, 1, 1.1)
  )
  column_mesh <- make_mesh(
    locations, c("east_km", "north_km"), cutoff = 0.12,
    id_col = "trait"
  )
  range_truth <- 1.6
  K_truth <- .spatial_coef_projected_correlation(
    column_mesh, sqrt(8) / range_truth, locations$trait
  )
  Sigma_truth <- matrix(c(0.16, 0.045, 0.045, 0.09), 2L, 2L)
  B <- t(chol(K_truth)) %*% matrix(stats::rnorm(10L), 5L, 2L) %*%
    chol(Sigma_truth)
  alpha <- c(C3 = 0.35, C4 = 0.75)
  beta <- c(C3 = -0.25, C4 = 0.30)
  wide <- data.frame(
    unit = factor(paste0("u", seq_len(30L))),
    moisture = seq(-1.5, 1.5, length.out = 30L)
  )
  for (j in seq_len(nrow(locations))) {
    pathway <- as.character(locations$pathway[[j]])
    wide[[locations$trait[[j]]]] <-
      alpha[[pathway]] + B[j, 1L] +
      (beta[[pathway]] + B[j, 2L]) * wide$moisture +
      stats::rnorm(nrow(wide), sd = 0.06)
  }
  long <- tidyr::pivot_longer(
    wide, cols = tidyselect::all_of(locations$trait),
    names_to = "trait", values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = locations$trait)

  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + pathway + moisture:pathway +
      spatial_coef(1 + moisture | trait, mesh = column_mesh, rho = 1),
    data = long, column_data = locations[c("trait", "pathway")],
    trait = "trait", unit = "unit", family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  gradient <- fit$tmb_obj$gr(fit$opt$par)

  expect_identical(fit$opt$convergence, 0L)
  expect_true(all(is.finite(gradient)))
  expect_lt(max(abs(gradient)), 1e-2)
  expect_identical(got$basis, c("(Intercept)", "moisture"))
  expect_identical(got$source$type, "spatial")
  expect_identical(got$rho, 1)
  expect_true(all(is.finite(got$Sigma)))
  expect_true(all(eigen(got$Sigma, symmetric = TRUE, only.values = TRUE)$values > 0))
  expect_equal(unname(diag(got$K_rho)), rep(1, 5L), tolerance = 1e-12)
})
