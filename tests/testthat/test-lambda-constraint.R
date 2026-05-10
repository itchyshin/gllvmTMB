# Stage 24 — galamm-style confirmatory loadings (`lambda_constraint`).
#
# These tests verify that the user-facing claim
#   "lambda_constraint = list(B = M) pins Lambda_B[i, j] = M[i, j]
#    wherever M[i, j] is not NA, leaving NA entries free."
# is actually enforced by the fit. Without these tests the feature is
# documented but unverified.
#
# The implementation lives in:
#   R/lambda-constraint.R    -- packed-theta index + map builder
#   R/fit-multi.R lines 311-323  -- wires the map into TMB

skip_if_not_installed("ape")

# Small sim with a known Λ_B so we can also check parameter recovery on the
# free entries while diagonals are pinned (galamm convention).
make_sim <- function(n_traits = 4, d = 2, seed = 1) {
  set.seed(seed)
  Lam_B_true <- matrix(0, nrow = n_traits, ncol = d)
  Lam_B_true[lower.tri(Lam_B_true, diag = TRUE)] <-
    c(1.0, 0.4, -0.3, 0.2,    # column 1 (diag + below)
      1.0, 0.6, -0.2)         # column 2 (diag + below)
  simulate_site_trait(
    n_sites               = 60,
    n_species             = 10,
    n_traits              = n_traits,
    mean_species_per_site = 5,
    Lambda_B              = Lam_B_true,
    S_B                   = rep(0.3, n_traits),
    seed                  = seed
  )
}

test_that("diagonal pin to 1 holds exactly after fit (galamm convention)", {
  sim <- make_sim()
  cnst <- matrix(NA_real_, nrow = 4, ncol = 2)
  diag(cnst) <- 1
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data,
    lambda_constraint = list(B = cnst)
  )
  expect_equal(fit$opt$convergence, 0L)
  L <- getLoadings(fit, level = "B")
  expect_equal(L[1, 1], 1, tolerance = 1e-8)
  expect_equal(L[2, 2], 1, tolerance = 1e-8)
})

test_that("off-diagonal pin to a non-zero value holds exactly", {
  sim <- make_sim()
  cnst <- matrix(NA_real_, nrow = 4, ncol = 2)
  diag(cnst) <- 1
  cnst[3, 1] <- 0.5    # pin trait-3 loading on factor-1 to 0.5
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data,
    lambda_constraint = list(B = cnst)
  )
  expect_equal(fit$opt$convergence, 0L)
  L <- getLoadings(fit, level = "B")
  expect_equal(L[3, 1], 0.5, tolerance = 1e-8)
  expect_equal(L[1, 1], 1.0, tolerance = 1e-8)
})

test_that("off-diagonal pin to zero zeros out the loading", {
  sim <- make_sim()
  cnst <- matrix(NA_real_, nrow = 4, ncol = 2)
  diag(cnst) <- 1
  cnst[4, 2] <- 0      # zero out trait-4 loading on factor-2
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data,
    lambda_constraint = list(B = cnst)
  )
  expect_equal(fit$opt$convergence, 0L)
  L <- getLoadings(fit, level = "B")
  expect_equal(L[4, 2], 0, tolerance = 1e-8)
})

test_that("free entries adjacent to pinned ones are still optimised", {
  # If we pin diag(L_B) = 1 and leave the lower triangle free, then the
  # unconstrained MLE on the free entries must NOT equal the simulator
  # values exactly (they're estimates), but they must NOT equal their init
  # value (0) either. This guards against a bug where the map wipes free
  # entries by mistake.
  sim <- make_sim()
  cnst <- matrix(NA_real_, nrow = 4, ncol = 2)
  diag(cnst) <- 1
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data,
    lambda_constraint = list(B = cnst)
  )
  L <- getLoadings(fit, level = "B")
  # Lower-triangle free entries: (2,1), (3,1), (4,1), (3,2), (4,2)
  free_entries <- c(L[2, 1], L[3, 1], L[4, 1], L[3, 2], L[4, 2])
  expect_true(all(abs(free_entries) > 1e-3))   # actually moved
})

test_that("upper-triangle pins are silently ignored (always 0 by construction)", {
  sim <- make_sim()
  cnst <- matrix(NA_real_, nrow = 4, ncol = 2)
  diag(cnst) <- 1
  cnst[1, 2] <- 0.99   # upper triangle — should be ignored, no error
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data,
    lambda_constraint = list(B = cnst)
  )
  L <- getLoadings(fit, level = "B")
  expect_equal(L[1, 2], 0, tolerance = 1e-12)   # NOT 0.99
})

test_that("dimension-mismatched constraint matrix errors with cli message", {
  sim <- make_sim()
  bad <- matrix(NA_real_, nrow = 3, ncol = 2)   # wrong: 3 rows, expected 4
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = sim$data,
      lambda_constraint = list(B = bad)
    ),
    "lambda_constraint matrix has wrong dimensions"
  )
})

test_that("W-level constraint pins Lambda_W diagonals", {
  sim <- make_sim()
  cnst_W <- matrix(NA_real_, nrow = 4, ncol = 1)
  cnst_W[1, 1] <- 1
  fit <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site,         d = 2) +
            latent(0 + trait | site_species, d = 1),
    data = sim$data,
    lambda_constraint = list(W = cnst_W)
  )
  expect_equal(fit$opt$convergence, 0L)
  L_W <- getLoadings(fit, level = "W")
  expect_equal(L_W[1, 1], 1, tolerance = 1e-8)
})

test_that("simultaneous B and W constraints both pin", {
  sim <- make_sim()
  cnst_B <- matrix(NA_real_, nrow = 4, ncol = 2); diag(cnst_B) <- 1
  cnst_W <- matrix(NA_real_, nrow = 4, ncol = 1); cnst_W[1, 1] <- 1
  fit <- gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site,         d = 2) +
            latent(0 + trait | site_species, d = 1),
    data = sim$data,
    lambda_constraint = list(B = cnst_B, W = cnst_W)
  )
  expect_equal(fit$opt$convergence, 0L)
  L_B <- getLoadings(fit, level = "B")
  L_W <- getLoadings(fit, level = "W")
  expect_equal(L_B[1, 1], 1, tolerance = 1e-8)
  expect_equal(L_B[2, 2], 1, tolerance = 1e-8)
  expect_equal(L_W[1, 1], 1, tolerance = 1e-8)
})
