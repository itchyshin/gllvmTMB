## Surface tests for extract_residual_cov(), extract_residual_cor(),
## getResidualCor() and extract_residual_split(): return shape, dimnames,
## cov/cor consistency, level handling, and the no-unit_obs behaviour.
## Pins what the code does today; value recovery lives in
## test-olre-separation.R and test-extractors-extra.R.

.residual_surface_fit <- function(two_tier = TRUE) {
  set.seed(1)
  n_site <- 60L
  n_trait <- 3L
  n_rep <- 3L
  df <- expand.grid(rep = seq_len(n_rep), site = seq_len(n_site),
                    t = seq_len(n_trait))
  df$site <- factor(df$site)
  df$trait <- factor(paste0("t", df$t))
  df$site_species <- factor(paste(df$site, df$rep, sep = "_"))
  u <- matrix(rnorm(n_site * n_trait), n_site)
  df$value <- u[cbind(as.integer(df$site), df$t)] +
    rnorm(nrow(df), sd = 0.5)
  form <- if (two_tier) {
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      indep(0 + trait | site_species)
  } else {
    value ~ 0 + trait + latent(0 + trait | site, d = 1)
  }
  suppressMessages(suppressWarnings(
    gllvmTMB(form, data = df, unit = "site",
             unit_obs = if (two_tier) "site_species" else NULL)
  ))
}

test_that("extract_residual_cov()/cor() return trait x trait matrices per level", {
  skip_on_cran()
  fit <- .residual_surface_fit()
  tn <- paste0("t", 1:3)

  for (lv in c("unit", "unit_obs")) {
    S <- extract_residual_cov(fit, level = lv)
    R <- extract_residual_cor(fit, level = lv)
    expect_true(is.matrix(S))
    expect_true(is.matrix(R))
    expect_equal(dim(S), c(3L, 3L))
    expect_equal(dim(R), c(3L, 3L))
    expect_equal(dimnames(S), list(tn, tn))
    expect_equal(dimnames(R), list(tn, tn))
    expect_true(isSymmetric(unname(S), tol = 1e-10))
    expect_equal(unname(diag(R)), rep(1, 3))
    ## cor is the cov2cor of cov
    expect_equal(R, stats::cov2cor(S), tolerance = 1e-8)
  }

  ## default level is "unit"
  expect_equal(extract_residual_cov(fit), extract_residual_cov(fit, "unit"))
  expect_equal(extract_residual_cor(fit), extract_residual_cor(fit, "unit"))

  ## The unit_obs tier here is indep(): diagonal covariance
  Sw <- extract_residual_cov(fit, level = "unit_obs")
  expect_equal(Sw[upper.tri(Sw)], rep(0, 3))
  expect_true(all(diag(Sw) > 0))
})

test_that("legacy level aliases B/W give the same matrices", {
  skip_on_cran()
  fit <- .residual_surface_fit()
  expect_equal(
    suppressWarnings(extract_residual_cov(fit, level = "B")),
    extract_residual_cov(fit, level = "unit")
  )
  expect_equal(
    suppressWarnings(extract_residual_cor(fit, level = "W")),
    extract_residual_cor(fit, level = "unit_obs")
  )
})

test_that("an invalid level errors (plain match.arg error today)", {
  skip_on_cran()
  fit <- .residual_surface_fit()
  ## Today this is base R's match.arg() error: unclassed, no advice line.
  ## Pin the message that names the accepted values, not a class.
  expect_error(extract_residual_cov(fit, level = "bogus"),
               "should be one of")
  expect_error(extract_residual_cor(fit, level = "bogus"),
               "should be one of")
  expect_error(extract_residual_cov(fit, level = "bogus"),
               class = "simpleError")
})

test_that("getResidualCor() equals extract_residual_cor()", {
  skip_on_cran()
  fit <- .residual_surface_fit()
  expect_equal(getResidualCor(fit), extract_residual_cor(fit))
  expect_equal(getResidualCor(fit, level = "unit_obs"),
               extract_residual_cor(fit, level = "unit_obs"))
  expect_equal(getResidualCov(fit), extract_residual_cov(fit))
})

test_that("extract_residual_split() components and diagonal sum", {
  skip_on_cran()
  fit <- .residual_surface_fit()
  sp <- extract_residual_split(fit)
  expect_s3_class(sp, "data.frame")
  expect_named(sp, c("trait", "sigma2_d", "sigma2_e", "sigma2_total"))
  expect_equal(nrow(sp), 3L)
  expect_equal(levels(sp$trait), paste0("t", 1:3))
  ## Gaussian: no family-implied residual
  expect_equal(sp$sigma2_d, rep(0, 3))
  expect_equal(sp$sigma2_total, sp$sigma2_d + sp$sigma2_e, tolerance = 1e-12)
  ## sigma2_e is the diagonal of the unit_obs residual covariance here
  expect_equal(sp$sigma2_e,
               unname(diag(extract_residual_cov(fit, level = "unit_obs"))),
               tolerance = 1e-8)

  expect_error(extract_residual_split(1), "gllvmTMB")
})

test_that("a fit with no unit_obs tier: NULL cov, zero split", {
  skip_on_cran()
  fit <- .residual_surface_fit(two_tier = FALSE)
  expect_equal(dim(extract_residual_cov(fit, level = "unit")), c(3L, 3L))
  ## Today: NULL (no error) for the absent tier
  expect_null(extract_residual_cov(fit, level = "unit_obs"))
  expect_null(extract_residual_cor(fit, level = "unit_obs"))
  expect_null(getResidualCor(fit, level = "unit_obs"))
  sp <- extract_residual_split(fit)
  expect_equal(sp$sigma2_e, rep(0, 3))
  expect_equal(sp$sigma2_total, rep(0, 3))
})
