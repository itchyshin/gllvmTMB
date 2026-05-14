## Design 09 Stage 2: Fisher-z Wald CIs for cross-trait correlations.
## See dev/design/09-fisher-z-wald-correlations.md.

## Build a tiny fit with rr_B + diag_B + diag_W (3 traits, 80 sites).
## Mirrors test-profile-ci.R's helper.
make_tiny_BW_fit_fz <- function(seed = 42L) {
  set.seed(seed)
  s <- gllvmTMB::simulate_site_trait(
    n_sites              = 80L,
    n_species            = 6L,
    n_traits             = 3L,
    mean_species_per_site = 4L,
    Lambda_B             = matrix(c(0.9, 0.4, -0.3), 3L, 1L),
    psi_B                  = c(0.40, 0.30, 0.50),
    psi_W                  = c(0.30, 0.40, 0.30),
    beta                 = matrix(0, 3L, 2L),
    seed                 = seed
  )
  suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site) +
        unique(0 + trait | site_species),
      data = s$data,
      silent = TRUE
    )
  ))
}

## ---- 1. New "fisher-z" method is accepted ---------------------------------

test_that("extract_correlations accepts method = 'fisher-z'", {
  skip_on_cran()
  fit <- make_tiny_BW_fit_fz()
  cors <- gllvmTMB::extract_correlations(
    fit, tier = "B", level = 0.95, method = "fisher-z"
  )
  expect_s3_class(cors, "data.frame")
  expect_named(cors, c("tier", "trait_i", "trait_j", "correlation",
                       "lower", "upper", "method"))
  expect_true(all(cors$method == "fisher-z"))
  expect_true(all(cors$correlation >= -1 & cors$correlation <= 1))
  expect_true(all(cors$lower >= -1 & cors$lower <= 1))
  expect_true(all(cors$upper >= -1 & cors$upper <= 1))
  expect_true(all(cors$lower <= cors$correlation + 1e-6))
  expect_true(all(cors$upper >= cors$correlation - 1e-6))
})

## ---- 2. New default is "fisher-z" (not "profile") -------------------------

test_that("extract_correlations default method is now 'fisher-z'", {
  skip_on_cran()
  fit <- make_tiny_BW_fit_fz()
  cors_default <- gllvmTMB::extract_correlations(fit, tier = "B")
  expect_true(all(cors_default$method == "fisher-z"))
})

## ---- 3. "wald" remains a backward-compat alias of "fisher-z" -------------

test_that("method = 'wald' returns identical numbers to 'fisher-z'", {
  skip_on_cran()
  fit <- make_tiny_BW_fit_fz()
  ## Suppress the one-shot deprecation message we emit for method='wald'.
  cors_wald <- suppressMessages(
    gllvmTMB::extract_correlations(fit, tier = "B", method = "wald")
  )
  cors_fz   <- gllvmTMB::extract_correlations(fit, tier = "B",
                                              method = "fisher-z")
  ## Same shape and identical numerics. Method label differs.
  expect_equal(cors_wald$correlation, cors_fz$correlation)
  expect_equal(cors_wald$lower,       cors_fz$lower)
  expect_equal(cors_wald$upper,       cors_fz$upper)
})

## ---- 4. n_eff override changes the CI half-width predictably -------------

test_that("n_eff override changes CI half-width as 1/sqrt(n_eff - 3)", {
  skip_on_cran()
  fit <- make_tiny_BW_fit_fz()
  ## Get default (n_eff = fit$n_sites = 80).
  cors_default <- gllvmTMB::extract_correlations(fit, tier = "B",
                                                 method = "fisher-z")
  ## Halve n_eff to 40. SE on z scales as 1/sqrt(n-3), so the
  ## CI HALF-WIDTH on z scales by sqrt((80-3)/(40-3)) = sqrt(77/37).
  cors_smaller <- gllvmTMB::extract_correlations(fit, tier = "B",
                                                 method = "fisher-z",
                                                 n_eff = 40L)
  ## Recover SE on z from the CI bounds: SE_z = (atanh(upper) -
  ## atanh(rho)) / qnorm(0.975).
  z_q <- stats::qnorm(0.975)
  pick <- which(!is.na(cors_default$upper))[1]   # first finite pair
  rho <- cors_default$correlation[pick]
  se_z_default <- (atanh(cors_default$upper[pick]) - atanh(rho)) / z_q
  se_z_smaller <- (atanh(cors_smaller$upper[pick]) - atanh(rho)) / z_q
  ratio_obs <- se_z_smaller / se_z_default
  ratio_exp <- sqrt((80 - 3) / (40 - 3))
  ## Within 1% — pure deterministic transform.
  expect_lt(abs(ratio_obs - ratio_exp), 0.01)
})

## ---- 5. n_eff validation: reject < 4 -------------------------------------

test_that("extract_correlations errors when n_eff < 4", {
  skip_on_cran()
  fit <- make_tiny_BW_fit_fz()
  ## Specifically the user-facing validation message, not the
  ## "unused argument" R parser error that fires before n_eff exists.
  expect_error(
    gllvmTMB::extract_correlations(fit, tier = "B", method = "fisher-z",
                                   n_eff = 3L),
    regexp = "n_eff.*must be at least 4"
  )
})

## ---- 6. CIs stay bounded in [-1, 1] under all paths ----------------------

test_that("Fisher-z CIs are guaranteed inside [-1, 1] for any rho", {
  skip_on_cran()
  fit <- make_tiny_BW_fit_fz()
  ## Even at extreme rho near +/- 1 (which can happen when latent
  ## structure pins a near-degenerate correlation), tanh-back keeps
  ## bounds inside [-1, 1].
  cors <- gllvmTMB::extract_correlations(fit, tier = "B",
                                         method = "fisher-z",
                                         n_eff = 4L)  # minimum allowed
  expect_true(all(cors$lower >= -1, na.rm = TRUE))
  expect_true(all(cors$upper <=  1, na.rm = TRUE))
})
