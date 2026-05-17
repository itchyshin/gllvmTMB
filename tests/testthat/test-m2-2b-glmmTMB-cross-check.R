## M2.2-B — glmmTMB cross-package light sanity check.
##
## Per maintainer 2026-05-17 cross-package policy
## (docs/design/41-binary-completeness.md §3 "Cross-package light
## sanity checks"): one shared fixture per comparator, no
## replicates, no grid. Big tests live at Phase 5.5.
##
## Shared fixture: 2-trait stacked binomial-logit data with a
## single shared random intercept per site. Both engines see the
## same long-format data; both use the lme4-style `(1 | site)`
## random-intercept term.
##
##   glmmTMB:  value ~ 0 + trait + (1 | site), family = binomial()
##   gllvmTMB: value ~ 0 + trait + (1 | site), family = binomial()
##
## Per-trait intercepts come back from `tidy()`/`fixef()`; the
## shared random-intercept SD comes from VarCorr (glmmTMB) and
## from the variance-component output (gllvmTMB).
##
## Tolerances: gllvmTMB and glmmTMB share the TMB + Laplace
## lineage, so we expect tight agreement at n = 200 — within
## ~0.1-0.2 absolute on intercepts, ~0.1-0.2 on the random
## intercept SD. We use generous bounds (0.25 / 0.3) so a single
## noisy replicate doesn't flake the test.

skip_if_glmmTMB_missing <- function() {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    skip("glmmTMB not installed (Suggests-only package).")
  }
}

# ---- Shared 2-trait binomial-logit DGP ------------------------------

build_two_trait_logit_data <- function(n_sites = 200L,
                                       alpha = c(0.3, -0.4),
                                       sigma_u = 0.8,
                                       seed = 20260607L) {
  set.seed(seed)
  u <- stats::rnorm(n_sites, mean = 0, sd = sigma_u)
  y1 <- stats::rbinom(n_sites, size = 1L,
                      prob = stats::plogis(alpha[1] + u))
  y2 <- stats::rbinom(n_sites, size = 1L,
                      prob = stats::plogis(alpha[2] + u))
  data.frame(
    site  = factor(rep(seq_len(n_sites), 2L)),
    trait = factor(rep(c("t1", "t2"), each = n_sites)),
    value = c(y1, y2)
  )
}

# ---- (1) Fixed-effect intercepts agree across packages --------------

test_that("gllvmTMB and glmmTMB agree on per-trait intercepts for binomial(logit) + (1|site) fit (M2.2-B / cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_logit_data(n_sites = 200L)

  ## glmmTMB reference fit.
  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::binomial()
  )))
  glmm_betas <- as.numeric(glmmTMB::fixef(fit_glmm)$cond)
  names(glmm_betas) <- names(glmmTMB::fixef(fit_glmm)$cond)

  ## gllvmTMB fit on the same formula + data.
  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::binomial()
  )))
  expect_equal(fit_gllvm$opt$convergence, 0L,
               info = "gllvmTMB 2-trait binomial fit did not converge")

  td <- suppressMessages(gllvmTMB::tidy(fit_gllvm, "fixed", conf.int = FALSE))
  gllvm_t1 <- td$estimate[td$term == "traitt1"]
  gllvm_t2 <- td$estimate[td$term == "traitt2"]
  glmm_t1  <- glmm_betas["traitt1"]
  glmm_t2  <- glmm_betas["traitt2"]

  expect_lt(abs(gllvm_t1 - glmm_t1), 0.25,
            label = sprintf("trait t1 intercept: gllvm = %.3f, glmm = %.3f",
                            gllvm_t1, glmm_t1))
  expect_lt(abs(gllvm_t2 - glmm_t2), 0.25,
            label = sprintf("trait t2 intercept: gllvm = %.3f, glmm = %.3f",
                            gllvm_t2, glmm_t2))
})

# ---- (2) Shared random-intercept SD agrees within tolerance ---------

test_that("gllvmTMB and glmmTMB agree on shared random-intercept SD (M2.2-B / cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_logit_data(n_sites = 200L)

  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::binomial()
  )))
  glmm_vc <- glmmTMB::VarCorr(fit_glmm)$cond$site
  glmm_sd <- as.numeric(sqrt(diag(as.matrix(glmm_vc))))[1]

  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = stats::binomial()
  )))

  ## gllvmTMB's tidy(ran_pars) does not currently surface the bare
  ## `(1|site)` lme4-style random-intercept SD (returns NULL when
  ## no `latent()` / `unique()` term is in the formula). Pull
  ## directly from the report: `log_sigma_re_int` is the natural-
  ## log SD of the random intercept block.
  if (is.null(fit_gllvm$report$log_sigma_re_int)) {
    skip("gllvmTMB report does not expose log_sigma_re_int; cross-check on the bare `(1|site)` random-intercept SD needs an alternative entry point.")
  }
  gllvm_sd <- as.numeric(exp(fit_gllvm$report$log_sigma_re_int))[1L]

  expect_lt(abs(gllvm_sd - glmm_sd), 0.3,
            label = sprintf("random-int SD: gllvm = %.3f, glmm = %.3f",
                            gllvm_sd, glmm_sd))
})
