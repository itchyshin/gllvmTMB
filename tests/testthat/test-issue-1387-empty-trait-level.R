## Issue #1387: an unused (empty) level of the trait factor must not be
## counted as a trait. It used to add free parameters silently (df/AIC
## inflated, sd_report NULL). The fit now aborts and names the level.

.el_data <- function(extra_level = FALSE) {
  set.seed(21)
  n <- 30L
  nt <- 3L
  d <- data.frame(
    unit = factor(rep(seq_len(n), each = nt)),
    trait = factor(rep(paste0("t", seq_len(nt)), n))
  )
  d$value <- c(1, 0, -1)[as.integer(d$trait)] + stats::rnorm(n * nt, sd = 0.7)
  if (extra_level) {
    d$trait <- factor(d$trait, levels = c("t1", "t2", "t3", "t4_unused"))
  }
  d
}

.el_fit <- function(dd) {
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1),
           data = dd, unit = "unit", trait = "trait", family = gaussian())
}

test_that("an empty trait level aborts, naming the level and droplevels() (#1387)", {
  skip_on_cran()
  err <- expect_error(
    .el_fit(.el_data(extra_level = TRUE)),
    class = "gllvmTMB_empty_trait_level"
  )
  expect_match(conditionMessage(err), "t4_unused", fixed = TRUE)
  expect_match(conditionMessage(err), "droplevels()", fixed = TRUE)
})

test_that("the droplevels()-ed data fits with df = 9 and finite SEs (#1387)", {
  skip_on_cran()
  dd <- .el_data(extra_level = TRUE)
  dd$trait <- droplevels(dd$trait)
  fit <- .el_fit(dd)
  expect_equal(fit$n_traits, 3L)
  expect_equal(attr(logLik(fit), "df"), 9)
  expect_false(is.null(fit$sd_report))
  expect_false(anyNA(tidy(fit, "fixed")$std.error))
})
