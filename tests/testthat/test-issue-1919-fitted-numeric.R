## #1919: `as.numeric(fitted(fit))` must work on standard wide and long fits
## (stats-style coercion for residual and plot code).

test_that("#1919: as.numeric(fitted(fit)) on traits() poisson wide fit", {
  skip_on_cran()
  set.seed(1919L)
  n <- 30L
  nms <- c("sp1", "sp2", "sp3")
  df <- data.frame(
    sp1 = stats::rpois(n, 2),
    sp2 = stats::rpois(n, 1),
    sp3 = stats::rpois(n, 3),
    site = factor(seq_len(n))
  )
  form <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = 2)",
    paste(nms, collapse = ", ")
  ))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    form,
    data = df,
    family = poisson(),
    unit = "site",
    control = gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
  )))
  stopifnot(isTRUE(fit$fit_health$converged))

  fv <- fitted(fit)
  expect_type(fv, "double")
  expect_length(fv, nrow(fit$data))
  expect_equal(fv, as.numeric(fitted(fit)))
  expect_equal(
    fv,
    predict(fit, newdata = NULL, type = "response")$est
  )
})

test_that("#1919: as.numeric(fitted(fit)) on long-format gaussian latent()", {
  skip_on_cran()
  set.seed(19192L)
  dat <- data.frame(
    site = factor(rep(1:10, each = 2)),
    trait = factor(rep(1:2, 10)),
    value = stats::rnorm(20)
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 1 + latent(1 | site, d = 1),
    data = dat,
    unit = "site",
    control = gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
  )))
  fv <- fitted(fit)
  expect_type(fv, "double")
  expect_length(fv, nrow(dat))
  expect_equal(fv, as.numeric(fitted(fit)))
})