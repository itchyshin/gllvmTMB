## McGillycuddy / glmmTMB-style residual starts.
## These tests pin the initialization contract only; convergence-rate claims
## belong to the M3 production grid, not CRAN-time unit tests.

test_that("residual factor helper seeds finite lower-triangular rr starts", {
  set.seed(101)
  n_groups <- 24L
  n_traits <- 3L
  rank <- 2L
  Lambda <- matrix(c(0.8, 0.4, -0.2,
                     0.0, 0.7,  0.3),
                   nrow = n_traits, ncol = rank)
  scores <- matrix(stats::rnorm(n_groups * rank), nrow = n_groups)
  R <- scores %*% t(Lambda) +
    matrix(stats::rnorm(n_groups * n_traits, sd = 0.05),
           nrow = n_groups, ncol = n_traits)

  trait_id <- rep(seq_len(n_traits) - 1L, times = n_groups)
  group_id <- rep(seq_len(n_groups) - 1L, each = n_traits)
  resid <- as.numeric(t(R))

  start <- gllvmTMB:::.gllvmTMB_residual_factor_start(
    resid = resid,
    trait_id = trait_id,
    group_id = group_id,
    n_traits = n_traits,
    n_groups = n_groups,
    rank = rank,
    jitter.sd = 0,
    default_theta = rep(0, n_traits * rank - rank * (rank - 1L) / 2L)
  )

  expect_true(start$usable)
  expect_equal(length(start$theta_rr),
               n_traits * rank - rank * (rank - 1L) / 2L)
  expect_equal(dim(start$z), c(rank, n_groups))
  expect_equal(length(start$theta_diag), n_traits)
  expect_equal(dim(start$s), c(n_traits, n_groups))
  expect_true(all(is.finite(start$theta_rr)))
  expect_true(all(is.finite(start$z)))
  expect_true(all(is.finite(start$theta_diag)))
  expect_true(any(abs(start$theta_rr) > 1e-8))
  expect_true(any(abs(start$z) > 1e-8))
  expect_gte(start$theta_rr[1], 0)
  expect_gte(start$theta_rr[2], 0)
})

test_that("start_method = 'res' changes latent starts and still fits a small Gaussian model", {
  skip_on_cran()
  set.seed(202)
  n_sites <- 18L
  n_traits <- 2L
  Lambda <- matrix(c(0.9, 0.5), nrow = n_traits, ncol = 1L)
  z <- matrix(stats::rnorm(n_sites), nrow = n_sites, ncol = 1L)
  eta <- z %*% t(Lambda)
  y <- eta + matrix(stats::rnorm(n_sites * n_traits, sd = 0.25),
                   nrow = n_sites, ncol = n_traits)
  df <- data.frame(
    site = factor(rep(seq_len(n_sites), each = n_traits)),
    trait = factor(rep(paste0("t", seq_len(n_traits)), times = n_sites),
                   levels = paste0("t", seq_len(n_traits))),
    value = as.numeric(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = df,
    family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(
      start_method = list(method = "res", jitter.sd = 0)
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(any(abs(fit$tmb_params$z_B) > 1e-8))
  expect_true(any(abs(fit$tmb_params$s_B) > 1e-8))
  expect_false(isTRUE(all.equal(
    fit$tmb_params$theta_rr_B,
    c(0.5, rep(0, n_traits - 1L))
  )))
})

test_that("start_method = 'indep' fits a simpler GLMM and copies matching starts", {
  skip_on_cran()
  set.seed(303)
  n_sites <- 16L
  n_traits <- 2L
  u <- matrix(stats::rnorm(n_sites * n_traits, sd = 0.7),
              nrow = n_sites, ncol = n_traits)
  y <- u + matrix(stats::rnorm(n_sites * n_traits, sd = 0.2),
                  nrow = n_sites, ncol = n_traits)
  df <- data.frame(
    site = factor(rep(seq_len(n_sites), each = n_traits)),
    trait = factor(rep(paste0("t", seq_len(n_traits)), times = n_sites),
                   levels = paste0("t", seq_len(n_traits))),
    value = as.numeric(t(y))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = df,
    family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(
      start_method = list(method = "indep")
    )
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(any(abs(fit$tmb_params$s_B) > 1e-8))
  expect_true(any(abs(fit$tmb_params$theta_diag_B) > 1e-8))
  ## The independent warm start seeds the GLMM pieces but leaves the latent
  ## block at its historical default when no same-shaped rr block is available.
  expect_equal(fit$tmb_params$theta_rr_B, c(0.5, 0))
})

## ---------------------------------------------------------------------------
## Why there is no "res reaches the best optimum" test here.
##
## `start_method = "res"` DOES reach a worse optimum than the default start, and
## that is now settled behaviour rather than an open defect: the method was
## soft-deprecated in 0.6.0 on the strength of it, so a test asserting the
## contrary would be a permanently red assertion about a method on its way out.
##
## The measured behaviour, for the record. Over 89 fit-pairs -- Gaussian,
## Poisson and nbinom2, d = 1..3, three and five traits -- `res` was never
## materially better than the default start (best margins 0.068, 0.29, 0.66
## nats), was materially worse eight times (up to 14.65 nats), and was exactly
## neutral at d >= 2 (34/34 agreeing to ~1e-7). Every failure reported
## `convergence == 0` and `pdHess = TRUE` on both sides, and `n_init = 5`
## returned the same worse optimum 5/5.
##
## The failure concentrates at 3 traits, d = 1 -- exactly identified, so both
## starts land on a Heywood boundary and simply collapse a DIFFERENT trait:
##   default  psi = (1.009, 0.000, 1.275)   -logLik 5699.076
##   res      psi = (1.031, 0.821, 0.000)   -logLik 5700.919
## Which basin you land in is decided by the loadings, and seeding them from the
## residual covariance commits the optimiser to that matrix's leading direction.
## Not a noise problem: a start built from noise-free GLMM random-effect modes
## lands in the same wrong basin (measured, then reverted).
##
## That behaviour is deliberately NOT pinned as a unit test. It is a basin
## selection on a multimodal surface, so it is exactly the kind of thing a
## different BLAS or platform can flip -- a poor fit for a cross-OS suite. The
## evidence lives in re-runnable scripts instead:
##   dev/2026-07-27-res-nongaussian.R
##   dev/2026-07-27-res-nongaussian-d2.R
##   dev/2026-07-27-eval-indep-blup-start.R
##   docs/dev-log/after-task/2026-07-27-start-method-res-worse-optimum.md
##
## What IS pinned, in test-unique-family-deprecation.R: that the soft-deprecation
## warning fires once per session, that `res` still fits, and that no other start
## method triggers it. Delete this note with the method when `res` is removed.
##
## The related diagnostic gap -- a collapsed variance component passing every
## check because the threshold was absolute on the sd scale -- is fixed and
## covered by test-slope-boundary-flag.R.
## ---------------------------------------------------------------------------
