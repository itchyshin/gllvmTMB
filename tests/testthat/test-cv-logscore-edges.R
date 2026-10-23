## .cv_logscore() binomial far-tail rows (#1489): fit-free, Julia-free.
## The response-scale probability rounds to exactly 1 at probit eta >= ~8.3
## and logit eta >= ~37, which made the held-out score -Inf while the fitted
## kernel stays finite. The score is now taken on the log scale from eta.

.cv_edge_joined <- function(eta, link_id, y, size) {
  p <- switch(
    as.character(link_id[1]),
    "0" = stats::plogis(eta),
    "1" = stats::pnorm(eta),
    -expm1(-exp(eta))
  )
  data.frame(
    family_id = 1L,
    est = p,
    y_true = y,
    n_trials = size,
    disp = NA_real_,
    eta = eta,
    link_id = link_id
  )
}
.cv_edge_fit <- structure(list(), class = "gllvmTMB_multi")

test_that(".cv_logscore() stays finite for probit far-tail misses", {
  j <- .cv_edge_joined(c(9, 30, 9, 30), 1L, c(0, 0, 2, 4), 5)
  ## the response-scale route rounds to p == 1 and gives -Inf
  expect_true(all(j$est == 1))
  ls <- .cv_logscore(j, .cv_edge_fit)
  ref <- c(
    5 * stats::pnorm(9, lower.tail = FALSE, log.p = TRUE),
    5 * stats::pnorm(30, lower.tail = FALSE, log.p = TRUE),
    lchoose(5, 2) + 3 * stats::pnorm(9, lower.tail = FALSE, log.p = TRUE),
    lchoose(5, 4) + stats::pnorm(30, lower.tail = FALSE, log.p = TRUE)
  )
  expect_true(all(is.finite(ls)))
  expect_equal(ls, ref, tolerance = 1e-12)
  expect_equal(ls[2], 5 * -454.32, tolerance = 1e-4)
})

test_that(".cv_logscore() stays finite for a logit far-tail miss", {
  j <- .cv_edge_joined(37, 0L, 0, 3)
  expect_equal(j$est, 1)
  ls <- .cv_logscore(j, .cv_edge_fit)
  expect_true(is.finite(ls))
  expect_equal(ls, 3 * plogis(37, lower.tail = FALSE, log.p = TRUE))
})

test_that(".cv_logscore() handles cloglog tails and exact hits", {
  j <- .cv_edge_joined(c(5, -40, 5), 2L, c(0, 1, 3), 3)
  ls <- .cv_logscore(j, .cv_edge_fit)
  expect_true(all(is.finite(ls)))
  expect_equal(ls[1], -3 * exp(5))
  ## far-lower tail: p ~ exp(eta), log p ~ eta
  expect_equal(ls[2], log(3) + -40 + 2 * -exp(-40), tolerance = 1e-12)
  ## y == size at p == 1 contributes 0 on the failure side, not NaN
  expect_equal(ls[3], 3 * log(-expm1(-exp(5))), tolerance = 1e-12)
})

test_that(".cv_logscore() matches dbinom at moderate eta to 1e-12", {
  eta <- c(-3, -1.2, 0, 0.4, 2.5)
  for (lk in 0:2) {
    j <- .cv_edge_joined(eta, lk, c(0, 1, 2, 3, 4), 4)
    expect_equal(
      .cv_logscore(j, .cv_edge_fit),
      stats::dbinom(j$y_true, j$n_trials, j$est, log = TRUE),
      tolerance = 1e-12
    )
  }
})

test_that(".cv_logscore() falls back to est when eta is absent", {
  j <- .cv_edge_joined(c(-1, 0.5), 1L, c(1, 2), 4)
  j$eta <- NULL
  j$link_id <- NULL
  expect_equal(
    .cv_logscore(j, .cv_edge_fit),
    stats::dbinom(j$y_true, j$n_trials, j$est, log = TRUE)
  )
})
