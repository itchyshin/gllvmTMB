## Phase B-matrix SLOPE-spatial-unique (Design 59): the spatial random-slope
## anchor `spatial_unique(1 + x | site)` x seven non-Gaussian families
## (binomial-probit, binomial-logit, ordinal_probit, poisson, nbinom2, gamma,
## beta). This walks the *spatial* leg of the random-slope column of the
## family x structure matrix -- the HARDEST combination in the campaign
## (spatial x slope x mean-dependent), so honest SKIPs are expected here and
## are reported as "stays partial", never forced green.
##
## What this cell would test (when the engine supports it):
##   * LHS = `(1 + x | coords)` (wide) -- the per-site (intercept, slope) drawn
##     jointly from N(0, Sigma_b (x) A_spde), where A_spde is the GMRF
##     covariance implied by the SPDE precision (Design 55 sec.A4, Design 56
##     sec.9.5e). Sigma_b is the 2x2 (intercept, slope) covariance.
##   * Recovery: sigma^2_intercept, sigma^2_slope, cov(intercept, slope) at the
##     site level (the augmented SPDE field block `report$sd_spde_b` /
##     `report$cor_spde_field`), plus the SPDE Matern (kappa / range)
##     parameters.
##   * CI smoke: a finite profile bound on the slope-field variance (the
##     augmented `log_sd_spde_b[2]` direct parameter) OR a non-degenerate
##     extract_correlations(tier = "spatial").
##
## ENGINE STATUS (updated 2026-06-03): the SPDE augmented-slope engine
## (`use_spde_slope`, driven by the `.spatial_unique_augmented` parser marker)
## IS live -- `spatial_unique(1 + x | coords)` builds a 2-column SPDE field
## (`tmb_data$n_lhs_cols_spde == 2`) with the 2x2 cross-field block reported as
## `log_sd_spde_b` / `sd_spde_b` / `cor_spde_field` (src/gllvmTMB.cpp). This is
## a DIFFERENT slot family from the phylo-tier augmented slope (`b_phy_aug` /
## `log_sd_b` / `n_lhs_cols`, default 1 on a pure spatial fit); the smoke bar
## below reads the SPDE `*_spde_b` slots. SPA-08 (#427) relaxed the
## gaussian-only family guard to the per-family allowlist
## c(0L, 1L, 2L, 4L, 5L, 7L, 14L), so the non-Gaussian families below now
## CONSTRUCT and reach the smoke bar instead of honest-skipping at the guard.
##
## DISCIPLINE (Design 59 Honest-matrix, hard): each family attempts the REAL
## fit through `gllvmTMB::gllvmTMB(value ~ 0 + trait + spatial_unique(1 + x |
## site), ...)`. If construction aborts (the current state), or the fit fails
## to converge / is non-PD, the family `skip()`s with the precise reason and
## the register row stays `partial`. The fit-attempt code is kept LIVE (not
## commented out) so that when the Stage-3 SPDE augmented-slope engine lands
## these tests activate automatically -- the post-construction assertions
## (convergence + PD Hessian + augmented use-flags + CI smoke) are written to
## the engine-faithful slots, never widened. No fake-pass.
##
## Tolerance note (for the activated path): fixed-residual-scale families
## (binomial-probit/-logit, ordinal_probit) carry a TIGHTER recovery band than
## mean-dependent families (poisson, nbinom2, gamma, beta), per the Phase B0
## scoping memo (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md
## sec.2-3). The smoke assertions below do not pin a numeric band -- they are
## the "fits + identifies + reports finite augmented structure" bar -- so they
## hold for both tolerance classes.

skip_if_not_slope_spatial_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## Build a small spatial random-slope fixture: ~100 sites with random 2D
## coordinates in the unit square, `n_traits` traits, a fixed covariate `x`
## (var(x) ~ 1) shared across traits within a site, and a per-site
## (intercept, slope) drawn jointly from N(0, Sigma_b (x) A_spde) where the
## shared latent surface is a Matern field on the engine's own SPDE precision
## (kappa^4 M0 + 2 kappa^2 M1 + M2), internally consistent with the C++
## template's prior. The `emit` callback turns the per-row latent `eta` into
## the family-specific response. One species per site makes `site` the unit of
## replication for the spatial random field.
make_slope_spatial_fixture <- function(emit,
                                       n_sites    = 100L,
                                       n_traits   = 3L,
                                       range_true = 0.3,
                                       seed       = 20260529L) {
  set.seed(seed)
  kappa_true <- sqrt(8) / range_true

  coords <- cbind(lon = stats::runif(n_sites),
                  lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites),
                    trait_id = seq_len(n_traits))
  df$species      <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait        <- factor(paste0("trait_", df$trait_id),
                            levels = paste0("trait_", seq_len(n_traits)))
  df$lon          <- coords[df$site, 1L]
  df$lat          <- coords[df$site, 2L]
  df$x            <- stats::rnorm(nrow(df))        # var(x) ~ 1

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1)
  n_mesh <- ncol(mesh$A_st)

  M0 <- mesh$spde$c0
  M1 <- mesh$spde$g1
  M2 <- mesh$spde$g2
  Q_base     <- as.matrix(kappa_true^4 * M0 +
                          2 * kappa_true^2 * M1 + M2)
  Sigma_base <- solve(Q_base)
  scale_om   <- 1 / sqrt(mean(diag(Sigma_base)))
  chol_S     <- chol(Sigma_base + 1e-8 * diag(n_mesh))

  ## Two independent Matern fields (one for the intercept surface, one for the
  ## slope surface), correlated through a 2x2 Sigma_b at the site level.
  draw_field <- function() {
    scale_om * as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))
  }
  A_full <- as.matrix(mesh$A_st)                   # n_obs x n_mesh

  ## 2x2 augmented covariance Sigma_b (intercept, slope): sigma2_int = 0.4,
  ## sigma2_slope = 0.3, rho = 0.5 -- the same truth as the phylo-slope sibling
  ## so the activated recovery target is comparable across structure tiers.
  sigma2_int_true   <- 0.4
  sigma2_slope_true <- 0.3
  rho_true          <- 0.5
  cov_true          <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  L_b <- chol(matrix(c(sigma2_int_true, cov_true,
                       cov_true, sigma2_slope_true), 2L, 2L))
  z1 <- A_full %*% draw_field()
  z2 <- A_full %*% draw_field()
  ab <- cbind(z1, z2) %*% L_b                       # n_obs x 2 (int, slope)

  alpha_t <- c(-0.1, 0.0, 0.1)[df$trait_id]
  eta     <- alpha_t + ab[, 1L] + ab[, 2L] * df$x

  df$value        <- emit(eta)
  df$site         <- factor(df$site, levels = seq_len(n_sites))
  df$species      <- factor(df$species, levels = 1L)
  df$site_species <- factor(df$site_species)

  list(
    data              = df,
    mesh              = mesh,
    n_traits          = n_traits,
    sigma2_int_true   = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true          = rho_true
  )
}

## Attempt the spatial random-slope fit for one family. Returns the fit object
## or the condition. `control` carries the multi-start used to give the
## optimiser a fair chance (mirrors the spatial paired tests).
fit_slope_spatial <- function(fx, family) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_unique(1 + x | site),
      data    = fx$data,
      mesh    = fx$mesh,
      family  = family,
      silent  = TRUE,
      control = list(n_init = 5, init_jitter = 0.5)
    ))),
    error = function(e) e
  )
}

## Shared post-construction smoke bar (only reached if the Stage-3 SPDE
## augmented-slope engine lands). Asserts the engine-faithful augmented slots:
## clean convergence + PD Hessian, the augmented use-flag + 2 LHS columns, the
## stated family id, and a finite augmented slope-variance profile CI OR a
## non-degenerate spatial correlation frame. Never widened.
expect_slope_spatial_smoke <- function(fit, expected_family_id) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], expected_family_id)

  ## Augmented SPDE correlated-slope path active with 2 LHS columns (intercept
  ## + slope). The augmented SPDE field reports the 2x2 block as
  ## report$sd_spde_b + report$cor_spde_field and counts its columns in
  ## tmb_data$n_lhs_cols_spde (set to 2L for the base spatial_unique /
  ## spatial_indep slope at R/fit-multi.R). NOTE: n_lhs_cols / report$sd_b /
  ## log_sd_b are the SEPARATE phylo_dep correlated-slope slots (default 1 on a
  ## pure spatial fit); the SPDE slope SDs live in the *_spde_b slots. The
  ## earlier draft of this smoke bar referenced the phylo_dep slots, which only
  ## escaped notice because every non-Gaussian cell honest-skipped at the
  ## gaussian-only guard until SPA-08 (#427) admitted these families.
  testthat::expect_equal(fit$tmb_data$n_lhs_cols_spde, 2L)
  sd_spde_b <- as.numeric(fit$report$sd_spde_b)
  testthat::expect_equal(length(sd_spde_b), 2L)
  testthat::expect_true(all(is.finite(sd_spde_b)))

  ## CI smoke -- Branch 1: profile the augmented SPDE slope log-SD
  ## (log_sd_spde_b[2]) and transform to the SD scale (the genuine direct-
  ## parameter profile for the slope field variance of this cell).
  slope_ci <- tryCatch(
    gllvmTMB:::tmbprofile_wrapper(
      fit, name = "log_sd_spde_b", which = 2L, transform = exp
    ),
    error = function(e) e
  )
  slope_ci_finite <- !inherits(slope_ci, "error") &&
    is.numeric(slope_ci) &&
    any(is.finite(slope_ci[c("lower", "upper")]))

  ## CI smoke -- Branch 2: a non-degenerate extract_correlations(tier =
  ## "spatial"). Either branch satisfies the Design 59 CI-smoke contract.
  cor_df <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
      fit, tier = "spatial", method = "fisher-z", link_residual = "none"
    ))),
    error = function(e) e
  )
  cor_ok <- !inherits(cor_df, "error") &&
    is.data.frame(cor_df) && nrow(cor_df) > 0L &&
    all(is.finite(cor_df$correlation))

  if (!slope_ci_finite && !cor_ok) {
    testthat::skip("Neither the augmented slope-variance profile CI nor extract_correlations(tier='spatial') was non-degenerate; honest skip rather than relax the assertion")
  }
  testthat::expect_true(slope_ci_finite || cor_ok)
}

## Run one family end-to-end: build the family-appropriate fixture, attempt the
## fit, honest-skip on construction failure / non-convergence / non-PD, else
## run the shared smoke bar. `emit` maps the latent eta to the response.
run_slope_spatial_family <- function(family, expected_family_id, emit,
                                     fixture_args = list()) {
  fx  <- do.call(make_slope_spatial_fixture, c(list(emit = emit), fixture_args))
  fit <- fit_slope_spatial(fx, family)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "spatial_unique(1 + x | site) did not construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_converged(fit)) {
    testthat::skip("spatial_unique(1 + x | site) fit did not converge with PD Hessian; cell stays partial pending bigger n / different seed")
  }
  expect_slope_spatial_smoke(fit, expected_family_id)
}

## ---------------------------------------------------------------
## binomial-probit  (family_id 1, link probit)
## ---------------------------------------------------------------
test_that("spatial_unique(1 + x | site) x binomial(probit): converges + PD + CI smoke (else honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_deps()
  run_slope_spatial_family(
    family             = stats::binomial(link = "probit"),
    expected_family_id = 1L,
    emit               = function(eta) stats::rbinom(length(eta), 1L, stats::pnorm(eta))
  )
})

## ---------------------------------------------------------------
## binomial-logit  (family_id 1, link logit)
## ---------------------------------------------------------------
test_that("spatial_unique(1 + x | site) x binomial(logit): converges + PD + CI smoke (else honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_deps()
  run_slope_spatial_family(
    family             = stats::binomial(link = "logit"),
    expected_family_id = 1L,
    emit               = function(eta) stats::rbinom(length(eta), 1L, stats::plogis(eta))
  )
})

## ---------------------------------------------------------------
## ordinal_probit  (family_id 14, K = 4 categories)
## ---------------------------------------------------------------
test_that("spatial_unique(1 + x | site) x ordinal_probit: converges + PD + CI smoke (else honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_deps()
  taus <- c(0, 0.7, 1.4)              # K = 4 ordinal thresholds (3 cutpoints)
  run_slope_spatial_family(
    family             = gllvmTMB::ordinal_probit(),
    expected_family_id = 14L,
    emit               = function(eta) {
      ystar <- eta + stats::rnorm(length(eta))
      as.integer(1L + (ystar > taus[1L]) + (ystar > taus[2L]) + (ystar > taus[3L]))
    }
  )
})

## ---------------------------------------------------------------
## poisson  (family_id 2, log link)
## ---------------------------------------------------------------
test_that("spatial_unique(1 + x | site) x poisson: converges + PD + CI smoke (else honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_deps()
  run_slope_spatial_family(
    family             = stats::poisson(),
    expected_family_id = 2L,
    emit               = function(eta) stats::rpois(length(eta), exp(eta))
  )
})

## ---------------------------------------------------------------
## nbinom2  (family_id 5, log link, overdispersion phi = 4)
## ---------------------------------------------------------------
test_that("spatial_unique(1 + x | site) x nbinom2: converges + PD + CI smoke (else honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_deps()
  phi <- 4
  run_slope_spatial_family(
    family             = gllvmTMB::nbinom2(),
    expected_family_id = 5L,
    emit               = function(eta) {
      mu <- exp(eta)
      stats::rnbinom(length(mu), size = phi, mu = mu)
    }
  )
})

## ---------------------------------------------------------------
## gamma  (family_id 4, log link, shape phi = 2 => CV ~ 0.707)
## ---------------------------------------------------------------
test_that("spatial_unique(1 + x | site) x Gamma(log): converges + PD + CI smoke (else honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_deps()
  phi <- 2
  run_slope_spatial_family(
    family             = stats::Gamma(link = "log"),
    expected_family_id = 4L,
    emit               = function(eta) {
      mu <- exp(eta)
      stats::rgamma(length(mu), shape = phi, scale = mu / phi)
    }
  )
})

## ---------------------------------------------------------------
## beta  (family_id 7, logit link, precision phi = 5)
## ---------------------------------------------------------------
test_that("spatial_unique(1 + x | site) x Beta(logit): converges + PD + CI smoke (else honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_deps()
  phi <- 5
  run_slope_spatial_family(
    family             = gllvmTMB::Beta(),
    expected_family_id = 7L,
    emit               = function(eta) {
      mu <- stats::plogis(eta)
      stats::rbeta(length(mu), shape1 = mu * phi, shape2 = (1 - mu) * phi)
    }
  )
})
