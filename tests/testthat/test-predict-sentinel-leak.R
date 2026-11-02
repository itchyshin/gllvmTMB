## #1406: in-sample predict()/fitted() must not return the internal sentinels
## `species = "placeholder"` (made by gllvmTMB() when the user gives no
## species/cluster grouping) or the auto-generated `.family_wide_` label of a
## wide mixed-family fit. User-supplied species columns and family labels stay.

test_that("#1406: no-species fit drops the placeholder species column", {
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
  expect_identical(names(p), c("id", "trait", "est"))
  expect_identical(names(f), c("id", "trait", "est"))
  expect_equal(nrow(p), nrow(iris2) * 4L)
})

test_that("#1406: wide mixed-family fit drops placeholder and .family_wide_", {
  skip_on_cran()
  m <- mtcars
  m$car <- factor(rownames(m))
  fam <- list(mpg = gaussian(), carb = poisson(), vs = binomial(), am = binomial())
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(mpg, carb, vs, am) ~ 1 + latent(1 | car, d = 1),
    data = m, unit = "car", family = fam, silent = TRUE
  )))
  p <- predict(fit, type = "response")
  expect_false("species" %in% names(p))
  expect_false(any(grepl("family_wide_", names(p))))
  expect_false(any(grepl("family_wide_", names(fitted(fit)))))
  expect_identical(names(p), c("car", "trait", "est"))
})

test_that("#1406: the sentinel helpers match only the internal sentinels", {
  expect_true(gllvmTMB:::.gllvmTMB_is_placeholder_col(factor(rep("placeholder", 3))))
  expect_false(gllvmTMB:::.gllvmTMB_is_placeholder_col(factor(c("a", "b"))))
  expect_false(gllvmTMB:::.gllvmTMB_is_placeholder_col(factor(character(0))))
  expect_false(gllvmTMB:::.gllvmTMB_is_placeholder_col(NULL))
  expect_true(gllvmTMB:::.gllvmTMB_is_auto_family_var(".family_wide_"))
  expect_true(gllvmTMB:::.gllvmTMB_is_auto_family_var("..family_wide_"))
  expect_false(gllvmTMB:::.gllvmTMB_is_auto_family_var("family"))
  expect_false(gllvmTMB:::.gllvmTMB_is_auto_family_var("isdm_source"))
  expect_false(gllvmTMB:::.gllvmTMB_is_auto_family_var(NULL))
})
