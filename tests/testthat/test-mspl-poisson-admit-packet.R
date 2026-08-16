## Poisson LA-MSPL admit packet — pinned c_P, event-weighted loading
## atom, TMB/pure-R oracles. Registry is admitted / admit_packet after
## G0 2026-08-16 (experimental point). #990 was operational PASS /
## admit-evidence FAIL. Not Bernoulli V_loading. Not Gaussian Hirose.
## Not public SE. Not NEWS covered.
##
## Research: docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md
## Constitution Phase 4: information atom + coercivity; exposure ≠
## information size; finite count fits alone do not pass.

.poisson_event_count <- function(y) {
  max(sum(as.numeric(y)), 1)
}

.poisson_cP <- function(p_free, event_count) {
  2 * sqrt(as.numeric(p_free) / as.numeric(event_count))
}

.poisson_c_bernoulli <- function(p_free, n_rows) {
  2 * sqrt(as.numeric(p_free) / as.numeric(n_rows))
}

.poisson_c_gaussian <- function(n_units) {
  sqrt(2 / as.numeric(n_units))
}

.poisson_Pj <- function(X, mu) {
  I <- crossprod(as.matrix(X), as.matrix(X) * as.numeric(mu))
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.poisson_V_bernoulli <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.poisson_V_event <- function(Lambda, ybar) {
  Lambda <- as.matrix(Lambda)
  ybar <- as.numeric(ybar)
  stopifnot(length(ybar) == nrow(Lambda))
  sum(sqrt(1 + rowSums(Lambda * Lambda) * ybar) - 1)
}

.poisson_ybar <- function(y, trait) {
  tapply(as.numeric(y), as.integer(trait), mean)
}

.poisson_admit_dat <- function(n_site = 8L, n_trait = 3L, seed = 160915L) {
  set.seed(seed)
  site <- factor(rep(seq_len(n_site), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site))
  z <- stats::rnorm(n_site)
  Lambda <- c(0.55, -0.40, 0.30)
  beta <- c(0.35, 0.10, 0.50)
  eta <- beta[as.integer(trait)] +
    z[as.integer(site)] * Lambda[as.integer(trait)]
  y <- stats::rpois(n_site * n_trait, lambda = exp(eta))
  data.frame(site = site, trait = trait, y = y)
}

.poisson_admit_fit <- function(dat, q = 1L) {
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)",
    as.integer(q)
  ))
  suppressMessages(gllvmTMB(
    form,
    data = dat,
    family = stats::poisson(link = "log"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L,
      init_jitter = 0,
      se = FALSE,
      warn_runaway = FALSE
    )
  ))
}

test_that("A1: Poisson rate c_P uses event count, not N_rows or N_units", {
  p_free <- 6
  y <- c(0, 1, 2, 0, 3, 1)
  n_rows <- length(y)
  n_units <- 3
  event <- .poisson_event_count(y)
  expect_equal(event, 7)
  cP <- .gllvmTMB_mspl_poisson_rate(p_free, event)
  expect_equal(cP, .poisson_cP(p_free, event), tolerance = 1e-15)
  expect_equal(cP, 2 * sqrt(6 / 7), tolerance = 1e-15)
  expect_false(isTRUE(all.equal(cP, 1, tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(
    cP,
    .poisson_c_bernoulli(p_free, n_rows),
    tolerance = 1e-8
  )))
  expect_false(isTRUE(all.equal(
    cP,
    .poisson_c_gaussian(n_units),
    tolerance = 1e-8
  )))
})

test_that("A2: all-zero event count floors at 1; c_P vanishes as events grow", {
  expect_equal(.gllvmTMB_mspl_poisson_event_count(c(0, 0, 0)), 1)
  expect_equal(.gllvmTMB_mspl_poisson_rate(4, 1), 4)
  big <- .gllvmTMB_mspl_poisson_rate(4, 1e6)
  expect_lt(big, 0.01)
  expect_gt(big, 0)
  expect_lt(
    .gllvmTMB_mspl_poisson_rate(4, 400),
    .gllvmTMB_mspl_poisson_rate(4, 100)
  )
})

test_that("A3: exposure at fixed y does not change c_P; N_rows is not I", {
  y <- c(3, 0, 2, 1, 4)
  p_free <- 5
  c0 <- .gllvmTMB_mspl_poisson_rate(
    p_free,
    .gllvmTMB_mspl_poisson_event_count(y)
  )
  ## Doubling a known exposure does not change observed counts, so c_P
  ## stays put. Event count (10) is not the row count (5).
  expect_equal(
    .gllvmTMB_mspl_poisson_rate(p_free, .gllvmTMB_mspl_poisson_event_count(y)),
    c0,
    tolerance = 0
  )
  expect_equal(.gllvmTMB_mspl_poisson_event_count(y), 10)
  expect_false(identical(length(y), 10L))
  expect_false(isTRUE(all.equal(
    c0,
    .poisson_c_bernoulli(p_free, length(y)),
    tolerance = 1e-8
  )))
})

test_that("A4: event-weighted loading atom is zero on all-zero traits", {
  Lambda <- matrix(c(2.0, -1.5, 0.8), 3L, 1L)
  expect_equal(
    .gllvmTMB_mspl_poisson_loading_atom(Lambda, c(0, 0, 0)),
    0,
    tolerance = 0
  )
  expect_gt(.poisson_V_bernoulli(Lambda), 1)
  ## ybar = 1 recovers the Bernoulli radial; a non-unit ybar must not.
  expect_equal(
    .gllvmTMB_mspl_poisson_loading_atom(Lambda, c(1, 1, 1)),
    .poisson_V_bernoulli(Lambda),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    .gllvmTMB_mspl_poisson_loading_atom(Lambda, c(0.4, 2.0, 0.25)),
    .poisson_V_bernoulli(Lambda),
    tolerance = 1e-8
  )))
})

test_that("A5: Poisson loading atom is coercive as ||lambda|| grows at ybar>0", {
  ybar <- c(1.2, 0.4, 0.8)
  grid <- c(0.5, 2, 8, 32)
  V <- vapply(
    grid,
    function(a) {
      .gllvmTMB_mspl_poisson_loading_atom(
        matrix(a * c(1, -0.6, 0.4), 3L, 1L),
        ybar
      )
    },
    numeric(1L)
  )
  expect_true(all(is.finite(V)))
  expect_true(all(diff(V) > 0))
  expect_gt(tail(V, 1L), 10)
  ## Bernoulli radial grows with ||lambda|| even when ybar is 0; Poisson
  ## event-weighted atom must not.
  V0 <- vapply(
    grid,
    function(a) {
      .gllvmTMB_mspl_poisson_loading_atom(
        matrix(a * c(1, -0.6, 0.4), 3L, 1L),
        c(0, 0, 0)
      )
    },
    numeric(1L)
  )
  expect_equal(V0, rep(0, length(grid)), tolerance = 0)
})

test_that("A6: Jeffreys atom still uses W=diag(mu); loading atom uses ybar", {
  X <- cbind(1, c(-1, 0, 1, 2))
  mu <- c(0.4, 1.1, 2.0, 0.7)
  Lambda <- matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  ybar <- c(0.5, 1.0, 1.5, 0.2)
  expect_equal(
    .gllvmTMB_mspl_poisson_jeffreys(X, mu),
    .poisson_Pj(X, mu),
    tolerance = 1e-12
  )
  V <- .gllvmTMB_mspl_poisson_loading_atom(Lambda, ybar)
  expect_equal(V, .poisson_V_event(Lambda, ybar), tolerance = 1e-15)
  mu_up <- mu
  mu_up[1L] <- mu_up[1L] + 1e-4
  expect_false(isTRUE(all.equal(
    .gllvmTMB_mspl_poisson_jeffreys(X, mu),
    .gllvmTMB_mspl_poisson_jeffreys(X, mu_up),
    tolerance = 1e-10
  )))
  expect_equal(
    .gllvmTMB_mspl_poisson_loading_atom(Lambda, ybar),
    V,
    tolerance = 0
  )
})

test_that("A7: live Poisson tape reports pinned c_P and event-weighted V", {
  skip_on_cran()
  dat <- .poisson_admit_dat()
  fit <- .poisson_admit_fit(dat, q = 1L)
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$registry_status, "admitted")
  expect_identical(fit$mspl$registry_evidence, "admit_packet")
  expect_false(identical(fit$mspl$registry_evidence, "covered"))

  p_free <- as.integer(fit$mspl$p_free)
  event <- .gllvmTMB_mspl_poisson_event_count(dat$y)
  cP <- .gllvmTMB_mspl_poisson_rate(p_free, event)
  expect_equal(as.numeric(fit$report$mspl_c_n), cP, tolerance = 1e-10)
  expect_equal(as.numeric(fit$mspl$c_n), cP, tolerance = 1e-10)
  expect_false(isTRUE(all.equal(
    as.numeric(fit$report$mspl_c_n),
    1,
    tolerance = 1e-8
  )))

  Lambda <- as.matrix(fit$report$Lambda_B)
  ybar <- as.numeric(.poisson_ybar(dat$y, dat$trait))
  V <- .gllvmTMB_mspl_poisson_loading_atom(Lambda, ybar)
  expect_equal(as.numeric(fit$report$mspl_V_loading), V, tolerance = 1e-8)
  expect_false(isTRUE(all.equal(
    as.numeric(fit$report$mspl_V_loading),
    .poisson_V_bernoulli(Lambda),
    tolerance = 1e-6
  )))

  X <- fit$mspl$fixed_design$X %||% fit$tmb_data$X_mspl
  b <- fit$tmb_obj$env$parList(fit$opt$par)$b_fix
  eta <- as.numeric(fit$tmb_data$X_fix %*% b + fit$tmb_data$offset_vec)
  mu <- exp(eta)
  expect_equal(
    as.numeric(fit$report$mspl_logdet_information),
    2 * .gllvmTMB_mspl_poisson_jeffreys(X, mu),
    tolerance = 2e-8
  )
})

test_that("A8: Poisson ordinary cells are experimental-point admitted after G0", {
  p1 <- .gllvmTMB_mspl_registry_lookup("poisson", "log", "ordinary", 1L)
  p2 <- .gllvmTMB_mspl_registry_lookup("poisson", "log", "ordinary", 2L)
  expect_identical(p1$status, "admitted")
  expect_identical(p2$status, "admitted")
  expect_identical(p1$evidence, "admit_packet")
  expect_identical(p2$evidence, "admit_packet")
  expect_false(identical(p1$evidence, "covered"))
  expect_match(p1$notes, "admit-evidence FAIL")
  expect_match(p1$notes, "not a covered campaign")
  expect_match(p1$notes, "no public SE")
})
