## Regression test for the VGH engine's phi_pool option (dev/vgh/vgh-engine.R).
## The engine estimates one gaussian dispersion PER TRAIT by default; phi_pool
## constrains that to a single shared value, matching the Laplace engine's one
## scalar residual SD.  This lives in dev/, outside the package namespace, so
## the test must source it and skip gracefully when it is unavailable (dev/ is
## .Rbuildignore'd -- same pattern as test-m3-grid-summary.R /
## test-lv-wald-coverage-harness.R).

source_vgh_engine <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("dev", "vgh", "vgh-engine.R"),
    file.path("..", "..", "dev", "vgh", "vgh-engine.R"),
    if (!is.na(workspace)) file.path(workspace, "dev", "vgh", "vgh-engine.R")
  )
  dev_file <- candidates[file.exists(candidates)][1]
  testthat::skip_if(
    is.na(dev_file),
    "dev/vgh/vgh-engine.R is unavailable in this source-tarball context"
  )
  source(dev_file, local = parent.frame())
}

## Heteroscedastic gaussian fixture: phi_j spans an 8x range (0.25 to 2), so
## pooled and unpooled dispersion estimates are genuinely distinguishable --
## a homoscedastic truth would make phi_pool a no-op and the test vacuous.
## d = 2L: vgh_update_model()'s R <- Avec + t(apply(amean, 1L, ...)) line has a
## PRE-EXISTING shape bug at d == 1L (apply() simplifies a length-1 FUN result
## to a plain vector, so t() transposes to the wrong orientation before the
## `if (d == 1L)` correction below it ever runs) -- unrelated to phi_pool and
## reproducible on an unmodified checkout, so this fixture uses d = 2L to stay
## on the working code path rather than papering over that defect here.
.vgh_pool_fixture <- function(n = 200L, m = 5L, d = 2L, seed = 20260730L) {
  set.seed(seed)
  phi_true <- seq(0.25, 2, length.out = m)
  Beta0 <- matrix(stats::rnorm(m), 1L, m)
  Lambda0 <- matrix(stats::rnorm(m * d, 0, 0.7), m, d)
  U0 <- matrix(stats::rnorm(n * d), n, d)
  X <- matrix(1, n, 1L)
  eta <- X %*% Beta0 + U0 %*% t(Lambda0)
  noise <- matrix(stats::rnorm(n * m), n, m) *
    matrix(sqrt(phi_true), n, m, byrow = TRUE)
  list(Y = eta + noise, X = X, d = d, phi_true = phi_true)
}

test_that("phi_pool shares one dispersion across traits, matches an independent recomputation, and keeps the ELBO monotone", {
  source_vgh_engine()
  fx <- .vgh_pool_fixture()
  Y <- fx$Y; X <- fx$X

  fit_pool   <- vgh_fit(Y, X, d = fx$d, family = "gaussian",
                        phi_pool = TRUE, trace_elbo = TRUE)
  fit_nopool <- vgh_fit(Y, X, d = fx$d, family = "gaussian",
                        phi_pool = FALSE)

  # (b) pooled phi is exactly uniform ...
  expect_lt(diff(range(fit_pool$phi)), 1e-10)
  # (c) ... and unpooled phi is not -- this arm is what proves the test can fail.
  expect_gt(diff(range(fit_nopool$phi)), 0.1)

  # the returned metadata records what actually ran
  expect_true(fit_pool$phi_pool)
  expect_false(fit_nopool$phi_pool)

  # (d) the pooled value equals the pooled residual variance, recomputed here
  # from the returned Beta/Lambda/amean/Avec -- NOT by re-calling
  # vgh_update_phi, which would only show the function agrees with itself.
  L2 <- t(apply(fit_pool$Lambda, 1L, function(l) as.vector(tcrossprod(l))))
  M_check  <- X %*% fit_pool$Beta + fit_pool$amean %*% t(fit_pool$Lambda)
  S2_check <- fit_pool$Avec %*% t(L2)
  phi_floor <- 1e-8   # mirrors vgh_update_phi()'s default; does not bind here
  phi_expected <- max(mean((Y - M_check)^2 + S2_check), phi_floor)
  expect_equal(fit_pool$phi, rep(phi_expected, ncol(Y)), tolerance = 1e-8)

  # (e) pooling is a constraint on the phi block; the optimiser must still
  # ascend the ELBO every sweep.
  expect_true(all(diff(fit_pool$elbo_path) >= -1e-8))
})
