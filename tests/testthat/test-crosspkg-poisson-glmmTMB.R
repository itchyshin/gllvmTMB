## Cross-package agreement check — Poisson GLLVM vs glmmTMB.
##
## Mirrors the established cross-package policy used by the binomial
## cross-check (test-m2-2b-glmmTMB-cross-check.R): one shared fixture
## per comparator, no replicates, no grid. Big cross-package grids
## live at Phase 5.5.
##
## Comparable structure
## --------------------
## We pick a cell that *both* engines express with identical syntax:
## a single shared lme4-style random intercept `(1 | site)` across two
## Poisson(log) traits, sharing one site-level deviation. Each trait
## keeps its own intercept via `0 + trait`. Both engines see the same
## stacked-long data and the same formula:
##
##   glmmTMB:  value ~ 0 + trait + (1 | site), family = poisson()
##   gllvmTMB: value ~ 0 + trait + (1 | site), family = poisson()
##
## Per-trait intercepts come back from `tidy()` (gllvmTMB) and
## `fixef()` (glmmTMB); the shared random-intercept SD comes from the
## report quantity `exp(log_sigma_re_int)` (gllvmTMB) and from
## `VarCorr` (glmmTMB).
##
## Agreement band
## --------------
## gllvmTMB and glmmTMB share the TMB + Laplace lineage and minimise
## the *same* Laplace-approximated Poisson marginal log-likelihood
## over the *same* data, so this is a numerical-agreement check, not a
## statistical one. On this fixture (n = 200 sites) the engines match
## to ~1e-6 on intercepts and ~2e-7 on the random-intercept SD.
##
## We assert a documented absolute band of 0.05 on both the
## fixed-effect intercepts and the random-intercept SD. That is ~4-5
## orders of magnitude looser than the observed agreement, leaving
## ample headroom for optimiser / BLAS / platform jitter while still
## being far tighter than the binomial cross-check's 0.25 / 0.3 bands
## (logit-scale fits do not share an exact objective the way these two
## TMB-lineage Poisson fits do). If a future change broke the shared
## structure, a 0.05 band would still catch it.
##
## Honest-skip contract: if glmmTMB is not installed, or if the
## gllvmTMB report does not expose the bare `(1|site)` random-intercept
## SD, we skip() with a precise reason rather than fabricate agreement.

# ---- Shared 2-trait Poisson(log) DGP --------------------------------

build_two_trait_poisson_data <- function(n_sites = 200L,
                                         alpha = c(0.5, -0.2),
                                         sigma_u = 0.6,
                                         seed = 20260530L) {
  set.seed(seed)
  u  <- stats::rnorm(n_sites, mean = 0, sd = sigma_u)
  y1 <- stats::rpois(n_sites, lambda = exp(alpha[1] + u))
  y2 <- stats::rpois(n_sites, lambda = exp(alpha[2] + u))
  data.frame(
    site  = factor(rep(seq_len(n_sites), 2L)),
    trait = factor(rep(c("t1", "t2"), each = n_sites)),
    value = c(y1, y2)
  )
}

# ---- (1) Fixed-effect intercepts agree across packages --------------

test_that("gllvmTMB and glmmTMB agree on per-trait intercepts for poisson(log) + (1|site) fit (cross-package)", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")

  df <- build_two_trait_poisson_data(n_sites = 200L)

  ## glmmTMB reference fit.
  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::poisson()
  )))
  glmm_betas <- as.numeric(glmmTMB::fixef(fit_glmm)$cond)
  names(glmm_betas) <- names(glmmTMB::fixef(fit_glmm)$cond)

  ## gllvmTMB fit on the same formula + data.
  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::poisson()
  )))
  expect_equal(fit_gllvm$opt$convergence, 0L,
               info = "gllvmTMB 2-trait Poisson fit did not converge")

  td <- suppressMessages(gllvmTMB::tidy(fit_gllvm, "fixed", conf.int = FALSE))
  gllvm_t1 <- td$estimate[td$term == "traitt1"]
  gllvm_t2 <- td$estimate[td$term == "traitt2"]
  glmm_t1  <- glmm_betas["traitt1"]
  glmm_t2  <- glmm_betas["traitt2"]

  expect_lt(abs(gllvm_t1 - glmm_t1), 0.05,
            label = sprintf("trait t1 intercept: gllvm = %.5f, glmm = %.5f",
                            gllvm_t1, glmm_t1))
  expect_lt(abs(gllvm_t2 - glmm_t2), 0.05,
            label = sprintf("trait t2 intercept: gllvm = %.5f, glmm = %.5f",
                            gllvm_t2, glmm_t2))
})

# ---- (2) Shared random-intercept SD agrees within tolerance ---------

test_that("gllvmTMB and glmmTMB agree on shared random-intercept SD for poisson(log) (cross-package)", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")

  df <- build_two_trait_poisson_data(n_sites = 200L)

  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::poisson()
  )))
  glmm_vc <- glmmTMB::VarCorr(fit_glmm)$cond$site
  glmm_sd <- as.numeric(sqrt(diag(as.matrix(glmm_vc))))[1]

  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::poisson()
  )))
  expect_equal(fit_gllvm$opt$convergence, 0L,
               info = "gllvmTMB 2-trait Poisson fit did not converge")

  ## gllvmTMB's tidy(ran_pars) does not surface the bare `(1|site)`
  ## lme4-style random-intercept SD; pull it from the report instead,
  ## where `log_sigma_re_int` is the natural-log SD of the random-
  ## intercept block (REPORT()'d in src/gllvmTMB.cpp). If a future
  ## refactor removes it, skip with a precise reason rather than fake
  ## agreement on a quantity we cannot read.
  if (is.null(fit_gllvm$report$log_sigma_re_int)) {
    skip("gllvmTMB report does not expose log_sigma_re_int; cross-check on the bare `(1|site)` random-intercept SD needs an alternative entry point.")
  }
  gllvm_sd <- as.numeric(exp(fit_gllvm$report$log_sigma_re_int))[1L]

  expect_lt(abs(gllvm_sd - glmm_sd), 0.05,
            label = sprintf("random-int SD: gllvm = %.5f, glmm = %.5f",
                            gllvm_sd, glmm_sd))
})
