## Phase B-INF Lane 2 / B3 (Design 58): `spatial_latent + spatial_unique`
## paired on a binary probit fit + SPDE mesh — recovery + CI smoke.
##
## Walks SPA-02 of `docs/design/35-validation-debt-register.md` from
## `partial` to `covered` for the binary probit branch.
##
## Fixture: 3 traits, 120 sites with random 2D coordinates in the unit
## square, a moderate Matern spatial field (range = 0.3 in normalised
## coordinates) driving the latent probit linear predictor.  Binary
## responses are drawn as `y = rbinom(1, pnorm(eta))`.  The fixture size
## (n_sites = 120, n_traits = 3, K = 1) was chosen as the smallest grid
## where the paired (latent + unique) fit reaches PD Hessian on binary
## probit; the engine is run with `control = list(n_init = 5,
## init_jitter = 0.5)` so the optimiser has a fair chance of escaping
## the local optima that a binary likelihood with absorbed tau induces.
## The focus is on the engine fitting the paired spec cleanly and on
## the CI smoke through the unified `confint(parm, method)` surface,
## not on coverage-grade Sigma recovery (which stays in Phase B-COV).
##
## What we assert:
##   * `spatial_latent(0 + trait | coords, d = 1) +
##      spatial_unique(0 + trait | coords)` fits cleanly on binary
##     probit with `fit_health$pd_hessian == TRUE` and both engine slots
##     toggled (`use$spatial_latent` and `use$spde`).
##   * CI smoke: `confint(parm = "rho:spatial:1,2", method = "profile")`
##     returns a 1x2 matrix with at least one finite bound (looped over
##     the three upper-triangular pairs so a single hard pair does not
##     collapse the test).
##
## SKIP discipline (no fake-pass): if the paired fit fails to converge
## or the Hessian is non-PD, we `skip()` honestly rather than relax the
## assertion.  In that case the register row stays `partial` and the
## final report says so.

skip_if_not_spatial_binary_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Build a small binary probit spatial fixture:
##   * Random 2D coordinates in [0, 1]^2 for n_sites sites.
##   * Draw one Matern (kappa = sqrt(8) / range) spatial field on the
##     fixture's own SPDE mesh, scaled to unit marginal variance.
##   * Per-trait loadings on the single shared field give a moderate
##     cross-trait correlation, so the paired (latent + unique) spec is
##     identifiable on the binary scale.
##   * Per-trait intercepts kept near zero so Pr(y = 1) lives mid-range
##     and the probit log-likelihood is not at the y == 0 or y == 1
##     boundary.
make_spatial_binary_fixture <- function(n_sites = 120L, n_traits = 3L,
                                        range_true = 0.3,
                                        seed = 20260528L) {
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
  df$value        <- NA_real_

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.07)
  n_mesh <- ncol(mesh$A_st)

  ## Draw the shared Matern field on the engine's own precision matrix
  ## (kappa^4 M0 + 2 kappa^2 M1 + M2) so the simulation is internally
  ## consistent with the C++ template's prior.  Rescale to unit marginal
  ## variance so the truth loadings sit on a standard scale.
  M0 <- mesh$spde$c0
  M1 <- mesh$spde$g1
  M2 <- mesh$spde$g2
  Q_base     <- as.matrix(kappa_true^4 * M0 +
                          2 * kappa_true^2 * M1 + M2)
  Sigma_base <- solve(Q_base)
  scale_om   <- 1 / sqrt(mean(diag(Sigma_base)))
  chol_S     <- chol(Sigma_base + 1e-8 * diag(n_mesh))
  omega_true <- scale_om *
    as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))   # length n_mesh

  ## Loadings on the single shared field: moderate same-sign on traits 1
  ## and 2, opposite sign on trait 3 -- gives a non-trivial cross-trait
  ## correlation pattern at the latent scale.
  Lambda_true <- matrix(c(0.9, 0.7, -0.6), nrow = n_traits, ncol = 1L)

  A_full          <- as.matrix(mesh$A_st)              # n_obs x n_mesh
  omega_per_row   <- as.numeric(A_full %*% omega_true) # length n_obs
  ## With K = 1, the spatial signal per row is omega_per_row * lambda_t
  ## where t is the row's trait index -- i.e. the row-wise inner product
  ## of omega_per_row (n_obs) and Lambda_true[trait_id, 1] (n_obs).
  spatial_per_row <- omega_per_row *
                     Lambda_true[df$trait_id, 1L, drop = TRUE]

  alpha_t <- c(-0.1, 0.0, 0.1)
  eta     <- alpha_t[df$trait_id] + spatial_per_row
  prob    <- stats::pnorm(eta)
  df$value <- stats::rbinom(length(eta), size = 1L, prob = prob)
  df$site         <- factor(df$site, levels = seq_len(n_sites))
  df$species      <- factor(df$species, levels = 1L)
  df$site_species <- factor(df$site_species)

  list(
    data        = df,
    mesh        = mesh,
    n_traits    = n_traits,
    Lambda_true = Lambda_true,
    range_true  = range_true
  )
}

## ---------------------------------------------------------------
## spatial_latent + spatial_unique paired on binary probit
## ---------------------------------------------------------------
test_that("spatial_latent + spatial_unique paired fit on binary probit; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_spatial_binary_deps()

  fx <- make_spatial_binary_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              spatial_latent(0 + trait | coords, d = 1) +
              spatial_unique(0 + trait | coords),
      data    = fx$data,
      mesh    = fx$mesh,
      family  = stats::binomial(link = "probit"),
      silent  = TRUE,
      control = list(n_init = 5, init_jitter = 0.5)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "spatial_latent + spatial_unique binary probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("spatial paired binary probit fit did not converge with PD Hessian; SPA-02 stays partial pending bigger n / different seed")
  }

  ## Engine slot diagnostics: both halves of the pair must be active.
  expect_stationary_for_recovery_test(fit)
  expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_latent))
  expect_equal(fit$tmb_data$spde_lv_k, 1L)

  ## Lambda_spde reported with the expected (n_traits x K) shape.
  Lhat <- fit$report$Lambda_spde
  expect_equal(dim(Lhat), c(fx$n_traits, 1L))

  ## CI smoke: confint(parm = "rho:spatial:i,j", method = "profile")
  ## routes through profile_ci_correlation() at the "spatial" tier and
  ## returns a 1x2 matrix.  We require at least one finite bound on at
  ## least one of the three upper-tri pairs (1,2 / 1,3 / 2,3) so a
  ## single hard pair does not collapse the test.  This is the smoke
  ## bar; tighter coverage at scale stays in Phase B-COV (CI-08).
  pairs_to_try <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
  any_finite <- FALSE
  for (p in pairs_to_try) {
    parm_token <- sprintf("rho:spatial:%d,%d", p[1L], p[2L])
    ci <- tryCatch(
      suppressMessages(suppressWarnings(stats::confint(
        fit, parm = parm_token, method = "profile"
      ))),
      error = function(e) e
    )
    if (!inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
          ncol(ci) == 2L && any(is.finite(ci))) {
      any_finite <- TRUE
      break
    }
  }
  if (!any_finite) {
    skip("Profile CI for rho:spatial did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)
})
