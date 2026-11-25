test_that("the q2 oracle refuses an uncontrolled prior tail", {
  L <- matrix(c(100, 0, 100, 0), 2, 2, byrow = TRUE)
  expect_error(
    .golden_site_log_marginal_q2(c(1, 1), c(-1500, -1500), L),
    "prior tail bound"
  )
})

test_that("the q2 oracle retains an analytic regular case", {
  L <- matrix(0, 2, 2)
  beta <- c(-0.3, 0.8)
  expected <- plogis(beta[1], log.p = TRUE) +
    plogis(beta[2], lower.tail = FALSE, log.p = TRUE)
  expect_equal(.golden_site_log_marginal_q2(c(1, 0), beta, L), expected,
               tolerance = 1e-8)
})

test_that("the tail guard rejects nonbinary observations", {
  expect_error(.golden_site_log_marginal_q2(2, 30, matrix(0, 1, 2)),
               "binary")
  expect_error(.golden_site_log_marginal_q2(NA_real_, 0, matrix(0, 1, 2)),
               "binary")
  expect_error(.golden_site_log_marginal_q2(factor("1", levels = c("0", "1")),
                                             30, matrix(0, 1, 2)), "binary")
  corrupt <- structure(1, class = "numeric_fixture")
  expect_error(.golden_site_log_marginal_q2(corrupt, 30, matrix(0, 1, 2)),
               "binary")
})

test_that("the relative-tail criterion brackets rare independent data", {
  L <- matrix(0, 1, 2)
  expect_equal(.golden_site_log_marginal_q2(1, -52, L),
               plogis(-52, log.p = TRUE), tolerance = 1e-8)
  expect_error(.golden_site_log_marginal_q2(1, -54, L), "prior tail bound")
})

test_that("the guard applies to either latent coordinate", {
  L <- matrix(c(0, 100, 0, 100), 2, 2, byrow = TRUE)
  expect_error(.golden_site_log_marginal_q2(c(1, 1), c(-1500, -1500), L),
               "prior tail bound")
})
