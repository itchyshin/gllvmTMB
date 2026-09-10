# Exact-marginal oracle for the Gaussian latent-variable path.
#
# WHY THIS EXISTS.
# For a GAUSSIAN LV model the Laplace approximation is EXACT: eta is linear in
# the latent variables and the response is Gaussian, so the integrand is exactly
# Gaussian and the "approximation" has zero error. That makes this one of the
# very few places in the package where the marginal likelihood has a closed form
# and can be checked OUTRIGHT rather than compared against something that shares
# its assumptions.
#
# Why it is not redundant with the Julia twin: GLLVM.jl is a deliberate port
# ("mirrors R" / "Faithful to" in its own source) AND it uses Laplace too, so
# twin agreement shares both the derivation and the approximation. This test
# shares neither -- it is plain base-R linear algebra on the marginal
# distribution, written from the model definition.
#
# NOTE: no RTMB (or any new dependency) is required. The reference here is
# chol() + backsolve() on Sigma_B + Sigma_W.
#
# WHAT IT CERTIFIES: that the fitted Sigma really is the covariance the
# likelihood used, that the marginal is assembled correctly, and that the
# Laplace path returns the exact value on this family. It certifies nothing
# about coverage, and nothing about non-Gaussian families -- where Laplace is
# an approximation and this closed form does not exist.

test_that("Gaussian LV marginal log-likelihood matches the exact closed form", {
  skip_on_cran()

  set.seed(1)
  sim <- simulate_site_trait(
    n_sites = 40, n_species = 6, n_traits = 3, mean_species_per_site = 4
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site_species, d = 1),
    data = sim$data, family = gaussian(),
    trait = "trait", unit = "site_species"
  )

  # guard the premise: this must be the LAPLACE path, not a fit whose latent
  # blocks were mapped out. (The package's own headline example has NO latent
  # variables -- every LV block mapped to NA -- so a test written against that
  # would exercise none of this machinery.)
  expect_gt(length(fit$tmb_obj$env$random), 0)

  # every unit must be complete and identically ordered for the compact
  # matrix form below to be the right likelihood
  by_unit <- split(as.character(sim$data$trait), sim$data$site_species)
  expect_true(all(lengths(by_unit) == 3L))
  expect_length(unique(vapply(by_unit, paste, character(1), collapse = ",")), 1L)

  # canonical level names (not the deprecated "B"/"W" aliases); $Sigma is the
  # covariance matrix itself. Summing the two levels is the model definition:
  # a unit's 3-vector has the between-unit and within-unit components added.
  Sigma <- extract_Sigma(fit, level = "unit", part = "total")$Sigma +
    extract_Sigma(fit, level = "unit_obs", part = "total")$Sigma

  ordered_data <- sim$data[order(sim$data$site_species, sim$data$trait), ]
  Y <- matrix(ordered_data$value, ncol = 3L, byrow = TRUE)
  mu <- as.numeric(coef(fit))

  # exact marginal: y_i ~ MVN(mu, Sigma), independent across units
  R <- chol(Sigma)
  log_det <- 2 * sum(log(diag(R)))
  centred <- sweep(Y, 2L, mu)
  quad <- sum(backsolve(R, t(centred), transpose = TRUE)^2)
  exact_ll <- -0.5 * (nrow(Y) * 3L * log(2 * pi) + nrow(Y) * log_det + quad)

  expect_equal(exact_ll, as.numeric(logLik(fit)), tolerance = 1e-6)
})
