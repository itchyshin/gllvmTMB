## Sweep C diagnostics. #897 (ordinal_probit degeneracy detector) was deliberately
## NOT extended: the shipped `ordinal_liability_loading` row already exists and is
## disarmed because five candidate statistics fail to separate degenerate from
## healthy ordinal fits (see #1097). Only #1167 is implemented here.

.sd_spde_fit <- function() {
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 2,
    mean_species_per_site = 5, spatial_range = 0.3,
    sigma2_spa = rep(0.5, 2), seed = 7
  )
  mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.1)
  gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait | coords),
    data = sim$data, mesh = mesh, unit = "site"
  )
}

test_that("#1167 healthy SPDE fit is NOT flagged as premature termination", {
  skip_on_cran()
  fit <- .sd_spde_fit()
  expect_true(fit$use$spde)
  expect_gt(fit$opt$iterations, 2)
  chk <- check_gllvmTMB(fit)
  expect_false("premature_termination" %in% chk$component)
  expect_false(isTRUE(fit$fit_health$premature_termination))
  expect_true(.gllvmTMB_build_fit_health(fit)$converged)
})

test_that("#1167 one iteration at objective 8.72e20 is flagged FAIL", {
  skip_on_cran()
  fit <- .sd_spde_fit()
  fit$opt$iterations <- 1L
  fit$opt$objective <- 8.72e20
  fit$fit_health <- NULL
  health <- .gllvmTMB_build_fit_health(fit)
  expect_true(health$premature_termination)
  expect_false(health$converged)
  chk <- check_gllvmTMB(fit)
  row <- chk[chk$component == "premature_termination", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "FAIL")
  ## a short run at a sane objective (e.g. 4.27e3 at 2 iterations) is not flagged
  fit$opt$objective <- 4.27e3
  fit$fit_health <- NULL
  expect_false(.gllvmTMB_build_fit_health(fit)$premature_termination)
})
