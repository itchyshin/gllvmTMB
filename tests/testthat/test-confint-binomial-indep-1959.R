## Issue #1959: Wald confint must match vcov(); profile must not return -Inf.

.issue1959_fit <- function() {
  set.seed(4L)
  df <- data.frame(
    unit = factor(rep(1:12, each = 2)),
    trait = factor(rep(c("t1", "t2"), 12)),
    x = rnorm(24),
    value = rbinom(24, 1, 0.4)
  )
  suppressMessages(gllvmTMB(
    value ~ 0 + trait + x + indep(0 + trait | unit),
    data = df,
    unit = "unit",
    trait = "trait",
    family = binomial(),
    silent = TRUE
  ))
}

test_that("confint(method = 'wald') matches vcov() / tidy Wald on issue #1959 repro", {
  skip_on_cran()
  skip_if_not_heavy()
  fit <- .issue1959_fit()
  skip_if_not(isTRUE(fit$fit_health$converged), "fit did not converge in this environment")
  skip_if(is.null(fit$sd_report), "no sd_report")

  td <- tidy(fit, "fixed", conf.int = TRUE, conf.level = 0.95)
  ci <- suppressMessages(confint(fit, method = "wald", level = 0.95))
  V <- vcov(fit)
  est <- coef(fit)
  se <- sqrt(diag(V))
  z <- stats::qnorm(0.975)

  expect_equal(length(est), nrow(td))
  expect_equal(rownames(ci), td$term)
  expect_equal(as.numeric(ci[, 1L]), td$conf.low, tolerance = 1e-6)
  expect_equal(as.numeric(ci[, 2L]), td$conf.high, tolerance = 1e-6)
  expect_equal(as.numeric(ci[, 1L]), est - z * se, tolerance = 1e-6)
  expect_equal(as.numeric(ci[, 2L]), est + z * se, tolerance = 1e-6)
  expect_false(any(is.infinite(ci)))
})

test_that("profile confint does not return -Inf on issue #1959 repro", {
  skip_on_cran()
  skip_if_not_heavy()
  fit <- .issue1959_fit()
  skip_if_not(isTRUE(fit$fit_health$converged), "fit did not converge in this environment")
  skip_if(is.null(fit$sd_report), "no sd_report")

  ci_x <- suppressWarnings(confint(fit, parm = "x", method = "profile", level = 0.95))
  expect_false(any(ci_x == -Inf))
  expect_false(any(ci_x == Inf))
})

test_that("b_fix profile which aligns one label per tidy row (#1959)", {
  skip_on_cran()
  skip_if_not_heavy()
  fit <- .issue1959_fit()
  wh <- gllvmTMB:::.gllvmTMB_b_fix_profile_which(fit)
  td <- tidy(fit, "fixed", conf.int = FALSE)
  expect_equal(length(wh), nrow(td))
  expect_false(anyNA(wh))
  expect_equal(max(wh), sum(names(fit$opt$par) == "b_fix"))
})