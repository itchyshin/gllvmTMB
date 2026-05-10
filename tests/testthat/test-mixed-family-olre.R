## Per-family-aware OLRE selection: tests for the W-tier per-trait skip
## of unidentifiable / suspect family-specific OLRE.
##
## Design choices being verified here:
##
##   * Pure single-trial Bernoulli + `unique(0 + trait | obs)` is OLRE on a
##     family that is statistically unidentifiable (no within-cell
##     replication). The engine maps `theta_diag_W[t]` AND the
##     corresponding `s_W` column off, pinning sd_W[t] at ~1e-6.
##     Parameter count drops by `n_traits` relative to fitting OLRE.
##
##   * Mixed-family fits (e.g., gaussian + binomial + poisson) selectively
##     skip OLRE only for the Bernoulli trait; the Gaussian and Poisson
##     traits keep OLRE estimable.
##
##   * Pure delta_lognormal + OLRE fits but emits a warning because the
##     OLRE enters the shared linear predictor of the hurdle and is not
##     biologically interpretable. (`latent + delta_lognormal` works
##     without a warning, verified ad-hoc.)
##
## References:
##   Nakagawa, S. & Schielzeth, H. (2010) Biol. Rev. 85, 935-956.
##   Nakagawa, S., Johnson, P. C. D. & Schielzeth, H. (2017) J. R. Soc. Interface 14, 20170213.

## ---- 1. Pure Bernoulli + OLRE: theta_diag_W mapped off, count drops by T ----

test_that("pure Bernoulli OLRE: theta_diag_W and s_W mapped off, parameter count down by n_traits", {
  skip_on_cran()

  set.seed(456)
  n_traits <- 3
  n_units  <- 200
  true_alpha <- c(0.0, 0.5, -0.5)
  df <- expand.grid(unit = seq_len(n_units), trait_idx = seq_len(n_traits))
  df$obs   <- factor(seq_len(nrow(df)))
  df$trait <- factor(paste0("t", df$trait_idx),
                     levels = paste0("t", seq_len(n_traits)))
  df$value <- rbinom(nrow(df), 1L, plogis(true_alpha[df$trait_idx]))

  ## Reference fit without unique() to get the baseline parameter count
  ## (just b_fix, no OLRE machinery at all).
  fit_ref <- suppressMessages(suppressWarnings(
    gllvmTMB(value ~ 0 + trait,
             data = df, unit = "unit", unit_obs = "obs",
             family = binomial())
  ))
  ## Fit WITH unique(): the per-family-aware block should map all T
  ## theta_diag_W entries off (and all s_W entries off), so the free
  ## parameter count matches the reference.
  msgs <- testthat::capture_messages(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | obs),
      data = df, unit = "unit", unit_obs = "obs",
      family = binomial()
    ))
  )
  expect_true(
    any(grepl("Skipping OLRE for single-trial Bernoulli", msgs)),
    label = "informational message announces the skip"
  )

  expect_equal(fit$opt$convergence, 0L)

  ## theta_diag_W is fully mapped off: every entry NA.
  td_map <- fit$tmb_obj$env$map$theta_diag_W
  expect_true("theta_diag_W" %in% names(fit$tmb_obj$env$map),
              label = "theta_diag_W in map")
  expect_true(all(is.na(td_map)),
              label = "all theta_diag_W entries NA")

  ## s_W is fully mapped off too.
  sW_map <- fit$tmb_obj$env$map$s_W
  expect_true("s_W" %in% names(fit$tmb_obj$env$map),
              label = "s_W in map")
  expect_true(all(is.na(sW_map)),
              label = "all s_W entries NA")

  ## Reported sd_W ~ 1e-6 (pinned floor), not free-estimated.
  expect_true(all(fit$report$sd_W < 1e-3),
              label = "sd_W pinned at ~1e-6")

  ## Free-parameter count: same as the reference (no extra free pars
  ## for the unidentifiable OLRE).
  expect_equal(length(fit$tmb_obj$par), length(fit_ref$tmb_obj$par),
               label = "fit with unique() has the same number of free pars as the reference (Bernoulli OLRE skipped)")
})


## ---- 2. Mixed (gauss + binom + pois) + OLRE: skip only Bernoulli ------------

test_that("mixed-family OLRE: skip Bernoulli trait only; estimate Gaussian and Poisson", {
  skip_on_cran()

  set.seed(789)
  n_units       <- 250
  true_sigma2_e <- c(0.4, 0.6, 0.5)
  true_alpha    <- c(0.0, 0.0, 1.0)
  trait_levels  <- c("gauss", "binom", "pois")
  fam_levels    <- c("gaussian", "binomial", "poisson")

  df <- expand.grid(unit = seq_len(n_units), trait_idx = 1:3)
  df$obs    <- factor(seq_len(nrow(df)))
  df$trait  <- factor(trait_levels[df$trait_idx], levels = trait_levels)
  df$family <- factor(fam_levels[df$trait_idx], levels = fam_levels)
  e_it <- rnorm(nrow(df), sd = sqrt(true_sigma2_e[df$trait_idx]))
  df$value <- ifelse(
    df$trait_idx == 1L,
    true_alpha[1] + e_it,
    ifelse(df$trait_idx == 2L,
           rbinom(nrow(df), 1L, plogis(true_alpha[2] + e_it)),
           rpois(nrow(df), exp(true_alpha[3] + e_it))))

  fams <- list(gaussian(), binomial(), poisson())
  attr(fams, "family_var") <- "family"

  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | obs),
    data = df, unit = "unit", unit_obs = "obs",
    family = fams
  )))
  expect_equal(fit$opt$convergence, 0L)

  ## Map: position 1 (gauss) and 3 (pois) are free; position 2 (binom) is NA.
  td_map <- fit$tmb_obj$env$map$theta_diag_W
  expect_true("theta_diag_W" %in% names(fit$tmb_obj$env$map),
              label = "theta_diag_W in map for mixed-family fit")
  expect_false(is.na(td_map[1]),
               label = "Gaussian trait theta_diag_W stays free")
  expect_true(is.na(td_map[2]),
              label = "Bernoulli trait theta_diag_W mapped off")
  expect_false(is.na(td_map[3]),
               label = "Poisson trait theta_diag_W stays free")

  ## sd_W: gauss + pois recover toward true; binom pinned ~1e-6.
  sd_W <- as.numeric(fit$report$sd_W)
  expect_lt(sd_W[2], 1e-3, label = "Bernoulli sd_W pinned (~1e-6)")
  expect_gt(sd_W[1], 0.05, label = "Gaussian sd_W estimated (> 0.05)")
  expect_gt(sd_W[3], 0.05, label = "Poisson sd_W estimated (> 0.05)")
})


## ---- 3. Pure delta_lognormal + OLRE: warning emitted, fit converges ---------

test_that("pure delta_lognormal + OLRE: warning emitted, fit still converges", {
  skip_on_cran()

  set.seed(2027)
  sim <- simulate_site_trait(n_sites = 30, n_species = 5, n_traits = 2,
                             mean_species_per_site = 4)
  ## Add an `obs` column at the per-row level so unique() is OLRE.
  sim$data$obs <- factor(seq_len(nrow(sim$data)))
  ## Introduce zeros and clip negatives so the response is non-negative
  ## (delta_lognormal requires y >= 0).
  sim$data$value[runif(nrow(sim$data)) < 0.4] <- 0
  sim$data$value <- pmax(sim$data$value, 0)

  expect_warning(
    fit <- suppressMessages(gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | obs),
      data = sim$data, unit_obs = "obs",
      family = delta_lognormal()
    )),
    regexp = "OLRE on hurdle / delta families",
    label = "warning fires for delta_lognormal + per-row unique()"
  )

  ## The fit still runs; theta_diag_W stays free (the warning is advisory).
  expect_equal(fit$opt$convergence, 0L)
  td_map <- fit$tmb_obj$env$map$theta_diag_W
  if (!is.null(td_map)) {
    ## Either theta_diag_W is unmapped (the canonical case for non-binomial
    ## traits) or, if a map exists, all entries should be free integers.
    expect_true(all(!is.na(td_map)),
                label = "delta_lognormal traits stay free under OLRE")
  }
})


## ---- 4. Pure ordinal_probit + OLRE: theta_diag_W mapped off ----------------

test_that("ordinal_probit OLRE: theta_diag_W mapped off (scale absorbed by cutpoints)", {
  skip_on_cran()

  ## ordinal_probit fixes sigma2_d = 1 by convention (cutpoint scale).
  ## Adding sd_W on top introduces an extra scale factor that the
  ## cutpoints absorb, so sd_W is structurally unidentifiable. The
  ## per-family-aware block should auto-skip just like single-trial
  ## Bernoulli.
  ##
  ## Test fixture mirrors the K=4 recovery test in test-ordinal-probit.R:
  ## one row per (individual, trait), so `unique(0 + trait | individual)`
  ## IS at per-row resolution for the W tier and the auto-suppress
  ## block fires.
  set.seed(951)
  n_ind  <- 300L
  Tn     <- 2L
  trait_names <- c("a", "b")
  ystar <- matrix(stats::rnorm(n_ind * Tn, mean = c(0.0, 0.3)), n_ind, Tn,
                  byrow = TRUE)
  y_a <- 1L + (ystar[, 1] > 0) + (ystar[, 1] > 0.6) + (ystar[, 1] > 1.2)
  y_b <- 1L + (ystar[, 2] > 0) + (ystar[, 2] > 0.6) + (ystar[, 2] > 1.2)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = c(t(cbind(y_a, y_b)))
  )

  msgs <- testthat::capture_messages(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait + unique(0 + trait | individual),
      data = df, unit = "individual", unit_obs = "individual",
      family = ordinal_probit()
    ))
  )
  expect_true(
    any(grepl("Skipping OLRE for", msgs) &
        grepl("ordinal_probit", msgs)),
    label = "informational message announces the ordinal_probit OLRE skip"
  )

  expect_equal(fit$opt$convergence, 0L)

  ## theta_diag_W is fully mapped off: every entry NA.
  expect_true("theta_diag_W" %in% names(fit$tmb_obj$env$map),
              label = "theta_diag_W in map")
  td_map <- fit$tmb_obj$env$map$theta_diag_W
  expect_true(all(is.na(td_map)),
              label = "all theta_diag_W entries NA for ordinal_probit")

  ## s_W is fully mapped off too.
  expect_true("s_W" %in% names(fit$tmb_obj$env$map),
              label = "s_W in map")
  sW_map <- fit$tmb_obj$env$map$s_W
  expect_true(all(is.na(sW_map)),
              label = "all s_W entries NA for ordinal_probit")

  ## Reported sd_W ~ 1e-6 (pinned floor), not free-estimated.
  expect_true(all(fit$report$sd_W < 1e-3),
              label = "sd_W pinned at ~1e-6 for ordinal_probit")
})
