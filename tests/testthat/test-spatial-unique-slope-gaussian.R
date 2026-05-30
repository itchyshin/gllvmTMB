## Design 55 §A4 + Design 56 §9.5e + Design 60 §3.4 --
## spatial_unique(1 + x | coords) Gaussian recovery + wide<->long byte-identity.
##
## ACTIVATED (the base SPDE slope engine is integrated; the public parser route
## spatial_unique(1 + x | coords) -> spde(..., .spatial_unique_augmented = TRUE)
## -> use_spde_slope is wired in R/brms-sugar.R + R/fit-multi.R). This is the
## end-to-end public-surface analogue of the direct-MakeADFun engine test
## tests/testthat/test-spde-slope-base-engine.R.
##
## Marginal-variance normalisation (Design 60 §"CRITICAL"): the SPDE marginal
## field SD is sd_marg = sd_param / (sqrt(4*pi) * kappa), NOT sd_param. The DGP
## is parameterised by the IDENTIFIABLE marginal SD scaled UP by
## sqrt(4*pi)*kappa; recovery targets the marginal field variances + the
## cross-field correlation rho. Because the PUBLIC route estimates kappa
## jointly, recovery normalises by the ESTIMATED kappa (report$kappa_s).

skip_if_not_spatial <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
}

## Reconstruct the dense SPDE precision Q_base for a given kappa (same Matern
## nu=1, d=2 operator the C++ template builds: kappa^4 M0 + 2 kappa^2 M1 + M2).
.spde_unique_Q_dense <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## Simulate one augmented-SPDE-slope Gaussian data set from a known DGP:
##   eta(o) = alpha_trait + (A_proj omega_alpha)(o) + x(o) * (A_proj omega_beta)(o)
##   vec(Omega) ~ N(0, Sigma_field (x) Q^{-1}),  Omega = [omega_a | omega_b].
## marg_a / marg_b are the marginal field SDs (identifiable); rho is the
## cross-field correlation. Returns the long-format data + mesh + truths.
.make_spatial_unique_slope_data <- function(seed,
                                            marg_a = 0.8, marg_b = 0.5,
                                            rho = -0.45,
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

  Q  <- .spde_unique_Q_dense(mesh, kappa_true)
  A  <- solve(Q)
  Sf <- matrix(c(sd_a_p^2, rho * sd_a_p * sd_b_p,
                 rho * sd_a_p * sd_b_p, sd_b_p^2), 2, 2)
  chA <- t(chol(A + 1e-9 * diag(n_mesh)))
  chS <- chol(Sf)
  Omega  <- chA %*% matrix(stats::rnorm(n_mesh * 2L), n_mesh, 2L) %*% chS
  A_full <- as.matrix(mesh$A_st)
  fa_tru <- as.numeric(A_full %*% Omega[, 1])
  fb_tru <- as.numeric(A_full %*% Omega[, 2])
  eta    <- fa_tru + df$x * fb_tru
  df$value <- stats::rnorm(n_traits, 0, 0.5)[df$trait_id] + eta +
    stats::rnorm(nrow(df), sd = sigma_eps)

  df$site         <- factor(df$site)
  df$species      <- factor(df$species)
  df$site_species <- factor(df$site_species)

  list(data = df, mesh = mesh, A_full = A_full,
       fa_tru = fa_tru, fb_tru = fb_tru,
       marg_a = marg_a, marg_b = marg_b, rho = rho,
       kappa_true = kappa_true)
}

## Pull (marg_a, marg_b, rho, kappa, field-BLUP correlations, convergence)
## out of a fitted spatial_unique(1 + x | coords) object. Marginals are
## normalised by the ESTIMATED kappa (the public route estimates it jointly).
.summarise_spatial_unique_slope <- function(fit, fx) {
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
  "spatial_unique(1 + x | coords) recovers marginal field variances + cross-field rho", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  seeds <- 1:6
  res <- lapply(seeds, function(s) {
    fx  <- .make_spatial_unique_slope_data(seed = s)
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_unique(1 + x | coords),
      data = fx$data, mesh = fx$mesh, silent = TRUE)))
    .summarise_spatial_unique_slope(fit, fx)
  })

  conv     <- vapply(res, `[[`, integer(1), "conv")
  pd       <- vapply(res, `[[`, logical(1), "pd")
  marg_a_h <- vapply(res, `[[`, numeric(1), "marg_a")
  marg_b_h <- vapply(res, `[[`, numeric(1), "marg_b")
  rho_h    <- vapply(res, `[[`, numeric(1), "rho")
  cor_fa   <- vapply(res, `[[`, numeric(1), "cor_fa")
  cor_fb   <- vapply(res, `[[`, numeric(1), "cor_fb")

  expect_true(all(conv == 0L))
  expect_true(all(pd))
  ## Field-BLUP recovery is the strong, distribution-free check.
  expect_gt(mean(cor_fa), 0.90)
  expect_gt(mean(cor_fb), 0.90)
  ## Marginal variances + cross-field correlation recovered on average
  ## (truths: marg_a = 0.8, marg_b = 0.5, rho = -0.45).
  expect_lt(abs(mean(marg_a_h) - 0.8), 0.20)
  expect_lt(abs(mean(marg_b_h) - 0.5), 0.20)
  expect_lt(abs(mean(rho_h) - (-0.45)), 0.20)
})

test_that(
  "spatial_unique wide == long byte-identical (Design 55 §3)", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  fx <- .make_spatial_unique_slope_data(seed = 11, n_sites = 200L, cutoff = 0.07)

  f_w <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(1 + x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE)))
  f_l <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(0 + trait + (0 + trait):x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE)))

  ## Identical augmented design matrix.
  expect_identical(f_w$tmb_data$Z_spde_aug, f_l$tmb_data$Z_spde_aug)
  expect_identical(f_w$tmb_data$n_lhs_cols_spde, 2L)
  expect_identical(f_l$tmb_data$n_lhs_cols_spde, 2L)
  ## Identical logLik to 1e-6.
  expect_lt(abs(as.numeric(logLik(f_w)) - as.numeric(logLik(f_l))), 1e-6)
  ## Identical reported augmented-field structure to 1e-6.
  expect_lt(max(abs(as.numeric(f_w$report$sd_spde_b) -
                      as.numeric(f_l$report$sd_spde_b))), 1e-6)
  expect_lt(abs(as.numeric(f_w$report$cor_spde_b) -
                  as.numeric(f_l$report$cor_spde_b)), 1e-6)
  expect_lt(abs(as.numeric(f_w$report$kappa_s) -
                  as.numeric(f_l$report$kappa_s)), 1e-6)
})

test_that(
  "spatial_unique(1 + x | coords) routes to the base SPDE slope engine (not the intercept-only path)", {
  skip_if_not_heavy()
  skip_if_not_spatial()

  fx <- .make_spatial_unique_slope_data(seed = 7, n_sites = 120L, cutoff = 0.1)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_unique(1 + x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE,
    control = list(optimize = FALSE))))

  ## The augmented SPDE slope engine is active and supersedes the
  ## intercept-only per-trait field; kappa stays estimable.
  expect_identical(fit$tmb_data$use_spde_slope, 1L)
  expect_identical(fit$tmb_data$use_spde, 0L)
  expect_identical(fit$tmb_data$n_lhs_cols_spde, 2L)
  expect_equal(dim(fit$tmb_data$Z_spde_aug), c(length(fit$tmb_data$y), 2L))
  expect_true(all(fit$tmb_data$Z_spde_aug[, 1] == 1))
  expect_equal(fit$tmb_data$Z_spde_aug[, 2], fx$data$x)
  ## omega_spde_aug joins the random vector; log_kappa_spde is NOT mapped off.
  expect_true("omega_spde_aug" %in%
                names(fit$tmb_obj$env$par[fit$tmb_obj$env$random]))
  expect_null(fit$tmb_map$log_kappa_spde)
})
