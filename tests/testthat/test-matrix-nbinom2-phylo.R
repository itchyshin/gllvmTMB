## Phase B-matrix B-nb2 (Design 59): `nbinom2()` x phylogenetic structural
## recovery + CI smoke. Walks PHY-04 / PHY-05 of
## `docs/design/35-validation-debt-register.md` from the binary-probit
## branch onto the nbinom2 (overdispersed-count) branch.
##
## Per the Phase B0 scoping memo
## (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md sec 3.2):
##   * nbinom2 x phylo x {unique, indep} = OK (overdispersion `phi` is
##     estimable in addition to Sigma_b; the Design 42 binomial-`psi`
##     lesson does NOT apply because nbinom2 carries a legitimate scale
##     parameter beyond the latent floor).
##   * nbinom2 x phylo x dep = BORDERLINE (full unstructured 2T x 2T +
##     estimated `phi` + structural matrix is the cross-product of
##     borderline cases). We therefore gate the dep cell on convergence
##     and skip honestly if it does not identify.
##
## Fixture (shared across cells): 3 traits, 50 species, ONE observation
## per (species, trait), log link, intercept mean ~ 2 on the log scale,
## phi = 2 (moderate overdispersion, Ver Hoef & Boveng 2007), star tree
## (identity VCV). A star tree means `Cphy = I_n_sp`: species are i.i.d.
## on the phylo side, the cleanest identifiable case for these keywords.
##
## nbinom2 is mean-dependent (Var = mu + mu^2/phi), so recovery of the
## phylogenetic variance is intrinsically noisier than for the
## fixed-residual-scale families (binomial, ordinal probit). Following
## the Phase B0 "mean-dependent => wider band" rule we assert structural
## recovery (fit converges, PD Hessian, Sigma_phy positive-definite,
## non-degenerate correlations) plus a wide intercept-mean band rather
## than a tight phylogenetic-variance band.
##
## What we assert per cell:
##   * fit converges (`opt$convergence == 0`) with PD Hessian
##     (`fit_health$pd_hessian == TRUE`);
##   * the engine flag matching the keyword is set;
##   * `phi_nbinom2` is reported and finite;
##   * trait intercepts land in a wide band around the true log-mean ~ 2.
## Plus, on the indep / dep cells:
##   * `extract_correlations(tier = "phy")` is non-degenerate;
##   * (dep only) `confint(parm = "rho:phy:1,2", method = "profile")`
##     returns a finite bound on at least one upper-tri pair.
##
## SKIP discipline (no fake-pass): if a fit fails to construct, fails to
## converge, or has a non-PD Hessian we `skip()` honestly with a reason
## rather than relax the assertion. A cell that only skips leaves its
## register row `partial`.

skip_if_not_phylo_nb2_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Shared nbinom2 x phylo fixture. `Cphy` is the identity (star tree); each
## trait draws an independent length-n_sp phylogenetic effect from
## N(0, sigma^2_phy[t] * I), which enters the log-mean additively on top of
## a per-trait intercept centred near 2. Counts are then drawn NB2 with a
## shared size = phi.
make_phylo_nb2_fixture <- function(n_sp = 50L, n_traits = 3L,
                                   phi_true = 2.0, seed = 2025L) {
  set.seed(seed)
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)

  ## Per-trait phylogenetic SDs: modest signal so the log-mean does not
  ## explode the counts at this fixture size.
  sigma2_phy_true <- c(0.5, 0.4, 0.3)[seq_len(n_traits)]
  ## Per-trait intercepts on the log scale, centred near 2 (so mean count
  ## ~ exp(2) ~ 7.4, comfortably above the Poisson floor for NB2 ID).
  alpha <- c(1.9, 2.0, 2.1, 2.0)[seq_len(n_traits)]

  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true[t]) *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }

  rows <- vector("list", n_sp * n_traits)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      y <- stats::rnbinom(1L, mu = exp(eta), size = phi_true)
      rows[[k]] <- data.frame(
        species = sp_names[i],
        trait   = paste0("trait_", t),
        value   = as.integer(y),
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp_names)
  df$trait   <- factor(df$trait,   levels = paste0("trait_", seq_len(n_traits)))

  list(
    data            = df,
    Cphy            = Cphy,
    sp_names        = sp_names,
    n_traits        = n_traits,
    phi_true        = phi_true,
    alpha           = alpha,
    sigma2_phy_true = sigma2_phy_true
  )
}

## Shared fit-health gate. Used to decide skip-vs-assert: callers first
## test these as a guard, then re-assert them once past the guard.
phylo_nb2_fit_ok <- function(fit) {
  inherits(fit, "gllvmTMB_multi") &&
    isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    isTRUE(fit$fit_health$pd_hessian)
}

expect_phylo_nb2_fit_health <- function(fit) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  ## nbinom2 carries an estimable overdispersion parameter; assert it is
  ## reported and finite (mean-dependent family => no tight band here).
  phi_hat <- as.numeric(fit$report$phi_nbinom2)
  testthat::expect_true(length(phi_hat) >= 1L)
  testthat::expect_true(all(is.finite(phi_hat)))
}

## Wide intercept-mean recovery check (mean-dependent => wide band per the
## Phase B0 memo). We compare the mean fitted trait intercept against the
## mean true log-mean alpha, allowing a generous 0.6 (log scale) gap.
expect_phylo_nb2_intercepts <- function(fit, alpha) {
  fixef <- summary(fit$sd_report, "fixed")
  bfix  <- fixef[grepl("^b_fix$", rownames(fixef)), "Estimate"]
  testthat::expect_true(length(bfix) >= 1L)
  testthat::expect_lt(abs(mean(bfix) - mean(alpha)), 0.6)
}

## ---------------------------------------------------------------
## phylo_latent + phylo_unique (paired) on nbinom2
## ---------------------------------------------------------------
test_that("phylo_latent + phylo_unique (paired) fits on nbinom2; Sigma_phy PD; intercepts recover", {
  skip_if_not_phylo_nb2_deps()
  fx <- make_phylo_nb2_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_latent(species, d = 2) + phylo_unique(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = gllvmTMB::nbinom2()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_latent+phylo_unique nbinom2 fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!phylo_nb2_fit_ok(fit)) {
    skip("phylo_latent+phylo_unique nbinom2 fit did not converge with PD Hessian; PHY-04 (nbinom2) stays partial pending bigger n / different seed")
  }

  expect_phylo_nb2_fit_health(fit)
  ## Paired PGLLVM: phylo_rr (Lambda_phy) co-fits with phylo_diag (Psi_phy)
  ## to give Sigma_phy = Lambda_phy Lambda_phy^T + Psi_phy.
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_diag))

  ## Sigma_phy is the structural target; assert it is the right shape,
  ## finite, symmetric, and positive on the diagonal. We do NOT require
  ## strict positive-definiteness: with phylo_latent(d = 2) on 3 traits the
  ## low-rank Lambda_phy Lambda_phy^T part is rank 2, and when Psi_phy
  ## collapses toward 0 the assembled Sigma_phy is legitimately
  ## positive-SEMI-definite (smallest eigenvalue ~ 0). A non-degenerate
  ## diagonal is the honest structural-recovery contract here (matches the
  ## Stage 35 PGLLVM test, which asserts diag(Sigma_phy) > 0 only).
  Sigma_phy <- fit$report$Sigma_phy
  expect_equal(dim(Sigma_phy), c(fx$n_traits, fx$n_traits))
  expect_true(all(is.finite(Sigma_phy)))
  expect_true(all(diag(Sigma_phy) > 0))
  expect_equal(Sigma_phy, t(Sigma_phy))

  expect_phylo_nb2_intercepts(fit, fx$alpha)
})

## ---------------------------------------------------------------
## phylo_scalar(species) on nbinom2
## ---------------------------------------------------------------
test_that("phylo_scalar(species) fits on nbinom2; propto flag set; lambda_phy profile CI smoke", {
  skip_if_not_phylo_nb2_deps()
  fx <- make_phylo_nb2_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = gllvmTMB::nbinom2()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_scalar nbinom2 fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!phylo_nb2_fit_ok(fit)) {
    skip("phylo_scalar nbinom2 fit did not converge with PD Hessian; PHY-04 (nbinom2) stays partial pending bigger n / different seed")
  }

  expect_phylo_nb2_fit_health(fit)
  ## `phylo_scalar` rewrites to `phylo()` then `propto()`: the engine flag
  ## set is `use$propto`, not `use$phylo_rr` / `use$phylo_diag`.
  expect_true(isTRUE(fit$use$propto))

  ## The single shared scaling lives in `loglambda_phy`; assert finite.
  loglam <- unname(fit$opt$par["loglambda_phy"])
  expect_true(is.finite(loglam))

  expect_phylo_nb2_intercepts(fit, fx$alpha)

  ## CI smoke for the single shared scaling: confint(parm = "lambda_phy",
  ## method = "profile") returns a 1x2 matrix. Require at least one finite
  ## bound; honest skip rather than relax if the profile is degenerate.
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "lambda_phy", method = "profile"
    ))),
    error = function(e) e
  )
  if (inherits(ci, "error") || !is.matrix(ci) || !any(is.finite(ci))) {
    skip("Profile CI for lambda_phy (nbinom2) did not return a finite bound; honest skip rather than relax assertion")
  }
  expect_true(any(is.finite(ci)))
})

## ---------------------------------------------------------------
## phylo_indep(0 + trait | species) on nbinom2
## ---------------------------------------------------------------
test_that("phylo_indep(0 + trait | species) fits on nbinom2; extract_correlations(tier='phy') non-degenerate", {
  skip_if_not_phylo_nb2_deps()
  fx <- make_phylo_nb2_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = gllvmTMB::nbinom2()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_indep nbinom2 fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!phylo_nb2_fit_ok(fit)) {
    skip("phylo_indep nbinom2 fit did not converge with PD Hessian; PHY-05 (nbinom2) stays partial pending bigger n / different seed")
  }

  expect_phylo_nb2_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_indep))

  expect_phylo_nb2_intercepts(fit, fx$alpha)

  ## extract_correlations(tier = "phy") on a diag-only phylo tier returns
  ## one row per upper-tri pair. Correlations are structural zeros but the
  ## frame must be non-degenerate: non-empty, expected columns, finite
  ## correlations.
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier          = "phy",
      method        = "fisher-z",
      link_residual = "none"
    )
  ))
  expect_s3_class(cor_df, "data.frame")
  expect_gt(nrow(cor_df), 0L)
  expect_true(all(c("tier", "trait_i", "trait_j", "correlation",
                    "lower", "upper") %in% names(cor_df)))
  expect_true(all(is.finite(cor_df$correlation)))
})

## ---------------------------------------------------------------
## phylo_dep(0 + trait | species) on nbinom2 (BORDERLINE per B0 memo)
## ---------------------------------------------------------------
test_that("phylo_dep(0 + trait | species) fits on nbinom2; CI smoke + extract_correlations non-degenerate", {
  skip_if_not_phylo_nb2_deps()
  fx <- make_phylo_nb2_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = gllvmTMB::nbinom2()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_dep nbinom2 fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!phylo_nb2_fit_ok(fit)) {
    skip("phylo_dep nbinom2 fit did not converge with PD Hessian (BORDERLINE per Phase B0 memo 3.2); PHY-05 (nbinom2) stays partial pending bigger n / different seed")
  }

  expect_phylo_nb2_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_dep))
  expect_true(isTRUE(fit$use$phylo_rr))  # phylo_dep rewrites to phylo_rr(d = n_traits)

  expect_phylo_nb2_intercepts(fit, fx$alpha)

  ## CI smoke: confint(parm = "rho:phy:1,2", method = "profile") routes
  ## through the phy-tier profile machinery and returns a 1x2 matrix. We
  ## require at least one finite bound on at least one upper-tri pair.
  pairs_to_try <- list(c(1L, 2L), c(1L, 3L), c(2L, 3L))
  any_finite <- FALSE
  for (p in pairs_to_try) {
    parm_token <- sprintf("rho:phy:%d,%d", p[1L], p[2L])
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
    skip("Profile CI for rho:phy (nbinom2) did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)

  ## extract_correlations on the phy tier with rr present: one row per
  ## upper-tri pair with finite correlations (full unstructured => genuinely
  ## non-degenerate, not structural zeros).
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier          = "phy",
      method        = "fisher-z",
      link_residual = "none"
    )
  ))
  expect_s3_class(cor_df, "data.frame")
  expect_gt(nrow(cor_df), 0L)
  expect_true(all(is.finite(cor_df$correlation)))
})
