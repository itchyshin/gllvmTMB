test_that("getResidualCor() uses link-residual scale for non-Gaussian traits (#1980)", {
  skip_on_cran()
  set.seed(42)
  Y <- matrix(stats::rbinom(30 * 4, 1, 0.35), 30, 4)
  colnames(Y) <- paste0("s", 1:4)
  df <- data.frame(site = 1:30, Y)

  fit <- suppressMessages(gllvmTMB(
    traits(s1, s2, s3, s4) ~ 1 + latent(1 | site, d = 1),
    data = df,
    unit = "site",
    family = binomial(),
    silent = TRUE
  ))
  expect_equal(fit$fit$convergence, 0L)

  R_legacy <- suppressMessages(getResidualCor(fit))
  R_ref <- suppressMessages(
    extract_Sigma(fit, level = "unit", part = "total", link_residual = "auto")
  )$R

  expect_false(all(R_legacy[upper.tri(R_legacy)] >= 1 - 1e-8))
  expect_equal(R_legacy, R_ref, tolerance = 1e-8)
})