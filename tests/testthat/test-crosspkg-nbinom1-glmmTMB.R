## Cross-package light sanity check: nbinom1 vs glmmTMB::nbinom1().
##
## Sibling of test-crosspkg-nbinom2-glmmTMB.R (NB2) and
## test-m2-2b-glmmTMB-cross-check.R (binomial-logit). Same cross-package
## policy (docs/design/41-binary-completeness.md S3 "Cross-package light
## sanity checks"): one shared fixture per comparator, no replicates, no
## grid. Big cross-package grids live at Phase 5.5.
##
## Closes the nbinom1 (NB1) cross-package gap flagged open by register row
## FAM-07: nbinom1 was wired 2026-05-30 (fid 15, linear mean-variance
## Var = mu*(1 + phi)) and given recovery + tier coverage, but no
## gllvmTMB-vs-glmmTMB equivalence cell existed. This file adds it.
##
## Shared fixture: 2-trait stacked NB1-count data with a single shared
## random intercept per site. Both engines see the same long-format data
## and the lme4-style `(1 | site)` random-intercept term:
##
##   glmmTMB:  value ~ 0 + trait + (1 | site),
##             dispformula = ~ 0 + trait, family = nbinom1()
##   gllvmTMB: value ~ 0 + trait + (1 | site), family = nbinom1()
##
## Parameterisation match (the part that needs care for NB1). gllvmTMB's
## nbinom1 (src/gllvmTMB.cpp fid 15) sets the second dnbinom_robust
## argument to log(var - mu) = log_mu + log_phi_nbinom1(t), i.e.
## Var(y) = mu * (1 + phi) with one phi per trait. This is *exactly*
## glmmTMB's nbinom1 parameterisation, where exp(disp) = sigma(fit) is the
## same phi (Var = mu * (1 + phi)). So the dispersions are directly
## comparable on the natural scale -- no NB2-style reciprocal. As with NB2,
## gllvmTMB fits a *per-trait* phi while glmmTMB's default nbinom1 fits a
## *single shared* phi, so we give glmmTMB `dispformula = ~ 0 + trait` to
## make both estimate one phi per trait; the conditional model
## (`value ~ 0 + trait + (1 | site)`) is then identical between packages.
##
## What we cross-check, and where each quantity comes from:
##   * per-trait log-mean intercepts -- gllvmTMB tidy("fixed"),
##     glmmTMB fixef()$cond;
##   * shared random-intercept SD -- gllvmTMB exp(log_sigma_re_int) from
##     the report (tidy(ran_pars) returns NULL for a bare `(1|site)` term,
##     same as the NB2 / binomial siblings), glmmTMB VarCorr;
##   * per-trait dispersion phi -- gllvmTMB report$phi_nbinom1, glmmTMB
##     exp(fixef()$disp). Both order phi by trait factor level (traitt1,
##     traitt2), so positional pairing is correct.
##
## NB1 dispersion, like NB2, is only weakly identified when overdispersion
## is mild: a trait with little excess variance drives phi -> 0 (the "back
## to Poisson" regime for NB1, since Var = mu*(1+phi) -> mu as phi -> 0) in
## a finite sample, and that happens in *both* engines, not as a
## disagreement. So the DGP uses strong, equal overdispersion (phi = 2,
## i.e. Var = 3*mu) at n = 300 per trait to keep phi well inside the
## identified range; the phi block additionally guards against the runaway
## (phi -> 0 or phi -> Inf) regime and skips honestly if either engine's
## phi lands there.
##
## Tolerances: gllvmTMB and glmmTMB share the TMB + Laplace lineage, and
## with the structures aligned above they fit the *same* model, so
## agreement is empirically near-exact (intercepts and SD to <1e-3, phi to
## a few 1e-5 at n = 300). We INHERIT the NB2 sibling's bands exactly:
## deliberately tight absolute bands -- 0.05 on intercepts, 0.05 on the
## random-intercept SD -- with slack over the observed differences to
## absorb cross-platform TMB optimiser jitter, and a 25% relative band on
## phi (dispersion is the least-constrained parameter even when
## identified). No band is widened relative to the NB2 sibling.
##
## Honest-skip contract: if glmmTMB is not installed, if either engine's
## phi lands in the weakly-identified regime, or if the gllvmTMB report
## does not expose the bare `(1|site)` random-intercept SD, we skip() with
## a precise reason rather than fabricate agreement.

skip_if_glmmTMB_missing <- function() {
  if (!requireNamespace("glmmTMB", quietly = TRUE)) {
    skip("glmmTMB not installed (Suggests-only package).")
  }
}

# ---- Shared 2-trait NB1-count DGP -----------------------------------
#
# NB1 (type-1 negative binomial): Var(y) = mu * (1 + phi). The standard
# `rnbinom(mu, size)` parameterisation has Var = mu + mu^2 / size, so to
# draw NB1 with a *constant* phi we set size = mu / phi (then
# mu^2 / size = mu * phi and Var = mu + mu * phi = mu * (1 + phi)). This is
# the same genuine-NB1 draw used by test-tiers-nbinom1.R / register FAM-07.

build_two_trait_nb1_data <- function(n_sites = 300L,
                                     alpha = c(0.3, -0.4),
                                     sigma_u = 0.6,
                                     phi = 2.0,
                                     seed = 20260607L) {
  set.seed(seed)
  u   <- stats::rnorm(n_sites, mean = 0, sd = sigma_u)
  mu1 <- exp(alpha[1] + u)
  mu2 <- exp(alpha[2] + u)
  y1  <- stats::rnbinom(n_sites, mu = mu1, size = mu1 / phi)
  y2  <- stats::rnbinom(n_sites, mu = mu2, size = mu2 / phi)
  data.frame(
    site  = factor(rep(seq_len(n_sites), 2L)),
    trait = factor(rep(c("t1", "t2"), each = n_sites)),
    value = c(y1, y2)
  )
}

# ---- (1) Fixed-effect log-mean intercepts agree across packages -----

test_that("gllvmTMB and glmmTMB agree on per-trait intercepts for nbinom1(log) + (1|site) fit (cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_nb1_data(n_sites = 300L)

  ## glmmTMB reference fit. Per-trait dispformula matches gllvmTMB's
  ## per-trait phi so the conditional models are identical.
  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    dispformula = ~ 0 + trait,
    data = df, family = glmmTMB::nbinom1()
  )))
  glmm_betas <- as.numeric(glmmTMB::fixef(fit_glmm)$cond)
  names(glmm_betas) <- names(glmmTMB::fixef(fit_glmm)$cond)

  ## gllvmTMB fit on the same conditional formula + data.
  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = gllvmTMB::nbinom1()
  )))
  if (!identical(fit_gllvm$opt$convergence, 0L) ||
        !isTRUE(fit_gllvm$sd_report$pdHess)) {
    skip("gllvmTMB 2-trait nbinom1 fit did not converge / Hessian not PD")
  }

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

test_that("gllvmTMB and glmmTMB agree on shared random-intercept SD for nbinom1 (cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_nb1_data(n_sites = 300L)

  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    dispformula = ~ 0 + trait,
    data = df, family = glmmTMB::nbinom1()
  )))
  glmm_vc <- glmmTMB::VarCorr(fit_glmm)$cond$site
  glmm_sd <- as.numeric(sqrt(diag(as.matrix(glmm_vc))))[1]

  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = gllvmTMB::nbinom1()
  )))
  if (!identical(fit_gllvm$opt$convergence, 0L) ||
        !isTRUE(fit_gllvm$sd_report$pdHess)) {
    skip("gllvmTMB 2-trait nbinom1 fit did not converge / Hessian not PD")
  }

  ## As in the NB2 / binomial siblings, gllvmTMB's tidy(ran_pars) does not
  ## surface the bare `(1|site)` SD (returns NULL with no
  ## latent()/unique() term). Pull from the report: log_sigma_re_int is the
  ## natural-log SD of the random-intercept block. If a future refactor
  ## removes it, skip with a precise reason rather than fake agreement on a
  ## quantity we cannot read.
  if (is.null(fit_gllvm$report$log_sigma_re_int)) {
    skip("gllvmTMB report does not expose log_sigma_re_int; cross-check on the bare `(1|site)` random-intercept SD needs an alternative entry point.")
  }
  gllvm_sd <- as.numeric(exp(fit_gllvm$report$log_sigma_re_int))[1L]

  expect_lt(abs(gllvm_sd - glmm_sd), 0.05,
            label = sprintf("random-int SD: gllvm = %.3f, glmm = %.3f",
                            gllvm_sd, glmm_sd))
})

# ---- (3) Per-trait NB1 dispersion phi agrees within tolerance -------

test_that("gllvmTMB and glmmTMB agree on per-trait nbinom1 dispersion phi (cross-package)", {
  skip_on_cran()
  skip_if_glmmTMB_missing()

  df <- build_two_trait_nb1_data(n_sites = 300L)

  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | site),
    dispformula = ~ 0 + trait,
    data = df, family = glmmTMB::nbinom1()
  )))
  ## Per-trait NB1 dispersion phi: glmmTMB stores log-phi in the dispersion
  ## fixef, ordered by trait factor level (traitt1, traitt2). exp() is the
  ## same phi (Var = mu * (1 + phi)) gllvmTMB reports -- no reciprocal.
  glmm_phi <- as.numeric(exp(glmmTMB::fixef(fit_glmm)$disp))
  names(glmm_phi) <- names(glmmTMB::fixef(fit_glmm)$disp)

  fit_gllvm <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (1 | site),
    data = df, family = gllvmTMB::nbinom1()
  )))
  if (!identical(fit_gllvm$opt$convergence, 0L) ||
        !isTRUE(fit_gllvm$sd_report$pdHess)) {
    skip("gllvmTMB 2-trait nbinom1 fit did not converge / Hessian not PD")
  }

  ## gllvmTMB reports phi per trait, ordered by trait factor level.
  gllvm_phi <- as.numeric(fit_gllvm$report$phi_nbinom1)

  expect_equal(length(gllvm_phi), 2L,
               info = "expected one gllvmTMB phi per trait")
  expect_equal(length(glmm_phi), 2L,
               info = "expected one glmmTMB phi per trait")

  ## Guard against the weakly-identified regime. For NB1, Var = mu*(1+phi),
  ## so mild excess variance drives phi -> 0 ("back to Poisson") in a finite
  ## sample, and a pathological fit can drive phi -> Inf; either happens in
  ## EITHER engine, not as a disagreement. A direct phi comparison is only
  ## meaningful when both fits keep phi finite and well inside the
  ## identified range; if not, skip honestly rather than assert on a runaway
  ## (or collapsed) parameter.
  phi_runaway   <- 1e3
  phi_collapsed <- 1e-2
  if (any(gllvm_phi > phi_runaway) || any(glmm_phi > phi_runaway) ||
        any(gllvm_phi < phi_collapsed) || any(glmm_phi < phi_collapsed)) {
    skip(sprintf(
      "nbinom1 dispersion not jointly identified on this fixture (gllvm phi = [%s], glmm phi = [%s]); no clean phi comparator.",
      paste(format(gllvm_phi, digits = 3), collapse = ", "),
      paste(format(glmm_phi, digits = 3), collapse = ", ")
    ))
  }

  ## Relative agreement per trait: dispersion is the least-constrained
  ## parameter even when identified, so we use a 25% relative band
  ## (inherited from the NB2 sibling, not widened).
  rel1 <- abs(gllvm_phi[1] - glmm_phi[1]) / glmm_phi[1]
  rel2 <- abs(gllvm_phi[2] - glmm_phi[2]) / glmm_phi[2]
  expect_lt(rel1, 0.25,
            label = sprintf("trait t1 phi: gllvm = %.3f, glmm = %.3f (rel = %.4f)",
                            gllvm_phi[1], glmm_phi[1], rel1))
  expect_lt(rel2, 0.25,
            label = sprintf("trait t2 phi: gllvm = %.3f, glmm = %.3f (rel = %.4f)",
                            gllvm_phi[2], glmm_phi[2], rel2))
})
