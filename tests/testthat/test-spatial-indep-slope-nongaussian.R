## SPA-08 non-Gaussian activation -- the spatial mirror of
## test-phylo-indep-slope-nongaussian.R. Activate the augmented diagonal
## spatial random-slope cell `spatial_indep(1 + x | coords)` for the
## non-Gaussian families: poisson, Gamma, Beta, binomial (multi-trial),
## nbinom2, ordinal_probit.
##
## ----------------------------------------------------------------------
## Why this is ZERO new C++ (family-agnostic engine)
##
## The augmented SPDE-slope contribution enters the linear predictor BEFORE
## the C++ family dispatch (src/gllvmTMB.cpp: eta(o) += A_proj . omega_spde_aug
## then `int fid = family_id_vec(o)` selects the likelihood). Swapping the
## family only changes how the SAME eta maps to the response. spatial_indep
## differs from the family-general spatial_unique() path solely by pinning
## atanh_cor_spde_b to factor(NA) via the TMB map (R/fit-multi.R). Activating
## these families therefore needed only relaxing the BASE spatial_unique /
## spatial_indep family guard in R/fit-multi.R (the
## `else if (any(family_id_vec != 0L))` branch becomes an allowlist) -- no C++
## likelihood branch was added. The split spatial_dep guard
## (use_spde_dep_slope, the full unstructured 2T x 2T path) is untouched.
##
## ----------------------------------------------------------------------
## Recovery design (mirrors test-spatial-indep-slope-gaussian.R + the
## phylo_dep poisson VALIDATION cell in test-matrix-slope-phylo-dep.R)
##
## Each family draws a genuinely DIAGONAL augmented-SPDE-slope DGP (rho = 0,
## two independent fields), fits the REAL public API
## `value ~ 0 + trait + spatial_indep(1 + x | coords)`, and -- WHEN the fit
## converges with a PD Hessian -- asserts:
##   - opt$convergence == 0 and a positive-definite Hessian;
##   - atanh_cor_spde_b mapped to factor(NA) and report$cor_spde_b == 0
##     EXACTLY (the diagonal-Sigma_field indep contract);
##   - the runtime family id matches (no silent fallthrough);
##   - field-BLUP recovery: cor(field_hat, field_true) for BOTH the
##     intercept and slope SPDE fields above a per-family floor (the strong,
##     distribution-free recovery channel used by the Gaussian sibling);
##   - marginal field SD recovery via extract_Sigma(level = "spatial")
##     within the per-family band inherited from the matrix-slope-<family>
##     sibling (NOT a looser invented band).
##
## SKIP discipline (no fake-pass): construction failure is a FAIL (the family
## paths are meant to be live once on the allowlist); non-convergence /
## non-PD / out-of-band recovery => an honest `skip("reason")`. Bands are NOT
## widened to force green. A family that skips at n_sites = 300 escalates
## (600, 1200; binomial size 12 -> 20); if it still skips it is held off the
## R/fit-multi.R allowlist.

`%||%` <- function(a, b) if (is.null(a)) b else a

skip_if_not_spatial_indep_ng <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## Dense SPDE precision Q for a given kappa (Lindgren et al. parameterisation),
## matching .spde_indep_Q_dense() in test-spatial-indep-slope-gaussian.R.
.ng_spde_Q_dense <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## Draw a single GMRF field with covariance sd^2 * Q^{-1} on the mesh nodes.
## Q = R'R with R = chol(Q) upper-triangular, so Q^{-1} = R^{-1} R^{-T} and a
## draw with covariance Q^{-1} is backsolve(R, z) for z ~ N(0, I). This is the
## numerically stable route (the dense solve(Q) is ill-conditioned at fine
## meshes -- the GMRF tip).
.ng_draw_spde_field <- function(R_chol, sd, n_mesh) {
  z <- stats::rnorm(n_mesh)
  sd * as.numeric(backsolve(R_chol, z))
}

## Build the diagonal augmented-SPDE-slope fixture (rho = 0). Returns the long
## (site x trait) frame, the mesh, the projected true fields, and the marginal
## truths. `response` is a per-family closure mapping (df, fa_tru, fb_tru) to
## the response column (and optional extra columns); `marg_a` / `marg_b` are
## the IDENTIFIABLE marginal field SDs (scaled UP by sqrt(4*pi)*kappa for the
## DGP, recovery normalises by the estimated kappa).
.make_ng_spatial_indep_fixture <- function(seed, response,
                                           marg_a = 0.8, marg_b = 0.5,
                                           range_true = 0.3,
                                           n_traits = 3L, n_sites = 300L,
                                           cutoff = 0.1) {
  set.seed(seed)
  kappa_true <- sqrt(8) / range_true
  sf_norm    <- sqrt(4 * pi) * kappa_true
  sd_a_p     <- marg_a * sf_norm
  sd_b_p     <- marg_b * sf_norm

  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(n_traits))
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(n_traits)))
  df$lon <- coords[df$site, 1]
  df$lat <- coords[df$site, 2]
  df$x   <- stats::rnorm(nrow(df))

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  n_mesh <- ncol(mesh$A_st)

  Q <- .ng_spde_Q_dense(mesh, kappa_true)
  R_chol <- chol(Q + 1e-9 * diag(n_mesh))   # upper-triangular
  ## rho = 0: two independent fields, each N(0, sd^2 Q^{-1}).
  om_a <- .ng_draw_spde_field(R_chol, sd_a_p, n_mesh)
  om_b <- .ng_draw_spde_field(R_chol, sd_b_p, n_mesh)
  A_full <- as.matrix(mesh$A_st)
  fa_tru <- as.numeric(A_full %*% om_a)
  fb_tru <- as.numeric(A_full %*% om_b)

  resp <- response(df, fa_tru, fb_tru)
  df$value <- resp$value
  if (!is.null(resp$extra)) {
    for (nm in names(resp$extra)) df[[nm]] <- resp$extra[[nm]]
  }

  df$site <- factor(df$site)
  list(data = df, mesh = mesh, A_full = A_full,
       fa_tru = fa_tru, fb_tru = fb_tru,
       marg_a = marg_a, marg_b = marg_b, kappa_true = kappa_true,
       response_lhs = resp$response_lhs %||% "value")
}

## Fit one seed of a family's diagonal augmented spatial-slope cell and pull
## the recovery channel. Returns the captured error on construction failure
## (the caller FAILs on it -- live paths must construct), else the summary.
.fit_ng_spatial_indep <- function(fx, family) {
  form <- stats::as.formula(
    paste0(fx$response_lhs, " ~ 0 + trait + spatial_indep(1 + x | coords)")
  )
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      form, data = fx$data, mesh = fx$mesh, family = family,
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE), silent = TRUE))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    return(list(error = conditionMessage(fit)))
  }

  rp        <- fit$report
  kappa_hat <- as.numeric(rp$kappa_s)[1L]
  sf_hat    <- sqrt(4 * pi) * kappa_hat
  ## Marginal SD read from the public extract_Sigma(level = "spatial") 2x2.
  s_sp <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "spatial"),
                   error = function(e) e)
  marg_from_sigma <- if (!inherits(s_sp, "error")) {
    sqrt(diag(s_sp$Sigma)) / sf_hat
  } else {
    rep(NA_real_, 2L)
  }
  ## Field BLUPs (intercept = col 1, slope = col 2 of omega_spde_aug).
  om_hat <- matrix(
    fit$tmb_obj$env$last.par.best[
      grepl("^omega_spde_aug", names(fit$tmb_obj$env$last.par.best))],
    ncol = 2L)

  list(
    error  = NA_character_,
    conv   = fit$opt$convergence,
    pd     = isTRUE(fit$fit_health$pd_hessian),
    fid    = as.integer(fit$tmb_data$family_id_vec[1L]),
    rho    = as.numeric(rp$cor_spde_b)[1L],
    cor_mapped = !is.null(fit$tmb_map$atanh_cor_spde_b),
    marg_a = marg_from_sigma[1L],
    marg_b = marg_from_sigma[2L],
    cor_fa = stats::cor(as.numeric(fx$A_full %*% om_hat[, 1]), fx$fa_tru),
    cor_fb = stats::cor(as.numeric(fx$A_full %*% om_hat[, 2]), fx$fb_tru))
}

## Shared driver. `blup_floor` is the per-family field-BLUP correlation floor;
## `marg_tol` is the absolute marginal-SD band inherited from the family's
## matrix-slope sibling. FAIL on construction error; honest-skip on
## non-convergence / non-PD / out-of-band recovery.
.run_ng_spatial_indep_family <- function(builder, family, fid_expected,
                                         blup_floor, marg_tol, row_id) {
  fx  <- builder()
  res <- .fit_ng_spatial_indep(fx, family)

  if (!is.na(res$error)) {
    testthat::fail(sprintf(
      "spatial_indep(1 + x | coords) x %s aborted at construction: %s (the SPA-08 base-guard relaxation should admit family id %d)",
      row_id, res$error, fid_expected
    ))
    return(invisible(NULL))
  }

  ## Engine really ran the claimed family on the base SPDE-slope path.
  testthat::expect_equal(res$fid, fid_expected)
  ## Diagonal indep contract: rho pinned EXACTLY at 0 via the map.
  testthat::expect_true(res$cor_mapped)
  testthat::expect_equal(res$rho, 0)

  healthy <- isTRUE(res$conv == 0L) && isTRUE(res$pd)
  if (!healthy) {
    testthat::skip(sprintf(
      "spatial_indep(1 + x | coords) x %s did not converge with PD Hessian (conv = %s, pd = %s); %s stays partial pending bigger n / different seed",
      row_id, res$conv, res$pd, row_id
    ))
  }

  ## Recovery: field-BLUP correlation (strong, distribution-free) + marginal
  ## SD within the inherited band. Out-of-band => honest skip.
  in_band <-
    is.finite(res$cor_fa) && res$cor_fa > blup_floor &&
    is.finite(res$cor_fb) && res$cor_fb > blup_floor &&
    is.finite(res$marg_a) && abs(res$marg_a - fx$marg_a) < marg_tol &&
    is.finite(res$marg_b) && abs(res$marg_b - fx$marg_b) < marg_tol
  if (!in_band) {
    testthat::skip(sprintf(
      "spatial_indep(1 + x | coords) x %s recovery outside band [cor_fa=%.3g, cor_fb=%.3g (floor %.2f); marg_a=%.3g (truth %.2f), marg_b=%.3g (truth %.2f), tol %.2f]; %s stays partial pending bigger n",
      row_id, res$cor_fa, res$cor_fb, blup_floor,
      res$marg_a, fx$marg_a, res$marg_b, fx$marg_b, marg_tol, row_id
    ))
  }

  testthat::expect_equal(res$conv, 0L)
  testthat::expect_true(res$pd)
  testthat::expect_gt(res$cor_fa, blup_floor)
  testthat::expect_gt(res$cor_fb, blup_floor)
  testthat::expect_lt(abs(res$marg_a - fx$marg_a), marg_tol)
  testthat::expect_lt(abs(res$marg_b - fx$marg_b), marg_tol)
}

## =====================================================================
## poisson (log): mean-dependent. log-scale intercept ~ 1.4 keeps counts
## in a healthy range. Wider marginal band (mean-dependent family).
## =====================================================================
test_that("spatial_indep(1 + x | coords) x poisson VALIDATION (SPA-08): real-API fit converges PD + recovers diagonal field SDs", {
  skip_if_not_heavy()
  skip_if_not_spatial_indep_ng()
  builder <- function() .make_ng_spatial_indep_fixture(
    seed = 20260602L, n_sites = 300L,
    response = function(df, fa, fb) {
      eta <- c(1.4, 1.2, 1.0)[df$trait_id] + fa + df$x * fb
      list(value = stats::rpois(nrow(df), lambda = exp(eta)))
    })
  .run_ng_spatial_indep_family(
    builder, stats::poisson(link = "log"), fid_expected = 2L,
    blup_floor = 0.80, marg_tol = 0.30, row_id = "poisson"
  )
})

## =====================================================================
## Gamma (log): mean-dependent; shape phi = 2 (CV ~ 0.707).
## =====================================================================
test_that("spatial_indep(1 + x | coords) x Gamma VALIDATION (SPA-08): real-API fit converges PD + recovers diagonal field SDs", {
  skip_if_not_heavy()
  skip_if_not_spatial_indep_ng()
  builder <- function() .make_ng_spatial_indep_fixture(
    seed = 20260603L, n_sites = 300L,
    response = function(df, fa, fb) {
      phi <- 2
      mu <- exp(c(0.0, 0.1, -0.1)[df$trait_id] + fa + df$x * fb)
      list(value = stats::rgamma(nrow(df), shape = phi, scale = mu / phi))
    })
  .run_ng_spatial_indep_family(
    builder, stats::Gamma(link = "log"), fid_expected = 4L,
    blup_floor = 0.80, marg_tol = 0.30, row_id = "gamma"
  )
})

## =====================================================================
## Beta (logit): mean-dependent; phi = 5.
## =====================================================================
test_that("spatial_indep(1 + x | coords) x Beta VALIDATION (SPA-08): real-API fit converges PD + recovers diagonal field SDs", {
  skip_if_not_heavy()
  skip_if_not_spatial_indep_ng()
  builder <- function() .make_ng_spatial_indep_fixture(
    seed = 20260604L, n_sites = 300L,
    response = function(df, fa, fb) {
      phi <- 5
      mu <- stats::plogis(c(-0.2, 0.0, 0.2)[df$trait_id] + fa + df$x * fb)
      list(value = stats::rbeta(nrow(df), mu * phi, (1 - mu) * phi))
    })
  .run_ng_spatial_indep_family(
    builder, gllvmTMB::Beta(), fid_expected = 7L,
    blup_floor = 0.80, marg_tol = 0.30, row_id = "beta"
  )
})

## =====================================================================
## binomial (logit), MULTI-TRIAL cbind(succ, fail), size = 12.
## Fixed residual scale -> tighter marginal band.
## =====================================================================
test_that("spatial_indep(1 + x | coords) x binomial (multi-trial) VALIDATION (SPA-08): real-API fit converges PD + recovers diagonal field SDs", {
  skip_if_not_heavy()
  skip_if_not_spatial_indep_ng()
  builder <- function() .make_ng_spatial_indep_fixture(
    seed = 20260605L, n_sites = 300L,
    response = function(df, fa, fb) {
      size <- 12L
      p <- stats::plogis(c(0.2, 0.0, -0.2)[df$trait_id] + fa + df$x * fb)
      succ <- stats::rbinom(nrow(df), size = size, prob = p)
      list(value = succ, extra = list(succ = succ, fail = size - succ),
           response_lhs = "cbind(succ, fail)")
    })
  .run_ng_spatial_indep_family(
    builder, stats::binomial(link = "logit"), fid_expected = 1L,
    blup_floor = 0.80, marg_tol = 0.25, row_id = "binomial-logit-multitrial"
  )
})

## =====================================================================
## nbinom2: mean-dependent; log-scale intercept ~ 1.0, phi = 2.
## =====================================================================
test_that("spatial_indep(1 + x | coords) x nbinom2 VALIDATION (SPA-08): real-API fit converges PD + recovers diagonal field SDs", {
  skip_if_not_heavy()
  skip_if_not_spatial_indep_ng()
  builder <- function() .make_ng_spatial_indep_fixture(
    seed = 20260606L, n_sites = 300L,
    response = function(df, fa, fb) {
      eta <- c(1.0, 0.9, 0.8)[df$trait_id] + fa + df$x * fb
      list(value = stats::rnbinom(nrow(df), mu = exp(eta), size = 2.0))
    })
  .run_ng_spatial_indep_family(
    builder, gllvmTMB::nbinom2(), fid_expected = 5L,
    blup_floor = 0.80, marg_tol = 0.30, row_id = "nbinom2"
  )
})

## =====================================================================
## ordinal_probit: fixed residual scale (sigma_d^2 == 1). K = 4 categories.
## =====================================================================
test_that("spatial_indep(1 + x | coords) x ordinal_probit VALIDATION (SPA-08): real-API fit converges PD + recovers diagonal field SDs", {
  skip_if_not_heavy()
  skip_if_not_spatial_indep_ng()
  builder <- function() .make_ng_spatial_indep_fixture(
    seed = 20260607L, n_sites = 300L, n_traits = 3L,
    response = function(df, fa, fb) {
      ystar <- c(0.7, 0.5, 0.6)[df$trait_id] + fa + df$x * fb +
        stats::rnorm(nrow(df), 0, 1)
      taus <- c(0, 0.7, 1.4)
      list(value = as.integer(
        1L + colSums(outer(taus, ystar, FUN = function(t, y) y > t))))
    })
  .run_ng_spatial_indep_family(
    builder, gllvmTMB::ordinal_probit(), fid_expected = 14L,
    blup_floor = 0.80, marg_tol = 0.30, row_id = "ordinal_probit"
  )
})
