test_that("nbinom2 trait moments mirror nbinom1 grouping", {
  y <- c(0, 1, 2, 5, 6)
  tid <- c(1L, 1L, 1L, 2L, 2L)
  mom <- .gllvmTMB_mspl_nbinom2_trait_moments(y, tid)
  expect_equal(nrow(mom), 2L)
  expect_equal(sum(mom$n), length(y))
  expect_error(
    .gllvmTMB_mspl_nbinom2_trait_moments(1:3, 1:4),
    "equal length"
  )
})

test_that("nbinom2 phi_hat is MoM dispersion", {
  lim <- .gllvmTMB_mspl_nbinom2_phi_poisson_limit
  expect_equal(.gllvmTMB_mspl_nbinom2_phi_hat(2, 2), lim)
  ph <- .gllvmTMB_mspl_nbinom2_phi_hat(3, 30)
  expect_true(ph > 0 && ph < lim)
  expect_equal(.gllvmTMB_mspl_nbinom2_phi_hat(2, 2), lim)
})

test_that("nbinom2 wbar and trait_wbar are non-negative", {
  y <- rep(3:6, each = 2)
  tid <- rep(1:2, each = 4)
  tw <- .gllvmTMB_mspl_nbinom2_trait_wbar(y, tid)
  expect_true(all(tw$wbar >= 0))
  wb <- .gllvmTMB_mspl_nbinom2_wbar(tw$ybar, tw$phi_hat)
  expect_equal(length(wb), nrow(tw))
  info <- .gllvmTMB_mspl_nbinom2_info_size(y, tid)
  expect_true(info >= 1)
})

test_that("nbinom2 rate and loading atom", {
  y <- rep(2, 6)
  tid <- rep(1L, 6)
  r <- .gllvmTMB_mspl_nbinom2_rate(2, y, tid)
  expect_true(is.finite(r) && r > 0)
  Lam <- diag(c(0.2, 0.1))
  atom <- .gllvmTMB_mspl_nbinom2_loading_atom(Lam, c(1, 1))
  expect_true(atom >= 0)
})

test_that("nbinom2 I_phi helpers are finite on-grid", {
  Ip <- .gllvmTMB_mspl_nbinom2_I_phi_one(2, 1.5, y_max = 20L)
  expect_true(Ip >= 0 && is.finite(Ip))
  Ivec <- .gllvmTMB_mspl_nbinom2_I_phi(2, 1.5)
  expect_true(Ivec >= 0 && is.finite(Ivec))
  Ilog <- .gllvmTMB_mspl_nbinom2_I_log_phi(2, 1.5)
  expect_true(is.finite(Ilog))
})

test_that("nbinom2 jeffreys from design", {
  X <- cbind(1, c(0, 1, 1, 0))
  j <- .gllvmTMB_mspl_nbinom2_jeffreys(X, c(1, 2, 3, 4), 2)
  expect_true(is.finite(j))
})

test_that("nbinom2 loading atom increases with ||Lambda||", {
  Lam0 <- matrix(0, 2, 2)
  Lam1 <- diag(c(0.5, 0.1))
  a0 <- .gllvmTMB_mspl_nbinom2_loading_atom(Lam0, c(1, 1))
  a1 <- .gllvmTMB_mspl_nbinom2_loading_atom(Lam1, c(1, 1))
  expect_equal(a0, 0)
  expect_gt(a1, 0)
  expect_error(.gllvmTMB_mspl_nbinom2_rate(0, 1:3, rep(1L, 3)), "positive p_free")
})