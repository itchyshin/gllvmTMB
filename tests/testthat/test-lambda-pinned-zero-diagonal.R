## A lambda_constraint that pins a diagonal loading Lambda[k, k] at 0 used to
## leave every free loading on axis k at exactly 0 (the pinned value was
## written over the diagonal start, so the column started as all zeros, a
## stationary point). The fit then reported convergence 0 with axis k all
## zeros (#1585, part 1).

test_that("a zero-pinned diagonal does not leave its axis stuck at zero (#1585)", {
  skip_on_cran()
  set.seed(1)
  Lambda <- cbind(c(0.5, 0.8, 0.6, 0, 0, 0), c(0, 0, 0, 1.0, 0.9, 0.9))
  sim <- simulate_unit_trait(
    n_units = 200, n_obs_per_unit = 2, n_traits = 6,
    Lambda_B = Lambda, psi_B = 0.5, sigma2_eps = 0.3
  )
  form <- value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = TRUE)
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(form, data = sim$data, trait = "trait", unit = "unit")
  ))
  tr <- levels(sim$data$trait)
  grp <- rep(c("A", "B"), each = 3)
  ## Block-ordered groups with anchors = NA pin Lambda[2, 2] = 0.
  M0 <- confirmatory_lambda(tr, grp, d = 2, loads_on = list(A = 1, B = 2),
                            anchors = c(NA, NA))
  expect_equal(M0[2, 2], 0)
  f_zero <- suppressMessages(suppressWarnings(
    gllvmTMB(form, data = sim$data, trait = "trait", unit = "unit",
             lambda_constraint = list(unit = M0))
  ))
  L2 <- f_zero$report$Lambda_B[, 2]
  free2 <- is.na(M0[, 2])
  expect_gt(max(abs(L2[free2])), 0.1)
  ## The constraint is true, but the constrained fit has 5 fewer parameters
  ## (19 vs 24), so it sits a few units below the unconstrained optimum; the
  ## stuck fit was ~90 below. The best constrained start in the issue is 4.8
  ## below, so allow 6.
  expect_lt(as.numeric(logLik(fit)) - as.numeric(logLik(f_zero)), 6)
})
