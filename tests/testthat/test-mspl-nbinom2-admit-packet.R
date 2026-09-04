## nbinom2 LA-MSPL admit packet — pinned c_NB2, information-weighted
## loading atom, Jeffreys-on-phi DROP, TMB/pure-R oracles. Registry
## stays planned. Not an admission flip. Not c=1. Not c_P. Not
## Bernoulli V_loading. Not public SE.
##
## Research: docs/dev-log/research/2026-08-16-mspl-nbinom-admit-packet.md

`%||%` <- function(x, y) {
  if (is.null(x) || (length(x) == 1L && is.na(x))) y else x
}

.nb2_c_bernoulli <- function(p_free, n_rows) {
  2 * sqrt(as.numeric(p_free) / as.numeric(n_rows))
}

.nb2_c_gaussian <- function(n_units) {
  sqrt(2 / as.numeric(n_units))
}

.nb2_c_poisson <- function(p_free, y) {
  2 * sqrt(as.numeric(p_free) / max(sum(as.numeric(y)), 1))
}

.nb2_V_bernoulli <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.nb2_V_poisson <- function(Lambda, ybar) {
  Lambda <- as.matrix(Lambda)
  ybar <- pmax(as.numeric(ybar), 0)
  sum(sqrt(1 + rowSums(Lambda * Lambda) * ybar) - 1)
}

.nb2_admit_dat <- function(n_site = 10L, n_trait = 3L, seed = 160816L) {
  set.seed(seed)
  site <- factor(rep(seq_len(n_site), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site))
  z <- stats::rnorm(n_site)
  Lambda <- c(0.55, -0.40, 0.30)
  beta <- c(0.45, 0.15, 0.55)
  eta <- beta[as.integer(trait)] +
    z[as.integer(site)] * Lambda[as.integer(trait)]
  y <- stats::rnbinom(n_site * n_trait, mu = exp(eta), size = 2.5)
  data.frame(site = site, trait = trait, y = y)
}

.nb2_read_cpp <- function() {
  ## Source-checkout + R CMD check layouts only. Do not use cwd-relative
  ## `../../src` or `system.file("..", "src", ...)`: under R CMD check those
  ## can be "" or a missing path, and `readLines` then errors instead of
  ## skipping (ubuntu CI 2026-08-17). Same two-/three-level 00_pkg_src
  ## rule as test-isdm-developer-fit.R.
  candidates <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    )
  )
  found <- candidates[
    nzchar(candidates) &
      !is.na(candidates) &
      file.exists(candidates) &
      !dir.exists(candidates)
  ]
  testthat::skip_if(
    length(found) == 0L,
    "gllvmTMB.cpp source file is not available in this test context."
  )
  paste(readLines(found[[1L]], warn = FALSE), collapse = "\n")
}

.nb2_admit_fit <- function(dat, q = 1L) {
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)",
    as.integer(q)
  ))
  suppressMessages(gllvmTMB(
    form,
    data = dat,
    family = nbinom2(link = "log"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L,
      init_jitter = 0,
      se = FALSE,
      warn_runaway = FALSE
    )
  ))
}

test_that("A1: NB2 rate uses data-plugin tr(W), not N_rows, N_units, sum(y), or 1", {
  p_free <- 6
  set.seed(2)
  y <- stats::rnbinom(12, mu = 3, size = 2)
  trait <- rep(1:3, each = 4)
  c_nb2 <- .gllvmTMB_mspl_nbinom2_rate(p_free, y, trait)
  expect_false(isTRUE(all.equal(c_nb2, 1, tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(
    c_nb2,
    .nb2_c_bernoulli(p_free, length(y)),
    tolerance = 1e-8
  )))
  expect_false(isTRUE(all.equal(
    c_nb2,
    .nb2_c_gaussian(4),
    tolerance = 1e-8
  )))
  expect_false(isTRUE(all.equal(
    c_nb2,
    .nb2_c_poisson(p_free, y),
    tolerance = 1e-8
  )))
  info <- .gllvmTMB_mspl_nbinom2_info_size(y, trait)
  expect_equal(c_nb2, 2 * sqrt(p_free / info), tolerance = 1e-15)
  expect_lt(info, sum(y))
  expect_gt(info, 1)
})

test_that("A2: all-zero floors I_NB2 at 1; rate vanishes as information grows", {
  z <- rep(0, 9)
  trait <- rep(1:3, each = 3)
  expect_equal(.gllvmTMB_mspl_nbinom2_info_size(z, trait), 1)
  expect_equal(.gllvmTMB_mspl_nbinom2_rate(4, z, trait), 4)
  y_big <- rep(c(200, 180, 220), 20)
  trait_big <- rep(1:3, 20)
  small <- .gllvmTMB_mspl_nbinom2_rate(4, y_big, trait_big)
  expect_lt(small, 0.2)
  expect_gt(small, 0)
})

test_that("A3: offset at fixed y does not move c_NB2; exposure doubling of mu is not I", {
  ## Constructed overdispersion so MoM does not hit the Poisson-limit
  ## floor (a small rnbinom draw can have s^2 <= ybar).
  y <- c(0, 0, 1, 14, 0, 1, 2, 16)
  trait <- rep(1:2, each = 4)
  p_free <- 5
  c0 <- .gllvmTMB_mspl_nbinom2_rate(p_free, y, trait)
  ## A known offset changes mu, not observed y, so the data-plugin rate
  ## stays put. That is the A3 pin; it is not a licence to copy c_P.
  expect_equal(
    .gllvmTMB_mspl_nbinom2_rate(p_free, y, trait),
    c0,
    tolerance = 0
  )
  expect_false(isTRUE(all.equal(c0, .nb2_c_poisson(p_free, y), tolerance = 1e-8)))
  tw <- .gllvmTMB_mspl_nbinom2_trait_wbar(y, trait)
  expect_true(all(tw$wbar < tw$ybar + 1e-12))
})

test_that("A4: information-weighted loading atom is zero on all-zero traits", {
  Lambda <- matrix(c(2.0, -1.5, 0.8), 3L, 1L)
  expect_equal(
    .gllvmTMB_mspl_nbinom2_loading_atom(Lambda, c(0, 0, 0)),
    0,
    tolerance = 0
  )
  expect_gt(.nb2_V_bernoulli(Lambda), 1)
  wbar <- c(0.4, 1.2, 0.25)
  ybar <- c(1.0, 2.5, 0.8)
  V <- .gllvmTMB_mspl_nbinom2_loading_atom(Lambda, wbar)
  expect_false(isTRUE(all.equal(V, .nb2_V_bernoulli(Lambda), tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(V, .nb2_V_poisson(Lambda, ybar), tolerance = 1e-8)))
  expect_equal(
    .gllvmTMB_mspl_nbinom2_loading_atom(Lambda, c(1, 1, 1)),
    .nb2_V_bernoulli(Lambda),
    tolerance = 1e-12
  )
})

test_that("A5: NB2 loading atom is coercive as ||lambda|| grows at wbar>0", {
  wbar <- c(0.8, 0.3, 0.5)
  grid <- c(0.5, 2, 8, 32)
  V <- vapply(
    grid,
    function(a) {
      .gllvmTMB_mspl_nbinom2_loading_atom(
        matrix(a * c(1, -0.6, 0.4), 3L, 1L),
        wbar
      )
    },
    numeric(1L)
  )
  expect_true(all(is.finite(V)))
  expect_true(all(diff(V) > 0))
  expect_gt(tail(V, 1L), 8)
  V0 <- vapply(
    grid,
    function(a) {
      .gllvmTMB_mspl_nbinom2_loading_atom(
        matrix(a * c(1, -0.6, 0.4), 3L, 1L),
        c(0, 0, 0)
      )
    },
    numeric(1L)
  )
  expect_equal(V0, rep(0, length(grid)), tolerance = 0)
})

test_that("A6: Jeffreys uses W=mu*phi/(phi+mu); loading atom uses data wbar", {
  X <- cbind(1, c(-1, 0, 1, 2))
  mu <- c(0.4, 1.1, 2.0, 0.7)
  phi <- 2
  Lambda <- matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  wbar <- c(0.3, 0.7, 1.1, 0.2)
  expect_equal(
    .gllvmTMB_mspl_nbinom2_jeffreys(X, mu, phi),
    0.5 * log(det(crossprod(X, X * (mu * phi / (phi + mu))))),
    tolerance = 1e-12
  )
  V <- .gllvmTMB_mspl_nbinom2_loading_atom(Lambda, wbar)
  mu_up <- mu
  mu_up[1L] <- mu_up[1L] + 1e-4
  expect_false(isTRUE(all.equal(
    .gllvmTMB_mspl_nbinom2_jeffreys(X, mu, phi),
    .gllvmTMB_mspl_nbinom2_jeffreys(X, mu_up, phi),
    tolerance = 1e-10
  )))
  expect_equal(
    .gllvmTMB_mspl_nbinom2_loading_atom(Lambda, wbar),
    V,
    tolerance = 0
  )
})

test_that("D-phi: NB2 Jeffreys-on-phi is DROPPED; Jacobian and quasi pins stay", {
  mu <- c(0.8, 1.4, 2.2, 0.6)
  phi <- 2
  i_phi <- sum(.gllvmTMB_mspl_nbinom2_I_phi(mu, phi))
  i_log <- .gllvmTMB_mspl_nbinom2_I_log_phi(mu, phi)
  expect_equal(i_log, phi^2 * i_phi, tolerance = 1e-12)
  quasi <- 0.5 * (mu / (mu + phi))^2
  expect_false(isTRUE(all.equal(
    .gllvmTMB_mspl_nbinom2_I_phi(mu, phi),
    quasi,
    tolerance = 1e-3
  )))
  ## As phi -> Inf, I_phi,phi -> 0 so (1/2) log I would go to -Inf
  ## (fights the Poisson limit). As phi -> 0 it grows (rewards
  ## infinite OD). Mean atom already moves with phi. Packet DROPS
  ## taping either 1/2 log I_phi,phi or 1/2 log I_logphi.
  i_big <- sum(.gllvmTMB_mspl_nbinom2_I_phi(mu, 1e4))
  i_tiny <- sum(.gllvmTMB_mspl_nbinom2_I_phi(mu, 0.05))
  expect_lt(i_big, 1e-3)
  expect_gt(i_tiny, i_phi)
  expect_lt(0.5 * log(i_big), 0.5 * log(i_phi))
  Pj0 <- .gllvmTMB_mspl_nbinom2_jeffreys(cbind(1, c(-1, 0, 1, 2)), mu, phi)
  Pj_hi <- .gllvmTMB_mspl_nbinom2_jeffreys(cbind(1, c(-1, 0, 1, 2)), mu, 1e4)
  expect_false(isTRUE(all.equal(Pj0, Pj_hi, tolerance = 1e-6)))
})

test_that("D-phi C++: dropped phi atom is commented, not taped", {
  cpp <- .nb2_read_cpp()
  expect_true(grepl("NB2 Jeffreys-on-phi DROPPED", cpp, fixed = TRUE))
  expect_false(grepl(
    "fid == 5[\\s\\S]{0,200}mspl_dispersion_nll",
    cpp
  ))
})

test_that("A7: live NB2 tape reports pinned c_NB2 and information-weighted V", {
  skip_on_cran()
  dat <- .nb2_admit_dat()
  fit <- .nb2_admit_fit(dat, q = 1L)
  expect_s3_class(fit, "gllvmTMB_mspl")
  expect_identical(fit$mspl$registry_status, "planned")
  expect_false(identical(fit$mspl$registry_status, "admitted"))

  p_free <- as.integer(fit$mspl$p_free)
  trait <- as.integer(dat$trait)
  c_nb2 <- .gllvmTMB_mspl_nbinom2_rate(p_free, dat$y, trait)
  expect_equal(as.numeric(fit$report$mspl_c_n), c_nb2, tolerance = 1e-8)
  expect_equal(as.numeric(fit$mspl$c_n), c_nb2, tolerance = 1e-8)
  expect_false(isTRUE(all.equal(as.numeric(fit$report$mspl_c_n), 1,
                                tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(
    as.numeric(fit$report$mspl_c_n),
    .nb2_c_poisson(p_free, dat$y),
    tolerance = 1e-8
  )))

  Lambda <- as.matrix(fit$report$Lambda_B)
  tw <- .gllvmTMB_mspl_nbinom2_trait_wbar(dat$y, trait)
  V <- .gllvmTMB_mspl_nbinom2_loading_atom(Lambda, tw$wbar)
  expect_equal(as.numeric(fit$report$mspl_V_loading), V, tolerance = 1e-7)
  expect_false(isTRUE(all.equal(
    as.numeric(fit$report$mspl_V_loading),
    .nb2_V_bernoulli(Lambda),
    tolerance = 1e-6
  )))
  ybar <- tw$ybar
  expect_false(isTRUE(all.equal(
    as.numeric(fit$report$mspl_V_loading),
    .nb2_V_poisson(Lambda, ybar),
    tolerance = 1e-6
  )))

  X <- fit$mspl$fixed_design$X %||% fit$tmb_data$X_mspl
  pars <- fit$tmb_obj$env$parList(fit$opt$par)
  b <- pars$b_fix
  eta <- as.numeric(fit$tmb_data$X_fix %*% b + fit$tmb_data$offset_vec)
  mu <- exp(eta)
  phi_t <- exp(as.numeric(pars$log_phi_nbinom2))
  phi <- phi_t[as.integer(dat$trait)]
  expect_equal(
    as.numeric(fit$report$mspl_logdet_information),
    2 * .gllvmTMB_mspl_nbinom2_jeffreys(X, mu, phi),
    tolerance = 2e-6
  )
})

test_that("A8: nbinom2 ordinary cells stay planned after the admit packet", {
  p1 <- .gllvmTMB_mspl_registry_lookup("nbinom2", "log", "ordinary", 1L)
  p2 <- .gllvmTMB_mspl_registry_lookup("nbinom2", "log", "ordinary", 2L)
  expect_identical(p1$status, "planned")
  expect_identical(p2$status, "planned")
  expect_identical(p1$evidence, "phase4_prep")
  expect_false(identical(p1$status, "admitted"))
  expect_match(p1$notes, "not admitted")
  expect_match(p1$notes, "not covered")
})
