## #1919: stats::fitted() convention — numeric vector in model-row order.

test_that("#1919 as.numeric(fitted()) works on traits() and long-format fits", {
  skip_on_cran()
  suppressPackageStartupMessages(library(gllvmTMB))

  iris2 <- iris
  iris2$id <- factor(seq_len(nrow(iris2)))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(Sepal.Length, Sepal.Width, Petal.Length, Petal.Width) ~
      1 + latent(1 | id, d = 1),
    data = iris2, unit = "id", family = gaussian(), silent = TRUE
  )))
  fv <- fitted(fit_wide)
  expect_type(fv, "double")
  expect_equal(length(fv), nobs(fit_wide))
  expect_equal(as.numeric(fv), fv)
  expect_identical(fv, predict(fit_wide, type = "response")$est)

  long <- expand.grid(
    unit = factor(1:30),
    trait = factor(paste0("t", 1:3))
  )
  long$y <- stats::rnorm(nrow(long))
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = long,
    unit = "unit",
    trait = "trait",
    family = gaussian(),
    silent = TRUE
  )))
  fl <- fitted(fit_long)
  expect_equal(as.numeric(fl), fl)
  expect_identical(fl, fitted(fit_long, type = "response"))
})