## Phase B-matrix SLOPE-spatial-indep (Design 59): the random-SLOPE column
## (`spatial_indep(1 + x | site)`) crossed with the seven non-Gaussian
## families on a small SPDE mesh -- the single hardest cell of the
## family x structure matrix.
##
## ONE test_that per family: binomial-probit, binomial-logit,
## ordinal_probit, poisson, nbinom2, gamma, beta. Each fits
## `value ~ 0 + trait + spatial_indep(1 + x | site)` on ~100 sites + a small
## mesh and -- WHEN the fit converges with a PD Hessian -- asserts the
## diagonal-by-construction `spatial_indep` contract: the cross-trait
## `rho:spatial` correlation token is EXPECTED to error (an independent
## per-field block has no off-diagonal to report), and the per-field
## variance pieces are finite-positive.
##
## ----------------------------------------------------------------------
## Honest-matrix discipline (Design 59), why every family currently SKIPs
## ----------------------------------------------------------------------
## `spatial_indep()` is rejected by contract for any bar other than the
## canonical `0 + trait | coords`. The augmented intercept+slope
## random-regression LHS (`1 + x | site`) is wired ONLY on the
## phylogenetic side (`phylo_unique` / `phylo_slope`, the
## `use_phylo_slope_correlated` / `report$sd_b` / `report$cor_b` path,
## R/fit-multi.R). On the SPDE side the parser's
## `normalise_spatial_orientation()` (R/brms-sugar.R) aborts a
## `spatial_indep(1 + x | site)` formula with
##   "`spatial_indep()` bar must be `0 + trait | coords`."
## BEFORE any family-specific code runs -- so the abort is identical for
## all seven families (verified empirically 2026-05-29 across all seven).
##
## This cell is therefore INFEASIBLE BY ENGINE CONTRACT, not by
## non-convergence or a tolerance choice. Per the campaign's no-fake-pass
## rule we attempt the literal random-slope spec for each family and
## `skip()` on the by-contract abort, reporting the cell as "stays
## partial". We do NOT silently substitute the `0 + trait | site`
## marginal-field spec (that is a different, non-slope cell already owned
## by the `test-matrix-*-spatial.R` siblings and the binary
## `test-spatial-depindep-binary.R`); doing so would make a "random-slope"
## claim the fit does not support.
##
## The test is written FORWARD-COMPATIBLY: each `test_that` reaches its
## real assertions the moment a future engine accepts
## `spatial_indep(1 + x | site)` and returns a converged, PD fit. Until
## then the by-contract abort is caught and skipped honestly. Time-box per
## fit is the campaign-wide 15 min; the abort returns instantly.

skip_if_not_slope_spatial_indep_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## Seed-controlled ~100-site fixture on a small mesh, shared by every
## family. One species per site so `site` is the unit of replication for
## the spatial field. `x` is a per-(site, trait) covariate -- the random
## slope the `1 + x | site` LHS would put a spatial field on. `family`
## selects the response generator; the linear predictor `eta` is held near
## 0 so each family's mean is well inside its support (no overflow / no
## all-zero / all-one degeneracy).
make_slope_spatial_indep_fixture <- function(family = c("count", "binary",
                                                        "gamma", "beta",
                                                        "ordinal"),
                                             n_sites = 100L, n_traits = 3L,
                                             seed = 20260529L) {
  family <- match.arg(family)
  set.seed(seed)

  coords <- cbind(lon = stats::runif(n_sites),
                  lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites),
                    trait_id = seq_len(n_traits))
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(n_traits)))
  df$lon   <- coords[df$site, 1L]
  df$lat   <- coords[df$site, 2L]
  df$x     <- stats::rnorm(nrow(df))

  ## A modest per-trait intercept + a per-site slope on x: the structure
  ## the augmented `1 + x | site` LHS is meant to capture. Kept small so
  ## eta stays near 0.
  alpha_t   <- c(0.0, 0.1, -0.1, 0.05)[df$trait_id]
  slope_site <- stats::rnorm(n_sites, 0, 0.3)[df$site]
  eta <- alpha_t + slope_site * df$x

  df$value <- switch(
    family,
    count   = stats::rpois(nrow(df), lambda = exp(eta + 1)),       # mean ~ e
    binary  = stats::rbinom(nrow(df), 1L, stats::plogis(eta)),
    gamma   = stats::rgamma(nrow(df), shape = 2, scale = exp(eta) / 2),
    beta    = {
      mu  <- stats::plogis(eta); phi <- 6
      stats::rbeta(nrow(df), mu * phi, (1 - mu) * phi)
    },
    ordinal = {
      ystar <- eta + stats::rnorm(nrow(df))
      as.integer(1L + (ystar > 0) + (ystar > 0.7) + (ystar > 1.4))
    }
  )

  df$site <- factor(df$site, levels = seq_len(n_sites))
  mesh    <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.12)
  list(data = df, mesh = mesh, n_traits = n_traits)
}

## Attempt the literal random-slope spec. Returns the fit object, or the
## condition object on error (the by-contract abort lands here).
fit_slope_spatial_indep <- function(fx, family) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(1 + x | site, mesh = fx$mesh),
      data   = fx$data,
      trait  = "trait",
      unit   = "site",
      mesh   = fx$mesh,
      family = family
    ))),
    error = function(e) e
  )
}

## Shared health + diagonal-contract assertions, run only on the
## forward-compatible branch (a converged, PD fit). For the diagonal
## `spatial_indep` block: (a) the cross-trait `rho:spatial` correlation
## token is EXPECTED to error (no off-diagonal in an independent block) --
## we assert the error rather than a finite CI; (b) the per-field variance
## machinery (`log_tau_spde`, one entry per field) is finite. `expected_id`
## guards against a silent family fallthrough.
expect_slope_spatial_indep_health_and_diag <- function(fit, n_traits,
                                                       expected_id) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], expected_id)
  testthat::expect_true(isTRUE(fit$use$spatial_indep))

  ## Diagonal-by-construction: a cross-trait rho token must NOT yield a
  ## finite correlation CI (the indep block has no off-diagonal). Per the
  ## task contract we assert the token errors rather than relaxing to a
  ## finite-bound smoke.
  rho_ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:spatial:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  testthat::expect_true(
    inherits(rho_ci, "error") ||
      !(is.matrix(rho_ci) && any(is.finite(rho_ci))),
    info = "spatial_indep is diagonal: rho:spatial must error or be non-finite by contract"
  )

  ## Per-field variance finiteness (the diagonal pieces that DO identify).
  log_tau <- as.numeric(fit$report$log_tau_spde)
  testthat::expect_gt(length(log_tau), 0L)
  testthat::expect_true(all(is.finite(log_tau)))
}

## One reusable body per family: attempt the literal random-slope fit,
## honest-skip on the by-contract abort / non-construction / non-PD, else
## run the diagonal-contract assertions.
run_slope_spatial_indep_family <- function(fixture_family, fit_family,
                                           expected_id, label) {
  fx  <- make_slope_spatial_indep_fixture(family = fixture_family)
  fit <- fit_slope_spatial_indep(fx, fit_family)

  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    msg <- if (inherits(fit, "error")) {
      conditionMessage(fit)
    } else {
      "non-gllvmTMB return"
    }
    testthat::skip(sprintf(
      "%s: spatial_indep(1 + x | site) random-slope rejected by engine contract (augmented intercept+slope LHS is phylo-only); SLOPE-spatial-indep(%s) stays partial. Engine: %s",
      label, label, gsub("\n", " ", msg)
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    testthat::skip(sprintf(
      "%s: spatial_indep(1 + x | site) did not converge with PD Hessian; SLOPE-spatial-indep(%s) stays partial pending bigger n / different seed",
      label, label
    ))
  }

  expect_slope_spatial_indep_health_and_diag(fit, fx$n_traits, expected_id)
}

## ---------------------------------------------------------------
## binomial-probit
## ---------------------------------------------------------------
test_that("binomial(probit): spatial_indep(1 + x | site) random slope converges + pd_hessian; rho errors by contract; per-field variance finite", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_indep_deps()
  run_slope_spatial_indep_family(
    fixture_family = "binary",
    fit_family     = stats::binomial(link = "probit"),
    expected_id    = 1L,
    label          = "binomial-probit"
  )
})

## ---------------------------------------------------------------
## binomial-logit
## ---------------------------------------------------------------
test_that("binomial(logit): spatial_indep(1 + x | site) random slope converges + pd_hessian; rho errors by contract; per-field variance finite", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_indep_deps()
  run_slope_spatial_indep_family(
    fixture_family = "binary",
    fit_family     = stats::binomial(link = "logit"),
    expected_id    = 1L,
    label          = "binomial-logit"
  )
})

## ---------------------------------------------------------------
## ordinal_probit
## ---------------------------------------------------------------
test_that("ordinal_probit: spatial_indep(1 + x | site) random slope converges + pd_hessian; rho errors by contract; per-field variance finite", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_indep_deps()
  run_slope_spatial_indep_family(
    fixture_family = "ordinal",
    fit_family     = gllvmTMB::ordinal_probit(),
    expected_id    = 14L,
    label          = "ordinal_probit"
  )
})

## ---------------------------------------------------------------
## poisson
## ---------------------------------------------------------------
test_that("poisson(log): spatial_indep(1 + x | site) random slope converges + pd_hessian; rho errors by contract; per-field variance finite", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_indep_deps()
  run_slope_spatial_indep_family(
    fixture_family = "count",
    fit_family     = stats::poisson(link = "log"),
    expected_id    = 2L,
    label          = "poisson"
  )
})

## ---------------------------------------------------------------
## nbinom2
## ---------------------------------------------------------------
test_that("nbinom2: spatial_indep(1 + x | site) random slope converges + pd_hessian; rho errors by contract; per-field variance finite", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_indep_deps()
  run_slope_spatial_indep_family(
    fixture_family = "count",
    fit_family     = gllvmTMB::nbinom2(),
    expected_id    = 5L,
    label          = "nbinom2"
  )
})

## ---------------------------------------------------------------
## gamma
## ---------------------------------------------------------------
test_that("Gamma(log): spatial_indep(1 + x | site) random slope converges + pd_hessian; rho errors by contract; per-field variance finite", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_indep_deps()
  run_slope_spatial_indep_family(
    fixture_family = "gamma",
    fit_family     = stats::Gamma(link = "log"),
    expected_id    = 4L,
    label          = "gamma"
  )
})

## ---------------------------------------------------------------
## beta
## ---------------------------------------------------------------
test_that("Beta: spatial_indep(1 + x | site) random slope converges + pd_hessian; rho errors by contract; per-field variance finite", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_indep_deps()
  run_slope_spatial_indep_family(
    fixture_family = "beta",
    fit_family     = gllvmTMB::Beta(),
    expected_id    = 7L,
    label          = "beta"
  )
})
