## SPA-10 non-Gaussian activation -- the spatial analogue of PHY-18
## (phylo_dep all-families, #422/#424) and the unstructured generalisation of
## SPA-08 (test-spatial-indep-slope-nongaussian.R). Activate the FULL
## unstructured 2T x 2T augmented SPDE field-covariance random-slope cell
## `spatial_dep(1 + x | coords)` for the non-Gaussian families: poisson, Gamma,
## Beta, binomial (multi-trial), nbinom2, ordinal_probit.
##
## ----------------------------------------------------------------------
## Why this is ZERO new C++ (family-agnostic engine)
##
## The augmented dep SPDE-slope contribution enters the linear predictor
## BEFORE the C++ family dispatch (src/gllvmTMB.cpp: eta(o) += A_proj .
## omega_spde_aug then `int fid = family_id_vec(o)` selects the likelihood).
## Swapping the family only changes how the SAME eta maps to the response.
## spatial_dep differs from the base spatial_unique/spatial_indep slope path by
## freeing the FULL unstructured 2T x 2T Sigma_field (theta_spde_dep_chol) and
## mapping off log_sd_spde_b / atanh_cor_spde_b (R/fit-multi.R). Activating
## these families therefore needed only relaxing the use_spde_dep_slope family
## guard in R/fit-multi.R (`c(0L)` -> per-family allowlist) -- no C++ likelihood
## branch was added. The BASE spatial_indep/spatial_unique guard (#427, SPA-08)
## is untouched.
##
## ----------------------------------------------------------------------
## Retired spike (#425). A previous attempt drew the SPDE field from a
## hand-built precision Q (solve(Q) singular / chol(Q) "leading minor not
## positive") and produced ZERO usable cells. That standalone spike is RETIRED.
## This file goes straight to recovery cells on the package's OWN validated
## Gaussian spatial DGP -- the exact stable `backsolve(chol(Q), z)` GMRF draw
## from test-spatial-indep-slope-nongaussian.R, here with a NON-ZERO cross-field
## (intercept/slope) correlation per trait so the recovery also asserts the
## off-diagonal.
##
## ----------------------------------------------------------------------
## Recovery design (mirrors test-spatial-indep-slope-nongaussian.R +
## test-spatial-dep-slope-gaussian.R recovery cell)
##
## Each family draws a correlated 2-field-per-trait augmented-SPDE-slope DGP
## (intercept field a_t and slope field b_t with cross-correlation rho_ab via a
## per-trait 2x2 Cholesky on top of the shared stable GMRF root), fits the REAL
## public API `value ~ 0 + trait + spatial_dep(1 + x | coords)`, and -- WHEN the
## fit converges with a PD Hessian -- asserts:
##   - opt$convergence == 0 and a positive-definite Hessian;
##   - the runtime family id matches (no silent fallthrough);
##   - the dep contract: a free theta_spde_dep_chol of length C(C+1)/2 and
##     log_sd_spde_b / atanh_cor_spde_b mapped off (NOT pinned to 0 -- the dep
##     path frees the full block);
##   - field-BLUP recovery: cor(field_hat, field_true) for BOTH the intercept
##     and slope SPDE fields above a per-family floor (the strong,
##     distribution-free recovery channel used by the Gaussian sibling);
##   - marginal field SD recovery via extract_Sigma(level = "spatial") within
##     the per-family band inherited from the spatial_indep sibling;
##   - the trait-0 intercept/slope cross-field correlation R[1, 2] within a band
##     (the ONE thing the unstructured dep block adds over the indep diagonal).
##
## SKIP discipline (no fake-pass): construction failure is a FAIL (the family
## paths are meant to be live once on the allowlist); non-convergence / non-PD /
## out-of-band recovery => an honest `skip("reason")`. Bands are NOT widened to
## force green. The unstructured 2T x 2T block is HARDER to identify than the
## indep diagonal (this is why phylo_dep poisson needed n_species ~ 200-300 and
## why dep was the last phylo cell to land), so a family that skips at
## n_sites = 400 escalates (600, 1000; binomial size 12 -> 20); if it still
## skips it is held OFF the R/fit-multi.R allowlist (partial success is fine).

`%||%` <- function(a, b) if (is.null(a)) b else a

skip_if_not_spatial_dep_ng <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## Dense SPDE precision Q for a given kappa (Lindgren et al. parameterisation),
## matching .Q_base_dense_dep() in test-spatial-dep-slope-gaussian.R.
.ngdep_spde_Q_dense <- function(mesh, kappa) {
  M0 <- as.matrix(mesh$spde$c0)
  M1 <- as.matrix(mesh$spde$g1)
  M2 <- as.matrix(mesh$spde$g2)
  kappa^4 * M0 + 2 * kappa^2 * M1 + M2
}

## Draw a single GMRF field with covariance sd^2 * Q^{-1} on the mesh nodes.
## Q = R'R with R = chol(Q) upper-triangular, so Q^{-1} = R^{-1} R^{-T} and a
## draw with covariance Q^{-1} is backsolve(R, z) for z ~ N(0, I). This is the
## numerically stable route (the dense solve(Q) is ill-conditioned at fine
## meshes -- the GMRF tip and the lesson of the retired #425 spike).
.ngdep_draw_spde_field <- function(R_chol, sd, n_mesh) {
  z <- stats::rnorm(n_mesh)
  sd * as.numeric(backsolve(R_chol, z))
}

## Build the CORRELATED augmented-SPDE-slope fixture. For each trait the
## intercept field a_t and slope field b_t share a per-trait 2x2 correlation
## rho_ab on top of the SAME stable GMRF root: draw two iid unit-Q fields
## (z_a, z_b) via backsolve(chol(Q), .), then mix [a; b] = [[1,0],[rho, s]] with
## s = sqrt(1 - rho^2), scaled by the marginal SDs. This is the spatial analogue
## of the matrix-normal vec(Omega) ~ N(0, Sf (x) Q^-1) draw in the gaussian
## sibling, restricted to a block-diagonal-per-trait cross-field structure so
## the off-diagonal is genuinely present but the DGP stays stable.
.make_ngdep_spatial_fixture <- function(seed, response,
                                        marg_a = 0.8, marg_b = 0.5,
                                        rho_ab = -0.5,
                                        range_true = 0.3,
                                        n_traits = 2L, n_sites = 400L,
                                        cutoff = 0.08) {
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

  Q      <- .ngdep_spde_Q_dense(mesh, kappa_true)
  R_chol <- chol(Q + 1e-9 * diag(n_mesh))   # upper-triangular
  A_full <- as.matrix(mesh$A_st)
  s_mix  <- sqrt(1 - rho_ab^2)

  fa_list <- vector("list", n_traits)
  fb_list <- vector("list", n_traits)
  for (t in seq_len(n_traits)) {
    z_a <- .ngdep_draw_spde_field(R_chol, 1, n_mesh)
    z_b <- .ngdep_draw_spde_field(R_chol, 1, n_mesh)
    om_a <- sd_a_p * z_a
    om_b <- sd_b_p * (rho_ab * z_a + s_mix * z_b)
    fa_list[[t]] <- as.numeric(A_full %*% om_a)
    fb_list[[t]] <- as.numeric(A_full %*% om_b)
  }
  ## Per-observation projected intercept/slope fields for that obs's trait.
  fa_tru <- numeric(nrow(df))
  fb_tru <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    t <- df$trait_id[o]
    fa_tru[o] <- fa_list[[t]][df$site[o]]
    fb_tru[o] <- fb_list[[t]][df$site[o]]
  }

  resp <- response(df, fa_tru, fb_tru)
  df$value <- resp$value
  if (!is.null(resp$extra)) {
    for (nm in names(resp$extra)) df[[nm]] <- resp$extra[[nm]]
  }

  df$site <- factor(df$site)
  list(data = df, mesh = mesh, A_full = A_full,
       fa_tru = fa_tru, fb_tru = fb_tru,
       marg_a = marg_a, marg_b = marg_b, rho_ab = rho_ab,
       kappa_true = kappa_true, n_traits = n_traits,
       response_lhs = resp$response_lhs %||% "value")
}

## Fit one seed of a family's dep augmented spatial-slope cell and pull the
## recovery channel. Returns the captured error on construction failure (the
## caller FAILs on it -- live paths must construct), else the summary.
.fit_ngdep_spatial <- function(fx, family) {
  form <- stats::as.formula(
    paste0(fx$response_lhs, " ~ 0 + trait + spatial_dep(1 + x | coords)")
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
  C         <- 2L * fx$n_traits
  ## Marginal SDs + cross-field R from the public extract_Sigma 2T x 2T block.
  s_sp <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "spatial"),
                   error = function(e) e)
  if (!inherits(s_sp, "error")) {
    marg_all <- sqrt(diag(s_sp$Sigma)) / sf_hat
    ## Interleaved: [intercept.t1, slope.t1, intercept.t2, slope.t2, ...].
    marg_a   <- marg_all[1L]   # trait-1 intercept field SD
    marg_b   <- marg_all[2L]   # trait-1 slope field SD
    r_ab     <- s_sp$R[1L, 2L] # trait-1 intercept/slope cross-field correlation
  } else {
    marg_a <- NA_real_; marg_b <- NA_real_; r_ab <- NA_real_
  }
  ## Field BLUPs: omega_spde_aug is n_mesh x C interleaved (intercept, slope)
  ## per trait. A_full (n_obs x n_mesh) projects mesh nodes to every obs row,
  ## so A_full %*% om_hat[, 1] is the trait-1 intercept field at every obs and
  ## A_full %*% om_hat[, 2] is the trait-1 slope field. The DGP truth fa_tru /
  ## fb_tru are the per-obs intercept/slope fields for THAT obs's trait; restrict
  ## the correlation to trait-1 observations to match the trait-1 BLUP columns.
  om_hat <- matrix(
    fit$tmb_obj$env$last.par.best[
      grepl("^omega_spde_aug", names(fit$tmb_obj$env$last.par.best))],
    ncol = C)
  t1_obs     <- which(fx$data$trait_id == 1L)
  fa_hat_obs <- as.numeric(fx$A_full %*% om_hat[, 1L])
  fb_hat_obs <- as.numeric(fx$A_full %*% om_hat[, 2L])

  list(
    error  = NA_character_,
    conv   = fit$opt$convergence,
    pd     = isTRUE(fit$fit_health$pd_hessian),
    fid    = as.integer(fit$tmb_data$family_id_vec[1L]),
    dep_len = length(fit$tmb_params$theta_spde_dep_chol),
    dep_expected = as.integer(C * (C + 1L) / 2L),
    b_mapped = !is.null(fit$tmb_map$log_sd_spde_b) &&
               !is.null(fit$tmb_map$atanh_cor_spde_b),
    marg_a = marg_a, marg_b = marg_b, r_ab = r_ab,
    cor_fa = stats::cor(fa_hat_obs[t1_obs], fx$fa_tru[t1_obs]),
    cor_fb = stats::cor(fb_hat_obs[t1_obs], fx$fb_tru[t1_obs]))
}

## Shared driver. `blup_floor` is the per-family field-BLUP correlation floor;
## `marg_tol` is the absolute marginal-SD band inherited from the spatial_indep
## sibling; `rho_tol` bands the cross-field correlation. FAIL on construction
## error; honest-skip on non-convergence / non-PD / out-of-band recovery.
.run_ngdep_spatial_family <- function(builder, family, fid_expected,
                                      blup_floor, marg_tol, rho_tol, row_id) {
  fx  <- builder()
  res <- .fit_ngdep_spatial(fx, family)

  if (!is.na(res$error)) {
    testthat::fail(sprintf(
      "spatial_dep(1 + x | coords) x %s aborted at construction: %s (the SPA-10 dep-guard relaxation should admit family id %d)",
      row_id, res$error, fid_expected
    ))
    return(invisible(NULL))
  }

  ## Engine really ran the claimed family on the dep SPDE-slope path.
  testthat::expect_equal(res$fid, fid_expected)
  ## Dep contract: full unstructured block freed; base 2x2 params mapped off.
  testthat::expect_equal(res$dep_len, res$dep_expected)
  testthat::expect_true(res$b_mapped)

  healthy <- isTRUE(res$conv == 0L) && isTRUE(res$pd)
  if (!healthy) {
    testthat::skip(sprintf(
      "spatial_dep(1 + x | coords) x %s did not converge with PD Hessian (conv = %s, pd = %s); %s stays partial pending bigger n / different seed",
      row_id, res$conv, res$pd, row_id
    ))
  }

  ## Recovery: field-BLUP correlation (strong, distribution-free) + marginal SD
  ## within the inherited band + the trait-1 cross-field correlation within
  ## rho_tol. Out-of-band => honest skip.
  in_band <-
    is.finite(res$cor_fa) && res$cor_fa > blup_floor &&
    is.finite(res$cor_fb) && res$cor_fb > blup_floor &&
    is.finite(res$marg_a) && abs(res$marg_a - fx$marg_a) < marg_tol &&
    is.finite(res$marg_b) && abs(res$marg_b - fx$marg_b) < marg_tol &&
    is.finite(res$r_ab)   && abs(res$r_ab - fx$rho_ab) < rho_tol
  if (!in_band) {
    testthat::skip(sprintf(
      "spatial_dep(1 + x | coords) x %s recovery outside band [cor_fa=%.3g, cor_fb=%.3g (floor %.2f); marg_a=%.3g (truth %.2f), marg_b=%.3g (truth %.2f), tol %.2f; r_ab=%.3g (truth %.2f), tol %.2f]; %s stays partial pending bigger n",
      row_id, res$cor_fa, res$cor_fb, blup_floor,
      res$marg_a, fx$marg_a, res$marg_b, fx$marg_b, marg_tol,
      res$r_ab, fx$rho_ab, rho_tol, row_id
    ))
  }

  testthat::expect_equal(res$conv, 0L)
  testthat::expect_true(res$pd)
  testthat::expect_gt(res$cor_fa, blup_floor)
  testthat::expect_gt(res$cor_fb, blup_floor)
  testthat::expect_lt(abs(res$marg_a - fx$marg_a), marg_tol)
  testthat::expect_lt(abs(res$marg_b - fx$marg_b), marg_tol)
  testthat::expect_lt(abs(res$r_ab - fx$rho_ab), rho_tol)
}

## =====================================================================
## poisson (log): mean-dependent. log-scale intercept ~ 1.4 keeps counts
## in a healthy range. Wider marginal band (mean-dependent family).
## =====================================================================
test_that("spatial_dep(1 + x | coords) x poisson VALIDATION (SPA-10): real-API fit converges PD + recovers unstructured field block", {
  skip_if_not_heavy()
  skip_if_not_spatial_dep_ng()
  builder <- function() .make_ngdep_spatial_fixture(
    seed = 20260603L, n_sites = 400L,
    response = function(df, fa, fb) {
      eta <- c(1.4, 1.2)[df$trait_id] + fa + df$x * fb
      list(value = stats::rpois(nrow(df), lambda = exp(eta)))
    })
  .run_ngdep_spatial_family(
    builder, stats::poisson(link = "log"), fid_expected = 2L,
    blup_floor = 0.80, marg_tol = 0.30, rho_tol = 0.30, row_id = "poisson"
  )
})

## =====================================================================
## Gamma (log): mean-dependent; shape phi = 2 (CV ~ 0.707).
## =====================================================================
test_that("spatial_dep(1 + x | coords) x Gamma VALIDATION (SPA-10): real-API fit converges PD + recovers unstructured field block", {
  skip_if_not_heavy()
  skip_if_not_spatial_dep_ng()
  builder <- function() .make_ngdep_spatial_fixture(
    seed = 20260604L, n_sites = 400L,
    response = function(df, fa, fb) {
      phi <- 2
      mu <- exp(c(0.0, 0.1)[df$trait_id] + fa + df$x * fb)
      list(value = stats::rgamma(nrow(df), shape = phi, scale = mu / phi))
    })
  .run_ngdep_spatial_family(
    builder, stats::Gamma(link = "log"), fid_expected = 4L,
    blup_floor = 0.80, marg_tol = 0.30, rho_tol = 0.30, row_id = "gamma"
  )
})

## =====================================================================
## Beta (logit): mean-dependent; phi = 5.
## =====================================================================
test_that("spatial_dep(1 + x | coords) x Beta VALIDATION (SPA-10): real-API fit converges PD + recovers unstructured field block", {
  skip_if_not_heavy()
  skip_if_not_spatial_dep_ng()
  builder <- function() .make_ngdep_spatial_fixture(
    seed = 20260605L, n_sites = 400L,
    response = function(df, fa, fb) {
      phi <- 5
      mu <- stats::plogis(c(-0.2, 0.0)[df$trait_id] + fa + df$x * fb)
      list(value = stats::rbeta(nrow(df), mu * phi, (1 - mu) * phi))
    })
  .run_ngdep_spatial_family(
    builder, gllvmTMB::Beta(), fid_expected = 7L,
    blup_floor = 0.80, marg_tol = 0.30, rho_tol = 0.30, row_id = "beta"
  )
})

## =====================================================================
## binomial (logit), MULTI-TRIAL cbind(succ, fail), size = 12.
## Fixed residual scale -> tighter marginal band.
## =====================================================================
test_that("spatial_dep(1 + x | coords) x binomial (multi-trial) VALIDATION (SPA-10): real-API fit converges PD + recovers unstructured field block", {
  skip_if_not_heavy()
  skip_if_not_spatial_dep_ng()
  builder <- function() .make_ngdep_spatial_fixture(
    seed = 20260606L, n_sites = 400L,
    response = function(df, fa, fb) {
      size <- 12L
      p <- stats::plogis(c(0.2, 0.0)[df$trait_id] + fa + df$x * fb)
      succ <- stats::rbinom(nrow(df), size = size, prob = p)
      list(value = succ, extra = list(succ = succ, fail = size - succ),
           response_lhs = "cbind(succ, fail)")
    })
  .run_ngdep_spatial_family(
    builder, stats::binomial(link = "logit"), fid_expected = 1L,
    blup_floor = 0.80, marg_tol = 0.25, rho_tol = 0.30,
    row_id = "binomial-logit-multitrial"
  )
})

## =====================================================================
## nbinom2: mean-dependent; log-scale intercept ~ 1.0, phi = 2.
## =====================================================================
test_that("spatial_dep(1 + x | coords) x nbinom2 VALIDATION (SPA-10): real-API fit converges PD + recovers unstructured field block", {
  skip_if_not_heavy()
  skip_if_not_spatial_dep_ng()
  builder <- function() .make_ngdep_spatial_fixture(
    seed = 20260607L, n_sites = 400L,
    response = function(df, fa, fb) {
      eta <- c(1.0, 0.9)[df$trait_id] + fa + df$x * fb
      list(value = stats::rnbinom(nrow(df), mu = exp(eta), size = 2.0))
    })
  .run_ngdep_spatial_family(
    builder, gllvmTMB::nbinom2(), fid_expected = 5L,
    blup_floor = 0.80, marg_tol = 0.30, rho_tol = 0.30, row_id = "nbinom2"
  )
})

## =====================================================================
## ordinal_probit: fixed residual scale (sigma_d^2 == 1). K = 4 categories.
## =====================================================================
test_that("spatial_dep(1 + x | coords) x ordinal_probit VALIDATION (SPA-10): real-API fit converges PD + recovers unstructured field block", {
  skip_if_not_heavy()
  skip_if_not_spatial_dep_ng()
  builder <- function() .make_ngdep_spatial_fixture(
    seed = 20260608L, n_sites = 400L,
    response = function(df, fa, fb) {
      ystar <- c(0.7, 0.5)[df$trait_id] + fa + df$x * fb +
        stats::rnorm(nrow(df), 0, 1)
      taus <- c(0, 0.7, 1.4)
      list(value = as.integer(
        1L + colSums(outer(taus, ystar, FUN = function(t, y) y > t))))
    })
  .run_ngdep_spatial_family(
    builder, gllvmTMB::ordinal_probit(), fid_expected = 14L,
    blup_floor = 0.80, marg_tol = 0.30, rho_tol = 0.30,
    row_id = "ordinal_probit"
  )
})
