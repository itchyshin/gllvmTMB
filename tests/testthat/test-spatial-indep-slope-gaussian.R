## Design 55 §A4 + Design 56 §9.5e-indep + Design 60 §3.5 --
## spatial_indep(1 + x | coords) Gaussian recovery + wide<->long byte-identity.
##
## ACTIVATED. spatial_indep(1 + x | coords) is the DIAGONAL special case of the
## base SPDE slope engine: the intercept-slope cross-field correlation rho is
## FIXED at 0 (atanh_cor_spde_b mapped to factor(NA) in R/fit-multi.R). Same
## engine as spatial_unique(); Sigma_field is diagonal (Design 56 §5.3).
##
## Marginal-variance normalisation as in test-spatial-unique-slope-gaussian.R:
## the DGP is parameterised by the IDENTIFIABLE marginal field SD scaled UP by
## sqrt(4*pi)*kappa, recovery normalises by the ESTIMATED kappa.

skip_helper <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
}

.spde_indep_Q_dense <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## Simulate from the DIAGONAL augmented-SPDE-slope DGP (rho = 0).
.make_spatial_indep_slope_data <- function(seed,
                                           marg_a = 0.8, marg_b = 0.5,
                                           range_true = 0.3,
                                           sigma_eps = 0.15,
                                           n_traits = 3L, n_sites = 300L,
                                           cutoff = 0.05) {
  set.seed(seed)
  kappa_true <- sqrt(8) / range_true
  sf_norm    <- sqrt(4 * pi) * kappa_true
  sd_a_p     <- marg_a * sf_norm
  sd_b_p     <- marg_b * sf_norm

  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$species      <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]
  df$lat <- coords[df$site, 2]
  df$x   <- stats::rnorm(nrow(df))

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  n_mesh <- ncol(mesh$A_st)

  Q  <- .spde_indep_Q_dense(mesh, kappa_true)
  A  <- solve(Q)
  ## rho = 0: two independent fields, each N(0, sd^2 Q^{-1}).
  chA <- t(chol(A + 1e-9 * diag(n_mesh)))
  om_a <- sd_a_p * (chA %*% stats::rnorm(n_mesh))
  om_b <- sd_b_p * (chA %*% stats::rnorm(n_mesh))
  A_full <- as.matrix(mesh$A_st)
  fa_tru <- as.numeric(A_full %*% om_a)
  fb_tru <- as.numeric(A_full %*% om_b)
  df$value <- stats::rnorm(n_traits, 0, 0.5)[df$trait_id] +
    fa_tru + df$x * fb_tru + stats::rnorm(nrow(df), sd = sigma_eps)

  df$site         <- factor(df$site)
  df$species      <- factor(df$species)
  df$site_species <- factor(df$site_species)

  list(data = df, mesh = mesh, A_full = A_full,
       fa_tru = fa_tru, fb_tru = fb_tru,
       marg_a = marg_a, marg_b = marg_b, kappa_true = kappa_true)
}

.summarise_spatial_indep_slope <- function(fit, fx) {
  rp        <- fit$report
  sd_hat    <- as.numeric(rp$sd_spde_b)
  kappa_hat <- as.numeric(rp$kappa_s)
  sf_hat    <- sqrt(4 * pi) * kappa_hat
  om_hat <- matrix(
    fit$tmb_obj$env$last.par.best[
      grepl("^omega_spde_aug", names(fit$tmb_obj$env$last.par.best))],
    ncol = 2L)
  list(
    conv   = fit$opt$convergence,
    pd     = isTRUE(fit$fit_health$pd_hessian),
    marg_a = sd_hat[1] / sf_hat,
    marg_b = sd_hat[2] / sf_hat,
    rho    = as.numeric(rp$cor_spde_b),
    cor_fa = stats::cor(as.numeric(fx$A_full %*% om_hat[, 1]), fx$fa_tru),
    cor_fb = stats::cor(as.numeric(fx$A_full %*% om_hat[, 2]), fx$fb_tru))
}

test_that(
  "spatial_indep(1 + x | coords) recovery: diagonal Sigma_field (rho pinned to 0) x SPDE precision", {
  skip_if_not_heavy()
  skip_helper()

  seeds <- 1:6
  res <- lapply(seeds, function(s) {
    fx  <- .make_spatial_indep_slope_data(seed = s)
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(1 + x | coords),
      data = fx$data, mesh = fx$mesh, silent = TRUE)))
    s_out <- .summarise_spatial_indep_slope(fit, fx)
    ## rho MUST be held exactly at 0 (atanh_cor_spde_b mapped to factor(NA)).
    s_out$atanh_mapped <- !is.null(fit$tmb_map$atanh_cor_spde_b)
    s_out
  })

  conv     <- vapply(res, `[[`, integer(1), "conv")
  pd       <- vapply(res, `[[`, logical(1), "pd")
  marg_a_h <- vapply(res, `[[`, numeric(1), "marg_a")
  marg_b_h <- vapply(res, `[[`, numeric(1), "marg_b")
  rho_h    <- vapply(res, `[[`, numeric(1), "rho")
  cor_fa   <- vapply(res, `[[`, numeric(1), "cor_fa")
  cor_fb   <- vapply(res, `[[`, numeric(1), "cor_fb")
  atanh_m  <- vapply(res, `[[`, logical(1), "atanh_mapped")

  expect_true(all(conv == 0L))
  expect_true(all(pd))
  ## rho held EXACTLY at 0 across every fit (the indep contract).
  expect_true(all(atanh_m))
  expect_true(all(rho_h == 0))
  ## Field-BLUP recovery is the strong, distribution-free check.
  expect_gt(mean(cor_fa), 0.90)
  expect_gt(mean(cor_fb), 0.90)
  ## Marginal variances recovered on average (truths: marg_a = 0.8, marg_b = 0.5).
  expect_lt(abs(mean(marg_a_h) - 0.8), 0.20)
  expect_lt(abs(mean(marg_b_h) - 0.5), 0.20)
})

test_that(
  "spatial_indep wide == long byte-identical (Design 55 §3)", {
  skip_if_not_heavy()
  skip_helper()

  fx <- .make_spatial_indep_slope_data(seed = 13, n_sites = 200L, cutoff = 0.07)

  f_w <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_indep(1 + x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE)))
  f_l <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait + (0 + trait):x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE)))

  expect_identical(f_w$tmb_data$Z_spde_aug, f_l$tmb_data$Z_spde_aug)
  expect_identical(f_w$tmb_data$n_lhs_cols_spde, 2L)
  ## Both surfaces pin rho to 0 via the map.
  expect_false(is.null(f_w$tmb_map$atanh_cor_spde_b))
  expect_false(is.null(f_l$tmb_map$atanh_cor_spde_b))
  expect_lt(abs(as.numeric(logLik(f_w)) - as.numeric(logLik(f_l))), 1e-6)
  expect_lt(max(abs(as.numeric(f_w$report$sd_spde_b) -
                      as.numeric(f_l$report$sd_spde_b))), 1e-6)
  expect_lt(abs(as.numeric(f_w$report$kappa_s) -
                  as.numeric(f_l$report$kappa_s)), 1e-6)
})
