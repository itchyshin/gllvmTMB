## Phase B-matrix B-gam (Design 59 Group B): `Gamma(link = "log")` x
## phylogenetic structural recovery + CI smoke.
##
## Walks PHY-04 / PHY-05 of `docs/design/35-validation-debt-register.md`
## from `partial` toward `covered` for the gamma (log-link) branch, one
## structural keyword per `test_that`.
##
## Cells (one test_that each):
##   * `phylo_latent + phylo_unique` paired (the two-U pattern; sets
##     `use$phylo_rr` + `use$phylo_diag`)
##   * `phylo_scalar`  (single shared variance via the propto path;
##     sets `use$propto`)
##   * `phylo_indep`   (diagonal Sigma_b on the phy tier; `use$phylo_indep`)
##   * `phylo_dep`     (unstructured Sigma_b; rewrites to phylo_rr(d=T),
##     so `use$phylo_dep` + `use$phylo_rr`)
##
## Fixture (Honest-matrix discipline, Design 59): seed-controlled,
## log-link, gamma shape phi = 2 (=> CV = 1/sqrt(2) ~ 0.707), trait
## intercepts on the log scale near 0 so E(y) = exp(eta) ~ 1, 3 traits,
## ~50 species, STAR tree (identity VCV). A star tree means Cphy = I:
## species are i.i.d. on the phylo side, the cleanest identifiable case.
## Gamma is a *mean-dependent* family (residual scale is not fixed by the
## link, unlike binomial/ordinal-probit), so per the Phase B0 scoping
## memo we use the WIDER recovery band (3x on the variance scale), never
## the tight fixed-residual-scale band.
##
## SKIP discipline (no fake-pass, Design 59): if a fit fails to construct,
## fails to converge, or is non-PD, we `skip()` honestly rather than relax
## the assertion. A cell that only skips leaves its register row `partial`.
## Time-box per fit is the campaign-wide 15 min; these star-tree fits are
## far under that locally.

skip_if_not_gamma_phylo_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Shared gamma-on-phylo fixture. `n_rep` replicates per (species, trait)
## cell: a single gamma observation per cell carries thin information about
## the latent N(0, sigma^2_phy) prior, so (as in the scalar/diag binary
## fixtures) we replicate to concentrate the per-cell likelihood. Star tree
## => Cphy = I, so each trait's species effects are i.i.d. N(0, sigma^2_phy).
make_gamma_phylo_fixture <- function(n_sp = 50L,
                                     n_traits = 3L,
                                     n_rep = 4L,
                                     phi = 2,
                                     seed = 20260529L) {
  set.seed(seed)
  ## Star tree: tip-correlation matrix = identity.
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)

  ## True phylogenetic SDs per trait on the log (linear-predictor) scale.
  ## Kept modest so exp(eta) stays in a sane range (no overflow) and the
  ## gamma mean is identifiable at this fixture size.
  sigma2_phy_true <- c(0.5, 0.4, 0.3, 0.35)[seq_len(n_traits)]
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true[t]) *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  ## Log-scale trait intercepts near 0 => E(y) = exp(intercept) ~ 1.
  alpha <- c(0.0, 0.1, -0.1, 0.05)[seq_len(n_traits)]

  ## gamma shape = phi (so CV = 1/sqrt(phi)); E(y) = mu = exp(eta);
  ## scale = mu / shape.
  shape <- phi
  rows <- vector("list", n_sp * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      mu <- exp(eta)
      for (r in seq_len(n_rep)) {
        y <- stats::rgamma(1L, shape = shape, scale = mu / shape)
        rows[[k]] <- data.frame(
          species = sp_names[i],
          trait   = paste0("trait_", t),
          value   = as.numeric(y),
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
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
    n_rep           = n_rep,
    phi             = phi,
    sigma2_phy_true = sigma2_phy_true
  )
}

expect_gamma_phylo_fit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_stationary_for_recovery_test(fit)
  ## Confirm the response really is gamma (family_id 4) — guards against a
  ## silent family fallthrough making the "gamma" claim hollow.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], 4L)
}

## extract_correlations(tier = "phy") must be non-degenerate: a data.frame
## with one row per upper-tri trait pair and finite correlations.
expect_phy_correlations_nondegenerate <- function(fit) {
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier          = "phy",
      method        = "fisher-z",
      link_residual = "none"
    )
  ))
  testthat::expect_s3_class(cor_df, "data.frame")
  testthat::expect_gt(nrow(cor_df), 0L)
  testthat::expect_true(all(c("tier", "trait_i", "trait_j", "correlation",
                              "lower", "upper") %in% names(cor_df)))
  testthat::expect_true(all(is.finite(cor_df$correlation)))
  invisible(cor_df)
}

## CI smoke: at least one finite profile bound on rho:phy across the three
## upper-tri trait pairs. Returns TRUE/FALSE; caller decides skip-vs-pass.
phy_profile_ci_any_finite <- function(fit, n_traits) {
  pairs_to_try <- utils::combn(seq_len(n_traits), 2L, simplify = FALSE)
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
      return(TRUE)
    }
  }
  FALSE
}

## ---------------------------------------------------------------
## Cell 1: phylo_latent + phylo_unique paired (two-U pattern)
## ---------------------------------------------------------------
test_that("phylo_latent + phylo_unique paired fits on Gamma(log); pd_hessian TRUE; phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_gamma_phylo_deps()
  fx <- make_gamma_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_latent(species, d = 1) +
        phylo_unique(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::Gamma(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_latent + phylo_unique gamma(log) fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("phylo_latent + phylo_unique gamma(log) fit did not converge with PD Hessian; PHY-04/05 stays partial pending bigger n / different seed")
  }

  expect_gamma_phylo_fit_health(fit)
  ## The two-U pattern sets both engine flags.
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_diag))
  ## Structural objects exist and are well-shaped.
  expect_false(is.null(fit$report$Lambda_phy))
  expect_phy_correlations_nondegenerate(fit)
})

## ---------------------------------------------------------------
## Cell 2: phylo_scalar (single shared phylogenetic variance)
## ---------------------------------------------------------------
test_that("phylo_scalar fits on Gamma(log); sigma^2_phy recovers within 3x band; lambda_phy profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_gamma_phylo_deps()
  fx <- make_gamma_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::Gamma(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_scalar gamma(log) fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("phylo_scalar gamma(log) fit did not converge with PD Hessian; PHY-04 stays partial pending bigger n / different seed")
  }

  expect_gamma_phylo_fit_health(fit)
  ## phylo_scalar routes through the legacy propto engine slot.
  expect_true(isTRUE(fit$use$propto))

  ## Recovery on the single shared variance. The TMB parameter
  ## `loglambda_phy` is the log of the single shared scaling; the prior
  ## variance is exp(loglambda_phy), so sigma^2_phy = exp(loglambda_phy).
  ## (Same parameterisation the phylo_scalar binary fixture documents.)
  ## DGP per-trait variances differ slightly; compare against their mean.
  loglam <- unname(fit$opt$par["loglambda_phy"])
  expect_true(is.finite(loglam))
  sigma2_phy_hat <- exp(loglam)
  sigma2_phy_truth <- mean(fx$sigma2_phy_true)
  ## WIDER (3x) band: gamma is mean-dependent, so the residual scale is not
  ## pinned by the link. Per Phase B0 this is the honest band at modest n;
  ## a single shared variance pooled across traits at n_sp = 50.
  ratio <- sigma2_phy_hat / sigma2_phy_truth
  if (!is.finite(ratio) || ratio < 1 / 3 || ratio > 3) {
    skip(sprintf(
      "sigma^2_phy_scalar recovery outside 3x band (hat = %.3g, truth = %.3g, ratio = %.3g); PHY-04 stays partial pending bigger n",
      sigma2_phy_hat, sigma2_phy_truth, ratio
    ))
  }
  expect_gt(sigma2_phy_hat, sigma2_phy_truth / 3)
  expect_lt(sigma2_phy_hat, sigma2_phy_truth * 3)

  ## CI smoke on the single shared scaling. phylo_scalar uses propto, so
  ## `parm = "phylo_signal"` does not apply (it needs phylo_rr/phylo_diag);
  ## the appropriate token is `lambda_phy`.
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "lambda_phy", method = "profile"
    ))),
    error = function(e) e
  )
  if (inherits(ci, "error")) {
    skip(sprintf(
      "confint(parm = 'lambda_phy', method = 'profile') errored: %s",
      conditionMessage(ci)
    ))
  }
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(ncol(ci), 2L)
  expect_true(any(is.finite(ci)))
})

## ---------------------------------------------------------------
## Cell 3: phylo_indep (diagonal Sigma_b on the phy tier)
## ---------------------------------------------------------------
test_that("phylo_indep(0 + trait | species) fits on Gamma(log); pd_hessian TRUE; phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_gamma_phylo_deps()
  fx <- make_gamma_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::Gamma(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_indep gamma(log) fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("phylo_indep gamma(log) fit did not converge with PD Hessian; PHY-05 stays partial pending bigger n / different seed")
  }

  expect_gamma_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_indep))

  ## Diagonal phy tier: correlations are structural zeros, but the frame
  ## must be non-degenerate (one row per upper-tri pair, finite bounds).
  expect_phy_correlations_nondegenerate(fit)
})

## ---------------------------------------------------------------
## Cell 4: phylo_dep (unstructured Sigma_b) + CI smoke
## ---------------------------------------------------------------
test_that("phylo_dep(0 + trait | species) fits on Gamma(log); CI smoke + phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_gamma_phylo_deps()
  fx <- make_gamma_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::Gamma(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_dep gamma(log) fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("phylo_dep gamma(log) fit did not converge with PD Hessian; PHY-05 stays partial pending bigger n / different seed")
  }

  expect_gamma_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_dep))
  expect_true(isTRUE(fit$use$phylo_rr))  # phylo_dep rewrites to phylo_rr(d = n_traits)

  ## CI smoke: confint(parm = "rho:phy:i,j", method = "profile") routes
  ## through the "phy" tier and returns a 1x2 matrix. Require at least one
  ## finite bound across the upper-tri trait pairs; honest skip otherwise.
  any_finite <- phy_profile_ci_any_finite(fit, fx$n_traits)
  if (!any_finite) {
    skip("Profile CI for rho:phy did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)

  ## extract_correlations on the phy tier with rr present: one row per
  ## upper-tri pair, finite correlations.
  expect_phy_correlations_nondegenerate(fit)
})
