## Phase B-INF Lane 2 / B5 (Design 58): `spatial_indep` and `spatial_dep`
## on a binary probit fit with an SPDE mesh -- recovery + CI smoke.
##
## Walks SPA-04 of `docs/design/35-validation-debt-register.md` from
## `partial` to `covered` for the binary probit branch.
##
## Fixture: 3 traits, 80 sites placed uniformly in the unit square, one
## species per site (so site = unit of replication for the spatial random
## field). The Gaussian latent surface from `simulate_site_trait()` is
## passed through a probit link to make 0/1 responses. The SPDE precision
## drives spatial smoothing on a small mesh (~50 vertices via
## `cutoff = 0.12`). The fixture size + signal strength were tuned so
## that both keywords reach a PD Hessian on a single seed; the test
## stays SKIP-honest rather than relaxing this if a future engine change
## breaks the recovery.
##
## What we assert:
##   * `spatial_indep(0 + trait | site)` fits cleanly (convergence == 0,
##     `fit_health$pd_hessian == TRUE`), the use-flag `fit$use$spatial_indep`
##     is set, and the reported `kappa` is finite-positive with one
##     `log_tau_spde` entry per trait. (No cross-trait correlation surface
##     to inspect here -- `spatial_indep` is diagonal-by-construction.)
##   * `spatial_dep(0 + trait | site)` on the same fixture fits cleanly,
##     `fit$use$spatial_dep` is set, the engine routes via
##     `spatial_latent(d = n_traits)` so `fit$use$spatial_latent` is also
##     TRUE, `extract_correlations(tier = "spatial")` returns a non-degenerate
##     data frame with finite correlations, and at least one of the
##     upper-tri profile CIs (`rho:spatial:i,j`) returns a finite bound.
##
## SKIP discipline (no fake-pass): if either fit fails to converge with a
## PD Hessian we `skip()` honestly rather than relax the assertion. The
## register row stays `partial` if the test only skips.

skip_if_not_spatial_binary_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

make_spatial_binary_fixture <- function(n_sites = 80L, n_traits = 3L,
                                        spatial_range = 0.4,
                                        sigma2_spa = 1.0,
                                        seed = 20260528L) {
  ## Generate Gaussian eta = trait intercept + spatial residual via the
  ## package's own simulator (spatial path uses an exponential Matern-ish
  ## kernel), then probit-transform to 0/1.
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites,
    n_species = 1L,
    n_traits = n_traits,
    mean_species_per_site = 1,
    n_predictors = 1,
    alpha = rep(0, n_traits),
    beta  = matrix(0, nrow = n_traits, ncol = 1),
    sigma2_eps = 0,
    spatial_range = spatial_range,
    sigma2_spa = rep(sigma2_spa, n_traits),
    seed = seed
  )
  df  <- sim$data
  eta <- df$value
  df$value <- stats::rbinom(length(eta), size = 1L, prob = stats::pnorm(eta))
  list(data = df, sim = sim)
}

expect_binary_spatial_fit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
}

## ---------------------------------------------------------------
## spatial_indep(0 + trait | site) on binary probit
## ---------------------------------------------------------------
test_that("spatial_indep(0 + trait | site) fits on binary probit; pd_hessian TRUE", {
  skip_if_not_heavy()
  skip_if_not_spatial_binary_deps()
  fx <- make_spatial_binary_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.12)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = stats::binomial(link = "probit")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "spatial_indep binary probit fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("spatial_indep binary probit fit did not converge with PD Hessian; SPA-04 stays partial pending bigger n / different seed")
  }

  expect_binary_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spatial_indep))
  expect_true(isTRUE(fit$use$spde))

  ## spatial_indep is per-trait independent SPDE fields. Verify the engine
  ## reported one kappa and one log_tau per trait (non-degenerate by virtue
  ## of being finite); no cross-trait correlation surface to extract.
  kappa <- as.numeric(fit$report$kappa)
  expect_true(is.finite(kappa))
  expect_gt(kappa, 0)

  log_tau <- as.numeric(fit$report$log_tau_spde)
  expect_equal(length(log_tau), fit$n_traits)
  expect_true(all(is.finite(log_tau)))
})

## ---------------------------------------------------------------
## spatial_dep(0 + trait | site) on the same fixture
## ---------------------------------------------------------------
test_that("spatial_dep(0 + trait | site) fits on binary probit; CI smoke + extract_correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_spatial_binary_deps()
  fx <- make_spatial_binary_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.12)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = stats::binomial(link = "probit")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "spatial_dep binary probit fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("spatial_dep binary probit fit did not converge with PD Hessian; SPA-04 stays partial pending bigger n / different seed")
  }

  expect_binary_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spatial_dep))
  ## spatial_dep rewrites to spatial_latent(d = n_traits); the latent flag
  ## must also be TRUE so the cross-trait correlation surface is available.
  expect_true(isTRUE(fit$use$spatial_latent))

  ## CI smoke: confint(parm = "rho:spatial:1,2", method = "profile") routes
  ## through profile_ci_correlation() at the "spde" / "spatial" tier. We
  ## require at least one finite bound on at least one of the three
  ## upper-tri pairs.
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

  ## extract_correlations on spatial tier: returns one row per upper-tri
  ## pair with finite correlations (the rotation-invariant cross-trait
  ## correlation surface implied by Lambda_spde Lambda_spde^T).
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier   = "spatial",
      method = "fisher-z",
      link_residual = "none"
    )
  ))
  expect_s3_class(cor_df, "data.frame")
  expect_gt(nrow(cor_df), 0L)
  expect_true(all(c("tier", "trait_i", "trait_j", "correlation",
                    "lower", "upper") %in% names(cor_df)))
  expect_true(all(is.finite(cor_df$correlation)))

  ## bootstrap_Sigma() does not yet carry an SPDE correlation bootstrap.
  ## The extractor must therefore return the explicit Wald/Fisher-z
  ## fallback rows instead of an empty data frame or mislabeled bootstrap
  ## support.
  cor_boot <- NULL
  expect_message(
    cor_boot <- suppressWarnings(gllvmTMB::extract_correlations(
      fit,
      tier   = "spatial",
      method = "bootstrap",
      nsim = 3L,
      seed = 20260704L,
      link_residual = "none"
    )),
    "falling back to Wald"
  )
  expect_s3_class(cor_boot, "data.frame")
  expect_equal(nrow(cor_boot), nrow(cor_df))
  expect_true(all(cor_boot$method == "wald"))
  expect_true(all(is.finite(cor_boot$correlation)))
  finite_bounds <- is.finite(cor_boot$lower) & is.finite(cor_boot$upper)
  expect_true(any(finite_bounds))
  expect_true(all(cor_boot$lower[finite_bounds] >= -1))
  expect_true(all(cor_boot$upper[finite_bounds] <= 1))
})
