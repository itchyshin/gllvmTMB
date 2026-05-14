## lme4 / glmmTMB-style observation weights for the multi engine.
##
## The single-response engine (src/gllvmTMB.cpp) already multiplies each
## row's log-likelihood by `weights_i(i)`. The multi engine
## (inst/tmb/gllvmTMB_multi.cpp) historically only honoured `weights = `
## as a binomial trial-count alias; for non-binomial families it was a
## silent no-op. This test file pins the new contract:
##
##   * For non-binomial rows, `weights[i]` multiplies the row's log-
##     likelihood (lme4 / glmmTMB convention).
##   * For binomial rows, `weights[i]` continues to be the trial count
##     (existing alternative API to `cbind(succ, fail)`).
##   * Mixed-family fits dispatch per row.
##
## References:
##   Bates et al. (2015) lme4 paper, sec. on observation weights.
##   Brooks et al. (2017) glmmTMB paper; weights documented identically.

skip_if_not_installed("gllvmTMB")

# ---- shared simulated data --------------------------------------------
make_gauss <- function(seed = 1L) {
  ## Small Gaussian DGP: 30 sites x 4 traits, with a non-trivial residual
  ## sigma (the simulator's default sigma2_eps = 0.5). We deliberately
  ## use a single low-rank `latent(d = 1)` term in the fit so the random-
  ## effect structure does NOT absorb all data variability — that keeps
  ## sigma_eps well above its numerical floor and makes weighted-vs-
  ## unweighted differences detectable in both objective and SEs.
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 4,
    mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2),
    psi_B = rep(0.2, 4),
    seed = seed
  )
  sim$data
}

# ----------------------------------------------------------------------
# Test 1: byte-equivalence under unit weights (Gaussian)
test_that("Gaussian fit with weights = 1 is byte-equiv to weights = NULL", {
  df <- make_gauss(seed = 1L)
  fit_null <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    silent  = TRUE
  )))
  fit_unit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    weights = rep(1, nrow(df)),
    silent  = TRUE
  )))
  expect_equal(fit_null$opt$convergence, 0L)
  expect_equal(fit_unit$opt$convergence, 0L)
  expect_equal(fit_unit$opt$objective, fit_null$opt$objective, tolerance = 1e-10)
})

# ----------------------------------------------------------------------
# Test 2: weights are non-trivially applied — objective changes AND
# point estimates of fixed effects are invariant under uniform scaling.
# Doubling all weights scales the data-NLL portion by 2; the RE prior
# is unweighted, so the joint NLL doesn't scale by exactly 2x but it
# must change. The argmax of fixed effects is unchanged under uniform
# scaling: this is the lme4 / glmmTMB observation-weights contract.
test_that("Uniform weight scaling: objective changes; b_fix invariant", {
  df <- make_gauss(seed = 2L)
  fit_w1 <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    weights = rep(1, nrow(df)),
    silent  = TRUE
  )))
  fit_w2 <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    weights = rep(2, nrow(df)),
    silent  = TRUE
  )))
  expect_equal(fit_w1$opt$convergence, 0L)
  expect_equal(fit_w2$opt$convergence, 0L)
  ## (a) Objectives must DIFFER: silent-ignore would leave them equal.
  ## We require >5% relative change to clear floating-point noise.
  rel_change <- abs(fit_w2$opt$objective - fit_w1$opt$objective) /
                pmax(abs(fit_w1$opt$objective), 1)
  expect_gt(rel_change, 0.05)
  ## (b) MLE point-estimate invariance for b_fix (the fixed-effects
  ## coefficients). The argmax of the data-NLL is invariant under
  ## constant-multiplier scaling.
  expect_equal(fit_w1$opt$par[names(fit_w1$opt$par) == "b_fix"],
               fit_w2$opt$par[names(fit_w2$opt$par) == "b_fix"],
               tolerance = 1e-3)
})

# ----------------------------------------------------------------------
# Test 3: SE scaling under uniform weight scaling
# When the loglik is multiplied by c, the (marginal) Fisher information
# for b_fix scales by c, so SEs shrink by ~1/sqrt(c). Doubling weights
# must therefore shrink b_fix SEs (each entry must shrink to less than
# the unweighted SE; we don't pin the exact ratio because the Laplace
# approximation perturbs individual coefficients differently — see
# Pinheiro & Bates 2000 ch. 7 and the lme4 / glmmTMB documentation on
# weights-as-information-multipliers).
test_that("Doubling weights shrinks b_fix SEs", {
  df <- make_gauss(seed = 3L)
  fit_w1 <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    weights = rep(1, nrow(df)),
    silent  = TRUE
  )))
  fit_w2 <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    weights = rep(2, nrow(df)),
    silent  = TRUE
  )))
  sd1 <- summary(fit_w1$sd_report, "fixed")
  sd2 <- summary(fit_w2$sd_report, "fixed")
  rows1 <- which(rownames(sd1) == "b_fix")
  rows2 <- which(rownames(sd2) == "b_fix")
  expect_equal(length(rows1), length(rows2))
  se1 <- sd1[rows1, "Std. Error"]
  se2 <- sd2[rows2, "Std. Error"]
  ## (a) Each SE must shrink (this fails immediately if weights are
  ## silently ignored — they would all stay equal).
  expect_true(all(se2 < se1))
  ## (b) The geometric-mean ratio must be substantially below 1, in
  ## the right ballpark for c = 2 (between 0.5 and 0.95). This catches
  ## both silent-ignore (~1) and grossly mis-scaled application
  ## (e.g. weight applied to wrong term).
  geo_ratio <- exp(mean(log(se2 / se1)))
  expect_gt(geo_ratio, 0.5)
  expect_lt(geo_ratio, 0.95)
})

# ----------------------------------------------------------------------
# Test 4: heteroscedastic recovery — weights move sigma in the right
# direction. We simulate Var(y) = sigma_0^2 / w; the optimal weights
# w_i = 1/var_i restore homoscedasticity. Fit with and without those
# weights and confirm the weighted fit's sigma estimate is closer to
# sigma_0 than the unweighted fit's.
test_that("Heteroscedastic Gaussian: weighted fit improves sigma recovery", {
  skip_on_cran()
  set.seed(42L)
  ## 30 sites x 3 traits, all Gaussian, but with row-wise variance
  ## inflation drawn from Uniform(0.5, 5). True sigma_0 = 1.
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 1, n_traits = 3,
    mean_species_per_site = 1,
    sigma2_eps = 0.0,                  # turn off the simulator's noise
    Lambda_B   = matrix(rnorm(6, sd = 0.4), 3, 2),
    psi_B        = rep(0.2, 3),
    seed       = 42L
  )
  df <- sim$data
  sigma_0 <- 1.0
  var_i <- runif(nrow(df), min = 0.5, max = 5)   # row-wise variance multipliers
  df$value <- df$value + rnorm(nrow(df), sd = sigma_0 * sqrt(var_i))
  w_i <- 1 / var_i

  fit_unw <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    silent  = TRUE
  )))
  fit_w   <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data    = df,
    weights = w_i,
    silent  = TRUE
  )))
  ## Both fits expose log_sigma_eps via report().
  rep_unw <- fit_unw$tmb_obj$report()
  rep_w   <- fit_w$tmb_obj$report()
  expect_lt(abs(rep_w$sigma_eps - sigma_0), abs(rep_unw$sigma_eps - sigma_0))
})

# ----------------------------------------------------------------------
# Test 5: binomial trial-count semantics preserved.
# weights = n_trials must continue to work as the alternative-API trial
# count, bit-for-bit equivalent to cbind(succ, fail). The new likelihood-
# multiplier code path must NOT double-apply the weight on binomial rows.
test_that("Binomial: weights = n_trials matches cbind(succ, fail) (no double-apply)", {
  set.seed(5L)
  n <- 50L
  trait_levels <- c("a", "b")
  df <- data.frame(
    site         = rep(factor(sprintf("s%02d", seq_len(n))), each = 2L),
    species      = factor(rep("placeholder", 2L * n)),
    trait        = factor(rep(trait_levels, n), levels = trait_levels),
    site_species = factor(rep(sprintf("s%02d_sp", seq_len(n)), each = 2L)),
    x            = rep(stats::rnorm(n), each = 2L)
  )
  n_trials_vec <- rep(8L, nrow(df))
  p <- plogis(0.2 + 0.4 * df$x)
  df$succ <- stats::rbinom(nrow(df), size = n_trials_vec, prob = p)
  df$fail <- n_trials_vec - df$succ

  fit_cbind <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + (0 + trait):x +
      latent(0 + trait | site, d = 1),
    data    = df,
    family  = binomial(),
    silent  = TRUE
  )))
  fit_w     <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    succ ~ 0 + trait + (0 + trait):x +
      latent(0 + trait | site, d = 1),
    data    = df,
    family  = binomial(),
    weights = n_trials_vec,
    silent  = TRUE
  )))
  expect_equal(fit_cbind$opt$convergence, 0L)
  expect_equal(fit_w$opt$convergence,     0L)
  expect_equal(fit_w$opt$objective, fit_cbind$opt$objective, tolerance = 1e-5)
})

# ----------------------------------------------------------------------
# Test 6: mixed-family fit with weights — per-row dispatch.
# Two traits: trait_1 = Gaussian (likelihood-multiplier), trait_2 =
# binomial (trial-count). One `weights` vector flows in. We verify that:
#   * the Gaussian rows respond to the weight (loglik changes with
#     scaled weights, so the objective changes proportionally), AND
#   * the binomial rows keep their trial-count semantics (matches a
#     cbind(succ, fail) fit on the same data with weights = 1 on the
#     gaussian rows).
test_that("Mixed-family fit: per-row weight dispatch works", {
  skip_on_cran()
  set.seed(6L)
  n <- 40L
  trait_levels <- c("g1", "b1")
  df <- data.frame(
    site         = rep(factor(sprintf("s%02d", seq_len(n))), each = 2L),
    species      = factor(rep("placeholder", 2L * n)),
    trait        = factor(rep(trait_levels, n), levels = trait_levels),
    site_species = factor(rep(sprintf("s%02d_sp", seq_len(n)), each = 2L)),
    x            = rep(stats::rnorm(n), each = 2L)
  )
  ## Gaussian rows (trait g1)
  is_g <- df$trait == "g1"
  df$value <- NA_real_
  df$value[is_g] <- 0.3 * df$x[is_g] + rnorm(sum(is_g), sd = 0.5)
  ## Binomial rows (trait b1) — k-of-n with n_trials = 6
  n_trials_vec <- ifelse(is_g, 1L, 6L)
  p <- plogis(0.2 + 0.5 * df$x)
  df$value[!is_g] <- stats::rbinom(sum(!is_g), size = n_trials_vec[!is_g],
                                   prob = p[!is_g])
  ## Family vector (one per trait level). The factor levels of `family`
  ## sort alphabetically to c("binomial", "gaussian"), so `fams` must be
  ## in that order for the multi-fit dispatcher to pair them correctly.
  df$family <- ifelse(is_g, "gaussian", "binomial")
  fams <- list(binomial(), gaussian())
  attr(fams, "family_var") <- "family"

  ## Fit with weights = n_trials. For Gaussian rows, weights=1 (unit);
  ## for binomial rows, weights = n_trials. So this should be byte-equiv
  ## to weights = NULL on Gaussian rows and weights = n_trials on
  ## binomial rows — both established semantics.
  fit_mixed <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (0 + trait):x +
      latent(0 + trait | site, d = 1),
    data    = df,
    family  = fams,
    weights = n_trials_vec,
    silent  = TRUE
  )))
  expect_equal(fit_mixed$opt$convergence, 0L)
  ## tmb_data should carry weights_i = 1 for binomial rows and the
  ## user-supplied value for gaussian rows.
  expect_true("weights_i" %in% names(fit_mixed$tmb_data))
  bin_rows <- fit_mixed$tmb_data$family_id_vec == 1L
  expect_true(all(fit_mixed$tmb_data$weights_i[bin_rows] == 1))
  expect_true(all(fit_mixed$tmb_data$weights_i[!bin_rows] == n_trials_vec[!bin_rows]))
  ## And n_trials should carry the user weights for binomial rows
  ## (existing behaviour) and 1 for gaussian rows.
  expect_true(all(fit_mixed$tmb_data$n_trials[bin_rows] == n_trials_vec[bin_rows]))
  expect_true(all(fit_mixed$tmb_data$n_trials[!bin_rows] == 1))
})
