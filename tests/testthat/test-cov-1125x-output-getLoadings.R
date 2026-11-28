## Coverage (2026-11-25): refusal paths in R/output-methods.R (getLoadings).

.cov1125_tiny_fit <- function() {
  set.seed(1125)
  n <- 12L
  df <- data.frame(
    unit = factor(rep(seq_len(n), each = 2L)),
    trait = factor(rep(c("a", "b"), n), levels = c("a", "b")),
    value = stats::rnorm(2L * n)
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    unit = "unit",
    trait = "trait",
    family = stats::gaussian(),
    silent = TRUE
  )))
}

test_that("getLoadings() refuses rotated loadings on julia bridge fits", {
  skip_on_cran()
  fake <- structure(list(d_B = 1L), class = c("gllvmTMB_julia", "gllvmTMB_multi"))
  expect_error(
    getLoadings(fake, rotate = "varimax"),
    "not routed yet"
  )
})

test_that("getLoadings() accepts legacy level aliases with a one-shot deprecation", {
  skip_on_cran()
  fit <- .cov1125_tiny_fit()
  opt <- "gllvmTMB.warned_level_B"
  withr::local_options(setNames(list(NULL), opt))
  expect_warning(
    L <- getLoadings(fit, level = "B"),
    class = "lifecycle_warning_deprecated"
  )
  expect_true(is.matrix(L))
  expect_equal(dim(L)[1L], nlevels(fit$data[[fit$trait_col]]))
})

test_that("extract_loadings() forwards to getLoadings()", {
  skip_on_cran()
  fit <- .cov1125_tiny_fit()
  expect_identical(
    extract_loadings(fit, level = "unit"),
    getLoadings(fit, level = "unit")
  )
})