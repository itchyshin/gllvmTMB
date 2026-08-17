## Issue #1079: simulate() correctness for the multi-trial binomial defect
## and the nine families that used to fall through to a Gaussian
## link-scale draw (tweedie, Beta, betabinomial, student-t,
## truncated_poisson, truncated_nbinom2, delta_lognormal, delta_gamma,
## ordinal_probit). These tests exercise `.draw_y_per_family()` directly
## against hand-built minimal `fit`-shaped lists -- the internal draw
## function only reads `fit$tmb_data` and `fit$report`, so a real TMB fit
## is unnecessary and would make these slow and less exact. Distributional
## checks compare draws to the SAME parameterisations
## `.gllvmTMB_exact_rq_residuals()` uses (R/predictive-diagnostics.R).

## A minimal fit-shaped list: only the fields `.draw_y_per_family()` reads.
.mk_fake_fit <- function(n, family_id, link_id = 0L, n_trials = 1,
                          report = list(),
                          n_ordinal_cuts_per_trait = NULL,
                          ordinal_offset_per_trait = NULL) {
  td <- list(
    family_id_vec = rep(as.integer(family_id), n),
    link_id_vec = rep(as.integer(link_id), n),
    trait_id = rep(0L, n),
    n_trials = rep(n_trials, length.out = n)
  )
  if (!is.null(n_ordinal_cuts_per_trait)) {
    td$n_ordinal_cuts_per_trait <- n_ordinal_cuts_per_trait
  }
  if (!is.null(ordinal_offset_per_trait)) {
    td$ordinal_offset_per_trait <- ordinal_offset_per_trait
  }
  list(tmb_data = td, report = report, opt = list(par = c(log_sigma_eps = 0)))
}

# ---- (a) multi-trial binomial: must fail on the pre-fix code -----------

test_that("simulate() draws multi-trial binomial at the row's actual n_trials, not Bernoulli (#1079)", {
  set.seed(1)
  n <- 5000L
  Nt <- 10
  p_true <- 0.5
  fit <- .mk_fake_fit(n, family_id = 1L, link_id = 0L, n_trials = Nt)
  eta <- rep(qlogis(p_true), n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)

  ## The old code hard-coded size = 1L: this assertion is FALSE against it
  ## (verified manually against the pre-fix function: max(y) == 1,
  ## mean(y) ~= 0.49 instead of ~5 -- see the after-task report for #1079).
  expect_gt(max(y), 1)
  expect_equal(mean(y), Nt * p_true, tolerance = 0.05)
})

# ---- (b) distributional sanity checks, one per newly implemented family ----

test_that("Beta (fid 7) draws match rbeta(mu*phi, (1-mu)*phi)", {
  set.seed(2)
  n <- 20000L
  mu <- 0.3
  phi <- 8
  fit <- .mk_fake_fit(n, family_id = 7L, report = list(phi_beta = phi))
  eta <- rep(qlogis(mu), n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  expect_true(all(y > 0 & y < 1))
  ks <- suppressWarnings(stats::ks.test(y, "pbeta", shape1 = mu * phi, shape2 = (1 - mu) * phi))
  expect_gt(ks$p.value, 0.01)
})

test_that("betabinomial (fid 8) draws match the Beta-Binomial mean/variance", {
  set.seed(3)
  n <- 20000L
  N <- 20
  mu <- 0.5
  phi <- 6
  fit <- .mk_fake_fit(n, family_id = 8L, n_trials = N, report = list(phi_betabinom = phi))
  eta <- rep(qlogis(mu), n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  theo_mean <- N * mu
  theo_var <- N * mu * (1 - mu) * (phi + N) / (phi + 1)
  expect_equal(mean(y), theo_mean, tolerance = 0.05)
  expect_equal(stats::var(y), theo_var, tolerance = 0.25)
})

test_that("student-t (fid 9) draws match eta + sigma_student * rt(df)", {
  set.seed(4)
  n <- 20000L
  eta_val <- 2
  sigma_t <- 1.5
  df_t <- 6
  fit <- .mk_fake_fit(
    n,
    family_id = 9L,
    report = list(sigma_student = sigma_t, df_student = df_t)
  )
  eta <- rep(eta_val, n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  z <- (y - eta_val) / sigma_t
  ks <- suppressWarnings(stats::ks.test(z, "pt", df = df_t))
  expect_gt(ks$p.value, 0.01)
})

test_that("truncated_poisson (fid 10) draws are >= 1 and match the truncated mean", {
  set.seed(5)
  n <- 20000L
  lambda <- 3
  fit <- .mk_fake_fit(n, family_id = 10L)
  eta <- rep(log(lambda), n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  expect_true(all(y >= 1))
  theo_mean <- lambda / (1 - exp(-lambda))
  expect_equal(mean(y), theo_mean, tolerance = 0.05)
})

test_that("truncated_nbinom2 (fid 11) draws are >= 1 and match the truncated mean", {
  set.seed(6)
  n <- 20000L
  mu <- 5
  size <- 4
  fit <- .mk_fake_fit(n, family_id = 11L, report = list(phi_truncnb2 = size))
  eta <- rep(log(mu), n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  expect_true(all(y >= 1))
  p0 <- stats::pnbinom(0, size = size, mu = mu)
  k <- 1:500
  pmf <- stats::dnbinom(k, size = size, mu = mu) / (1 - p0)
  theo_mean <- sum(k * pmf)
  expect_equal(mean(y), theo_mean, tolerance = 0.05)
})

test_that("ordinal_probit (fid 14) category frequencies match the threshold model", {
  set.seed(7)
  n <- 20000L
  eta_val <- 0.5
  fit <- .mk_fake_fit(
    n,
    family_id = 14L,
    report = list(ordinal_cutpoints = c(1, 2.5)),
    n_ordinal_cuts_per_trait = 2L,
    ordinal_offset_per_trait = 0L
  )
  eta <- rep(eta_val, n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  expect_true(all(y %in% 1:4))
  cuts <- c(0, 1, 2.5)
  p_theo <- diff(c(0, stats::pnorm(cuts - eta_val), 1))
  obs <- as.numeric(table(factor(y, levels = 1:4)))
  chi <- stats::chisq.test(obs, p = p_theo)
  expect_gt(chi$p.value, 0.01)
})

test_that("delta_lognormal (fid 12) presence + positive part match the shared-eta hurdle", {
  set.seed(8)
  n <- 20000L
  eta_val <- 0.3
  sigma_ld <- 0.7
  fit <- .mk_fake_fit(n, family_id = 12L, report = list(sigma_lognormal_delta = sigma_ld))
  eta <- rep(eta_val, n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  expect_equal(mean(y > 0), stats::plogis(eta_val), tolerance = 0.02)
  pos <- y[y > 0]
  ks <- suppressWarnings(stats::ks.test(pos, "plnorm", meanlog = eta_val, sdlog = sigma_ld))
  expect_gt(ks$p.value, 0.01)
})

test_that("delta_gamma (fid 13) presence + positive part match the shared-eta hurdle", {
  set.seed(9)
  n <- 20000L
  eta_val <- 0.4
  phi_gd <- 0.5
  fit <- .mk_fake_fit(n, family_id = 13L, report = list(phi_gamma_delta = phi_gd))
  eta <- rep(eta_val, n)
  y <- gllvmTMB:::.draw_y_per_family(fit, eta)
  expect_equal(mean(y > 0), stats::plogis(eta_val), tolerance = 0.02)
  pos <- y[y > 0]
  shape_g <- 1 / phi_gd^2
  scale_g <- exp(eta_val) * phi_gd^2
  ks <- suppressWarnings(stats::ks.test(pos, "pgamma", shape = shape_g, scale = scale_g))
  expect_gt(ks$p.value, 0.01)
})

# ---- (c) unsupported families: NA, never a Gaussian link-scale number ----

test_that("unsupported family (tweedie, fid 6) draws NA_real_ with a warning, not a Gaussian number", {
  fit <- .mk_fake_fit(10L, family_id = 6L)
  eta <- rep(0, 10L)
  expect_warning(
    y <- gllvmTMB:::.draw_y_per_family(fit, eta),
    class = "gllvmTMB_simulate_unsupported_family"
  )
  expect_true(all(is.na(y)))
})

test_that("an unrecognised family_id also draws NA_real_ with a warning", {
  fit <- .mk_fake_fit(10L, family_id = 999L)
  eta <- rep(0, 10L)
  expect_warning(
    y <- gllvmTMB:::.draw_y_per_family(fit, eta),
    class = "gllvmTMB_simulate_unsupported_family"
  )
  expect_true(all(is.na(y)))
})

# ---- (d) the warning fires per fit, not once per session -----------------

test_that("the unsupported-family warning fires on every call, not just the first (#1079)", {
  fit <- .mk_fake_fit(5L, family_id = 6L)
  eta <- rep(0, 5L)
  expect_warning(
    gllvmTMB:::.draw_y_per_family(fit, eta),
    class = "gllvmTMB_simulate_unsupported_family"
  )
  ## A second call (a second simulate() on a second fit, or a repeat draw on
  ## the same fit) must warn again -- the pre-fix `options()` cache would
  ## have silenced this second call.
  expect_warning(
    gllvmTMB:::.draw_y_per_family(fit, eta),
    class = "gllvmTMB_simulate_unsupported_family"
  )
})
