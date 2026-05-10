## Tests for cross-sectional unique() usage.
##
## Verifies that when a user fits cross-sectional data (one observation per
## individual per trait) and adds `+ unique(0 + trait | individual)`, the
## engine auto-suppresses sigma_eps and recovers the trait-specific unique
## variances.
##
## Science: in cross-sectional morphometric data the (trait, individual) tuple
## uniquely identifies every row. The engine detects this (fit-multi.R:557-573)
## and fixes log_sigma_eps to a tiny constant so unique() absorbs the full
## per-row residual.

test_that("cross-sectional unique(): sigma_eps auto-suppressed and s_t recovered", {
  skip_on_cran()

  ## ---- simulate cross-sectional data -----------------------------------
  set.seed(4242)
  n_ind  <- 100
  T_n    <- 4
  trait_names <- c("t1", "t2", "t3", "t4")

  ## True factor structure
  Lambda_true <- matrix(
    c(0.8, 0.3, -0.5, 0.6,
      0.2, 0.7,  0.4, 0.1),
    nrow = T_n, ncol = 2,
    dimnames = list(trait_names, c("f1", "f2"))
  )

  ## True trait-specific unique variances (on the variance scale)
  s2_true <- c(t1 = 0.5, t2 = 0.3, t3 = 0.8, t4 = 0.4)

  ## Generate 100 individuals x 4 traits, one obs per cell (cross-sectional)
  u   <- matrix(rnorm(n_ind * 2), n_ind, 2)
  eps <- sapply(seq_len(T_n), function(t) rnorm(n_ind, sd = sqrt(s2_true[t])))
  Y   <- u %*% t(Lambda_true) + eps

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = T_n)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(Y))
  )

  ## ---- fit with unique() -----------------------------------------------
  expect_message(
    fit <- suppressWarnings(gllvmTMB(
      value ~ 0 + trait +
              latent(0 + trait | individual, d = 1) +
              unique(0 + trait | individual),
      data = df,
      site = "individual"
    )),
    regexp = "Auto-suppressing.*sigma_eps"
  )

  ## (a) model converged
  expect_equal(fit$opt$convergence, 0L)

  ## (b) log_sigma_eps is in the map and is NA (auto-suppression triggered)
  expect_true("log_sigma_eps" %in% names(fit$tmb_obj$env$map),
              label = "log_sigma_eps present in map")
  expect_true(is.na(fit$tmb_obj$env$map$log_sigma_eps[[1]]),
              label = "log_sigma_eps mapped to NA")

  ## (c) recovered s_t within ±0.4 of simulated truth.
  ##
  ## Note: the unique/shared partition of trait variance is weakly identified
  ## in factor models (rotation/shift indeterminacy; see extract-sigma.R §
  ## "Caveat: 'shared' vs 'unique' partition"). n=100 with d=1 can shift
  ## variance between the factor and unique components by ~0.3 SD units while
  ## holding total trait variance constant. We therefore check a generous
  ## band around the simulated truth rather than tight recovery.
  s_hat <- extract_Sigma(fit, level = "B", part = "unique")$s
  expect_equal(length(s_hat), T_n)
  s_true_sd <- sqrt(s2_true)   # compare on SD scale to match s_hat
  for (t in seq_len(T_n)) {
    expect_lt(
      abs(s_hat[t] - s_true_sd[t]), 0.4,
      label = paste0("s_hat[", t, "] within ±0.4 of truth (", round(s_true_sd[t], 3), ")")
    )
  }
})
