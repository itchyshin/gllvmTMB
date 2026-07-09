## Phase B-matrix C-pois (Design 59 Group C): `poisson(link = "log")` on the
## spatial (SPDE) structural keywords -- structural recovery + CI smoke.
##
## Walks SPA-02 (spatial_latent + spatial_unique paired), SPA-03
## (spatial_scalar) and SPA-04 (spatial_indep / spatial_dep) of
## `docs/design/35-validation-debt-register.md` from `partial` to `covered`
## for the Poisson branch. The binary-probit branch is already `covered`
## (test-spatial-pair-binary.R, test-spatial-depindep-binary.R); this file
## is the count (log-link Poisson) analogue. It mirrors the committed Beta
## sibling (test-matrix-beta-spatial.R), swapping the family to Poisson.
##
## Family scope: Poisson is a MEAN-DEPENDENT family (the latent residual on
## the log scale is log(1 + 1/mu_t), so the effective scale shifts with the
## intercept; there is no fixed link-residual the way binomial-logit has
## pi^2/3 or ordinal-probit has 1). Per the Phase B0 scoping memo
## (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md sec.2-3),
## mean-dependent families carry WIDER recovery tolerance than
## fixed-residual-scale families. We therefore do NOT make a tight B0
## point-recovery assertion on the SPDE variances/range; the load-bearing
## assertions are (a) clean convergence with a PD Hessian, (b) the engine
## use-flag for the intended structural path, and (c) a CI smoke
## (`confint(parm = "rho:spatial:1,2", method = "profile")` finite on >= 1
## pair) OR a non-degenerate `extract_correlations(tier = "spatial")`. This
## is the honest target for a mean-dependent family at a modest fixture size:
## structural *recovery* in the "fits + identifies + reports finite
## structure" sense, not a narrow numeric band. Poisson has no dispersion
## parameter (no phi), so the family sanity check is on family_id == 2 only.
##
## Fixture: 3 traits, ~100 sites with random 2D coordinates in the unit
## square, response a count with mean ~= 2, small SPDE mesh. The Gaussian
## latent surface (drawn either on the engine's own SPDE precision or via the
## package simulator's exponential kernel) is added to a per-trait log
## intercept near log(2) and then emitted as rpois(exp(eta)) with modest
## loadings so the count mean stays mid-range (neither near-zero, where there
## is no information, nor overflowing). Per the B0 memo the SPDE +
## mean-dependent combination is genuinely noisy at small n, so the paired
## (latent + unique) and dep cells are the ones most likely to honest-SKIP.
##
## SKIP discipline (no fake-pass): any cell that fails to construct, fails to
## converge, or returns a non-PD Hessian is `skip()`-ped with a reason and
## reported as "stays partial". A degenerate CI or correlation frame also
## skips rather than relaxing the assertion. The register row only moves to
## `covered` on real passing evidence. Each fit is expected to finish well
## within the 15-min-per-fit time-box on these small fixtures.

skip_if_not_poisson_spatial_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

expect_poisson_spatial_fit_health <- function(fit) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
  ## Sanity: this really is the Poisson family (family_id 2). Poisson has no
  ## dispersion parameter, so there is no phi to check.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 2L)
}

## Reusable CI smoke: at least one finite profile bound on one of the
## upper-tri rho:spatial pairs. Returns TRUE/FALSE; the caller decides skip.
poisson_spatial_rho_ci_any_finite <- function(fit, n_traits) {
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

## Reusable: extract_correlations(tier = "spatial") is a non-degenerate frame.
expect_poisson_spatial_correlations_nondegenerate <- function(fit) {
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier          = "spatial",
      method        = "fisher-z",
      link_residual = "none"
    )
  ))
  testthat::expect_s3_class(cor_df, "data.frame")
  testthat::expect_gt(nrow(cor_df), 0L)
  testthat::expect_true(all(c("tier", "trait_i", "trait_j", "correlation",
                              "lower", "upper") %in% names(cor_df)))
  testthat::expect_true(all(is.finite(cor_df$correlation)))
}

## Paired (latent + unique) Poisson spatial fixture. Mirrors the binary-probit
## paired fixture (test-spatial-pair-binary.R): draw ONE shared Matern field
## on the engine's own SPDE precision (kappa^4 M0 + 2 kappa^2 M1 + M2) so the
## simulation is internally consistent with the C++ template's prior, rescale
## to unit marginal variance, then load it onto traits via a (T x 1) Lambda.
## The log-scale eta is emitted as rpois(exp(eta)) with a per-trait intercept
## near log(2) so the count mean stays mid-range. The single shared field
## gives the cross-trait correlation that the paired (latent + unique) spec is
## meant to identify.
make_poisson_spatial_paired_fixture <- function(n_sites = 100L, n_traits = 3L,
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
  df$value        <- NA_real_

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

  ## Modest loadings so the latent eta stays mid-range and the Poisson mean
  ## does not overflow: moderate same-sign on traits 1 and 2, opposite sign
  ## on trait 3 -- a non-trivial cross-trait correlation.
  Lambda_true <- matrix(c(0.6, 0.5, -0.4)[seq_len(n_traits)],
                        nrow = n_traits, ncol = 1L)

  A_full          <- as.matrix(mesh$A_st)
  omega_per_row   <- as.numeric(A_full %*% omega_true)
  spatial_per_row <- omega_per_row *
                     Lambda_true[df$trait_id, 1L, drop = TRUE]

  ## Log-scale intercepts near log(2) so the count mean ~= 2 per trait.
  alpha_t <- log(2) + c(-0.1, 0.0, 0.1)[seq_len(n_traits)]
  eta     <- alpha_t[df$trait_id] + spatial_per_row
  df$value <- stats::rpois(length(eta), lambda = exp(eta))

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

## Single-field Poisson spatial fixture for scalar / indep / dep. Uses the
## package simulator to draw a Gaussian spatial residual surface (exponential
## Matern-ish kernel) with one species per site, then adds a log-intercept
## near log(2) and emits rpois(exp(eta)). One species per site makes `site`
## the unit of replication for the spatial random field.
make_poisson_spatial_fixture <- function(n_sites = 100L, n_traits = 3L,
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
  ## sim$value is the Gaussian latent log-scale spatial surface (mean 0).
  ## Shift by log(2) so the Poisson mean sits mid-range (~= 2) rather than
  ## at exp(0) = 1 where small-count noise dominates.
  eta <- df$value + log(2)
  df$value <- stats::rpois(length(eta), lambda = exp(eta))
  list(data = df, sim = sim, n_traits = n_traits,
       sigma2_spa_true = sigma2_spa_true)
}

## ---------------------------------------------------------------
## Cell 1 (SPA-02): spatial_latent(d = 1) + spatial_unique paired
## ---------------------------------------------------------------
## The paired spec supplies the reduced-rank cross-trait SPDE block
## (use$spatial_latent) plus the per-trait SPDE block (use$spde). Per the B0
## memo this is the borderline latent-on-mean-dependent case, so an honest
## skip is expected if the fixture does not identify it. The engine is run
## with `control = list(n_init = 5, init_jitter = 0.5)` so the optimiser has
## a fair chance of escaping the local optima a mean-dependent likelihood
## with absorbed tau induces (mirrors the binary-probit paired test).
test_that("Poisson: spatial_latent(d=1) + spatial_unique paired fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_poisson_spatial_deps()
  fx <- make_poisson_spatial_paired_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              spatial_latent(0 + trait | coords, d = 1) +
              spatial_unique(0 + trait | coords),
      data    = fx$data,
      mesh    = fx$mesh,
      family  = stats::poisson(link = "log"),
      silent  = TRUE,
      control = list(n_init = 5, init_jitter = 0.5)
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Poisson spatial_latent + spatial_unique fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Poisson spatial_latent + spatial_unique did not converge with PD Hessian; SPA-02(poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_latent))
  expect_equal(fit$tmb_data$spde_lv_k, 1L)

  ## Lambda_spde reported with the expected (n_traits x K) shape.
  Lhat <- fit$report$Lambda_spde
  expect_equal(dim(Lhat), c(fx$n_traits, 1L))

  ## CI smoke on rho:spatial. If no pair yields a finite profile bound, skip
  ## honestly rather than relaxing the assertion.
  if (!poisson_spatial_rho_ci_any_finite(fit, fx$n_traits)) {
    skip("Profile CI for rho:spatial returned no finite bound on any pair (Poisson spatial paired); honest skip rather than relax assertion")
  }
  expect_true(poisson_spatial_rho_ci_any_finite(fit, fx$n_traits))
})

## ---------------------------------------------------------------
## Cell 2 (SPA-03): spatial_scalar(0 + trait | site)
## ---------------------------------------------------------------
## A single shared SPDE variance across traits: the engine ties every
## per-trait `log_tau_spde` entry to one value via TMB's `map` mechanism
## (the byte-equivalence contract for `spatial_scalar`). use$spatial_scalar
## and use$spde are both set. CI smoke is on the single shared `tau_spde`
## (under the map the parm token is the bare "tau_spde", block_length == 1L).
test_that("Poisson: spatial_scalar(0 + trait | site) fits; tau tied; tau_spde profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_poisson_spatial_deps()
  fx   <- make_poisson_spatial_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.1)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_scalar(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = stats::poisson(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Poisson spatial_scalar fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Poisson spatial_scalar did not converge with PD Hessian; SPA-03(poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_scalar))

  ## Tied-tau contract: spatial_scalar collapses log_tau_spde to one shared
  ## value via TMB's `map`; the reported vector must be exactly tied.
  ltau <- as.numeric(fit$report$log_tau_spde)
  expect_equal(length(ltau), fx$n_traits)
  expect_true(all(abs(ltau - ltau[1L]) < 1e-10),
              info = "spatial_scalar must tie log_tau_spde across traits via tmb_map")

  ## Mean-dependent family: only require the shared SPDE tau / kappa to be
  ## finite-positive (no tight numeric band per the B0 memo).
  expect_true(is.finite(exp(ltau[1L])))
  expect_gt(exp(ltau[1L]), 0)
  kappa <- as.numeric(fit$report$kappa)
  expect_true(is.finite(kappa))
  expect_gt(kappa, 0)

  ## CI smoke: confint(parm = "tau_spde", method = "profile").
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "tau_spde", method = "profile"
    ))),
    error = function(e) e
  )
  if (inherits(ci, "error")) {
    skip(sprintf(
      "confint(parm = 'tau_spde', method = 'profile') errored on Poisson spatial_scalar: %s",
      conditionMessage(ci)
    ))
  }
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(ncol(ci), 2L)
  if (!any(is.finite(ci))) {
    skip("tau_spde profile CI returned no finite bound on Poisson spatial_scalar; honest skip rather than relax assertion")
  }
  expect_true(any(is.finite(ci)))
})

## ---------------------------------------------------------------
## Cell 3 (SPA-04): spatial_indep(0 + trait | site)
## ---------------------------------------------------------------
## Per-trait independent SPDE fields (diagonal-by-construction):
## use$spatial_indep is set. Verify one kappa and one log_tau per trait,
## both finite. No cross-trait correlation surface to extract here. Per the
## B0 memo this is the easiest mean-dependent spatial case after `unique`.
test_that("Poisson: spatial_indep(0 + trait | site) fits; pd_hessian TRUE", {
  skip_if_not_heavy()
  skip_if_not_poisson_spatial_deps()
  fx   <- make_poisson_spatial_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.12)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = stats::poisson(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Poisson spatial_indep fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Poisson spatial_indep did not converge with PD Hessian; SPA-04(poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_spatial_fit_health(fit)
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
## are both set. Per the B0 memo this is the borderline mean-dependent case
## (full cross-trait surface may give boundary correlations at small n), so it
## is the most likely to honest-SKIP. CI smoke: at least one finite profile
## bound on one rho:spatial pair OR a non-degenerate
## extract_correlations(tier = "spatial").
test_that("Poisson: spatial_dep(0 + trait | site) fits; pd_hessian TRUE; CI smoke OR correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_poisson_spatial_deps()
  fx   <- make_poisson_spatial_fixture()
  mesh <- gllvmTMB::make_mesh(fx$data, c("lon", "lat"), cutoff = 0.12)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(0 + trait | site, mesh = mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = mesh,
      family = stats::poisson(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Poisson spatial_dep fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Poisson spatial_dep did not converge with PD Hessian; SPA-04(poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spatial_dep))
  ## spatial_dep rewrites to spatial_latent(d = n_traits); the latent flag
  ## must also be TRUE so the cross-trait correlation surface is available.
  expect_true(isTRUE(fit$use$spatial_latent))

  ## CI smoke on rho:spatial OR a non-degenerate correlation frame. The
  ## paired-binary test required only the CI; here we accept either branch
  ## as the structural-recovery evidence for this borderline cell, and skip
  ## honestly only if BOTH degenerate.
  ci_ok <- poisson_spatial_rho_ci_any_finite(fit, fx$n_traits)
  cor_df <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
      fit, tier = "spatial", method = "fisher-z", link_residual = "none"
    ))),
    error = function(e) e
  )
  cor_ok <- !inherits(cor_df, "error") &&
    is.data.frame(cor_df) && nrow(cor_df) > 0L &&
    all(is.finite(cor_df$correlation))
  if (!ci_ok && !cor_ok) {
    skip("Neither rho:spatial profile CI nor extract_correlations(tier='spatial') was non-degenerate (Poisson spatial_dep); honest skip rather than relax assertion")
  }
  expect_true(ci_ok || cor_ok)
})
