## Fencing on the exported total-variance profile route.
##
## `profile_ci_total_variance()` accepts five tiers, any family and any level,
## The 2026-07-29 campaign measured the implemented penalty-profile
## approximation, but did not retain the constrained-refit convergence and
## target-fidelity details needed to call it an exact LR profile. Every computed
## interval therefore remains `route-only` until that mechanism is repaired and
## recalibrated. The `interval_status` column keeps this fail-closed boundary
## machine-visible.
##
## Deliberately fit-free: the labelling is a pure function of a handful of fit
## fields, and heavy tests are invisible to CI (798 skipped in a green run), so
## the fence itself must be checked in the light tier.

## A stub carrying only the fields the regime predicate reads.
certified_stub <- function(...) {
  base <- list(
    tmb_data = list(family_id_vec = rep(0L, 12L)),
    use = list(rr_B = TRUE),
    d_B = 2L,
    n_sites = 150L,
    fit_health = list(converged = TRUE),
    aghq = list(used = FALSE, penalised = FALSE, ridge_tau = Inf)
  )
  utils::modifyList(base, list(...))
}

status_of <- function(fit, tier = "unit", level = 0.95) {
  gllvmTMB:::.total_variance_interval_status(
    fit,
    tier = tier,
    level = level,
    lower = 0.5,
    upper = 1.5
  )
}

test_that("historically measured total-variance cells fail closed to route-only", {
  expect_identical(status_of(certified_stub()), "route-only")
  expect_identical(status_of(certified_stub(d_B = 1L)), "route-only")
  expect_identical(status_of(certified_stub(n_sites = 400L)), "route-only")
  expect_identical(status_of(certified_stub(n_sites = 4000L)), "route-only")
})

test_that("each uncertified axis on its own flips the row to route-only", {
  ## Integration/estimand: AGHQ and either kind of loading ridge were not in
  ## the certificate campaign, even when every structural field matches.
  expect_identical(
    status_of(certified_stub(
      aghq = list(used = TRUE, penalised = FALSE, ridge_tau = Inf)
    )),
    "route-only"
  )
  expect_identical(
    status_of(certified_stub(
      aghq = list(used = FALSE, penalised = TRUE, ridge_tau = 2)
    )),
    "route-only"
  )
  ## The numeric tau also fails closed if a malformed object contradicts its
  ## own `penalised` flag.
  expect_identical(
    status_of(certified_stub(
      aghq = list(used = FALSE, penalised = FALSE, ridge_tau = 2)
    )),
    "route-only"
  )
  ## Missing engine metadata is uncertainty, not permission to certify an old
  ## or synthetic fit object.
  missing_engine <- certified_stub()
  missing_engine$aghq <- NULL
  expect_identical(status_of(missing_engine), "route-only")
  ## Family: any non-Gaussian observation.
  expect_identical(
    status_of(certified_stub(
      tmb_data = list(family_id_vec = c(rep(0L, 11L), 1L))
    )),
    "route-only"
  )
  missing_family <- certified_stub()
  missing_family$tmb_data$family_id_vec <- NULL
  expect_identical(status_of(missing_family), "route-only")
  ## Tier: everything except the ordinary unit tier.
  for (tr in c("unit_obs", "phy", "W")) {
    expect_identical(status_of(certified_stub(), tier = tr), "route-only")
  }
  ## Rank: d > 2 was never measured, and neither was a diagonal-only unit tier.
  expect_identical(status_of(certified_stub(d_B = 3L)), "route-only")
  expect_identical(
    status_of(certified_stub(use = list(rr_B = FALSE))),
    "route-only"
  )
  ## Sample size: only n = 150 was measured. Both smaller and larger cells
  ## remain route-only until separately calibrated.
  expect_identical(status_of(certified_stub(n_sites = 149L)), "route-only")
  expect_identical(status_of(certified_stub(n_sites = 151L)), "route-only")
  ## Level: the gate was measured for the nominal-95% interval only.
  expect_identical(status_of(certified_stub(), level = 0.90), "route-only")
  expect_identical(status_of(certified_stub(), level = 0.99), "route-only")
  ## Convergence: the certificate is conditional on it.
  expect_identical(
    status_of(certified_stub(fit_health = list(converged = FALSE))),
    "route-only"
  )
})

test_that("the legacy tier alias 'B' cannot revive the withdrawn certificate", {
  expect_identical(status_of(certified_stub(), tier = "B"), "route-only")
})

test_that("a row with no interval is 'none', not an uncertified interval", {
  st <- gllvmTMB:::.total_variance_interval_status(
    certified_stub(),
    tier = "unit",
    level = 0.95,
    lower = c(0.5, NA_real_),
    upper = c(1.5, NA_real_)
  )
  expect_identical(st, c("route-only", "none"))
})

test_that("profile_ci_total_variance is exported from the installed namespace", {
  ## Guards the failure mode where the function works under load_all() but was
  ## never added to NAMESPACE.
  expect_true(
    "profile_ci_total_variance" %in% getNamespaceExports("gllvmTMB")
  )
  expect_true(is.function(gllvmTMB::profile_ci_total_variance))
})

## A small Gaussian fit with a unit-tier latent. n_sites = 80 puts it below the
## certified n on purpose: Gaussian and d = 1, but out of regime.
make_out_of_regime_fit <- function(seed = 42L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = 80L,
    n_species = 6L,
    n_traits = 3L,
    mean_species_per_site = 4L,
    Lambda_B = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B = c(0.40, 0.30, 0.50),
    psi_W = c(0.30, 0.40, 0.30),
    beta = matrix(0, 3L, 2L),
    seed = seed
  )
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site) +
        unique(0 + trait | site_species),
      data = s$data,
      silent = TRUE
    )
  ))
}

test_that("the exported route labels a real out-of-regime fit route-only", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- make_out_of_regime_fit()
  out <- gllvmTMB::profile_ci_total_variance(fit, tier = "unit")

  expect_true(all(
    c(
      "trait",
      "tier",
      "estimate",
      "lower",
      "upper",
      "method",
      "interval_status"
    ) %in%
      names(out)
  ))
  expect_true(all(out$interval_status %in% c("route-only", "none")))
  expect_false(any(out$interval_status == "certified-0.94"))
  ## The public surface speaks the canonical tier name, not the internal slot.
  expect_identical(unique(out$tier), "unit")

  ## Exporting must not change what was measured: the bounds are identical to
  ## the internal route the certificate harness calls.
  internal <- gllvmTMB:::.profile_ci_total_variance(fit, tier = "unit")
  expect_equal(out$estimate, internal$estimate, tolerance = 1e-12)
  expect_equal(out$lower, internal$lower, tolerance = 1e-12)
  expect_equal(out$upper, internal$upper, tolerance = 1e-12)
})

## ---- The estimand may not change silently ---------------------------------
##
## `.total_variance_spec()` is the single source of truth for
## V_t = (Lambda Lambda^T)_tt + psi_t^2. When a tier carries loadings but no
## diagonal component there is no psi_t^2 to add, and every psi term below it
## evaluates to zero -- so both routes keep reporting, but they report Sigma_tt
## under the name V_t. That silent substitution is what produced the coverage
## collapse 0.517 -> 0.300 -> 0.096 in the 2026-08-03 Step-0 pilot, with
## point-estimate gaps tracking the planted psi_t^2 almost exactly. These tests
## pin the refusal so the estimand cannot drift again without a test failing.

## A stub carrying only the fields `.total_variance_spec()` reads.
spec_stub <- function(par_names, n_traits = 2L) {
  par <- rep(0.5, length(par_names))
  names(par) <- par_names
  structure(
    list(
      opt = list(par = par),
      data = data.frame(
        trait = factor(paste0("t", seq_len(n_traits)))
      ),
      trait_col = "trait",
      tmb_map = list(),
      d_B = 1L,
      d_W = 1L,
      d_phy = 1L
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("a loadings-only tier is refused rather than silently scoring Sigma_tt", {
  ## theta_rr_B present, theta_diag_B absent: psi_t does not exist in this fit.
  loadings_only <- spec_stub(c("theta_rr_B", "theta_rr_B"))
  expect_error(
    gllvmTMB:::.total_variance_spec(loadings_only, tier = "unit"),
    regexp = "theta_diag_B"
  )
  ## The message must name the estimand, not just the missing parameter, so the
  ## reader learns V_t would have collapsed to Sigma_tt.
  expect_error(
    gllvmTMB:::.total_variance_spec(loadings_only, tier = "unit"),
    regexp = "Sigma_tt"
  )
})

test_that("a tier carrying psi still builds, and the empty tier keeps its own error", {
  with_psi <- spec_stub(c(
    "theta_rr_B",
    "theta_rr_B",
    "theta_diag_B",
    "theta_diag_B"
  ))
  expect_no_error(gllvmTMB:::.total_variance_spec(with_psi, tier = "unit"))

  ## A tier with neither component keeps the pre-existing message -- the new
  ## guard must not swallow it.
  neither <- spec_stub(c("beta"))
  expect_error(
    gllvmTMB:::.total_variance_spec(neither, tier = "unit"),
    regexp = "latent and/or diagonal"
  )
})
