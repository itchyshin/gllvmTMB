## #1585: confirmatory_lambda() applies no +1 anchors by default (an anchor is
## an extra restriction on unit-variance latent axes, not a scale choice), and
## check_gllvmTMB() does not flag a diagonal loading the user pinned.

test_that("confirmatory_lambda() default is zeros-only, anchors are opt-in (#1585)", {
  species <- c("A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2")
  group   <- c(rep("A", 3), rep("B", 3), rep("C", 2))

  M <- confirmatory_lambda(species, group, d = 2L,
                           loads_on = list(A = 1L, B = 2L))
  expect_false(any(M == 1, na.rm = TRUE))
  expect_equal(M["A1", 2], 0)
  expect_equal(M["B1", 1], 0)
  expect_true(all(is.na(M[c("A1", "A2", "A3"), 1])))

  ## Explicit scalar NA is the same as the default.
  expect_identical(
    M,
    confirmatory_lambda(species, group, d = 2L,
                        loads_on = list(A = 1L, B = 2L), anchors = NA)
  )

  ## Opt-in: explicit anchors and NULL auto-pick still pin +1.
  Mx <- confirmatory_lambda(species, group, d = 2L,
                            loads_on = list(A = 1L, B = 2L),
                            anchors = c("A2", "B3"))
  expect_equal(Mx["A2", 1], 1)
  expect_equal(Mx["B3", 2], 1)
  Mn <- confirmatory_lambda(species, group, d = 2L,
                            loads_on = list(A = 1L, B = 2L), anchors = NULL)
  expect_equal(Mn["A1", 1], 1)
  expect_equal(Mn["B1", 2], 1)
})

test_that("a healthy fit with a user-pinned zero diagonal is not flagged near_zero_B_loading (#1585)", {
  skip_on_cran()
  set.seed(1)
  Lambda <- cbind(c(0.5, 0.8, 0.6, 0, 0, 0), c(0, 0, 0, 1.0, 0.9, 0.9))
  sim <- simulate_unit_trait(
    n_units = 200, n_obs_per_unit = 2, n_traits = 6,
    Lambda_B = Lambda, psi_B = 0.5, sigma2_eps = 0.3
  )
  form <- value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = TRUE)
  tr  <- levels(sim$data$trait)
  grp <- rep(c("A", "B"), each = 3)
  M0 <- confirmatory_lambda(tr, grp, d = 2, loads_on = list(A = 1, B = 2))
  expect_equal(M0[2, 2], 0)
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB(form, data = sim$data, trait = "trait", unit = "unit",
             lambda_constraint = list(unit = M0),
             control = gllvmTMBcontrol(n_init = 3))
  ))
  expect_false("near_zero_B_loading" %in%
                 gllvmTMB:::.gllvmTMB_boundary_flags(fit))
  chk <- check_gllvmTMB(fit)
  expect_false(any(grepl("near_zero_B_loading", chk$value)))

  ## A free diagonal that really collapses is still flagged.
  fake <- fit
  fake$report$Lambda_B[1, 1] <- 0
  fake$lambda_constraint <- NULL
  expect_true("near_zero_B_loading" %in%
                gllvmTMB:::.gllvmTMB_boundary_flags(fake))
})
