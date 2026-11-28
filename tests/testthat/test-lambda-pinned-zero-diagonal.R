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

## suggest_lambda_constraints() pins in the varimax frame. On this design the
## rotated axes come out in the opposite order to gllvmTMB()'s lower-
## triangular loadings, so trait_1 is pinned at 0 on f1 and left free on f2,
## where Lambda[1, 2] is a structural zero: trait_1 silently had no loading.
## The svd restart was also skipped whenever theta_rr_B was mapped (#1585).
test_that("a varimax constraint that drops a loading warns and names the fix (#1585)", {
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
  ## One warning per varimax-frame convention compared (varimax_threshold
  ## and wald_retention).
  warns <- character()
  rec <- withCallingHandlers(
    suggest_lambda_constraints(fit)$recommended,
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("trait_1.*no estimated loading", warns)))
  expect_true(any(grepl("constraint[, c(2, 1)]", warns, fixed = TRUE)))
  M <- rec$constraint
  expect_identical(gllvmTMB:::.lambda_unestimable_rows(M), 1L)
  ## The order the warning names fits the engine frame and gives the same
  ## pattern as the group hypothesis.
  ord <- gllvmTMB:::.lambda_engine_frame_order(M)
  expect_identical(ord, c(2L, 1L))
  M_fix <- M[, ord, drop = FALSE]
  expect_false(anyNA(M_fix[upper.tri(M_fix)]))
  M0 <- confirmatory_lambda(levels(sim$data$trait), rep(c("A", "B"), each = 3),
                            d = 2, loads_on = list(A = 1, B = 2))
  expect_identical(unname(is.na(M_fix)), unname(is.na(M0)))

  for (n_init in c(1L, 3L)) {
    f_fix <- suppressMessages(
      gllvmTMB(form, data = sim$data, trait = "trait", unit = "unit",
               lambda_constraint = list(unit = M_fix),
               control = gllvmTMBcontrol(n_init = n_init))
    )
    L <- f_fix$report$Lambda_B
    ## Every trait has a shared loading; pinned entries stay exactly 0.
    expect_true(all(apply(abs(L), 1, max) > 0.1))
    expect_true(all(L[!is.na(M_fix)] == 0))
    ## The svd restart now runs under the mapped theta_rr_B.
    expect_true("svd" %in% f_fix$restart_history$start_label)
  }
})

test_that("confirmatory_lambda() warns when a species gets no estimable loading (#1585)", {
  tr <- paste0("trait_", 1:6)
  ## trait_1's group loads only on axis 2, above trait_1's row.
  expect_warning(
    M <- confirmatory_lambda(tr, rep(c("B", "A"), each = 3), d = 2,
                             loads_on = list(A = 1, B = 2)),
    "trait_1.*no estimated loading"
  )
  expect_identical(gllvmTMB:::.lambda_unestimable_rows(M), 1L)
  ## Block order that fits the frame: no warning.
  expect_no_warning(
    confirmatory_lambda(tr, rep(c("A", "B"), each = 3), d = 2,
                        loads_on = list(A = 1, B = 2))
  )
  ## A free first row (the default lower-triangular frame) is not flagged.
  expect_length(gllvmTMB:::.lambda_unestimable_rows(matrix(NA_real_, 6, 2)), 0L)
})
