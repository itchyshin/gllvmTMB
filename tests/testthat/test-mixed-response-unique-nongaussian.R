## Recovery tests: unique(0 + trait | obs) as OLRE for non-Gaussian and mixed-family fits.
##
## Science: when every (trait, obs) tuple identifies exactly one row of data,
## `unique(0 + trait | obs)` at the W-tier is an observation-level random effect
## (OLRE) — an additive Gaussian random effect on the linear predictor.
## For Poisson / binomial responses this is the "additive overdispersion" model
## of Nakagawa & Schielzeth (2010) and Nakagawa, Johnson & Schielzeth (2017).
##
## For pure non-Gaussian fits (tests 1 & 2): sigma_eps is already mapped off
## via the `!any_continuous` branch in fit-multi.R:545-547; no auto-suppress
## message fires. The unique() random effects are free to absorb the
## observation-level overdispersion.
##
## For the mixed-family fit (test 3): any_continuous = TRUE (Gaussian trait),
## so the auto-suppress branch fires and sigma_eps is fixed at a tiny value.
##
## *** Identifiability note ***
## Single-trial binomial (Bernoulli, size = 1) OLRE is statistically unidentifiable
## when each unit has exactly ONE observation per trait: there is no replicated
## information within a (unit, trait) cell to distinguish the OLRE variance from
## pure Bernoulli noise. As of the per-family-aware OLRE selection commit,
## the engine maps `theta_diag_W[t]` and the corresponding `s_W` column off
## for Bernoulli-only traits and pins sd_W[t] at ~1e-6, so the unidentifiable
## free parameter is removed and the reported sd_W stays near zero.
## Test 2 documents this skip explicitly. Test 3 carries a binomial trait
## and correspondingly expects sd_W ≈ 0 for that trait.
## Multi-trial binomial (size > 1) WOULD be identifiable, and is fit normally
## now that gllvmTMB_multi.cpp respects the per-row `n_trials` vector.
## See `tests/testthat/test-mixed-family-olre.R` for tests of the per-trait
## skip and warn behaviour.
##
## References:
##   Nakagawa, S. & Schielzeth, H. (2010) Biol. Rev. 85, 935-956.
##   Nakagawa, S., Johnson, P. C. D. & Schielzeth, H. (2017) J. R. Soc. Interface 14, 20170213.

## ---- test 1: Pure Poisson + OLRE per trait ---------------------------------

test_that("recovery: pure Poisson + unique(0+trait|obs) recovers per-trait OLRE variances", {
  skip_on_cran()

  set.seed(123)
  n_traits <- 4
  n_units  <- 200
  true_sigma2_e <- c(0.5, 0.3, 0.8, 0.4)
  true_alpha    <- c(2.0, 1.5, 1.0, 0.5)

  df <- expand.grid(unit = seq_len(n_units), trait_idx = seq_len(n_traits))
  df$obs   <- factor(seq_len(nrow(df)))
  df$trait <- factor(paste0("t", df$trait_idx), levels = paste0("t", seq_len(n_traits)))
  e_it <- rnorm(nrow(df), sd = sqrt(true_sigma2_e[df$trait_idx]))
  df$value <- rpois(nrow(df), exp(true_alpha[df$trait_idx] + e_it))

  ## Pure Poisson: sigma_eps should be auto-mapped off via !any_continuous path;
  ## NO "Auto-suppressing" message should appear.
  msgs <- testthat::capture_messages(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | obs),
      data = df, unit = "unit", unit_obs = "obs",
      family = poisson()
    ))
  )
  expect_false(
    any(grepl("Auto-suppressing.*sigma_eps", msgs)),
    label = "No auto-suppress message for pure Poisson (sigma_eps already mapped off)"
  )

  ## Convergence
  expect_equal(fit$opt$convergence, 0L)

  ## sigma_eps is mapped off (it's not a parameter for Poisson)
  fids <- fit$tmb_data$family_id_vec
  expect_true(all(fids == 2L), label = "all rows have family_id == 2 (Poisson)")
  expect_true("log_sigma_eps" %in% names(fit$tmb_obj$env$map),
              label = "log_sigma_eps in map for pure Poisson")
  expect_true(is.na(fit$tmb_obj$env$map$log_sigma_eps[[1]]),
              label = "log_sigma_eps mapped to NA for pure Poisson")

  ## Pull recovered per-trait sigma2_e from psi_W diagonal.
  ## extract_Sigma returns a named vector; use unname() so expect_equal
  ## compares values only (not names vs unnamed expected vector).
  res <- suppressMessages(extract_Sigma(fit, level = "W", part = "unique"))
  expect_false(is.null(res), label = "extract_Sigma returns non-NULL for W-tier unique")
  sigma2_e_hat <- unname(res$s)
  expect_length(sigma2_e_hat, n_traits)
  ## Recovery tolerance 0.2 on the variance scale (200 units, 4 Poisson traits)
  expect_equal(sigma2_e_hat, true_sigma2_e, tolerance = 0.2,
               label = "Poisson OLRE variances recovered within 0.2")
})


## ---- test 2: Pure single-trial binomial — documents identifiability limit --

test_that("single-trial binomial OLRE: per-family-aware skip pins sd_W at ~0", {
  skip_on_cran()

  ## Single-trial binomial (Bernoulli) OLRE is unidentifiable: with one 0/1
  ## observation per (unit, trait) cell there is no within-cell replication to
  ## separate OLRE variance from Bernoulli noise. The engine now skips the
  ## OLRE for Bernoulli-only traits: theta_diag_W[t] and the s_W column are
  ## mapped off, sd_W[t] is pinned at ~1e-6. This test confirms that behaviour
  ## -- it is NOT a recovery test.
  set.seed(456)
  n_traits <- 3
  n_units  <- 300
  true_sigma2_e <- c(0.6, 0.4, 0.9)   # true but unrecoverable with size = 1
  true_alpha    <- c(0.0, 0.5, -0.5)

  df <- expand.grid(unit = seq_len(n_units), trait_idx = seq_len(n_traits))
  df$obs   <- factor(seq_len(nrow(df)))
  df$trait <- factor(paste0("t", df$trait_idx), levels = paste0("t", seq_len(n_traits)))
  e_it <- rnorm(nrow(df), sd = sqrt(true_sigma2_e[df$trait_idx]))
  p    <- plogis(true_alpha[df$trait_idx] + e_it)
  df$value <- rbinom(nrow(df), 1L, p)

  ## Pure binomial: sigma_eps auto-mapped off; no Auto-suppressing message.
  msgs <- testthat::capture_messages(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | obs),
      data = df, unit = "unit", unit_obs = "obs",
      family = binomial()
    ))
  )
  expect_false(
    any(grepl("Auto-suppressing.*sigma_eps", msgs)),
    label = "No auto-suppress message for pure binomial"
  )

  ## Engine converges (correct); sd_W is pinned near zero by the per-family
  ## aware skip
  expect_equal(fit$opt$convergence, 0L)

  ## sigma_eps mapped off for pure binomial
  fids <- fit$tmb_data$family_id_vec
  expect_true(all(fids == 1L), label = "all rows have family_id == 1 (binomial)")
  expect_true("log_sigma_eps" %in% names(fit$tmb_obj$env$map),
              label = "log_sigma_eps in map for pure binomial")
  expect_true(is.na(fit$tmb_obj$env$map$log_sigma_eps[[1]]),
              label = "log_sigma_eps mapped to NA for pure binomial")

  ## Documented behaviour: sd_W ≈ 0 (unidentifiable with single-trial binary data).
  ## The engine pins sd_W at ~1e-6 via the per-family-aware skip; the
  ## reported variance is therefore essentially zero (~1e-12).
  res <- suppressMessages(extract_Sigma(fit, level = "W", part = "unique"))
  expect_false(is.null(res))
  sigma2_e_hat <- unname(res$s)
  expect_length(sigma2_e_hat, n_traits)
  ## All returned variances should be essentially zero (< 0.01 on variance scale)
  expect_true(
    all(sigma2_e_hat < 0.01),
    label = paste(
      "Single-trial binomial OLRE is unidentifiable: per-family-aware skip",
      "pins sd_W ~ 1e-6 (variance ~ 1e-12 per trait).",
      "Multi-trial binomial is identifiable and fit normally."
    )
  )
})


## ---- test 3: Mixed-family (Gaussian + binomial + Poisson) + OLRE -----------

test_that("recovery: mixed-family (gaussian+binomial+poisson) + unique(0+trait|obs): gaussian+poisson recover, binomial unidentified", {
  skip_on_cran()

  ## Gaussian and Poisson OLRE variances are recovered.
  ## Binomial OLRE is skipped per the per-family-aware selection (sd_W pinned
  ## at ~1e-6); the variance reported for the binomial trait is therefore ~0.
  ## For the Gaussian trait: sigma_eps is auto-suppressed; unique() absorbs the residual.
  set.seed(789)
  n_units       <- 250
  true_sigma2_e <- c(0.4, 0.6, 0.5)   # gaussian, binomial, poisson
  true_alpha    <- c(0.0, 0.0, 1.0)
  trait_levels  <- c("gauss", "binom", "pois")
  fam_levels    <- c("gaussian", "binomial", "poisson")

  df <- expand.grid(unit = seq_len(n_units), trait_idx = 1:3)
  df$obs   <- factor(seq_len(nrow(df)))
  df$trait <- factor(trait_levels[df$trait_idx], levels = trait_levels)
  df$family <- factor(fam_levels[df$trait_idx], levels = fam_levels)
  e_it <- rnorm(nrow(df), sd = sqrt(true_sigma2_e[df$trait_idx]))

  df$value <- ifelse(
    df$trait_idx == 1L,
    true_alpha[1L] + e_it,
    ifelse(
      df$trait_idx == 2L,
      rbinom(nrow(df), 1L, plogis(true_alpha[2L] + e_it)),
      rpois(nrow(df), exp(true_alpha[3L] + e_it))
    )
  )

  fams <- list(gaussian(), binomial(), poisson())
  attr(fams, "family_var") <- "family"

  ## Mixed-family with Gaussian rows: any_continuous = TRUE, per-row diag at
  ## W-tier => auto-suppress fires. Expect the "Auto-suppressing" message.
  expect_message(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | obs),
      data = df, unit = "unit", unit_obs = "obs",
      family = fams
    )),
    regexp = "Auto-suppressing.*sigma_eps",
    label = "Auto-suppress fires for mixed-family (Gaussian rows present)"
  )

  ## Convergence
  expect_equal(fit$opt$convergence, 0L)

  ## sigma_eps auto-suppressed (mapped to NA)
  expect_true("log_sigma_eps" %in% names(fit$tmb_obj$env$map),
              label = "log_sigma_eps in map after auto-suppress")
  expect_true(is.na(fit$tmb_obj$env$map$log_sigma_eps[[1]]),
              label = "log_sigma_eps mapped to NA after auto-suppress")

  ## Per-row family IDs correct
  fid <- fit$tmb_data$family_id_vec
  expect_equal(sum(fid == 0L), n_units,
               label = "Gaussian rows count matches n_units")
  expect_equal(sum(fid == 1L), n_units,
               label = "Binomial rows count matches n_units")
  expect_equal(sum(fid == 2L), n_units,
               label = "Poisson rows count matches n_units")

  ## Pull per-trait OLRE variances
  res <- suppressMessages(extract_Sigma(fit, level = "W", part = "unique"))
  expect_false(is.null(res))
  sigma2_e_hat <- res$s
  expect_length(sigma2_e_hat, 3L)

  ## Gaussian trait (trait 1): sigma_eps suppressed; unique() absorbs the residual.
  ## Recovery within 0.3.
  expect_equal(
    unname(sigma2_e_hat["gauss"]), true_sigma2_e[1], tolerance = 0.3,
    label = "Gaussian OLRE variance recovered within 0.3"
  )

  ## Poisson trait (trait 3): OLRE identifiable and recovered.
  expect_equal(
    unname(sigma2_e_hat["pois"]), true_sigma2_e[3], tolerance = 0.3,
    label = "Poisson OLRE variance recovered within 0.3"
  )

  ## Binomial trait (trait 2): single-trial binary -> per-family-aware skip
  ## pins sd_W at ~1e-6, so the reported variance is ~1e-12 < 0.01.
  expect_lt(
    unname(sigma2_e_hat["binom"]), 0.01,
    label = "Binomial OLRE pinned at ~1e-6 (single-trial binary; per-family-aware skip)"
  )
})
