## Tests for the rotation advisory hook in getLoadings(): when a user
## fits an rr() model with d > 1 and no lambda_constraint, accessing the
## raw Lambda via getLoadings(level, rotate = "none") should surface a
## one-shot informational message pointing at suggest_lambda_constraint()
## or rotate_loadings().

test_that("rr B fit with d > 1 and no constraint stores advisory flag", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    S_B = rep(0, 4), beta = matrix(0, 4, 2), seed = 1
  )
  fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
                  data = s$data)
  expect_true(isTRUE(fit$needs_rotation_advice$B))
  expect_false(isTRUE(fit$needs_rotation_advice$W))
  expect_false(isTRUE(fit$needs_rotation_advice$phy))
})

test_that("rr B fit with lambda_constraint clears the advisory flag", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    S_B = rep(0, 4), beta = matrix(0, 4, 2), seed = 1
  )
  cnst <- matrix(NA_real_, 4, 2)
  diag(cnst) <- 1
  fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
                  data = s$data,
                  lambda_constraint = list(B = cnst))
  expect_false(isTRUE(fit$needs_rotation_advice$B))
})

test_that("rr B fit with d = 1 does NOT trigger advisory (no rotational ambiguity)", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3), 4, 1),
    S_B = rep(0, 4), beta = matrix(0, 4, 2), seed = 1
  )
  fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
                  data = s$data)
  expect_false(isTRUE(fit$needs_rotation_advice$B))
})

test_that("getLoadings(rotate = 'none') emits the informational message", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    S_B = rep(0, 4), beta = matrix(0, 4, 2), seed = 1
  )
  fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
                  data = s$data)
  expect_message(getLoadings(fit, level = "B", rotate = "none"),
                 regexp = "rotation")
})

test_that("getLoadings(rotate = 'varimax') does NOT emit the message", {
  set.seed(1)
  s <- simulate_site_trait(
    n_sites = 40, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    S_B = rep(0, 4), beta = matrix(0, 4, 2), seed = 1
  )
  fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
                  data = s$data)
  expect_no_message(getLoadings(fit, level = "B", rotate = "varimax"))
})
