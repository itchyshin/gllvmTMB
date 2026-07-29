## Oracle for the VGH -> Laplace packing transform.
##
## Fixtures are generated INLINE (see the note at the top of test-vgh-oracle.R:
## nothing here may read from docs/, which .Rbuildignore excludes).
##
## The transform maps VGH's dense Lambda + amean onto the template's packed
## theta_rr_* and rank x units z_*. Every assertion below corresponds to a way
## the mapping can be wrong while still producing plausible-looking output.

.vgh_ws_fixture <- function(n_traits = 6L, rank = 2L, n_units = 40L,
                            seed = 20260730L) {
  set.seed(seed)
  structure(
    list(
      Lambda = matrix(stats::rnorm(n_traits * rank), n_traits, rank),
      amean  = matrix(stats::rnorm(n_units * rank), n_units, rank),
      q = rank, T = n_traits, N = n_units
    ),
    class = "vgh_fit"
  )
}

test_that("the packing transform leaves the linear predictor untouched", {
  fit <- .vgh_ws_fixture()
  st <- .vgh_to_laplace_start(fit)

  eta_before <- tcrossprod(fit$amean, fit$Lambda)
  ## Reconstruct from the SHIPPED z, not from the internal scores -- that is
  ## what the template will actually consume.
  eta_after <- tcrossprod(t(st$z), st$loadings)

  expect_equal(eta_after, eta_before, tolerance = 1e-12)
  expect_lt(st$diagnostics$eta_rel_dev, 1e-12)
})

test_that("G = Lambda Lambda' is preserved, and the block is triangular", {
  fit <- .vgh_ws_fixture()
  st <- .vgh_to_laplace_start(fit)

  expect_equal(tcrossprod(st$loadings), tcrossprod(fit$Lambda),
               tolerance = 1e-12)

  rank <- ncol(fit$Lambda)
  block <- st$loadings[seq_len(rank), seq_len(rank), drop = FALSE]
  expect_lt(max(abs(block[row(block) < col(block)])), 1e-12)
  expect_true(all(diag(block) >= 0))
})

test_that("packed length is the reduced form and z is rank x units", {
  n_traits <- 6L; rank <- 2L; n_units <- 40L
  fit <- .vgh_ws_fixture(n_traits, rank, n_units)
  st <- .vgh_to_laplace_start(fit)

  expect_length(st$theta_rr, n_traits * rank - rank * (rank - 1L) / 2L)
  ## The dense layout VGH itself uses would be longer; a start of that length
  ## is silently skipped by .gllvmTMB_apply_start_from() rather than rejected.
  expect_false(length(st$theta_rr) == n_traits * rank)
  expect_identical(dim(st$z), c(rank, n_units))
})

test_that("the transform rejects malformed input", {
  fit <- .vgh_ws_fixture()

  bad_rank <- fit
  bad_rank$amean <- bad_rank$amean[, 1L, drop = FALSE]
  expect_error(.vgh_to_laplace_start(bad_rank), "Rank mismatch")

  bad_finite <- fit
  bad_finite$Lambda[1L, 1L] <- NA_real_
  expect_error(.vgh_to_laplace_start(bad_finite), "non-finite")

  expect_error(.vgh_to_laplace_start(list()), "vgh_fit")
})

test_that("a Lambda-only rotation moves eta -- the control that proves the rest", {
  ## .va_r3_rotate_to_lower_triangular() rotates Lambda WITHOUT its scores.
  ## If this control ever stops firing, every invariance assertion above is
  ## vacuous, because the oracle would be unable to see the failure it exists
  ## to catch.
  fit <- .vgh_ws_fixture()
  rotated <- .va_r3_rotate_to_lower_triangular(fit$Lambda, ncol(fit$Lambda))
  skip_if(is.null(rotated), "rotation helper declined this fixture")

  eta_true <- tcrossprod(fit$amean, fit$Lambda)
  eta_bad <- tcrossprod(fit$amean, rotated)
  expect_gt(max(abs(eta_bad - eta_true)), 1e-6)
})

test_that("the transform handles a REAL vgh_fit, not just a fixture", {
  ## A synthetic Lambda/amean pair proves the linear algebra. Only a live fit
  ## proves the transform matches VGH's actual return contract and the numeric
  ## ranges it produces.
  set.seed(11L)
  n <- 60L; n_traits <- 5L; rank <- 2L

  lambda_true <- matrix(stats::rnorm(n_traits * rank, 0, 0.7), n_traits, rank)
  u <- matrix(stats::rnorm(n * rank), n, rank)
  beta <- stats::rnorm(n_traits, 0, 0.4)
  eta <- matrix(beta, n, n_traits, byrow = TRUE) + u %*% t(lambda_true)
  y <- eta + matrix(stats::rnorm(n * n_traits, 0, 0.5), n, n_traits)

  fit <- .vgh_fit(
    y = as.numeric(t(y)),
    n_trials = rep(1L, n * n_traits),
    X = matrix(1, n * n_traits, 1),
    unit_id = rep(seq_len(n), each = n_traits),
    trait_id = rep(seq_len(n_traits), times = n),
    N = n, T = n_traits, q = rank,
    family = "gaussian_anchor", link = "identity",
    gaussian_sd = 0.5, maxit = 60L
  )
  expect_s3_class(fit, "vgh_fit")

  st <- .vgh_to_laplace_start(fit)

  expect_equal(tcrossprod(t(st$z), st$loadings),
               tcrossprod(fit$amean, fit$Lambda),
               tolerance = 1e-12)
  expect_length(st$theta_rr, n_traits * rank - rank * (rank - 1L) / 2L)
  expect_identical(dim(st$z), c(rank, n))
})

test_that("a silently-skipped warm start is detected", {
  fit <- .vgh_ws_fixture()
  st <- .vgh_to_laplace_start(fit)

  landed <- list(theta_rr_B = st$theta_rr, z_B = st$z)
  expect_true(.vgh_assert_start_landed(landed, st, "theta_rr_B", "z_B"))

  ## What the parameter list looks like when the copy was skipped: the
  ## template defaults are still in place and the fit proceeds regardless.
  skipped <- list(theta_rr_B = rep(0.5, length(st$theta_rr)),
                  z_B = matrix(0, nrow(st$z), ncol(st$z)))
  expect_error(.vgh_assert_start_landed(skipped, st, "theta_rr_B", "z_B"),
               "did not land")

  expect_error(.vgh_assert_start_landed(list(), st, "theta_rr_B", "z_B"),
               "no entry named")
})
