## Cross-package light sanity check: nbinom2 vs glmmTMB::nbinom2().
##
## Sibling of test-m2-2b-glmmTMB-cross-check.R (binomial-logit). Same
## cross-package policy (docs/design/41-binary-completeness.md §3
## "Cross-package light sanity checks"): one shared fixture per
## comparator, no replicates, no grid. Big tests live at Phase 5.5.
##
## Shared fixture: 2-trait stacked NB2-count data with a single shared
## random intercept per site. Both engines see the same long-format
## data and the lme4-style `(1 | site)` random-intercept term:
##
##   glmmTMB:  value ~ 0 + trait + (1 | site),
##             dispformula = ~ 0 + trait, family = nbinom2()
##   gllvmTMB: value ~ 0 + trait + (1 | site), family = nbinom2()
##
## Structure alignment (the part that needs care for NB2). gllvmTMB's
## nbinom2 fits a *per-trait* dispersion `phi` (one entry per trait;
## Var(y) = mu + mu^2 / phi). glmmTMB's default nbinom2 fits a *single
## shared* dispersion across all rows, which is a different model. To
## compare like with like we give glmmTMB `dispformula = ~ 0 + trait`,
## so both engines estimate one phi per trait. The conditional model
## (`value ~ 0 + trait + (1 | site)`) is then identical between
## packages.
##
## What we cross-check, and where each quantity comes from:
##   * per-trait log-mean intercepts -- gllvmTMB tidy("fixed"),
##     glmmTMB fixef()$cond;
##   * shared random-intercept SD -- gllvmTMB exp(log_sigma_re_int)
##     from the report (tidy(ran_pars) returns NULL for a bare
##     `(1|site)` term, same as the binomial sibling), glmmTMB VarCorr;
##   * per-trait dispersion phi -- gllvmTMB report$phi_nbinom2,
##     glmmTMB exp(fixef()$disp). Both order phi by trait factor level
##     (traitt1, traitt2), so positional pairing is correct.
##
## NB2 dispersion is only weakly identified when overdispersion is
## mild: a trait with little excess variance drives phi -> Inf in a
## finite sample (the "back to Poisson" regime), and that happens in
## *both* engines, not as a disagreement. So the DGP uses strong,
## equal overdispersion (size = 1) at n = 300 per trait to keep phi
## well inside the identified range; the phi block additionally guards
## against the runaway regime and skips honestly if either engine's
## phi lands there.
##
## Tolerances: gllvmTMB and glmmTMB share the TMB + Laplace lineage,
## and with the structures aligned above they fit the *same* model, so
## agreement is empirically near-exact (intercepts and SD to <1e-2,
## phi to a few % at n = 300). We assert deliberately tight absolute
## bands -- 0.05 on intercepts, 0.05 on the random-intercept SD -- with
## a little slack over the observed ~1e-3 differences to absorb
## cross-platform TMB optimiser jitter. The phi band is relative
## (25%) because dispersion is the least-constrained parameter even
## when well identified.

skip_if_glmmTMB_missing <- function() {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    skip("glmmTMB not installed (Suggests-only package).")
  }
}

# ---- Shared 2-trait NB2-count DGP -----------------------------------

build_two_trait_nb2_data <- function(n_sites = 300L,
                                     alpha = c(0.3, -0.4),
                                     sigma_u = 0.6,
                                     phi = 1.0,
                                     seed = 20260607L) {
  set.seed(seed)
  u <- stats::rnorm(n_sites, mean = 0, sd = sigma_u)
  y1 <- stats::rnbinom(n_sites, mu = exp(alpha[1] + u), size = phi)
  y2 <- stats::rnbinom(n_sites, mu = exp(alpha[2] + u), size = phi)
  data.frame(
    site  = factor(rep(seq_len(n_sites), 2L)),
    trait = factor(rep(c("t1", "t2"), each = n_sites)),
    value = c(y1, y2)
  )
}

# ---- (1) Fixed-effect log-mean intercepts agree across packages -----

test_that("gllvmTMB and glmmTMB agree on per-trait intercepts for nbinom2(log) + (1|site) fit (cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_nb2_data(n_sites = 300L)

  ## glmmTMB reference fit. Per-trait dispformula matches gllvmTMB's
  ## per-trait phi so the conditional models are identical.
  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    dispformula = ~ 0 + trait,
    data = df, family = glmmTMB::nbinom2()
  )))
  glmm_betas <- as.numeric(glmmTMB::fixef(fit_glmm)$cond)
  names(glmm_betas) <- names(glmmTMB::fixef(fit_glmm)$cond)

  ## gllvmTMB fit on the same conditional formula + data.
  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = gllvmTMB::nbinom2()
  )))
  expect_equal(fit_gllvm$opt$convergence, 0L,
               info = "gllvmTMB 2-trait nbinom2 fit did not converge")

  td <- suppressMessages(gllvmTMB::tidy(fit_gllvm, "fixed", conf.int = FALSE))
  gllvm_t1 <- td$estimate[td$term == "traitt1"]
  gllvm_t2 <- td$estimate[td$term == "traitt2"]
  glmm_t1  <- glmm_betas["traitt1"]
  glmm_t2  <- glmm_betas["traitt2"]

  expect_lt(abs(gllvm_t1 - glmm_t1), 0.05,
            label = sprintf("trait t1 intercept: gllvm = %.3f, glmm = %.3f",
                            gllvm_t1, glmm_t1))
  expect_lt(abs(gllvm_t2 - glmm_t2), 0.05,
            label = sprintf("trait t2 intercept: gllvm = %.3f, glmm = %.3f",
                            gllvm_t2, glmm_t2))
})

# ---- (2) Shared random-intercept SD agrees within tolerance ---------

test_that("gllvmTMB and glmmTMB agree on shared random-intercept SD for nbinom2 (cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_nb2_data(n_sites = 300L)

  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    dispformula = ~ 0 + trait,
    data = df, family = glmmTMB::nbinom2()
  )))
  glmm_vc <- glmmTMB::VarCorr(fit_glmm)$cond$site
  glmm_sd <- as.numeric(sqrt(diag(as.matrix(glmm_vc))))[1]

  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = gllvmTMB::nbinom2()
  )))
  expect_equal(fit_gllvm$opt$convergence, 0L,
               info = "gllvmTMB 2-trait nbinom2 fit did not converge")

  ## As in the binomial sibling, gllvmTMB's tidy(ran_pars) does not
  ## surface the bare `(1|site)` SD (returns NULL with no
  ## latent()/unique() term). Pull from the report: log_sigma_re_int
  ## is the natural-log SD of the random-intercept block.
  if (is.null(fit_gllvm$report$log_sigma_re_int)) {
    skip("gllvmTMB report does not expose log_sigma_re_int; cross-check on the bare `(1|site)` random-intercept SD needs an alternative entry point.")
  }
  gllvm_sd <- as.numeric(exp(fit_gllvm$report$log_sigma_re_int))[1L]

  expect_lt(abs(gllvm_sd - glmm_sd), 0.05,
            label = sprintf("random-int SD: gllvm = %.3f, glmm = %.3f",
                            gllvm_sd, glmm_sd))
})

# ---- (3) Per-trait NB2 dispersion phi agrees within tolerance -------

test_that("gllvmTMB and glmmTMB agree on per-trait nbinom2 dispersion phi (cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_nb2_data(n_sites = 300L)

  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    dispformula = ~ 0 + trait,
    data = df, family = glmmTMB::nbinom2()
  )))
  ## Per-trait dispersion (NB2 `size`): glmmTMB stores log-theta in the
  ## dispersion fixef, ordered by trait factor level (traitt1, traitt2).
  glmm_phi <- as.numeric(exp(glmmTMB::fixef(fit_glmm)$disp))
  names(glmm_phi) <- names(glmmTMB::fixef(fit_glmm)$disp)

  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = gllvmTMB::nbinom2()
  )))
  expect_equal(fit_gllvm$opt$convergence, 0L,
               info = "gllvmTMB 2-trait nbinom2 fit did not converge")

  ## gllvmTMB reports phi per trait, ordered by trait factor level.
  gllvm_phi <- as.numeric(fit_gllvm$report$phi_nbinom2)

  expect_equal(length(gllvm_phi), 2L,
               info = "expected one gllvmTMB phi per trait")
  expect_equal(length(glmm_phi), 2L,
               info = "expected one glmmTMB phi per trait")

  ## Guard against the weakly-identified ("back to Poisson") regime,
  ## where a finite sample with mild excess variance drives phi -> Inf
  ## in EITHER engine. A direct phi comparison is only meaningful when
  ## both fits keep phi finite and well inside the identified range; if
  ## not, skip honestly rather than assert on a runaway parameter.
  phi_runaway <- 1e3
  if (any(gllvm_phi > phi_runaway) || any(glmm_phi > phi_runaway)) {
    skip(sprintf(
      "nbinom2 dispersion not jointly identified on this fixture (gllvm phi = [%s], glmm phi = [%s]); no clean phi comparator.",
      paste(format(gllvm_phi, digits = 3), collapse = ", "),
      paste(format(glmm_phi, digits = 3), collapse = ", ")
    ))
  }

  ## Relative agreement per trait: dispersion is the least-constrained
  ## parameter even when identified, so we use a 25% relative band.
  rel1 <- abs(gllvm_phi[1] - glmm_phi[1]) / glmm_phi[1]
  rel2 <- abs(gllvm_phi[2] - glmm_phi[2]) / glmm_phi[2]
  expect_lt(rel1, 0.25,
            label = sprintf("trait t1 phi: gllvm = %.3f, glmm = %.3f (rel = %.3f)",
                            gllvm_phi[1], glmm_phi[1], rel1))
  expect_lt(rel2, 0.25,
            label = sprintf("trait t2 phi: gllvm = %.3f, glmm = %.3f (rel = %.3f)",
                            gllvm_phi[2], glmm_phi[2], rel2))
})
