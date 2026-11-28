## Issue #1020: LA-MSPL cloglog fits with many units aborted with an O(1)
## penalty-off decomposition residual.
##
## The MSPL Bernoulli kernel formed log(1 - p) = -exp(eta) from an eta that
## is floored at log(1e-4) for the y = 1 series branch. A y = 0 row therefore
## contributed a constant -1e-4, with zero gradient and zero curvature, for
## every eta below log(1e-4). At low prevalence the conditional modes of the
## all-zero sites land on that kink, the inner Newton solve oscillates across
## it and exits early, and the Laplace objective depends on which side the
## solve stops. Only the kernel-level block is a platform-robust red proof;
## the two end-to-end cases depend on the optimiser path on the old kernel.

.cloglog_1020_b1_cell <- function(cell_index, outer_id, n_site, q) {
  ## Design 118 B1 campaign DGP, restated so the regression does not depend
  ## on the campaign harness.
  withr::local_seed(
    218000000L + cell_index * 1000000L + outer_id,
    .rng_kind = "Mersenne-Twister", .rng_normal_kind = "Inversion",
    .rng_sample_kind = "Rejection"
  )
  n_trait <- 3L
  site <- factor(rep(sprintf("s%03d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%02d", seq_len(n_trait)), n_site),
    levels = sprintf("t%02d", seq_len(n_trait))
  )
  z <- matrix(stats::rnorm(n_site * q), n_site, q)
  b <- log(-log1p(-0.03)) + seq(-0.525, 0.525, length.out = n_trait)
  base <- c(0.8, -0.55, 0.35)
  lambda <- vapply(seq_len(q), function(j) {
    base[((seq_len(3L) - 1L + (j - 1L)) %% 3L) + 1L]
  }, numeric(n_trait))
  ti <- as.integer(trait)
  si <- as.integer(site)
  eta <- b[ti] + rowSums(lambda[ti, , drop = FALSE] * z[si, , drop = FALSE])
  data.frame(
    site = site, trait = trait,
    y = stats::rbinom(length(eta), 1L, -expm1(-exp(eta)))
  )
}

.cloglog_1020_fit <- function(dat, q) {
  gllvmTMB(
    stats::as.formula(sprintf(
      "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)", q
    )),
    data = dat, unit = "site", family = stats::binomial("cloglog"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    ),
    silent = TRUE
  )
}

## Re-solve the inner problem from a cold start (all random effects 0) at
## the selected estimate.
.cloglog_1020_cold_objective <- function(obj, par) {
  obj$env$last.par.best[obj$env$random] <- 0
  as.numeric(obj$fn(par))
}

.cloglog_1020_expect_clean_mode <- function(fit) {
  objective <- as.numeric(fit$opt$objective)
  expect_lt(abs(fit$mspl$decomposition_residual), 1e-7 * (1 + abs(objective)))
  obj <- fit$tmb_obj
  rnd <- obj$env$random
  ## The inner mode is a stationary point, not an early exit from an
  ## oscillation across a kink.
  expect_lt(max(abs(obj$env$f(obj$env$last.par, order = 1)[rnd])), 1e-6)
  ## The objective does not depend on where the inner solve starts.
  expect_equal(.cloglog_1020_cold_objective(obj, fit$opt$par), objective,
               tolerance = 1e-8)
}

test_that("MSPL cloglog y = 0 rows keep their slope below log(1e-4) (#1020)", {
  dat <- .cloglog_1020_b1_cell(2L, 1L, n_site = 12L, q = 1L)
  fit <- suppressMessages(suppressWarnings(.cloglog_1020_fit(dat, q = 1L)))
  tape <- fit$mspl$unpenalized_tmb_obj
  par <- tape$env$last.par
  par[tape$env$random] <- 0
  b_idx <- which(names(par) == "b_fix")
  expect_length(b_idx, nlevels(dat$trait))
  n0 <- as.numeric(tapply(dat$y == 0, dat$trait, sum))
  n1 <- as.numeric(tapply(dat$y == 1, dat$trait, sum))
  for (b in c(-9, -9.21, -9.3, -12, -20, -30)) {
    par[b_idx] <- b
    grad_b <- as.numeric(tape$env$f(par, order = 1)[b_idx])
    ## d(-loglik)/d eta: exp(eta) for y = 0, and
    ## -exp(eta) * exp(-exp(eta)) / (1 - exp(-exp(eta))) for y = 1.
    a <- exp(b)
    expected <- n0 * a + n1 * (-a * exp(-a) / -expm1(-a))
    ## Element-wise ratio: expect_equal() scales by mean(|expected|), which
    ## would let an O(1) y = 1 slope hide a missing O(1e-9) y = 0 slope.
    expect_equal(grad_b / expected, rep(1, length(expected)),
                 tolerance = 1e-8, info = sprintf("eta = %g", b))
  }
  nll_at <- function(b) {
    par[b_idx] <- b
    as.numeric(tape$env$f(par))
  }
  ## Value: -log(1 - p) = exp(eta) for every y = 0 row.
  expect_equal(
    nll_at(-12) - nll_at(-20),
    sum(n0) * (exp(-12) - exp(-20)) -
      sum(n1) * (log(-expm1(-exp(-12))) - log(-expm1(-exp(-20)))),
    tolerance = 1e-10
  )
})

test_that("cloglog LA-MSPL at n_site = 192 has a clean, reproducible inner mode (#1020)", {
  skip_on_cran()
  ## B124 outer 1: cloglog, pi = 0.03, n_site = 192, n_trait = 3, q = 1.
  fit <- suppressMessages(suppressWarnings(
    .cloglog_1020_fit(.cloglog_1020_b1_cell(124L, 1L, 192L, 1L), q = 1L)
  ))
  expect_s3_class(fit, "gllvmTMB_mspl")
  .cloglog_1020_expect_clean_mode(fit)
})

test_that("cloglog LA-MSPL with q = 2 at n_site = 96 has a clean, reproducible inner mode (#1020)", {
  skip_on_cran()
  ## B048 outer 2: inner dimension n_site * q = 192.
  fit <- suppressMessages(suppressWarnings(
    .cloglog_1020_fit(.cloglog_1020_b1_cell(48L, 2L, 96L, 2L), q = 2L)
  ))
  expect_s3_class(fit, "gllvmTMB_mspl")
  .cloglog_1020_expect_clean_mode(fit)
})
