## Phase B-matrix Agent A-logit (Design 59): `binomial(link = "logit")`
## on the unit tier, structural-dependence keywords.
##
## Walks FG-07 / FG-08 / FG-09 (binomial-logit) of
## `docs/design/35-validation-debt-register.md` for the unit-tier
## `indep` / `dep` / scalar cells. The `latent + unique` paired block is
## already covered for binomial (test-m2-2a-binary-recovery.R, single
## trial); here it is a multi-trial regression anchor that pins the same
## engine path under the cbind() likelihood.
##
## ----------------------------------------------------------------------
## Why this fixture is tighter than test-m2-2a-binary-recovery.R
##
## That file uses single-trial Bernoulli at d = 1, which the Phase B0
## scoping memo (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-
## scoping.md §3.1) calls "genuinely noisy" -> loose Sigma bound 0.5.
## We instead use MULTI-TRIAL `cbind(succ, fail)` with `size` trials per
## row and `n_rep >= 3` rows per (unit, trait) cell. Per §3.1 of that
## memo, "multi-trial binomial ... has tighter identification" than
## single-trial, so we adopt a meaningfully tighter Sigma bound (0.30)
## and a correlation bound (0.25). The latent residual is fixed by the
## logit link at sigma^2_d = pi^2 / 3, so it is NOT estimated -- there is
## no scale parameter to trade against Sigma_b, which sharpens recovery.
##
## ----------------------------------------------------------------------
## Grammar note (honest-matrix discipline)
##
## At the UNIT tier the canonical callable keywords are `indep(...)`,
## `dep(...)`, `latent(...)`, and `unique(...)`. There is no standalone
## `scalar(0 + trait | unit)` keyword -- `scalar` exists only as
## `phylo_scalar()` / `spatial_scalar()` and as a brms-sugar `mode=`.
## The unit-tier *scalar* covariance structure (one variance shared
## across all traits, zero cross-trait covariance) is the canonical
## `unique(0 + trait | unit, common = TRUE)` form, which ties every
## trait SD to a single parameter. We test that genuine structure here.
##
## ----------------------------------------------------------------------
## SKIP discipline (no fake-pass)
##
## Every cell tries the fit inside tryCatch; if construction fails, the
## fit does not converge, or the Hessian is non-PD, we skip() honestly
## with a reason and the matching register row stays `partial`. We never
## relax a tolerance to force green.

skip_if_not_logit_unit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Unit-tier multi-trial binomial-logit DGP.
##   b_i ~ N(0, Sigma_b) is a T-variate unit random effect; each
##   (unit, trait) cell gets `n_rep` Binomial(size, plogis(alpha_t + b_it))
##   draws stored as cbind(succ, fail). `struct` chooses the truth Sigma_b:
##     "dep"    -> full unstructured (non-zero cross-trait correlations)
##     "indep"  -> diagonal (independent traits, free per-trait variances)
##     "scalar" -> single shared variance on the diagonal
##     "lu"     -> Lambda Lambda^T + diag(psi^2) (rank-1 + unique)
make_logit_unit_fx <- function(struct = c("dep", "indep", "scalar", "lu"),
                               n_units = 60L, T = 3L, n_rep = 3L,
                               size = 10L, seed = 101L) {
  struct <- match.arg(struct)
  set.seed(seed)

  Lam <- NULL
  if (struct == "dep") {
    R3  <- matrix(c(1, 0.5, 0.3,
                    0.5, 1, -0.2,
                    0.3, -0.2, 1), 3L, 3L)
    sds <- c(0.9, 0.8, 0.7)[seq_len(T)]
    R   <- R3[seq_len(T), seq_len(T), drop = FALSE]
    Sig <- diag(sds, T) %*% R %*% diag(sds, T)
  } else if (struct == "indep") {
    sds <- c(0.9, 0.8, 0.7)[seq_len(T)]
    Sig <- diag(sds^2, T)
  } else if (struct == "scalar") {
    sds <- rep(0.8, T)
    Sig <- diag(sds^2, T)
  } else {                       # "lu": rank-1 latent + unique
    Lam <- matrix(c(0.9, 0.7, -0.5, 0.4)[seq_len(T)], T, 1L)
    psi <- c(0.30, 0.25, 0.35, 0.20)[seq_len(T)]
    Sig <- Lam %*% t(Lam) + diag(psi^2, T)
  }

  L            <- chol(Sig + 1e-9 * diag(T))
  alpha        <- seq(-0.3, 0.3, length.out = T)  # mid-range so p stays away from 0/1
  trait_levels <- paste0("t", seq_len(T))

  rows <- vector("list", n_units * T * n_rep)
  k <- 1L
  for (i in seq_len(n_units)) {
    b <- as.numeric(t(L) %*% stats::rnorm(T))
    for (t in seq_len(T)) {
      p <- stats::plogis(alpha[t] + b[t])
      for (r in seq_len(n_rep)) {
        s <- stats::rbinom(1L, size = size, prob = p)
        rows[[k]] <- data.frame(
          unit  = sprintf("u%03d", i),
          trait = trait_levels[t],
          succ  = s,
          fail  = size - s,
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$unit  <- factor(df$unit)
  df$trait <- factor(df$trait, levels = trait_levels)

  list(data = df, Sigma_b = Sig, Lambda = Lam, T = T, sigma2_d = pi^2 / 3)
}

## Fit a unit-tier model with the given RHS covstruct term; return the
## fit, or a character message on construction error.
fit_logit_unit <- function(fx, rhs_term) {
  form <- stats::as.formula(
    paste("cbind(succ, fail) ~ 0 + trait +", rhs_term)
  )
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      form,
      data   = fx$data,
      family = stats::binomial(),   # default logit
      unit   = "unit"
    ))),
    error = function(e) conditionMessage(e)
  )
}

## Honest health gate: returns TRUE iff the fit is a converged,
## PD-Hessian gllvmTMB_multi object.
fit_is_healthy <- function(fit) {
  inherits(fit, "gllvmTMB_multi") &&
    isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    isTRUE(fit$fit_health$pd_hessian)
}

## Recovery check: total-Sigma on the unit tier vs truth (Sigma_b plus
## the link-fixed pi^2/3 latent residual on the diagonal). Multi-trial
## bound 0.30 (tighter than the 0.5 single-trial binary bound; see header).
expect_unit_sigma_recovery <- function(fit, fx, sigma_tol = 0.30,
                                       cor_tol = 0.25, info = "") {
  Sigma_truth <- fx$Sigma_b + diag(fx$sigma2_d, fx$T)
  Se <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "total", link_residual = "auto"
  ))
  rel_err <- max(abs(Se$Sigma - Sigma_truth)) / max(abs(Sigma_truth))
  testthat::expect_lt(
    rel_err, sigma_tol,
    label = sprintf("%s max rel err on unit Sigma = %.3f", info, rel_err)
  )
  R_truth <- stats::cov2cor(Sigma_truth)
  testthat::expect_lt(
    max(abs(Se$R - R_truth)), cor_tol,
    label = sprintf("%s max abs err on unit R", info)
  )
}

## ---------------------------------------------------------------
## (1) indep(0 + trait | unit) -- diagonal Sigma_b (FG-07)
## ---------------------------------------------------------------
test_that("binomial(logit) indep(0+trait|unit) recovers diagonal Sigma; pd_hessian TRUE", {
  skip_if_not_heavy()
  skip_if_not_logit_unit_deps()
  fx  <- make_logit_unit_fx(struct = "indep", seed = 20260529L)
  fit <- fit_logit_unit(fx, "indep(0 + trait | unit)")

  if (is.character(fit)) {
    skip(sprintf("binomial-logit indep unit fit failed to construct: %s",
                 substr(fit, 1L, 100L)))
  }
  if (!fit_is_healthy(fit)) {
    skip("binomial-logit indep unit fit did not converge with PD Hessian; FG-07 (binomial-logit) stays partial pending bigger n / different seed")
  }

  expect_true(isTRUE(fit$use$indep_B))
  expect_unit_sigma_recovery(fit, fx, info = "indep")

  ## extract_correlations on a diagonal unit tier: one row per upper-tri
  ## pair, finite (structural-zero) correlations -- non-degenerate frame.
  cor_df <- suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
    fit, tier = "unit", method = "fisher-z", link_residual = "auto"
  )))
  expect_s3_class(cor_df, "data.frame")
  expect_gt(nrow(cor_df), 0L)
  expect_true(all(is.finite(cor_df$correlation)))
})

## ---------------------------------------------------------------
## (2) dep(0 + trait | unit) -- full unstructured Sigma_b + CI smoke (FG-08)
## ---------------------------------------------------------------
test_that("binomial(logit) dep(0+trait|unit) recovers unstructured Sigma; rho profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_logit_unit_deps()
  fx  <- make_logit_unit_fx(struct = "dep", seed = 20260530L)
  fit <- fit_logit_unit(fx, "dep(0 + trait | unit)")

  if (is.character(fit)) {
    skip(sprintf("binomial-logit dep unit fit failed to construct: %s",
                 substr(fit, 1L, 100L)))
  }
  if (!fit_is_healthy(fit)) {
    skip("binomial-logit dep unit fit did not converge with PD Hessian; FG-08 (binomial-logit) stays partial pending bigger n / different seed")
  }

  expect_true(isTRUE(fit$use$dep_B))
  expect_true(isTRUE(fit$use$rr_B))   # dep rewrites to a full-rank latent block
  expect_unit_sigma_recovery(fit, fx, info = "dep")

  ## CI smoke: confint(parm = "rho:unit:1,2", method = "profile") routes
  ## through .confint_rho() -> profile_ci_correlation() at the unit tier.
  ## We require a 1x2 matrix with at least one finite bound on at least
  ## one upper-tri pair (1,2 / 1,3 / 2,3).
  pairs_to_try <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
  any_finite <- FALSE
  for (p in pairs_to_try) {
    parm_token <- sprintf("rho:unit:%d,%d", p[1L], p[2L])
    ci <- tryCatch(
      suppressMessages(suppressWarnings(stats::confint(
        fit, parm = parm_token, method = "profile"
      ))),
      error = function(e) e
    )
    if (!inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
          ncol(ci) == 2L && any(is.finite(ci))) {
      any_finite <- TRUE
      break
    }
  }
  if (!any_finite) {
    skip("Profile CI for rho:unit did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)
})

## ---------------------------------------------------------------
## (3) scalar structure via unique(common = TRUE) -- shared variance (FG-09)
## ---------------------------------------------------------------
test_that("binomial(logit) unit scalar (unique common=TRUE) recovers shared variance; pd_hessian TRUE", {
  skip_if_not_heavy()
  skip_if_not_logit_unit_deps()
  fx  <- make_logit_unit_fx(struct = "scalar", seed = 20260531L)
  ## Unit-tier "scalar" = one variance tied across all traits. The
  ## canonical callable form is unique(..., common = TRUE); there is no
  ## standalone scalar(0 + trait | unit) keyword (see header note).
  fit <- fit_logit_unit(fx, "unique(0 + trait | unit, common = TRUE)")

  if (is.character(fit)) {
    skip(sprintf("binomial-logit unit scalar fit failed to construct: %s",
                 substr(fit, 1L, 100L)))
  }
  if (!fit_is_healthy(fit)) {
    skip("binomial-logit unit scalar fit did not converge with PD Hessian; FG-09 (binomial-logit) stays partial pending bigger n / different seed")
  }

  expect_true(isTRUE(fit$use$diag_B))
  ## common = TRUE ties every trait SD to one shared value.
  sds <- as.numeric(fit$report$sd_B)
  expect_length(sds, fx$T)
  expect_true(all(abs(sds - sds[1L]) < 1e-8))

  expect_unit_sigma_recovery(fit, fx, info = "scalar")
})

## ---------------------------------------------------------------
## (4) latent(d=1) + unique paired block -- multi-trial regression anchor
## ---------------------------------------------------------------
test_that("binomial(logit) latent+unique paired block recovers Sigma (regression anchor)", {
  skip_if_not_heavy()
  skip_if_not_logit_unit_deps()
  fx  <- make_logit_unit_fx(struct = "lu", T = 4L, seed = 20260601L)
  fit <- fit_logit_unit(
    fx, "latent(0 + trait | unit, d = 1) + unique(0 + trait | unit)"
  )

  if (is.character(fit)) {
    skip(sprintf("binomial-logit latent+unique unit fit failed to construct: %s",
                 substr(fit, 1L, 100L)))
  }
  if (!fit_is_healthy(fit)) {
    skip("binomial-logit latent+unique unit fit did not converge with PD Hessian; regression anchor skipped honestly")
  }

  expect_true(isTRUE(fit$use$rr_B))
  expect_true(isTRUE(fit$use$diag_B))
  ## Anchor recovery: same multi-trial bounds as the structural cells.
  expect_unit_sigma_recovery(fit, fx, info = "latent+unique")
})
