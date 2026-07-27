## Singular / boundary-fit diagnostic for random SLOPES. `fit_health$boundary_flags`
## already flags near-zero intercept-tier variances (sd_B/sd_phy/sd_spde); it now
## also covers the augmented random-slope variances sd_b (dep/indep/`||` slope
## engines) and sd_spde_b (spatial slope) -- the cells most prone to a boundary
## (singular) fit. This is the isSingular-style signal for a weakly-identified
## random-slope fit (the review's ask), recorded in fit_health for inspection.

test_that("boundary_flags flags a near-zero augmented slope variance (sd_b)", {
  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_b = c(0.5, 1e-6, 0.4, 0.3, 0.2, 0.6)), use = list()))
  expect_true("near_zero_sd_b" %in% bf)
})

test_that("boundary_flags flags a near-zero spatial slope variance (sd_spde_b)", {
  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_spde_b = c(0.4, 0.3, 1e-7, 0.5, 0.2, 0.6)), use = list()))
  expect_true("near_zero_sd_spde_b" %in% bf)
})

test_that("well-identified slope variances raise no boundary flag", {
  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_b = c(0.5, 0.4, 0.4, 0.3, 0.2, 0.6),
                  sd_spde_b = c(0.4, 0.3, 0.5, 0.5, 0.2, 0.6)), use = list()))
  expect_false(any(grepl("sd_b|sd_spde_b", bf)))
})

## Relative collapse. An absolute sd threshold of 1e-4 corresponds to a variance
## below 1e-8, so a boundary-pinned (Heywood) component whose sd is 6.8e-4 --
## variance 4.7e-7, six orders of magnitude below its siblings -- used to pass
## every check the package had. psi is estimated on the log scale, so psi -> 0 is
## an interior point of the transformed space and pdHess stays positive definite
## there too. The relative test is what makes this detectable.
## Values below are the real sd_B from the 2026-07-27 start_method = "res"
## worse-optimum fit (see docs/dev-log/after-task/2026-07-27-start-method-res-worse-optimum.md).

test_that("boundary_flags flags a component collapsed relative to its siblings", {
  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_B = c(1.01521, 0.906282, 0.000682614)),
    use = list()))
  expect_true("near_zero_sd_B" %in% bf)
})

test_that("the relative test needs two components and tolerates non-finite values", {
  rc <- gllvmTMB:::.gllvmTMB_relative_collapse
  ## Nothing to compare a lone component against.
  expect_false(rc(0.7, 1e-3))
  ## An all-zero vector has no scale, so it is not a *relative* collapse; the
  ## absolute threshold is what covers that case.
  expect_false(rc(c(0, 0, 0), 1e-3))
  expect_false(rc(numeric(0), 1e-3))
  ## Non-finite entries are dropped, not propagated.
  expect_true(rc(c(1, NA, 1e-9), 1e-3))
  expect_false(rc(c(1, NA), 1e-3))
  ## Sign must not matter -- these are magnitudes.
  expect_true(rc(c(-1.2, 1e-9), 1e-3))
})

test_that("a spread of healthy variance components is not a relative collapse", {
  ## min/max = 0.2/0.6 = 0.33, far above the 1e-3 relative threshold. This is
  ## the guard against the relative test firing on ordinary heterogeneity.
  bf <- gllvmTMB:::.gllvmTMB_boundary_flags(list(
    report = list(sd_b = c(0.5, 0.4, 0.4, 0.3, 0.2, 0.6)), use = list()))
  expect_false(any(grepl("sd_b", bf)))
  ## An order of magnitude apart is still not collapse.
  expect_false(gllvmTMB:::.gllvmTMB_relative_collapse(c(1.0, 0.1, 0.05), 1e-3))
})
