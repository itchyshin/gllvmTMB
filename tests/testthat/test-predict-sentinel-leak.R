## #1406: predict()/fitted() must not return the internal sentinels
## `species = "placeholder"` (synthesised when the user gave no species/cluster
## grouping) or the auto-generated `.family_wide_` column of a wide
## mixed-family fit. Failure-before-fix: both columns are present on the
## base commit, so these expectations fail there.

test_that("#1406: predict()/fitted() on a no-species fit drop the placeholder", {
  skip_on_cran()
  iris2 <- iris
  iris2$id <- factor(seq_len(nrow(iris2)))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(Sepal.Length, Sepal.Width, Petal.Length, Petal.Width) ~
      1 + latent(1 | id, d = 1),
    data = iris2, unit = "id", silent = TRUE
  )))
  p <- predict(fit)
  f <- fitted(fit)
  expect_false("species" %in% names(p))
  expect_false("species" %in% names(f))
  expect_false(any(vapply(p, function(col) any(as.character(col) == "placeholder"), logical(1))))
  expect_identical(names(p), c("id", "trait", "est"))
  expect_equal(nrow(p), nrow(iris2) * 4L)
})

test_that("#1406: a wide mixed-family fit does not return .family_wide_", {
  skip_on_cran()
  m <- mtcars
  m$car <- factor(rownames(m))
  fam <- list(mpg = gaussian(), carb = poisson(), vs = binomial(), am = binomial())
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(mpg, carb, vs, am) ~ 1 + latent(1 | car, d = 1),
    data = m, unit = "car", family = fam, silent = TRUE
  )))
  p <- predict(fit, type = "response")
  expect_false(any(grepl("family_wide_", names(p))))
  expect_false(any(grepl("family_wide_", names(fitted(fit)))))
  expect_false("species" %in% names(p))
  expect_identical(names(p), c("car", "trait", "est"))
})

test_that("#1406: sentinel helpers only match the internal sentinels", {
  expect_true(gllvmTMB:::.gllvmTMB_is_placeholder_col(factor(rep("placeholder", 3))))
  expect_false(gllvmTMB:::.gllvmTMB_is_placeholder_col(factor(c("a", "b"))))
  expect_false(gllvmTMB:::.gllvmTMB_is_placeholder_col(NULL))
  expect_true(gllvmTMB:::.gllvmTMB_is_auto_family_var(".family_wide_"))
  expect_true(gllvmTMB:::.gllvmTMB_is_auto_family_var("..family_wide_"))
  expect_false(gllvmTMB:::.gllvmTMB_is_auto_family_var("family"))
  expect_false(gllvmTMB:::.gllvmTMB_is_auto_family_var("isdm_source"))
})
