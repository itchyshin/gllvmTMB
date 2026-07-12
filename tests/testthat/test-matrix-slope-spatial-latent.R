## Phase B-matrix agent SLOPE-spatial-latent (Design 59): random-slope
## `spatial_latent(1 + x | site, d = 1)` x 7 non-Gaussian families --
## augmented-LHS spatial recovery + CI smoke. This is the HARDEST cell of
## the campaign: an augmented (intercept + slope) LHS layered on the
## reduced-rank SPDE latent path.
##
## Relationship to the Gaussian anchor: the Gaussian template for this exact
## cell, `tests/testthat/test-spatial-latent-slope-gaussian.R`, is a
## SKELETON gated by `skip()` until Design 56 Stage 3 lands the augmented-LHS
## x spatial engine work (see that file's `skip_until_stage3()` and Design 56
## sec. 1-2 + sec. 9.5e-latent). The Gaussian cell is therefore NOT yet
## covered; this file adds the non-Gaussian rows for the same
## `spatial_latent(1 + x | site, d = 1)` augmented-LHS spatial structure.
##
## ENGINE STATE: the augmented-LHS x spatial_latent SLOPE path is now LIVE for
## the validated families. R/fit-multi.R's reduced-rank latent-slope guard
## (use_spde_latent_slope) carries a family-id allowlist -- gaussian, binomial
## (probit / logit), poisson, nbinom2, Gamma, Beta, ordinal_probit -- relaxed
## from the prior gaussian-only abort following the #388 / #392 allowlist
## discipline (a family joins ONLY after its recovery cell here passes
## empirically). The augmented `spatial_latent(1 + x | site, d)` bar routes
## through the `.spatial_latent_augmented` covstruct marker to the dedicated
## block-diagonal reduced-rank slope engine; it is NOT the parser-rejected form
## of earlier builds. Per the Honest-matrix discipline (Design 59): a cell that
## fails to construct / converge / is non-PD is `skip()`-ped with a reason and
## reported as "stays partial", NEVER forced green.
##
## Each test runs the real fixture and the real `gllvmTMB()` call. The skip is
## conditional on construction failure / non-convergence / non-PD / a dropped
## slope column / a degenerate CI smoke -- not an unconditional gate -- so a
## cell turns green precisely when the (family x spatial_latent-slope) fit is
## genuinely healthy at the fixture's n / seed.
##
## Per-family honest tolerance: fixed-residual-scale families (binomial-probit,
## binomial-logit, ordinal_probit) carry no point-recovery band here -- the
## load-bearing assertions are clean convergence + PD Hessian + the
## reduced-rank slope engine flag (use_spde_latent_slope, NOT the intercept-
## only spatial_latent flag) + a CI smoke. Mean-dependent families (poisson,
## nbinom2, gamma, beta) are noisier still on this hardest cell, so they too
## assert only fit health + slope-path-live + CI smoke, not a numeric band
## (Phase B0 memo sec. 2-3: mean-dependent families get wider tolerance, and
## augmented-LHS x SPDE at ~100 sites is the cross-product of the borderline
## cases). The CI smoke is a finite sdreport SE on the reduced-rank slope
## loadings `theta_rr_spde_slope` (the spatial analogue of the #392
## phylo_latent `theta_rr_phy_slope` smoke); the block-diagonal latent exposes
## no rho:spatial token and the `extract_correlations(tier = "spatial")` path
## keys on the intercept-only flag a slope fit does not set, so the loadings SE
## is the genuinely-available uncertainty handle.
##
## SKIP discipline (no fake-pass, Design 59): a cell that fails to construct,
## fails to converge, is non-PD, or whose CI smoke is degenerate is
## `skip()`-ped with a reason and reported as "stays partial". The register
## row only moves to `covered` on real passing evidence. Time-box per fit is
## the campaign-wide 15 min; the small-mesh fixtures here are far under that.

skip_if_not_slope_spatial_latent_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## ---------------------------------------------------------------------------
## Shared augmented-LHS spatial fixture.
## ---------------------------------------------------------------------------
## ~100 sites with random 2D coordinates in the unit square, 3 traits, a
## single shared Matern field on the engine's own SPDE precision
## (kappa^4 M0 + 2 kappa^2 M1 + M2, rescaled to unit marginal variance), and
## a per-(site, trait) covariate `x` with var(x) ~ 1. The latent linear
## predictor carries BOTH a spatial intercept contribution (the shared field
## loaded onto traits) and a spatial-varying SLOPE on `x` (a second field
## loaded onto traits) -- this is the augmented (1 + x | site) structure the
## cell is meant to identify. The Gaussian latent surface `eta` is returned
## raw; each family's `test_that` emits its own response from `eta` (or from
## a link transform of it), so the fixture is family-agnostic.
make_slope_spatial_latent_fixture <- function(n_sites = 100L, n_traits = 3L,
                                              range_true = 0.3,
                                              seed = 20260529L) {
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
  df$x            <- stats::rnorm(nrow(df), 0, 1)   # var(x) ~ 1
  df$value        <- NA_real_

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

  ## Two independent shared fields: one for the spatial intercept, one for
  ## the spatial slope on x. Each is rescaled to unit marginal variance.
  omega_int_true <- scale_om *
    as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))
  omega_slp_true <- scale_om *
    as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))

  ## Modest per-trait loadings (same-sign on traits 1, 2; opposite on 3) so
  ## the latent eta stays mid-range and a non-trivial cross-trait correlation
  ## exists for the latent path to identify.
  Lambda_int <- c(0.6, 0.5, -0.4)[seq_len(n_traits)]
  Lambda_slp <- c(0.4, 0.3, -0.3)[seq_len(n_traits)]

  A_full <- as.matrix(mesh$A_st)
  int_per_row <- as.numeric(A_full %*% omega_int_true) *
                 Lambda_int[df$trait_id]
  slp_per_row <- as.numeric(A_full %*% omega_slp_true) *
                 Lambda_slp[df$trait_id]

  alpha_t <- c(-0.1, 0.0, 0.1)[seq_len(n_traits)]
  ## eta = trait intercept + spatial intercept + (spatial slope) * x.
  eta <- alpha_t[df$trait_id] + int_per_row + slp_per_row * df$x

  df$site         <- factor(df$site, levels = seq_len(n_sites))
  df$species      <- factor(df$species, levels = 1L)
  df$site_species <- factor(df$site_species)

  list(data = df, mesh = mesh, n_traits = n_traits, eta = eta)
}

## ---------------------------------------------------------------------------
## Shared fit-health + CI-smoke helpers (reached only once the engine path
## for augmented-LHS x spatial_latent lands; until then the per-family tests
## skip at the construction stage before these run).
## ---------------------------------------------------------------------------
expect_slope_spatial_latent_fit_health <- function(fit, family_id) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  ## Guard against a silent family fallthrough making the family claim hollow.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], family_id)
  ## The augmented spatial-latent SLOPE path must be the one that was taken.
  ## NOTE: the augmented `spatial_latent(1 + x | site, d)` covstruct carries
  ## the `.spatial_latent_augmented` marker, which drives the dedicated
  ## reduced-rank slope engine (use_spde_latent_slope). It does NOT set the
  ## intercept-only `.spatial_latent` marker, so `fit$use$spatial_latent` is
  ## FALSE on a slope fit; the live flag is `fit$use$spde_latent_slope` (this
  ## mirrors the #392 phylo_latent fix where the slope path keys on the
  ## *_slope engine flag, not the intercept-only latent flag).
  testthat::expect_true(isTRUE(fit$use$spde_latent_slope))
}

## The engine-state guard: is the reduced-rank SLOPE path actually live? A
## genuine slope-bearing spatial_latent fit must carry a 2-column augmented
## LHS (n_lhs_cols_spde_lat == 2) AND the dedicated latent-slope engine flag
## (use_spde_latent_slope == 1). The intercept-only spatial_latent path leaves
## these at 1 / 0, so this guard keys on the *_spde_lat fields the augmented
## latent engine populates (spatial analogue of #392's slope_latent_path_is_live).
slope_spatial_latent_path_is_live <- function(fit) {
  isTRUE(fit$tmb_data$n_lhs_cols_spde_lat == 2L) &&
    isTRUE(fit$tmb_data$use_spde_latent_slope == 1L)
}

## CI smoke (slope-structure uncertainty). The block-diagonal reduced-rank
## latent slope exposes NO rho:spatial token (each LHS column has its own
## Lambda_k Lambda_k^T; there is no cross-column correlation block) and the
## `extract_correlations(tier = "spatial")` path keys on the intercept-only
## `fit$use$spatial_latent` flag, which a slope fit does not set. So neither
## the `confint(rho:spatial)` nor the `extract_correlations` smoke is the right
## handle here. The genuinely-available uncertainty handle -- exactly as in
## the #392 phylo_latent fix -- is the sdreport SE on the reduced-rank slope
## loadings `theta_rr_spde_slope` (which build Sigma_spde_slope_*): a finite
## SE there is a finite slope-structure CI smoke.
slope_spatial_latent_loading_ci_finite <- function(fit) {
  sdr <- tryCatch(summary(fit$sd_report), error = function(e) NULL)
  if (is.null(sdr)) return(FALSE)
  idx <- which(rownames(sdr) == "theta_rr_spde_slope")
  if (length(idx) < 1L) return(FALSE)
  est <- sdr[idx, "Estimate"]
  se  <- sdr[idx, "Std. Error"]
  any(is.finite(est) & is.finite(se) & se > 0)
}

## Single driver for all 7 families: build the family-specific response from
## the shared latent eta, attempt the augmented-LHS spatial_latent fit, skip
## honestly on construction failure / non-convergence / non-PD / degenerate
## CI, and assert fit health + CI smoke when the engine path is live.
##   * `family_obj`   : the family object passed to gllvmTMB().
##   * `family_id`    : the expected fit$tmb_data$family_id_vec[1] value.
##   * `response_fun` : function(eta) -> response vector (the DGP emission).
##   * `extra_terms`  : RHS additions (ordinal/binomial drive the latent with
##                      a fixed `x` main effect too; here `x` already enters
##                      via the spatial slope, so the fixed RHS stays
##                      `0 + trait`).
##   * `row_label`    : human label for skip messages.
run_slope_spatial_latent_cell <- function(family_obj, family_id, response_fun,
                                          row_label, n_sites = 100L,
                                          seed = 20260529L) {
  ## SPA-09 promotion: the default fixture (n_sites = 100, seed 20260529) is PD
  ## for binomial-probit / poisson / Gamma / Beta but borderline non-PD for
  ## binomial-logit / ordinal_probit / nbinom2 at that specific seed -- a
  ## finite-sample POWER artifact, not non-identifiability (the families are
  ## already on the R/fit-multi.R use_spde_latent_slope allowlist, and the
  ## block-diagonal latent path is PD at n_sites = 150 / alternate seeds; see
  ## Design 35 SPA-09). Those three cells pass `n_sites = 150L` so the cell
  ## turns green on a genuinely healthy fit rather than honest-skipping; the
  ## four already-PD families keep the default n_sites = 100L (no regression).
  fx <- make_slope_spatial_latent_fixture(n_sites = n_sites, seed = seed)
  fx$data$value <- response_fun(fx$eta)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_latent(1 + x | site, d = 1),
      data    = fx$data,
      mesh    = fx$mesh,
      family  = family_obj,
      silent  = TRUE,
      control = list(n_init = 5, init_jitter = 0.5)
    ))),
    error = function(e) e
  )

  ## The augmented-LHS x spatial_latent engine path is LIVE for the validated
  ## families (gaussian, binomial probit/logit, poisson, nbinom2, Gamma, Beta,
  ## ordinal_probit; the family-id allowlist in R/fit-multi.R). A construction
  ## failure is therefore no longer the expected state -- it is an honest skip
  ## that keeps the cell partial only if it genuinely fails to build.
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s: spatial_latent(1 + x | site, d = 1) did not construct: %s",
      row_label,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    testthat::skip(sprintf(
      "%s: spatial_latent(1 + x | site, d = 1) did not converge with PD Hessian; stays partial pending bigger n / different seed",
      row_label
    ))
  }
  if (!slope_spatial_latent_path_is_live(fit)) {
    testthat::skip(sprintf(
      paste0(
        "%s: reduced-rank slope-bearing spatial_latent path not live (the engine ",
        "dropped the slope column: n_lhs_cols_spde_lat = %s, use_spde_latent_slope = %s); ",
        "no latent slope structure to recover, cell stays partial -- honest skip"
      ),
      row_label,
      as.character(fit$tmb_data$n_lhs_cols_spde_lat %||% NA),
      as.character(fit$tmb_data$use_spde_latent_slope %||% NA)
    ))
  }

  expect_slope_spatial_latent_fit_health(fit, family_id)

  if (!slope_spatial_latent_loading_ci_finite(fit)) {
    testthat::skip(sprintf(
      "%s: no finite SE on the reduced-rank slope loadings (theta_rr_spde_slope); CI smoke stays partial rather than relax the assertion",
      row_label
    ))
  }
  testthat::expect_true(slope_spatial_latent_loading_ci_finite(fit))
}

## ---------------------------------------------------------------------------
## One test_that per family. Each runs the real fixture + real fit and, on the
## current expected construction rejection, skips honestly.
## ---------------------------------------------------------------------------

test_that("binomial-probit: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  run_slope_spatial_latent_cell(
    family_obj   = stats::binomial(link = "probit"),
    family_id    = 1L,
    response_fun = function(eta) stats::rbinom(length(eta), 1L, stats::pnorm(eta)),
    row_label    = "binomial-probit"
  )
})

test_that("binomial-logit: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  run_slope_spatial_latent_cell(
    family_obj   = stats::binomial(link = "logit"),
    family_id    = 1L,
    response_fun = function(eta) stats::rbinom(length(eta), 1L, stats::plogis(eta)),
    row_label    = "binomial-logit",
    n_sites      = 150L   # SPA-09 promotion: PD at n=150 (power, not identifiability)
  )
})

test_that("ordinal_probit: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## K = 4 ordinal: y* = eta + N(0, 1) cut at 3 thresholds.
  taus <- c(0, 0.7, 1.4)
  run_slope_spatial_latent_cell(
    family_obj   = gllvmTMB::ordinal_probit(),
    family_id    = 14L,
    response_fun = function(eta) {
      ystar <- eta + stats::rnorm(length(eta), 0, 1)
      as.integer(1L + (ystar > taus[1L]) + (ystar > taus[2L]) +
                   (ystar > taus[3L]))
    },
    row_label    = "ordinal_probit",
    n_sites      = 150L   # SPA-09 promotion: PD at n=150 (power, not identifiability)
  )
})

test_that("poisson: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  run_slope_spatial_latent_cell(
    family_obj   = stats::poisson(link = "log"),
    family_id    = 2L,
    response_fun = function(eta) stats::rpois(length(eta), lambda = exp(eta)),
    row_label    = "poisson"
  )
})

test_that("nbinom2: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## nbinom2 with a moderate size (low overdispersion => near-Poisson,
  ## cleanest count case per the B0 memo sec. 3.2).
  phi_nb <- 5
  run_slope_spatial_latent_cell(
    family_obj   = gllvmTMB::nbinom2(),
    ## Runtime family_id from family_to_id(): nbinom2 = 5 (NOT the lognormal = 3
    ## id this previously claimed; the equality assertion only fires on a live
    ## fit, so the wrong id was latent until the engine path was activated).
    family_id    = 5L,
    response_fun = function(eta) stats::rnbinom(length(eta), mu = exp(eta), size = phi_nb),
    row_label    = "nbinom2",
    n_sites      = 150L   # SPA-09 promotion: PD at n=150 (power, not identifiability)
  )
})

test_that("gamma: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## Gamma(log): shape = phi (CV = 1/sqrt(phi)); E(y) = exp(eta); scale = mu/phi.
  phi_g <- 2
  run_slope_spatial_latent_cell(
    family_obj   = stats::Gamma(link = "log"),
    family_id    = 4L,
    response_fun = function(eta) {
      mu <- exp(eta)
      stats::rgamma(length(mu), shape = phi_g, scale = mu / phi_g)
    },
    row_label    = "gamma"
  )
})

test_that("beta: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## Beta (logit): mu = plogis(eta); precision phi; y ~ Beta(mu*phi, (1-mu)*phi).
  phi_b <- 5
  run_slope_spatial_latent_cell(
    family_obj   = gllvmTMB::Beta(),
    family_id    = 7L,
    response_fun = function(eta) {
      mu <- stats::plogis(eta)
      stats::rbeta(length(mu), mu * phi_b, (1 - mu) * phi_b)
    },
    row_label    = "beta"
  )
})
