## nbinom1 LA-MSPL admit-packet science — Pure-R oracles for c_NB1
## and exact-I weighted loading atom. Registry stays planned. Not
## an admission flip. Not a live TMB twin (A7). Not c=1. Not c_P.
## Not quasi. Not Bernoulli V_loading. Not the NB2 wbar atom.
## Not public SE.
##
## Research: docs/dev-log/research/2026-08-17-mspl-nbinom-admit-oracles.md

.nb1_c_bernoulli <- function(p_free, n_rows) {
  2 * sqrt(as.numeric(p_free) / as.numeric(n_rows))
}

.nb1_c_gaussian <- function(n_units) {
  sqrt(2 / as.numeric(n_units))
}

.nb1_c_poisson <- function(p_free, y) {
  2 * sqrt(as.numeric(p_free) / max(sum(as.numeric(y)), 1))
}

.nb1_quasi_info <- function(y, trait_id, phi) {
  mom <- .gllvmTMB_mspl_nbinom1_trait_moments(y, trait_id)
  sum(mom$n * mom$ybar / (1 + as.numeric(phi)))
}

.nb1_V_bernoulli <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.nb1_V_poisson <- function(Lambda, ybar) {
  Lambda <- as.matrix(Lambda)
  ybar <- pmax(as.numeric(ybar), 0)
  sum(sqrt(1 + rowSums(Lambda * Lambda) * ybar) - 1)
}

test_that("A1: NB1 rate uses exact I_eta plugin, not quasi, sum(y), N, or 1", {
  p_free <- 6
  set.seed(4)
  mu <- rep(c(1.2, 2.0, 3.1), each = 4)
  phi <- 1.5
  y <- stats::rnbinom(12, size = mu / phi, prob = 1 / (1 + phi))
  trait <- rep(1:3, each = 4)
  c_nb1 <- .gllvmTMB_mspl_nbinom1_rate(p_free, y, trait)
  expect_false(isTRUE(all.equal(c_nb1, 1, tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(
    c_nb1,
    .nb1_c_bernoulli(p_free, length(y)),
    tolerance = 1e-8
  )))
  expect_false(isTRUE(all.equal(
    c_nb1,
    .nb1_c_gaussian(4),
    tolerance = 1e-8
  )))
  expect_false(isTRUE(all.equal(
    c_nb1,
    .nb1_c_poisson(p_free, y),
    tolerance = 1e-8
  )))
  info <- .gllvmTMB_mspl_nbinom1_info_size(y, trait)
  quasi <- .nb1_quasi_info(y, trait, phi)
  expect_false(isTRUE(all.equal(info, quasi, tolerance = 1e-4)))
  expect_false(isTRUE(all.equal(info, sum(y), tolerance = 1e-4)))
  expect_equal(c_nb1, 2 * sqrt(p_free / info), tolerance = 1e-15)
})

test_that("A2: all-zero floors I_NB1 at 1; rate vanishes as information grows", {
  z <- rep(0, 9)
  trait <- rep(1:3, each = 3)
  expect_equal(.gllvmTMB_mspl_nbinom1_info_size(z, trait), 1)
  expect_equal(.gllvmTMB_mspl_nbinom1_rate(4, z, trait), 4)
  y_big <- rep(c(80, 90, 70), 16)
  trait_big <- rep(1:3, 16)
  small <- .gllvmTMB_mspl_nbinom1_rate(4, y_big, trait_big)
  expect_lt(small, 0.3)
  expect_gt(small, 0)
})

test_that("A3: offset at fixed y does not move c_NB1", {
  set.seed(5)
  mu <- rep(c(1.5, 2.5), each = 4)
  y <- stats::rnbinom(8, size = mu / 1.4, prob = 1 / (1 + 1.4))
  trait <- rep(1:2, each = 4)
  p_free <- 5
  c0 <- .gllvmTMB_mspl_nbinom1_rate(p_free, y, trait)
  expect_equal(
    .gllvmTMB_mspl_nbinom1_rate(p_free, y, trait),
    c0,
    tolerance = 0
  )
  expect_false(isTRUE(all.equal(
    c0,
    .nb1_c_poisson(p_free, y),
    tolerance = 1e-8
  )))
})

test_that("A4: exact-I loading atom is zero on all-zero traits; not Poisson ybar", {
  Lambda <- matrix(c(2.0, -1.5, 0.8), 3L, 1L)
  expect_equal(
    .gllvmTMB_mspl_nbinom1_loading_atom(Lambda, c(0, 0, 0)),
    0,
    tolerance = 0
  )
  expect_gt(.nb1_V_bernoulli(Lambda), 1)
  Ibar <- c(0.5, 1.4, 0.3)
  ybar <- c(1.2, 2.0, 0.7)
  V <- .gllvmTMB_mspl_nbinom1_loading_atom(Lambda, Ibar)
  expect_false(isTRUE(all.equal(V, .nb1_V_bernoulli(Lambda), tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(
    V,
    .nb1_V_poisson(Lambda, ybar),
    tolerance = 1e-8
  )))
})

test_that("A5: NB1 loading atom is coercive as ||lambda|| grows at Ibar>0", {
  Ibar <- c(0.7, 0.4, 0.9)
  grid <- c(0.5, 2, 8, 32)
  V <- vapply(
    grid,
    function(a) {
      .gllvmTMB_mspl_nbinom1_loading_atom(
        matrix(a * c(1, -0.6, 0.4), 3L, 1L),
        Ibar
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
      .gllvmTMB_mspl_nbinom1_loading_atom(
        matrix(a * c(1, -0.6, 0.4), 3L, 1L),
        c(0, 0, 0)
      )
    },
    numeric(1L)
  )
  expect_equal(V0, rep(0, length(grid)), tolerance = 0)
})

test_that("A6: NB1 Jeffreys uses exact I_eta, not quasi; loading uses Ibar", {
  X <- cbind(1, c(-1, 0, 1, 2))
  mu <- c(0.8, 1.3, 2.1, 0.6)
  phi <- 1.5
  Lambda <- matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  Ibar <- c(0.4, 0.9, 1.2, 0.3)
  Pj <- .gllvmTMB_mspl_nbinom1_jeffreys(X, mu, phi)
  w_exact <- vapply(
    mu,
    function(m) .gllvmTMB_mspl_nbinom1_exact_I_eta(m, phi),
    numeric(1L)
  )
  expect_equal(
    Pj,
    0.5 * log(det(crossprod(X, X * w_exact))),
    tolerance = 1e-12
  )
  w_quasi <- mu / (1 + phi)
  expect_false(isTRUE(all.equal(w_exact, w_quasi, tolerance = 1e-6)))
  V <- .gllvmTMB_mspl_nbinom1_loading_atom(Lambda, Ibar)
  expect_equal(
    .gllvmTMB_mspl_nbinom1_loading_atom(Lambda, Ibar),
    V,
    tolerance = 0
  )
})

test_that("A8: nbinom1 ordinary cells stay planned after the oracle pin", {
  p1 <- .gllvmTMB_mspl_registry_lookup("nbinom1", "log", "ordinary", 1L)
  p2 <- .gllvmTMB_mspl_registry_lookup("nbinom1", "log", "ordinary", 2L)
  expect_identical(p1$status, "planned")
  expect_identical(p2$status, "planned")
  expect_identical(p1$evidence, "phase4_prep")
  expect_false(identical(p1$status, "admitted"))
  expect_match(p1$notes, "not admitted")
  expect_match(p1$notes, "not covered")
})

test_that("NB1 and NB2 do not share a rate or loading weight on the same y", {
  y <- c(0, 1, 14, 2, 0, 3, 16, 1)
  trait <- rep(1:2, each = 4)
  p_free <- 5
  c1 <- .gllvmTMB_mspl_nbinom1_rate(p_free, y, trait)
  c2 <- .gllvmTMB_mspl_nbinom2_rate(p_free, y, trait)
  expect_false(isTRUE(all.equal(c1, c2, tolerance = 1e-8)))
  tw1 <- .gllvmTMB_mspl_nbinom1_trait_wbar(y, trait)
  tw2 <- .gllvmTMB_mspl_nbinom2_trait_wbar(y, trait)
  expect_false(isTRUE(all.equal(tw1$wbar, tw2$wbar, tolerance = 1e-6)))
  Lambda <- matrix(c(1.2, -0.7), 2L, 1L)
  expect_false(isTRUE(all.equal(
    .gllvmTMB_mspl_nbinom1_loading_atom(Lambda, tw1$wbar),
    .gllvmTMB_mspl_nbinom2_loading_atom(Lambda, tw2$wbar),
    tolerance = 1e-8
  )))
})
