test_that("Poisson MSPL rate increases with p_free", {
  e <- 20
  r1 <- gllvmTMB:::.gllvmTMB_mspl_poisson_rate(4, e)
  r2 <- gllvmTMB:::.gllvmTMB_mspl_poisson_rate(16, e)
  expect_gt(r2, r1)
})

test_that("Poisson loading atom is non-negative", {
  Lam <- matrix(c(0.5, -0.2, 0.1, 0.3), nrow = 2)
  val <- gllvmTMB:::.gllvmTMB_mspl_poisson_loading_atom(Lam, c(1, 2))
  expect_gte(val, 0)
})

test_that("zero loadings give zero loading atom contribution", {
  Lam <- matrix(0, 3, 2)
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_poisson_loading_atom(Lam, c(1, 2, 3)),
    0
  )
})

test_that("Poisson rate uses floor event count of 1", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_poisson_rate(2, 0),
    gllvmTMB:::.gllvmTMB_mspl_poisson_rate(2, 1)
  )
})

test_that("Poisson rate matches closed form", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_mspl_poisson_rate(9, 100),
    2 * sqrt(9 / 100)
  )
})

test_that("loading atom increases with larger ybar", {
  Lam <- matrix(c(1, 0.5), ncol = 1)
  low <- gllvmTMB:::.gllvmTMB_mspl_poisson_loading_atom(Lam, c(0.1, 0.1))
  high <- gllvmTMB:::.gllvmTMB_mspl_poisson_loading_atom(Lam, c(5, 5))
  expect_gt(high, low)
})