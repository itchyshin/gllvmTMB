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
