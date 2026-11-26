## Issue #1952 (option A, 2026-11-26): unused levels on the unit factor must not
## allocate phantom sites in getLV() / ordination output. Refuse and name the
## level(s), same contract as #1387 for trait.

.issue1952_data <- function() {
  set.seed(901)
  sim <- simulate_unit_trait(
    n_units = 20L, n_obs_per_unit = 2L, n_traits = 4L,
    Lambda_B = matrix(0.5, 4, 1), psi_B = rep(0.2, 4)
  )
  dat <- sim$data
  used <- unique(as.character(dat$unit))
  dat$unit <- factor(dat$unit, levels = c(used, "ghost1", "ghost2"))
  dat
}

.issue1952_fit <- function(dat) {
  gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = TRUE),
    data = dat, trait = "trait", unit = "unit",
    control = gllvmTMBcontrol(se = TRUE)
  )
}

test_that("unused unit levels abort, naming the levels and droplevels() (#1952)", {
  skip_on_cran()
  dat <- .issue1952_data()
  err <- expect_error(.issue1952_fit(dat), class = "gllvmTMB_empty_unit_level")
  expect_match(conditionMessage(err), "ghost1", fixed = TRUE)
  expect_match(conditionMessage(err), "ghost2", fixed = TRUE)
  expect_match(conditionMessage(err), "droplevels()", fixed = TRUE)
})

test_that("droplevels() on unit removes the guard and fits 20 sites (#1952)", {
  skip_on_cran()
  dat <- transform(.issue1952_data(), unit = droplevels(unit))
  fit <- .issue1952_fit(dat)
  expect_equal(fit$n_sites, 20L)
  expect_equal(nrow(getLV(fit)), 20L)
})