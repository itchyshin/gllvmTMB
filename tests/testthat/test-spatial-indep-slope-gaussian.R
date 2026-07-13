## Design 79/80 (B2) -- spatial_indep(1 + x | coords) Gaussian, MIGRATED to the
## per-trait block-diagonal contract.
##
## spatial_indep(1 + x | coords) USED to fit a shared spatial field with the
## intercept-slope correlation PINNED to 0 (atanh_cor_spde_b mapped to NA). It
## NOW fits T INDEPENDENT per-trait (intercept, slope) spatial-field blocks --
## the spde dep 2T-wide engine (use_spde_dep_slope) with the cross-block Cholesky
## entries pinned (use_spde_indep_blockdiag), correlation ESTIMATED per trait and
## cross-trait covariance structurally zero -- exactly mirroring phylo_indep /
## animal_indep (Design 79/80). Verified locally with fmesher (no INLA needed).
## `||` gives the fully-diagonal (uncorrelated) form; see the sibling engine.

skip_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  if (!identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1")) {
    testthat::skip("heavy recovery test; set GLLVMTMB_HEAVY_TESTS=1 to run")
  }
}

## Per-trait spatial slope fixture: each trait gets its own (intercept, slope)
## SPDE field pair with a real within-trait correlation, drawn from the SPDE
## precision Q = (kappa^2 I - Laplacian)^2 via its dense Cholesky.
make_spatial_slope_fixture <- function(seed, n_sites = 160L, n_traits = 3L,
                                       range = 0.3, cutoff = 0.08) {
  set.seed(seed)
  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$trait <- factor(paste0("t", df$trait_id), levels = paste0("t", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]; df$lat <- coords[df$site, 2]
  df$x <- stats::rnorm(nrow(df)); df$site <- factor(df$site)
  ## Mesh must be built on the same long-format data passed to gllvmTMB().
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  kappa <- sqrt(8) / range
  M0 <- as.matrix(mesh$spde$c0); M1 <- as.matrix(mesh$spde$g1); M2 <- as.matrix(mesh$spde$g2)
  Q <- kappa^4 * M0 + 2 * kappa^2 * M1 + M2
  Lq <- t(chol(Q)); n_mesh <- nrow(Q)
  Ast <- mesh$A_st                       # n_obs x n_mesh
  fld <- function() as.numeric(Ast %*% backsolve(t(Lq), stats::rnorm(n_mesh)))
  val <- numeric(nrow(df))
  for (t in seq_len(n_traits)) {
    a <- fld() * 0.8; b <- fld() * 0.5   # per-observation intercept + slope fields
    idx <- df$trait_id == t
    val[idx] <- a[idx] + df$x[idx] * b[idx]
  }
  df$value <- val + stats::rnorm(nrow(df), 0, 0.15)
  list(df = df, mesh = mesh)
}

.fit_sp <- function(fx, lhs) suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  stats::as.formula(sprintf("value ~ 0 + trait + spatial_indep(%s | site, mesh = mesh)", lhs)),
  data = fx$df, mesh = fx$mesh, unit = "site", cluster = "site",
  family = stats::gaussian(), silent = TRUE)))

test_that("spatial_indep(1 + x | coords) fits the per-trait block-diagonal engine", {
  skip_spatial()
  fx <- make_spatial_slope_fixture(seed = 1L); T <- 3L
  fit <- .fit_sp(fx, "1 + x")
  expect_equal(fit$opt$convergence, 0L)
  ## per-trait engine: 2T augmented columns, block-diagonal theta_spde_dep_chol.
  expect_equal(fit$tmb_data$n_lhs_cols_spde, 2L * T)
  ## The per-trait dep-slope Cholesky is FREE with block pins: 3 params per trait
  ## (two diagonal + one within-block intercept-slope), i.e. 3T -- rho ESTIMATED
  ## per trait, not the old single pinned shared block.
  expect_equal(sum(!is.na(as.integer(fit$tmb_obj$env$map$theta_spde_dep_chol))), 3L * T)
  ## positive per-trait field SDs recovered (2T of them).
  expect_true(all(fit$report$sd_spde_b > 0))
  expect_length(fit$report$sd_spde_b, 2L * T)
})

test_that("spatial_indep wide == long byte-identical under the per-trait engine", {
  skip_spatial()
  fx <- make_spatial_slope_fixture(seed = 13L, n_sites = 180L)
  f_w <- .fit_sp(fx, "1 + x")
  f_l <- .fit_sp(fx, "0 + trait + (0 + trait):x")
  expect_identical(f_w$tmb_data$Z_spde_aug, f_l$tmb_data$Z_spde_aug)
  expect_identical(f_w$tmb_data$n_lhs_cols_spde, 6L)
  expect_lt(abs(as.numeric(stats::logLik(f_w)) - as.numeric(stats::logLik(f_l))), 1e-6)
  expect_lt(max(abs(as.numeric(f_w$report$sd_spde_b) -
                      as.numeric(f_l$report$sd_spde_b))), 1e-6)
})
