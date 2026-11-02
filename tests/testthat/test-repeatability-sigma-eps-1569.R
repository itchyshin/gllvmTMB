## #1569: with replicate rows inside a unit_obs record, sigma_eps is
## estimated and belongs in the within-unit variance of the repeatability.

.repeat_1569_fit <- function(n_rep = 2L, n_site = 60L) {
  set.seed(11)
  d <- expand.grid(
    rep = seq_len(n_rep), trait = paste0("t", 1:3), rec = 1:4,
    site = seq_len(n_site)
  )
  d$site_rec <- paste(d$site, d$rec, sep = "_")
  recs <- unique(d$site_rec)
  ti <- as.integer(factor(d$trait))
  uB <- matrix(stats::rnorm(n_site * 3, sd = sqrt(0.6)), n_site, 3)
  uW <- matrix(stats::rnorm(length(recs) * 3, sd = sqrt(0.4)), length(recs), 3)
  d$value <- uB[cbind(d$site, ti)] + uW[cbind(match(d$site_rec, recs), ti)] +
    stats::rnorm(nrow(d), sd = 1)
  d$site <- factor(d$site)
  d$site_rec <- factor(d$site_rec)
  d$trait <- factor(d$trait)
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site) + indep(0 + trait | site_rec),
    data = d, trait = "trait", unit = "site", unit_obs = "site_rec"
  )))
}

test_that("repeatability counts the estimated Gaussian residual (#1569)", {
  skip_on_cran()
  fit <- .repeat_1569_fit()
  s2 <- unname(fit$report$sigma_eps)^2
  expect_gt(s2, 0.5)

  vB <- diag(extract_Sigma(fit, level = "unit", part = "total",
                           link_residual = "none")$Sigma)
  vW <- diag(extract_Sigma(fit, level = "unit_obs", part = "total",
                           link_residual = "none")$Sigma)
  expected <- vB / (vB + vW + s2)
  ## the residual is a real part of the denominator: the old value is far off
  expect_gt(max(abs(expected - vB / (vB + vW))), 0.2)

  expect_equal(unname(extract_ICC_site(fit)), unname(expected),
               tolerance = 1e-8)
  rp <- suppressWarnings(extract_repeatability(fit))
  expect_equal(rp$R, unname(expected), tolerance = 1e-6)
  expect_true(all(rp$lower < rp$R & rp$R < rp$upper))
  ## the issue reports the true between-site share, 0.3
  expect_lt(max(abs(rp$R - 0.3)), 0.12)
})

test_that("bootstrap ICC summary uses the same denominator (#1569)", {
  skip_on_cran()
  fit <- .repeat_1569_fit(n_site = 30L)
  boot <- suppressWarnings(suppressMessages(bootstrap_Sigma(
    fit, n_boot = 2L, level = c("unit", "unit_obs"), what = "ICC",
    seed = 1, progress = FALSE
  )))
  s2 <- unname(fit$report$sigma_eps)^2
  vB <- diag(extract_Sigma(fit, level = "unit", part = "total",
                           link_residual = "none")$Sigma)
  vW <- diag(extract_Sigma(fit, level = "unit_obs", part = "total",
                           link_residual = "none")$Sigma)
  expect_equal(unname(boot$point_est$ICC_site), unname(vB / (vB + vW + s2)),
               tolerance = 1e-8)
  expect_equal(unname(boot$point_est$ICC_site),
               unname(extract_ICC_site(fit)), tolerance = 1e-8)
  expect_equal(unname(boot$point_est$ICC_site),
               suppressWarnings(extract_repeatability(fit))$R,
               tolerance = 1e-6)
})

test_that("one row per record keeps the old repeatability (#1569)", {
  skip_on_cran()
  set.seed(5)
  d <- expand.grid(trait = paste0("t", 1:3), rec = 1:3, site = 1:40)
  d$site_rec <- paste(d$site, d$rec, sep = "_")
  ti <- as.integer(factor(d$trait))
  uB <- matrix(stats::rnorm(40 * 3, sd = 0.8), 40, 3)
  d$value <- uB[cbind(d$site, ti)] + stats::rnorm(nrow(d), sd = 0.7)
  d$site <- factor(d$site)
  d$site_rec <- factor(d$site_rec)
  d$trait <- factor(d$trait)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site) + indep(0 + trait | site_rec),
    data = d, trait = "trait", unit = "site", unit_obs = "site_rec"
  )))
  ## sigma_eps is fixed by the engine here, so it is not added.
  expect_true(.gllvmTMB_sigma_eps_mapped_off(fit))
  vB <- diag(extract_Sigma(fit, level = "unit", part = "total",
                           link_residual = "none")$Sigma)
  vW <- diag(extract_Sigma(fit, level = "unit_obs", part = "total",
                           link_residual = "none")$Sigma)
  expect_equal(unname(extract_ICC_site(fit)), unname(vB / (vB + vW)),
               tolerance = 1e-10)
})
