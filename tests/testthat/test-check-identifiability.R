## Phase 1b 2026-05-15 item 4: tests for `check_identifiability()`.
##
## Two flavours:
##   (1) Input validation -- cheap, exercised on every run (no CRAN gate
##       needed because they all fail fast).
##   (2) Smoke + structure tests on a tiny Gaussian fit with `sim_reps = 10`.
##       These run the actual simulate-refit loop and so are gated by
##       `skip_on_cran()` (each refit takes a few seconds; 10 refits is the
##       smallest configuration that meaningfully exercises the Procrustes
##       alignment + recovery table + Hessian aggregation).
##
## The heavy / canonical usage (`sim_reps = 100L` for the spurious-factor
## detection) is documented in roxygen and verified in the Phase 1b
## validation milestone artefact; it is not part of the unit-test suite.

## ---- tiny Gaussian fixture -----------------------------------------------

make_tiny_gaussian_fit <- function(seed = 1L) {
  set.seed(seed)
  n_sites <- 20L; Tn <- 3L
  Lambda_B <- matrix(c(0.9, 0.4, -0.3,
                       0.0, 0.6,  0.2), Tn, 2)
  psi_B <- c(0.20, 0.15, 0.10)
  Lambda_W <- matrix(c(0.4, 0.2, -0.1), Tn, 1)
  psi_W <- c(0.10, 0.08, 0.05)
  s <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites, n_species = 3, n_traits = Tn,
    mean_species_per_site = 3,
    Lambda_B = Lambda_B, psi_B = psi_B,
    Lambda_W = Lambda_W, psi_W = psi_W,
    beta = matrix(0, Tn, 2), seed = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | site,         d = 2) + unique(0 + trait | site) +
      latent(0 + trait | site_species, d = 1) + unique(0 + trait | site_species),
    data = s$data
  )))
}

## ---- mock fits (for the input-validation tests) --------------------------

make_mock_fit <- function(family_id_vec = 0L) {
  structure(
    list(
      tmb_data = list(family_id_vec = family_id_vec)
    ),
    class = "gllvmTMB_multi"
  )
}

## ---- input validation ---------------------------------------------------

test_that("check_identifiability() errors on non-gllvmTMB_multi input", {
  expect_error(
    gllvmTMB::check_identifiability(list(foo = 1), sim_reps = 10L),
    "gllvmTMB_multi"
  )
})

test_that("check_identifiability() rejects sim_reps < 2", {
  fit <- make_mock_fit()
  expect_error(
    gllvmTMB::check_identifiability(fit, sim_reps = 1L),
    "sim_reps"
  )
  expect_error(
    gllvmTMB::check_identifiability(fit, sim_reps = NA_integer_),
    "sim_reps"
  )
})

test_that("check_identifiability() rejects alpha outside (0, 1)", {
  fit <- make_mock_fit()
  expect_error(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L, alpha = 0),
    "alpha"
  )
  expect_error(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L, alpha = 1),
    "alpha"
  )
  expect_error(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L, alpha = -0.1),
    "alpha"
  )
})

test_that("check_identifiability() errors on non-Gaussian fits (V1 scope)", {
  ## family_id 1 = binomial
  fit <- make_mock_fit(family_id_vec = c(0L, 1L, 0L))
  expect_error(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L),
    class = "gllvmTMB_check_identifiability_nongaussian"
  )
})

test_that("check_identifiability() warns when parallel = TRUE", {
  ## Reach the warn-then-error path: warn first, then error on the
  ## Gaussian-only scope check.
  fit <- make_mock_fit(family_id_vec = c(0L, 1L))
  expect_warning(
    expect_error(
      gllvmTMB::check_identifiability(fit, sim_reps = 10L, parallel = TRUE),
      class = "gllvmTMB_check_identifiability_nongaussian"
    ),
    "parallel"
  )
})

## ---- internal helper: Procrustes alignment recovers orthogonal rotations ----

test_that(".procrustes_align recovers a known orthogonal rotation", {
  ## Construct a T x d target, rotate it by a known orthogonal Q, then
  ## verify the helper aligns back to within numerical noise.
  set.seed(11L)
  target <- matrix(rnorm(12L), 4L, 3L)
  ## Random orthogonal matrix via QR decomposition.
  Q <- qr.Q(qr(matrix(rnorm(9L), 3L, 3L)))
  rotated <- target %*% Q
  aligned <- gllvmTMB:::.procrustes_align(target, rotated)
  expect_equal(aligned, target, tolerance = 1e-8)
})

test_that(".procrustes_align is a no-op when target/estimate have mismatched dims", {
  set.seed(12L)
  target <- matrix(rnorm(12L), 4L, 3L)
  est <- matrix(rnorm(8L), 4L, 2L)
  ## Mismatched dims -> returned unchanged.
  out <- gllvmTMB:::.procrustes_align(target, est)
  expect_equal(out, est)
})

## ---- smoke + structure on a tiny Gaussian fit ---------------------------

test_that("check_identifiability() returns the expected list structure (smoke test)", {
  skip_on_cran()
  skip_on_ci()  ## sim-refit loop is too slow for routine CI; gate to local
  fit <- make_tiny_gaussian_fit()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L,
                                    seed = 42L, verbose = FALSE)
  ))
  expect_s3_class(res, "gllvmTMB_identifiability")
  expect_named(res,
               c("recovery", "loadings", "hessian", "flags",
                 "call", "n_reps", "n_converged"))
  expect_equal(res$n_reps, 10L)
  expect_true(res$n_converged >= 1L)
  expect_true(is.character(res$flags))
})

test_that("check_identifiability() $recovery has the documented columns", {
  skip_on_cran()
  skip_on_ci()
  fit <- make_tiny_gaussian_fit()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L,
                                    seed = 7L, verbose = FALSE)
  ))
  expected_cols <- c("param", "tier", "truth", "mean_est",
                     "bias", "rmse", "sd_est", "coverage_95",
                     "n_converged")
  expect_true(all(expected_cols %in% colnames(res$recovery)))
  ## Recovery rows are non-empty for a converged smoke run.
  expect_gt(nrow(res$recovery), 0L)
  ## Tier column takes values from the documented set.
  expect_true(all(res$recovery$tier %in%
                    c("B", "W", "phy", "fixed")))
})

test_that("check_identifiability() $loadings is a named list of T x d matrices", {
  skip_on_cran()
  skip_on_ci()
  fit <- make_tiny_gaussian_fit()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L,
                                    seed = 19L, verbose = FALSE)
  ))
  ## Tier B should be present (the fixture has d_B = 2).
  expect_true("B" %in% names(res$loadings))
  M_B <- res$loadings$B
  expect_true(is.matrix(M_B))
  expect_equal(nrow(M_B), 3L)   # Tn = 3 traits
  expect_equal(ncol(M_B), 2L)   # d_B = 2
  ## All entries are non-negative (mean-abs residuals).
  expect_true(all(is.finite(M_B)))
  expect_true(all(M_B >= 0))
})

test_that("check_identifiability() $hessian has one row per replicate with documented columns", {
  skip_on_cran()
  skip_on_ci()
  fit <- make_tiny_gaussian_fit()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L,
                                    seed = 3L, verbose = FALSE)
  ))
  expect_s3_class(res$hessian, "data.frame")
  expect_equal(nrow(res$hessian), 10L)
  expected_hess_cols <- c("replicate", "min_eig", "max_eig",
                          "condition_number", "n_zero_eig",
                          "pdHess")
  expect_true(all(expected_hess_cols %in% colnames(res$hessian)))
})

test_that("check_identifiability() $flags is a subset of the documented set", {
  skip_on_cran()
  skip_on_ci()
  fit <- make_tiny_gaussian_fit()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L,
                                    seed = 31L, verbose = FALSE)
  ))
  documented_flags <- c("rank_deficient", "loading_collapse",
                        "slow_inference", "converged_rate < 0.9")
  expect_true(all(res$flags %in% documented_flags))
})

## ---- print method --------------------------------------------------------

test_that("print.gllvmTMB_identifiability() runs without error", {
  skip_on_cran()
  skip_on_ci()
  fit <- make_tiny_gaussian_fit()
  res <- suppressMessages(suppressWarnings(
    gllvmTMB::check_identifiability(fit, sim_reps = 10L,
                                    seed = 5L, verbose = FALSE)
  ))
  ## cli::cli_h1 etc. write to stderr, so expect_output (stdout) cannot
  ## see them. The data-frame portion (printed via base::print()) does
  ## go to stdout, so we verify both: the cli messages fire and the
  ## tabular output appears.
  expect_message(print(res), "gllvmTMB identifiability check")
  expect_output(print(res), "Lambda_B")
})
