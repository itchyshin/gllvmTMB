## Tests for exact family-CDF randomized-quantile residuals added to
## `.gllvmTMB_exact_rq_residuals()` (R/predictive-diagnostics.R): binomial,
## lognormal, Gamma, Beta, betabinomial, Student-t, zero-truncated Poisson,
## zero-truncated NB2, and ordinal-probit. Gaussian, Poisson, NB2, and NB1
## are already covered by test-predictive-diagnostics.R and are not
## re-tested here.
##
## For each implemented family below:
##   (a) residuals are finite and in-range for a fitted model;
##   (b) the returned `status` is not "unsupported_family";
##   (c) a correctness check: under a correctly-specified DGP the
##       "normal"-scale residual should be approximately standard normal.
##       A moment check (mean, sd) at a fixed seed with a generous
##       tolerance catches a wrong CDF or a wrong shape/scale
##       parameterisation without flaking on ordinary Monte Carlo noise;
##   (d) invalid/missing-parameter rows get their explicit status rather
##       than a silent (wrong) number.
##
## Each family is fit ONCE; (a)-(c) and (d) reuse the same fitted object
## (mutating copies of $tmb_data / $report for (d)) to keep total TMB fit
## count to one per family.

rztpois <- function(n, lambda) {
  ## Draw from zero-truncated Poisson via rejection sampling (matches the
  ## helper in test-truncated-recovery.R).
  lambda <- rep_len(lambda, n)
  out <- integer(n)
  for (i in seq_len(n)) {
    repeat {
      x <- stats::rpois(1, lambda[i])
      if (x >= 1L) {
        out[i] <- x
        break
      }
    }
  }
  out
}

rztnbinom2 <- function(n, mu, phi) {
  mu <- rep_len(mu, n)
  phi <- rep_len(phi, n)
  out <- integer(n)
  for (i in seq_len(n)) {
    repeat {
      x <- stats::rnbinom(1, size = phi[i], mu = mu[i])
      if (x >= 1L) {
        out[i] <- x
        break
      }
    }
  }
  out
}

## Moment bounds alone are a weak check: mutation testing found several
## realistic CDF/parameterisation defects (a betabinomial a/b swap, a
## dropped zero-truncation renormalisation, a dropped ordinal tau_1 = 0
## prepend, a probit CDF fit with a logit link) that stay inside generous
## mean/sd bounds. `res$u` should be exactly Uniform(0, 1) under a correct
## CDF regardless of the fitted eta's shape, so a KS test against punif
## catches those misses; keep it alongside (not instead of) the moment
## bounds, since the KS test alone is insensitive to a location-only bias
## that a small mean check still catches directly.
expect_rq_moments_ok <- function(
  res,
  mean_tol = 0.30,
  sd_lo = 0.70,
  sd_hi = 1.35,
  ks_alpha = 1e-3
) {
  expect_true(all(res$status == "ok"))
  r <- res$residual
  m <- mean(r)
  s <- stats::sd(r)
  expect_lt(abs(m), mean_tol)
  expect_gt(s, sd_lo)
  expect_lt(s, sd_hi)
  expect_gt(
    suppressWarnings(stats::ks.test(res$u, "punif"))$p.value,
    ks_alpha
  )
}

## ---- binomial (fid 1) ------------------------------------------------------

make_rq_binomial_fit <- function(seed = 201L, link = c("logit", "probit", "cloglog")) {
  link <- match.arg(link)
  set.seed(seed)
  n_ind <- 250L
  Tn <- 2L
  trait_names <- c("a", "b")
  N <- 12L
  mu_true <- c(-0.6, 0.5)
  invlink <- switch(
    link,
    logit = stats::plogis,
    probit = stats::pnorm,
    cloglog = function(e) -expm1(-exp(e))
  )
  succ <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t <- invlink(mu_true[t])
    succ[, t] <- stats::rbinom(n_ind, size = N, prob = p_t)
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    succ = as.vector(t(succ)),
    fail = as.vector(t(N - succ))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = stats::binomial(link = link)
  )))
  fit
}

test_that("binomial (logit link) exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_binomial_fit(seed = 201L, link = "logit")
  expect_true(all(fit$tmb_data$family_id_vec == 1L))
  expect_true(all(fit$tmb_data$link_id_vec == 0L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 301L)
  expect_true(all(res$family == "binomial"))
  expect_rq_moments_ok(res)
})

## The probit and cloglog branches of `.gllvmTMB_binom_prob()` are correct
## by inspection (they mirror src/gllvmTMB.cpp fid == 1 line for line) but
## were otherwise DEAD in this suite -- the logit fixture above cannot
## exercise them, and a probit CDF fit to a logit-generated response stays
## inside the moment bounds (mutation-tested: mean +0.077, sd 1.130).
test_that("binomial (probit link) exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_binomial_fit(seed = 211L, link = "probit")
  expect_true(all(fit$tmb_data$family_id_vec == 1L))
  expect_true(all(fit$tmb_data$link_id_vec == 1L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 326L)
  expect_true(all(res$family == "binomial"))
  expect_rq_moments_ok(res)
})

test_that("binomial (cloglog link) exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_binomial_fit(seed = 212L, link = "cloglog")
  expect_true(all(fit$tmb_data$family_id_vec == 1L))
  expect_true(all(fit$tmb_data$link_id_vec == 2L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 327L)
  expect_true(all(res$family == "binomial"))
  expect_rq_moments_ok(res)
})

test_that("binomial exact residuals flag invalid/missing/unknown-link rows explicitly", {
  skip_on_cran()
  fit <- make_rq_binomial_fit()

  fit_bad_trials <- fit
  fit_bad_trials$tmb_data$n_trials[1] <- NA_real_
  res1 <- stats::residuals(fit_bad_trials, type = "randomized_quantile", seed = 302L)
  expect_equal(res1$status[1], "missing_trials")
  expect_true(is.na(res1$residual[1]))

  fit_bad_y <- fit
  fit_bad_y$tmb_data$y[1] <- fit_bad_y$tmb_data$n_trials[1] + 1
  res2 <- stats::residuals(fit_bad_y, type = "randomized_quantile", seed = 303L)
  expect_equal(res2$status[1], "invalid_observed")
  expect_true(is.na(res2$residual[1]))

  fit_bad_link <- fit
  fit_bad_link$tmb_data$link_id_vec[1] <- 99L
  res3 <- stats::residuals(fit_bad_link, type = "randomized_quantile", seed = 328L)
  expect_equal(res3$status[1], "unknown_link")
  expect_true(is.na(res3$residual[1]))
})

## ---- lognormal (fid 3) -----------------------------------------------------

make_rq_lognormal_fit <- function(seed = 202L) {
  set.seed(seed)
  n_ind <- 250L
  Tn <- 2L
  trait_names <- c("a", "b")
  mu_true <- c(0.2, -0.3)
  sigma_true <- 0.4
  u <- stats::rnorm(n_ind, sd = 0.25)
  eta <- cbind(mu_true[1] + u, mu_true[2] + 0.6 * u)
  y <- exp(eta + matrix(stats::rnorm(n_ind * Tn, sd = sigma_true), n_ind, Tn))
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = gllvmTMB::lognormal()
  )))
  fit
}

test_that("lognormal exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_lognormal_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 3L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 304L)
  expect_true(all(res$family == "lognormal"))
  expect_rq_moments_ok(res)
})

test_that("lognormal exact residuals flag non-positive observed values", {
  skip_on_cran()
  fit <- make_rq_lognormal_fit()
  fit$tmb_data$y[1] <- 0
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 305L)
  expect_equal(res$status[1], "invalid_observed")
  expect_true(is.na(res$residual[1]))
})

## ---- Gamma (fid 4) ---------------------------------------------------------

make_rq_gamma_fit <- function(seed = 203L) {
  set.seed(seed)
  n_ind <- 250L
  Tn <- 2L
  trait_names <- c("a", "b")
  mu_true <- c(0.3, 0.8)
  shape_true <- 5
  u <- stats::rnorm(n_ind, sd = 0.2)
  eta <- cbind(mu_true[1] + u, mu_true[2] + 0.5 * u)
  y <- matrix(
    stats::rgamma(n_ind * Tn, shape = shape_true, rate = shape_true / exp(as.vector(eta))),
    n_ind,
    Tn
  )
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = stats::Gamma(link = "log")
  )))
  fit
}

test_that("Gamma exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_gamma_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 4L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 306L)
  expect_true(all(res$family == "Gamma"))
  expect_rq_moments_ok(res)
})

test_that("Gamma exact residuals flag non-positive observed and missing shape", {
  skip_on_cran()
  fit <- make_rq_gamma_fit()

  fit_bad_y <- fit
  fit_bad_y$tmb_data$y[1] <- 0
  res1 <- stats::residuals(fit_bad_y, type = "randomized_quantile", seed = 307L)
  expect_equal(res1$status[1], "invalid_observed")

  fit_bad_phi <- fit
  fit_bad_phi$report$phi_gamma[] <- NA_real_
  res2 <- stats::residuals(fit_bad_phi, type = "randomized_quantile", seed = 308L)
  expect_true(all(res2$status == "missing_phi"))
  expect_true(all(is.na(res2$residual)))
})

## ---- Beta (fid 7) ----------------------------------------------------------

make_rq_beta_fit <- function(seed = 204L) {
  set.seed(seed)
  n_ind <- 250L
  Tn <- 2L
  trait_names <- c("a", "b")
  mu_true <- c(-0.4, 0.5)
  phi_true <- 6
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t <- stats::plogis(mu_true[t])
    y[, t] <- stats::rbeta(n_ind, p_t * phi_true, (1 - p_t) * phi_true)
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = gllvmTMB::Beta()
  )))
  fit
}

test_that("Beta exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_beta_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 7L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 309L)
  expect_true(all(res$family == "Beta"))
  expect_rq_moments_ok(res)
})

test_that("Beta exact residuals flag out-of-range observed and missing phi", {
  skip_on_cran()
  fit <- make_rq_beta_fit()

  fit_bad_y <- fit
  fit_bad_y$tmb_data$y[1] <- 1
  res1 <- stats::residuals(fit_bad_y, type = "randomized_quantile", seed = 310L)
  expect_equal(res1$status[1], "invalid_observed")

  fit_bad_phi <- fit
  fit_bad_phi$report$phi_beta[] <- NA_real_
  res2 <- stats::residuals(fit_bad_phi, type = "randomized_quantile", seed = 311L)
  expect_true(all(res2$status == "missing_phi"))
})

## ---- betabinomial (fid 8) --------------------------------------------------

make_rq_betabinomial_fit <- function(seed = 205L) {
  set.seed(seed)
  n_ind <- 280L
  Tn <- 2L
  trait_names <- c("a", "b")
  ## mu_true near 0.5 makes an a/b (shape1/shape2) swap nearly symmetric and
  ## mutation-invisible (measured: mean +0.132, sd 1.239 at c(-0.3, 0.4), a
  ## miss the moment bounds alone did not catch). Push trait a further from
  ## 0.5 (plogis(-1.4) = 0.198) so a swap is separable at this sample size.
  mu_true <- c(-1.4, 0.4)
  phi_true <- 4
  N <- 10L
  succ <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    p_t <- stats::plogis(mu_true[t])
    p_random <- stats::rbeta(n_ind, p_t * phi_true, (1 - p_t) * phi_true)
    succ[, t] <- stats::rbinom(n_ind, size = N, prob = p_random)
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    succ = as.vector(t(succ)),
    fail = as.vector(t(N - succ))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = gllvmTMB::betabinomial()
  )))
  fit
}

test_that("betabinomial exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_betabinomial_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 8L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 312L)
  expect_true(all(res$family == "betabinomial"))
  expect_rq_moments_ok(res)
})

test_that("betabinomial exact residuals flag invalid/missing rows explicitly", {
  skip_on_cran()
  fit <- make_rq_betabinomial_fit()

  fit_bad_trials <- fit
  fit_bad_trials$tmb_data$n_trials[1] <- 0
  res1 <- stats::residuals(fit_bad_trials, type = "randomized_quantile", seed = 313L)
  expect_equal(res1$status[1], "missing_trials")

  fit_bad_phi <- fit
  fit_bad_phi$report$phi_betabinom[] <- NA_real_
  res2 <- stats::residuals(fit_bad_phi, type = "randomized_quantile", seed = 314L)
  expect_true(all(res2$status == "missing_phi"))
})

## ---- Student-t (fid 9) ------------------------------------------------------

make_rq_student_fit <- function(seed = 206L) {
  set.seed(seed)
  n_ind <- 250L
  Tn <- 2L
  trait_names <- c("a", "b")
  mu_true <- c(0.0, 1.0)
  sigma_true <- 0.8
  ## At df = 8 a pt-for-pnorm (or pnorm-for-pt) substitution is
  ## mutation-invisible: the fitted sigma re-absorbs the shape difference
  ## and KS p = 0.52 on the resulting residuals. df = 3 keeps finite
  ## variance (df > 2) while staying heavy-tailed enough to be separable
  ## from a normal at this sample size.
  df_true <- 3
  y <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    y[, t] <- mu_true[t] + sigma_true * stats::rt(n_ind, df = df_true)
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    ## Fix df: a two-parameter (sigma, df) per-trait estimation problem at
    ## this sample size is noisier and not the point of this residual test.
    family = gllvmTMB::student(df = df_true)
  )))
  fit
}

test_that("student exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- suppressMessages(make_rq_student_fit())
  expect_true(all(fit$tmb_data$family_id_vec == 9L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 315L)
  expect_true(all(res$family == "student"))
  expect_rq_moments_ok(res)
})

test_that("student exact residuals flag missing sigma/df", {
  skip_on_cran()
  fit <- suppressMessages(make_rq_student_fit())

  fit_bad_sigma <- fit
  fit_bad_sigma$report$sigma_student[] <- NA_real_
  res1 <- stats::residuals(fit_bad_sigma, type = "randomized_quantile", seed = 316L)
  expect_true(all(res1$status == "missing_phi"))

  fit_bad_df <- fit
  fit_bad_df$report$df_student[] <- 1
  res2 <- stats::residuals(fit_bad_df, type = "randomized_quantile", seed = 317L)
  expect_true(all(res2$status == "missing_phi"))
})

## ---- zero-truncated Poisson (fid 10) ---------------------------------------

make_rq_truncated_poisson_fit <- function(seed = 207L) {
  set.seed(seed)
  n_ind <- 250L
  Tn <- 2L
  trait_names <- c("a", "b")
  mu_true <- c(0.8, 1.3)
  y <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    y[, t] <- rztpois(n_ind, exp(mu_true[t]))
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = gllvmTMB::truncated_poisson()
  )))
  fit
}

test_that("truncated_poisson exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_truncated_poisson_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 10L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 318L)
  expect_true(all(res$family == "truncated_poisson"))
  expect_rq_moments_ok(res)
})

test_that("truncated_poisson exact residuals flag support-violating rows", {
  skip_on_cran()
  fit <- make_rq_truncated_poisson_fit()
  fit$tmb_data$y[1] <- 0
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 319L)
  expect_equal(res$status[1], "invalid_observed")
})

## ---- zero-truncated NB2 (fid 11) -------------------------------------------

make_rq_truncated_nbinom2_fit <- function(seed = 208L) {
  set.seed(seed)
  n_ind <- 280L
  Tn <- 2L
  trait_names <- c("a", "b")
  mu_true <- c(1.6, 2.1)
  phi_true <- 2.5
  y <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    y[, t] <- rztnbinom2(n_ind, exp(mu_true[t]), phi_true)
  }
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1, unique = FALSE),
    data = df,
    unit = "individual",
    family = gllvmTMB::truncated_nbinom2()
  )))
  fit
}

test_that("truncated_nbinom2 exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_truncated_nbinom2_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 11L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 320L)
  expect_true(all(res$family == "truncated_nbinom2"))
  expect_rq_moments_ok(res)
})

test_that("truncated_nbinom2 exact residuals flag support-violating and missing-phi rows", {
  skip_on_cran()
  fit <- make_rq_truncated_nbinom2_fit()

  fit_bad_y <- fit
  fit_bad_y$tmb_data$y[1] <- 0
  res1 <- stats::residuals(fit_bad_y, type = "randomized_quantile", seed = 321L)
  expect_equal(res1$status[1], "invalid_observed")

  fit_bad_phi <- fit
  fit_bad_phi$report$phi_truncnb2[] <- NA_real_
  res2 <- stats::residuals(fit_bad_phi, type = "randomized_quantile", seed = 322L)
  expect_true(all(res2$status == "missing_phi"))
})

## ---- ordinal_probit (fid 14) -----------------------------------------------

make_rq_ordinal_fit <- function(seed = 209L) {
  set.seed(seed)
  n_ind <- 300L
  Tn <- 2L
  trait_names <- c("a", "b")
  true_taus_a <- c(0, 0.7, 1.4) # K = 4
  true_taus_b <- c(0, 0.5) # K = 3
  true_intercept <- c(0.2, -0.1)
  ystar <- matrix(NA_real_, n_ind, Tn)
  for (t in seq_len(Tn)) {
    ystar[, t] <- stats::rnorm(n_ind, mean = true_intercept[t], sd = 1)
  }
  y_a <- 1L + (ystar[, 1] > 0) + (ystar[, 1] > 0.7) + (ystar[, 1] > 1.4)
  y_b <- 1L + (ystar[, 2] > 0) + (ystar[, 2] > 0.5)
  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = c(t(cbind(y_a, y_b)))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | individual),
    data = df,
    unit = "individual",
    family = gllvmTMB::ordinal_probit()
  )))
  fit
}

test_that("ordinal_probit exact residuals are finite, ok, and approximately N(0,1)", {
  skip_on_cran()
  fit <- make_rq_ordinal_fit()
  expect_true(all(fit$tmb_data$family_id_vec == 14L))
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 323L)
  expect_true(all(res$family == "ordinal_probit"))
  expect_rq_moments_ok(res)
})

test_that("ordinal_probit exact residuals flag out-of-range categories", {
  skip_on_cran()
  fit <- make_rq_ordinal_fit()
  max_y <- max(fit$tmb_data$y)
  fit$tmb_data$y[1] <- max_y + 1
  res <- stats::residuals(fit, type = "randomized_quantile", seed = 324L)
  expect_equal(res$status[1], "invalid_observed")
})

## ---- families deliberately left unimplemented ------------------------------

test_that("tweedie, delta_lognormal, delta_gamma, and multinomial stay unsupported_family", {
  skip_on_cran()
  ## Reuses a Gaussian fixture's tmb_data shape (no new TMB fit needed) --
  ## overwrite family_id_vec to each not-implemented id and confirm the
  ## exact-residual path retains "unsupported_family" rather than silently
  ## returning a number.
  fit <- make_rq_gamma_fit(seed = 210L)
  for (fid_not_done in c(6L, 12L, 13L, 16L)) {
    fit_probe <- fit
    fit_probe$tmb_data$family_id_vec[] <- fid_not_done
    res <- stats::residuals(fit_probe, type = "randomized_quantile", seed = 325L)
    expect_true(all(res$status == "unsupported_family"))
    expect_true(all(is.na(res$residual)))
  }
})
