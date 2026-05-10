## Tests for the zero-truncated count families added to the multivariate
## engine: truncated_poisson() and truncated_nbinom2().
##
## DGP:  y_it ~ ZTPois(lambda) or ZTNB2(mu, phi); log link
## Fit:  family = truncated_poisson() or truncated_nbinom2()
##
## Biological motivation: zero-truncated counts arise whenever the sampling
## scheme conditions on detection (capture-recapture sample sizes, group
## sizes given the group has been observed, abundance among present sites
## in a presence-conditional analysis). See Welsh, Cunningham, Donnelly &
## Lindenmayer (1996) Ecol. Modelling 88:297-308 for the use of
## zero-truncated count models in ecology, and Cameron & Trivedi (2013)
## "Regression Analysis of Count Data" (2nd ed., Cambridge UP), ch. 4 for
## the truncated Poisson / NB2 likelihoods.

## ---- truncated_poisson() ---------------------------------------------------

rztpois <- function(n, lambda) {
  ## Draw from zero-truncated Poisson via inverse-CDF on the conditional
  ## distribution. Vectorised over lambda (recycled to length n).
  lambda <- rep_len(lambda, n)
  out <- integer(n)
  for (i in seq_len(n)) {
    repeat {
      x <- stats::rpois(1, lambda[i])
      if (x >= 1L) { out[i] <- x; break }
    }
  }
  out
}

test_that("truncated_poisson() converges and recovers trait intercepts", {
  skip_on_cran()
  set.seed(42)
  n_ind <- 250
  Tn <- 3
  trait_names <- letters[seq_len(Tn)]
  mu_true <- c(0.5, 1.0, 1.5)   # log-scale
  y <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- rztpois(n_ind, exp(mu_true[t]))

  df_long <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )
  expect_true(all(df_long$value >= 1L))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df_long,
    site   = "individual",
    family = truncated_poisson()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 10L)

  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.20)
})

test_that("truncated_poisson rejects rows with y < 1", {
  set.seed(1)
  df_long <- data.frame(
    individual = factor(rep(1:10, each = 2)),
    trait      = factor(rep(c("a", "b"), 10)),
    value      = c(rep(0L, 4), stats::rpois(16, 2) + 1L)  # zeros present
  )
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      data = df_long, site = "individual",
      family = truncated_poisson()
    )),
    regexp = "y >= 1"
  )
})

## ---- truncated_nbinom2() --------------------------------------------------

rztnbinom2 <- function(n, mu, phi) {
  mu  <- rep_len(mu, n)
  phi <- rep_len(phi, n)
  out <- integer(n)
  for (i in seq_len(n)) {
    repeat {
      x <- stats::rnbinom(1, size = phi[i], mu = mu[i])
      if (x >= 1L) { out[i] <- x; break }
    }
  }
  out
}

test_that("truncated_nbinom2() converges and recovers trait intercepts + phi", {
  skip_on_cran()
  set.seed(99)
  n_ind <- 300
  Tn <- 3
  trait_names <- letters[seq_len(Tn)]
  ## Choose mu_true on the higher side: with low mu the truncation removes
  ## the bulk of the zero-mass evidence and phi becomes weakly identified
  ## (the truncated NB2 collapses toward truncated Poisson). At mu in
  ## {exp(1.5), exp(2), exp(2.5)} = {4.5, 7.4, 12.2} the zero-truncation
  ## correction is small and phi is identifiable.
  mu_true  <- c(1.5, 2.0, 2.5)
  phi_true <- 2.0
  y <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- rztnbinom2(n_ind, exp(mu_true[t]), phi_true)

  df_long <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(trait_names, n_ind), levels = trait_names),
    value      = as.vector(t(y))
  )
  expect_true(all(df_long$value >= 1L))

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data   = df_long,
    site   = "individual",
    family = truncated_nbinom2()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 11L)

  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  expect_equal(length(bfix), Tn)
  expect_lt(max(abs(bfix - mu_true)), 0.30)

  phi_hat <- as.numeric(fit$report$phi_truncnb2)
  expect_equal(length(phi_hat), Tn)
  expect_true(all(phi_hat > 0.3 * phi_true & phi_hat < 5 * phi_true))
})

test_that("truncated_nbinom2 logLik agrees with glmmTMB::truncated_nbinom2()", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")
  set.seed(13)
  n_ind <- 300
  Tn <- 2
  mu_true  <- c(1.5, 2.2)
  phi_true <- 2.0
  y <- matrix(NA_integer_, n_ind, Tn)
  for (t in seq_len(Tn))
    y[, t] <- rztnbinom2(n_ind, exp(mu_true[t]), phi_true)

  df_long <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait      = factor(rep(c("a", "b"), n_ind), levels = c("a", "b")),
    value      = as.vector(t(y))
  )

  fit_g <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df_long, site = "individual",
    family = truncated_nbinom2()
  )))

  fit_a <- glmmTMB::glmmTMB(
    value ~ 1 + (1 | individual),
    data = df_long[df_long$trait == "a", ],
    family = glmmTMB::truncated_nbinom2()
  )
  fit_b <- glmmTMB::glmmTMB(
    value ~ 1 + (1 | individual),
    data = df_long[df_long$trait == "b", ],
    family = glmmTMB::truncated_nbinom2()
  )

  ll_gllvm   <- -fit_g$opt$objective
  ll_glmmTMB <- as.numeric(stats::logLik(fit_a)) + as.numeric(stats::logLik(fit_b))
  rel_err    <- abs(ll_gllvm - ll_glmmTMB) / abs(ll_glmmTMB)
  expect_lt(rel_err, 0.10)
})

test_that("truncated_nbinom2 rejects rows with y < 1", {
  set.seed(1)
  df_long <- data.frame(
    individual = factor(rep(1:10, each = 2)),
    trait      = factor(rep(c("a", "b"), 10)),
    value      = c(rep(0L, 4), stats::rpois(16, 2) + 1L)
  )
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | individual, d = 1),
      data = df_long, site = "individual",
      family = truncated_nbinom2()
    )),
    regexp = "y >= 1"
  )
})
