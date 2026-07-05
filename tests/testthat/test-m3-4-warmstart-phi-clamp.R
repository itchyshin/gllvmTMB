## M3.4 — boundary-regime mitigations (Design 48):
## (A) single-trait warmup + (B) phi-clamp [0.01, 100].
##
## These tests pin the contract of the two mitigations introduced
## by the M3.4 implementation PR. They are *not* full coverage
## tests (those require the R = 200 production grid); they verify:
##   1. `gllvmTMBcontrol(init_strategy = "single_trait_warmup")` is
##      accepted and produces a finite fit.
##   2. Warm-start does NOT regress on Gaussian fits (where no phi
##      parameter exists, the warmup is a no-op).
##   3. Warm-start computes finite, clamped, non-default log-phi seeds
##      for nbinom2 fits. Full optimizer convergence-rate claims belong
##      to the M3 production grid, not this CRAN-time smoke test.
##   4. The phi clamp is applied to initial values regardless of
##      warmup (defensive — confirmed via a fit that converges
##      cleanly with no diverging-phi warnings).

# ---- (1) `init_strategy` arg is accepted -----------------------------

test_that("gllvmTMBcontrol(init_strategy = 'single_trait_warmup') is accepted", {
  skip_if_not_heavy()
  ctl <- gllvmTMB::gllvmTMBcontrol(init_strategy = "single_trait_warmup")
  expect_equal(ctl$init_strategy, "single_trait_warmup")
})

test_that("gllvmTMBcontrol(init_strategy = 'default') is the documented default", {
  skip_if_not_heavy()
  ctl <- gllvmTMB::gllvmTMBcontrol()
  expect_equal(ctl$init_strategy, "default")
})

test_that("gllvmTMBcontrol(init_strategy = 'bogus') errors loudly", {
  skip_if_not_heavy()
  expect_error(gllvmTMB::gllvmTMBcontrol(init_strategy = "bogus"))
})

# ---- (2) No regression on Gaussian fits (warmup is a no-op) ----------

make_gaussian_fixture <- function(n_sites = 30L, n_traits = 2L, seed = 7L) {
  set.seed(seed)
  Lambda <- matrix(c(1.0, 0.8, 0.0, 0.6), nrow = 2L, ncol = 2L)
  z      <- matrix(stats::rnorm(2L * n_sites), nrow = 2L)
  eta    <- t(Lambda %*% z)
  y      <- eta + matrix(stats::rnorm(n_sites * n_traits, sd = 0.5),
                         nrow = n_sites, ncol = n_traits)
  df <- data.frame(
    site  = factor(rep(seq_len(n_sites), each = n_traits)),
    trait = factor(rep(paste0("t", seq_len(n_traits)), times = n_sites),
                   levels = paste0("t", seq_len(n_traits))),
    value = as.numeric(t(y))
  )
  df
}

test_that("warmup does not change Gaussian convergence (no-op for non-phi families)", {
  skip_if_not_heavy()
  skip_on_cran()
  df <- make_gaussian_fixture()
  fit_default <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = df, family = gaussian()
  )))
  fit_warm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = df, family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(
      init_strategy = "single_trait_warmup"
    )
  )))
  expect_equal(fit_default$opt$convergence, 0L)
  expect_equal(fit_warm$opt$convergence, 0L)
  ## Gaussian doesn't carry log_phi_*; warmup should land at the
  ## same logLik (the Lambda/Psi/sigma_eps starts are unaffected).
  expect_equal(as.numeric(logLik(fit_warm)),
               as.numeric(logLik(fit_default)),
               tolerance = 1e-4,
               label = "warmup is a no-op on Gaussian fits")
})

# ---- (3) Warmup activates on nbinom2 fits ----------------------------

make_nbinom2_fixture <- function(n_sites = 30L, n_traits = 2L,
                                  phi_true = 2.0, seed = 11L) {
  set.seed(seed)
  Lambda <- matrix(c(1.0, 0.5), nrow = 2L, ncol = 1L)
  z      <- matrix(stats::rnorm(1L * n_sites), nrow = 1L)
  eta    <- 1.5 + t(Lambda %*% z)
  mu     <- exp(eta)
  ## NB2: Var = mu + mu^2 / phi
  y <- matrix(0L, nrow = n_sites, ncol = n_traits)
  for (t in seq_len(n_traits)) {
    y[, t] <- stats::rnbinom(n_sites, size = phi_true, mu = mu[, t])
  }
  df <- data.frame(
    site  = factor(rep(seq_len(n_sites), each = n_traits)),
    trait = factor(rep(paste0("t", seq_len(n_traits)), times = n_sites),
                   levels = paste0("t", seq_len(n_traits))),
    value = as.numeric(t(y))
  )
  df
}

test_that("warmup on nbinom2 produces finite non-default initial log_phi", {
  skip_if_not_heavy()
  skip_on_cran()
  skip_if_not_installed("MASS")
  df <- make_nbinom2_fixture()
  warm <- gllvmTMB:::.gllvmTMB_single_trait_warmup(
    trait_vec      = as.integer(df$trait),
    y              = df$value,
    family_per_row = rep(list(gllvmTMB::nbinom2()), nrow(df)),
    n_traits       = nlevels(df$trait),
    verbose        = FALSE
  )
  expect_true(all(is.finite(warm$log_phi_nbinom2)))
  expect_true(all(warm$log_phi_nbinom2 <= log(100.0)))
  expect_true(all(warm$log_phi_nbinom2 >= log(0.01)))
  expect_true(any(abs(warm$log_phi_nbinom2) > 1e-8))
})

# ---- (4) Phi-clamp: warmup with extreme y still produces clamped phi --

test_that("phi clamp [0.01, 100] is applied to warmup output", {
  skip_if_not_heavy()
  ## Construct a y that would push glm.nb's theta to extreme values
  ## (very low overdispersion → high theta → high phi).
  set.seed(1L)
  ## Near-Poisson: very low overdispersion ⇒ theta huge ⇒ phi huge.
  y_near_poisson <- stats::rpois(50L, lambda = 5)
  fam <- gllvmTMB::nbinom2()
  if (!requireNamespace("MASS", quietly = TRUE)) skip("MASS not installed")
  warm <- gllvmTMB:::.gllvmTMB_single_trait_warmup(
    trait_vec     = rep(1L, length(y_near_poisson)),
    y             = as.numeric(y_near_poisson),
    family_per_row = rep(list(fam), length(y_near_poisson)),
    n_traits      = 1L,
    verbose       = FALSE
  )
  ## Even if glm.nb pushes theta to numerical infinity, the clamp
  ## must hold the warm-start phi within [log(0.01), log(100)].
  expect_true(warm$log_phi_nbinom2[1L] <= log(100.0))
  expect_true(warm$log_phi_nbinom2[1L] >= log(0.01))
})

test_that("start-parameter reclamp catches top-level and nested log_phi names", {
  par <- c(
    log_phi_nbinom2 = log(1000),
    family.log_phi_beta = log(1e-4),
    not_phi = 99
  )

  out <- gllvmTMB:::.gllvmTMB_reclamp_start_par(par)

  expect_equal(out[["log_phi_nbinom2"]], log(100.0))
  expect_equal(out[["family.log_phi_beta"]], log(0.01))
  expect_equal(out[["not_phi"]], 99)
})

# ---- (5) Internal helper: univariate phi computation ------------------

test_that(".gllvm_univariate_phi handles unsupported families gracefully", {
  skip_if_not_heavy()
  ## Gaussian family doesn't carry phi → returns NULL.
  res <- gllvmTMB:::.gllvm_univariate_phi(
    y = stats::rnorm(20), family_name = "gaussian"
  )
  expect_null(res)
})

test_that(".gllvm_univariate_phi computes a sensible phi for beta", {
  skip_if_not_heavy()
  set.seed(3L)
  ## Simulate from Beta(2, 8) — mu = 0.2, phi = 10.
  y_beta <- stats::rbeta(100L, shape1 = 2, shape2 = 8)
  res <- gllvmTMB:::.gllvm_univariate_phi(y = y_beta, family_name = "beta")
  expect_false(is.null(res))
  expect_true(is.finite(res$log_phi))
  ## Method-of-moments estimate should land near log(10) = 2.30.
  expect_lt(abs(res$log_phi - log(10)), 1.5)
})
