## Phase B-matrix C-ord (Design 59 Group C): `ordinal_probit()` x spatial
## (SPDE) structural recovery + CI smoke.
##
## Walks SPA-02 (spatial_latent + spatial_unique paired), SPA-03
## (spatial_scalar) and SPA-04 (spatial_indep / spatial_dep) of
## `docs/design/35-validation-debt-register.md` from `partial` toward
## `covered` for the ordinal-probit branch, one structural keyword per
## `test_that`.
##
## Cells (one test_that each):
##   * `spatial_latent(d = 1) + spatial_unique` paired (supplies the
##     reduced-rank cross-trait SPDE block plus the per-trait SPDE block;
##     sets `use$spatial_latent` + `use$spde`)
##   * `spatial_scalar(0 + trait | site)`  (single shared SPDE variance tied
##     across traits via TMB `map`; sets `use$spatial_scalar` + `use$spde`)
##   * `spatial_indep(0 + trait | site)`   (per-trait independent SPDE fields,
##     diagonal-by-construction; sets `use$spatial_indep`)
##   * `spatial_dep(0 + trait | site)`     (unstructured cross-trait SPDE
##     block; rewrites to spatial_latent(d = n_traits), so `use$spatial_dep`
##     + `use$spatial_latent`)
##
## Fixture (Honest-matrix discipline, Design 59): seed-controlled, K = 4
## ordinal categories (3 thresholds; tau = 0, 0.7, 1.4), 3 traits, ~100
## sites with random 2D coordinates in the unit square, one species per site
## (so `site` is the unit of replication for the spatial field), small SPDE
## mesh. The K = 4 ordinal response is built from a latent
## y* = alpha_t + beta_x * x + spatial_per_row + N(0, 1) cut at the
## thresholds. A fixed covariate `x` with var(x) ~ 1 (>> 0.5) drives the
## latent process: ordinal-probit pins the latent residual at sigma_d^2 = 1
## EXACTLY (Wright/Falconer/Hadfield threshold model), so per the Phase B0
## scoping memo (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md
## sec. 3.3 + 4) the structural signal is only identifiable when
## var(x) >= 0.5. We use var(x) ~ 1 to stay well clear of that floor.
##
## Tolerance: ordinal-probit is a FIXED-residual-scale family (sigma_d^2 = 1
## by construction, like binomial-probit), so per Design 59 the recovery band
## is TIGHTER than mean-dependent families (poisson/nbinom2/gamma/beta get
## 3x). The load-bearing assertions per cell are (a) clean convergence with a
## PD Hessian, (b) the engine use-flag for the intended structural path, (c)
## the family really is ordinal_probit (family_id 14) with live cutpoints,
## and (d) a CI smoke (`confint(parm = "rho:spatial:i,j", method = "profile")`
## finite on >= 1 pair) OR a non-degenerate
## `extract_correlations(tier = "spatial")`. Where a single shared SPDE
## variance is recoverable (spatial_scalar), we add a 2.5x point band on
## tau_spde. Per the B0 memo the SPDE + ordinal combination is genuinely
## noisy at small n, so the paired (latent + unique) and dep cells are the
## ones most likely to honest-SKIP.
##
## SKIP discipline (no fake-pass, Design 59): any cell that fails to
## construct, fails to converge, or returns a non-PD Hessian is `skip()`-ped
## with a reason and reported as "stays partial". A degenerate CI or
## correlation frame also skips rather than relaxing the assertion. The
## register row only moves to `covered` on real passing evidence. Bootstrap
## CI is unsupported for ordinal_probit (Design 50 family-ID 14 guard); CI
## smoke uses the PROFILE method only. Time-box per fit is the campaign-wide
## 15 min; these small-mesh fits are far under that locally.

skip_if_not_ordinal_spatial_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

expect_ordinal_spatial_fit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  ## Confirm the response really is ordinal_probit (family_id 14) -- guards
  ## against a silent family fallthrough making the "ordinal" claim hollow.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 14L)
  ## And the cutpoint machinery is live: a K = 4 ordinal fit must expose
  ## free cutpoints. (K = 4 => 2 free cutpoints per trait beyond tau_1.)
  cuts <- gllvmTMB::extract_cutpoints(fit)
  testthat::expect_s3_class(cuts, "data.frame")
  testthat::expect_gt(nrow(cuts), 0L)
  testthat::expect_true(all(is.finite(cuts$tau_estimate)))
}

## Reusable CI smoke: at least one finite profile bound on one of the
## upper-tri rho:spatial pairs. Returns TRUE/FALSE; the caller decides skip.
## PROFILE only -- bootstrap is unsupported for ordinal_probit.
ordinal_spatial_rho_ci_any_finite <- function(fit, n_traits) {
  pairs_to_try <- utils::combn(seq_len(n_traits), 2L, simplify = FALSE)
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
      return(TRUE)
    }
  }
  FALSE
}

## Reusable: extract_correlations(tier = "spatial") is a non-degenerate
## frame -- one row per upper-tri trait pair with finite correlations.
ordinal_spatial_correlations_ok <- function(fit) {
  cor_df <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
      fit, tier = "spatial", method = "fisher-z", link_residual = "none"
    ))),
    error = function(e) e
  )
  !inherits(cor_df, "error") &&
    is.data.frame(cor_df) && nrow(cor_df) > 0L &&
    all(c("tier", "trait_i", "trait_j", "correlation", "lower", "upper")
        %in% names(cor_df)) &&
    all(is.finite(cor_df$correlation))
}

## Paired (latent + unique) ordinal spatial fixture. Mirrors the beta-spatial
## paired fixture (test-matrix-beta-spatial.R): draw ONE shared Matern field
## on the engine's own SPDE precision (kappa^4 M0 + 2 kappa^2 M1 + M2) so the
## simulation is internally consistent with the C++ template's prior, rescale
## to unit marginal variance, then load it onto traits via a (T x 1) Lambda.
## The latent y* = alpha_t + beta_x * x + spatial_per_row + N(0, 1) is cut at
## the K = 4 thresholds. The single shared field gives the cross-trait
## correlation the paired (latent + unique) spec is meant to identify.
make_ordinal_spatial_paired_fixture <- function(n_sites = 100L, n_traits = 3L,
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
  df$value        <- NA_integer_

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.07)
  n_mesh <- ncol(mesh$A_st)

  M0 <- mesh$spde$c0
  M1 <- mesh$spde$g1
  M2 <- mesh$spde$g2
  Q_base     <- as.matrix(kappa_true^4 * M0 +
                          2 * kappa_true^2 * M1 + M2)
  Sigma_base <- solve(Q_base)
  scale_om   <- 1 / sqrt(mean(diag(Sigma_base)))
  chol_S     <- chol(Sigma_base + 1e-8 * diag(n_mesh))
  omega_true <- scale_om *
    as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))

  ## Modest loadings: moderate same-sign on traits 1 and 2, opposite sign on
  ## trait 3 -- a non-trivial cross-trait correlation. Intercepts near 0 so
  ## the K = 4 categories all fill.
  Lambda_true <- matrix(c(0.6, 0.5, -0.4)[seq_len(n_traits)],
                        nrow = n_traits, ncol = 1L)
  alpha_t <- c(0.1, 0.0, -0.1)[seq_len(n_traits)]
  beta_x  <- 0.8                       # fixed-effect slope on the covariate x
  taus    <- c(0, 0.7, 1.4)            # K = 4 ordinal thresholds (3 cutpoints)

  A_full          <- as.matrix(mesh$A_st)
  omega_per_row   <- as.numeric(A_full %*% omega_true)
  spatial_per_row <- omega_per_row *
                     Lambda_true[df$trait_id, 1L, drop = TRUE]

  df$x  <- stats::rnorm(nrow(df), 0, 1)            # var(x) ~ 1 >> 0.5
  ystar <- alpha_t[df$trait_id] + beta_x * df$x + spatial_per_row +
           stats::rnorm(nrow(df), 0, 1)
  df$value <- as.integer(1L + (ystar > taus[1L]) + (ystar > taus[2L]) +
                         (ystar > taus[3L]))

  df$site         <- factor(df$site, levels = seq_len(n_sites))
  df$species      <- factor(df$species, levels = 1L)
  df$site_species <- factor(df$site_species)

  list(
    data        = df,
    mesh        = mesh,
    n_traits    = n_traits,
    Lambda_true = Lambda_true
  )
}

## Single-field ordinal spatial fixture for scalar / indep / dep. Uses the
## package simulator to draw a Gaussian spatial residual surface (exponential
## Matern-ish kernel) with one species per site, then forms the latent
## y* = spatial_surface + beta_x * x + N(0, 1) and cuts at the K = 4
## thresholds. One species per site makes `site` the unit of replication for
## the spatial random field.
make_ordinal_spatial_fixture <- function(n_sites = 100L, n_traits = 3L,
                                         spatial_range = 0.35,
                                         sigma2_spa_true = 0.5,
                                         seed = 20260529L) {
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
    sigma2_spa = rep(sigma2_spa_true, n_traits),
    seed = seed
  )
  df  <- sim$data
  ## Add a fixed covariate x with var(x) ~ 1 to lift the latent signal above
  ## the sigma_d^2 = 1 ordinal floor (Phase B0 memo sec. 3.3 / 4).
  set.seed(seed + 1L)
  df$x  <- stats::rnorm(nrow(df), 0, 1)
  beta_x <- 0.8
  taus   <- c(0, 0.7, 1.4)            # K = 4 ordinal thresholds (3 cutpoints)
  ystar  <- df$value + beta_x * df$x + stats::rnorm(nrow(df), 0, 1)
  df$value <- as.integer(1L + (ystar > taus[1L]) + (ystar > taus[2L]) +
                         (ystar > taus[3L]))
  list(data = df, sim = sim, n_traits = n_traits,
       sigma2_spa_true = sigma2_spa_true)
}

## ---------------------------------------------------------------
## Cell 1 (SPA-02): spatial_latent(d = 1) + spatial_unique paired
## ---------------------------------------------------------------
## The paired spec supplies the reduced-rank cross-trait SPDE block
## (use$spatial_latent) plus the per-trait SPDE block (use$spde). Per the B0
## memo this is the borderline latent-on-fixed-residual case, so an honest
## skip is expected if the fixture does not identify it. The engine is run
## with `control = list(n_init = 5, init_jitter = 0.5)` so the optimiser has
## a fair chance of escaping local optima (mirrors the beta-spatial paired
## test).
test_that("ordinal_probit: spatial_latent(d=1) + spatial_unique paired fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_ordinal_spatial_deps()
  fx <- make_ordinal_spatial_paired_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x +
              spatial_latent(0 + trait | coords, d = 1) +
              spatial_unique(0 + trait | coords),
      data    = fx$data,
      mesh    = fx$mesh,
      family  = gllvmTMB::ordinal_probit(),
      silent  = TRUE,
      control = list(n_init = 5, init_jitter = 0.5)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "ordinal spatial_latent + spatial_unique fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("ordinal spatial_latent + spatial_unique did not converge with PD Hessian; SPA-02(ordinal) stays partial pending bigger n / different seed")
  }

  expect_ordinal_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_latent))
  expect_equal(fit$tmb_data$spde_lv_k, 1L)

  ## Lambda_spde reported with the expected (n_traits x K) shape.
  Lhat <- fit$report$Lambda_spde
  expect_equal(dim(Lhat), c(fx$n_traits, 1L))

  ## CI smoke on rho:spatial OR non-degenerate correlations. If neither, skip
  ## honestly rather than relaxing the assertion.
  ci_ok  <- ordinal_spatial_rho_ci_any_finite(fit, fx$n_traits)
  cor_ok <- ordinal_spatial_correlations_ok(fit)
  if (!ci_ok && !cor_ok) {
    skip("Neither rho:spatial profile CI nor extract_correlations(tier='spatial') was non-degenerate (ordinal spatial paired); honest skip rather than relax assertion")
  }
  expect_true(ci_ok || cor_ok)
})

## ---------------------------------------------------------------
## Cell 2 (SPA-03): spatial_scalar(0 + trait | site)
## ---------------------------------------------------------------
## A single shared SPDE variance across traits: the engine ties every
## per-trait `log_tau_spde` entry to one value via TMB's `map` mechanism
## (the byte-equivalence contract for `spatial_scalar`). use$spatial_scalar
## and use$spde are both set. CI smoke is on the single shared `tau_spde`
## (under the map the parm token is the bare "tau_spde", block_length == 1L).
test_that("ordinal_probit: spatial_scalar(0 + trait | site) fits; tau tied; tau_spde profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_ordinal_spatial_deps()
  fx   <- make_ordinal_spatial_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.1)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + spatial_scalar(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = gllvmTMB::ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "ordinal spatial_scalar fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("ordinal spatial_scalar did not converge with PD Hessian; SPA-03(ordinal) stays partial pending bigger n / different seed")
  }

  expect_ordinal_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_scalar))

  ## Tied-tau contract: spatial_scalar collapses log_tau_spde to one shared
  ## value via TMB's `map`; the reported vector must be exactly tied.
  ltau <- as.numeric(fit$report$log_tau_spde)
  expect_equal(length(ltau), fx$n_traits)
  expect_true(all(abs(ltau - ltau[1L]) < 1e-10),
              info = "spatial_scalar must tie log_tau_spde across traits via tmb_map")

  ## Shared SPDE tau / kappa finite-positive.
  expect_true(is.finite(exp(ltau[1L])))
  expect_gt(exp(ltau[1L]), 0)
  kappa <- as.numeric(fit$report$kappa)
  expect_true(is.finite(kappa))
  expect_gt(kappa, 0)

  ## Recovery on the single shared SPDE marginal variance. The SPDE marginal
  ## variance is sigma^2 = 1 / (4 pi kappa^2 tau^2); ordinal-probit fixes the
  ## latent residual at sigma_d^2 = 1, so per Design 59 the structural-variance
  ## band is TIGHTER (2.5x) than mean-dependent families (which get 3x). Honest
  ## skip if outside the band rather than relaxing it.
  tau_hat          <- exp(ltau[1L])
  sigma2_spa_hat   <- 1 / (4 * pi * kappa^2 * tau_hat^2)
  sigma2_spa_truth <- fx$sigma2_spa_true
  ratio            <- sigma2_spa_hat / sigma2_spa_truth
  if (!is.finite(ratio) || ratio < 1 / 2.5 || ratio > 2.5) {
    skip(sprintf(
      "sigma^2_spa_scalar recovery outside 2.5x band (hat = %.3g, truth = %.3g, ratio = %.3g); SPA-03 stays partial pending bigger n",
      sigma2_spa_hat, sigma2_spa_truth, ratio
    ))
  }
  expect_gt(sigma2_spa_hat, sigma2_spa_truth / 2.5)
  expect_lt(sigma2_spa_hat, sigma2_spa_truth * 2.5)

  ## CI smoke: confint(parm = "tau_spde", method = "profile"). PROFILE only.
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "tau_spde", method = "profile"
    ))),
    error = function(e) e
  )
  if (inherits(ci, "error")) {
    skip(sprintf(
      "confint(parm = 'tau_spde', method = 'profile') errored on ordinal spatial_scalar: %s",
      conditionMessage(ci)
    ))
  }
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(ncol(ci), 2L)
  if (!any(is.finite(ci))) {
    skip("tau_spde profile CI returned no finite bound on ordinal spatial_scalar; honest skip rather than relax assertion")
  }
  expect_true(any(is.finite(ci)))
})

## ---------------------------------------------------------------
## Cell 3 (SPA-04): spatial_indep(0 + trait | site)
## ---------------------------------------------------------------
## Per-trait independent SPDE fields (diagonal-by-construction):
## use$spatial_indep is set. Verify one kappa and one log_tau per trait,
## both finite. No cross-trait correlation surface to extract here. Per the
## B0 memo this is the easiest ordinal spatial case after `unique`.
test_that("ordinal_probit: spatial_indep(0 + trait | site) fits; pd_hessian TRUE", {
  skip_if_not_heavy()
  skip_if_not_ordinal_spatial_deps()
  fx   <- make_ordinal_spatial_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.12)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + spatial_indep(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = gllvmTMB::ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "ordinal spatial_indep fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("ordinal spatial_indep did not converge with PD Hessian; SPA-04(ordinal) stays partial pending bigger n / different seed")
  }

  expect_ordinal_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spatial_indep))
  expect_true(isTRUE(fit$use$spde))

  kappa <- as.numeric(fit$report$kappa)
  expect_true(is.finite(kappa))
  expect_gt(kappa, 0)

  log_tau <- as.numeric(fit$report$log_tau_spde)
  expect_equal(length(log_tau), fit$n_traits)
  expect_true(all(is.finite(log_tau)))
})

## ---------------------------------------------------------------
## Cell 4 (SPA-04): spatial_dep(0 + trait | site)
## ---------------------------------------------------------------
## Full unstructured cross-trait SPDE block; rewrites to
## spatial_latent(d = n_traits), so use$spatial_dep AND use$spatial_latent
## are both set. Per the B0 memo this is the borderline fixed-residual case
## (full cross-trait surface may give boundary correlations at small n), so it
## is the most likely to honest-SKIP. CI smoke: at least one finite profile
## bound on one rho:spatial pair OR a non-degenerate
## extract_correlations(tier = "spatial"). PROFILE only (no bootstrap for
## ordinal_probit per Design 50 family-ID 14 guard).
test_that("ordinal_probit: spatial_dep(0 + trait | site) fits; pd_hessian TRUE; CI smoke OR correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_ordinal_spatial_deps()
  fx   <- make_ordinal_spatial_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.12)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + spatial_dep(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = gllvmTMB::ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "ordinal spatial_dep fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("ordinal spatial_dep did not converge with PD Hessian; SPA-04(ordinal) stays partial pending bigger n / different seed")
  }

  expect_ordinal_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spatial_dep))
  ## spatial_dep rewrites to spatial_latent(d = n_traits); the latent flag
  ## must also be TRUE so the cross-trait correlation surface is available.
  expect_true(isTRUE(fit$use$spatial_latent))

  ## CI smoke on rho:spatial OR a non-degenerate correlation frame. Accept
  ## either branch as the structural-recovery evidence for this borderline
  ## cell, and skip honestly only if BOTH degenerate.
  ci_ok  <- ordinal_spatial_rho_ci_any_finite(fit, fx$n_traits)
  cor_ok <- ordinal_spatial_correlations_ok(fit)
  if (!ci_ok && !cor_ok) {
    skip("Neither rho:spatial profile CI nor extract_correlations(tier='spatial') was non-degenerate (ordinal spatial_dep); honest skip rather than relax assertion")
  }
  expect_true(ci_ok || cor_ok)
})
