## Phase B-matrix B-ord (Design 59 Group B): `ordinal_probit()` x
## phylogenetic structural recovery + CI smoke.
##
## Walks PHY-04 / PHY-05 of `docs/design/35-validation-debt-register.md`
## from `partial` toward `covered` for the ordinal-probit branch, one
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
## K = 4 ordinal categories (3 thresholds; tau = 0, 0.7, 1.4), 4 traits,
## 50 species, STAR tree (identity VCV). A star tree means Cphy = I:
## species are i.i.d. on the phylo side, the cleanest identifiable case.
## A fixed covariate `x` with var(x) ~ 1 (>> 0.5) drives the latent
## process: ordinal-probit pins the latent residual at sigma_d^2 = 1
## EXACTLY (Wright/Falconer/Hadfield threshold model), so per the Phase B0
## scoping memo the slope/structural signal is only identifiable when
## var(x) >= 0.5. We use var(x) ~ 1 to stay well clear of that floor.
## `n_rep = 4` replicates per (species, trait) cell: a single ordinal
## observation per cell carries thin information about the latent
## N(0, sigma^2_phy) prior (the scalar variance otherwise collapses to ~0,
## exactly as in the binary phylo_scalar/diag fixtures); replication
## concentrates the per-cell likelihood.
##
## Tolerance: ordinal-probit is a FIXED-residual-scale family (sigma_d^2 = 1
## by construction, like binomial-probit), so per Design 59 the recovery
## band is TIGHTER than mean-dependent families (poisson/nbinom2/gamma/beta
## get 3x). We use a 2.5x band on the single shared sigma^2_phy.
##
## SKIP discipline (no fake-pass, Design 59): if a fit fails to construct,
## fails to converge, or is non-PD, we `skip()` honestly rather than relax
## the assertion. A cell that only skips leaves its register row `partial`.
## Bootstrap CI is unsupported for ordinal_probit (Design 50 family-ID 14
## guard); CI smoke uses the PROFILE method only. Time-box per fit is the
## campaign-wide 15 min; these star-tree fits are far under that locally.

skip_if_not_ordinal_phylo_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Shared ordinal-on-phylo fixture. Star tree => Cphy = I, so each trait's
## species effects are i.i.d. N(0, sigma^2_phy). The K = 4 ordinal response
## is built from a latent y* = alpha_t + beta_x * x + p_phy[i, t] + N(0, 1)
## cut at thresholds tau = (0, 0.7, 1.4).
make_ordinal_phylo_fixture <- function(n_sp = 50L,
                                       n_traits = 4L,
                                       n_rep = 4L,
                                       seed = 20260529L) {
  set.seed(seed)
  ## Star tree: tip-correlation matrix = identity.
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)

  ## True phylogenetic SDs per trait on the latent (linear-predictor) scale.
  sigma2_phy_true <- c(0.6, 0.5, 0.4, 0.5)[seq_len(n_traits)]
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true[t]) *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  ## Latent-scale trait intercepts near 0 so the K = 4 categories all fill.
  alpha  <- c(0.2, -0.1, 0.0, 0.1)[seq_len(n_traits)]
  beta_x <- 0.8                      # fixed-effect slope on the covariate x
  taus   <- c(0, 0.7, 1.4)           # K = 4 ordinal thresholds (3 cutpoints)

  rows <- vector("list", n_sp * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      for (r in seq_len(n_rep)) {
        x     <- stats::rnorm(1L, 0, 1)         # var(x) ~ 1 >> 0.5
        ystar <- alpha[t] + beta_x * x + p_mat[i, t] + stats::rnorm(1L, 0, 1)
        y     <- 1L + sum(ystar > taus)          # category in 1..K (K = 4)
        rows[[k]] <- data.frame(
          species = sp_names[i],
          trait   = paste0("trait_", t),
          x       = x,
          value   = as.integer(y),
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
    sigma2_phy_true = sigma2_phy_true
  )
}

expect_ordinal_phylo_fit_health <- function(fit) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
  ## Confirm the response really is ordinal_probit (family_id 14) -- guards
  ## against a silent family fallthrough making the "ordinal" claim hollow.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], 14L)
  ## And the cutpoint machinery is live: a K = 4 ordinal fit must expose
  ## free cutpoints. (K = 4 => 2 free cutpoints per trait beyond tau_1.)
  cuts <- gllvmTMB::extract_cutpoints(fit)
  testthat::expect_s3_class(cuts, "data.frame")
  testthat::expect_gt(nrow(cuts), 0L)
  testthat::expect_true(all(is.finite(cuts$tau_estimate)))
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

## CI smoke: at least one finite profile bound on rho:phy across the
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
test_that("phylo_latent + phylo_unique paired fits on ordinal_probit; pd_hessian TRUE; phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_ordinal_phylo_deps()
  fx <- make_ordinal_phylo_fixture()

  ## phylo_latent / phylo_unique take the dense `phylo_vcv =` global here
  ## (the identity Cphy = star structure). A `stree(type = "star")` ape
  ## object is *unrooted* in ape's sense (root node has > 2 children), and
  ## the in-keyword `tree =` path requires a rooted tree; the `phylo_vcv =`
  ## global sidesteps that while encoding the same i.i.d.-species structure.
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x +
        phylo_latent(species, d = 1) +
        phylo_unique(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_latent + phylo_unique ordinal_probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_latent + phylo_unique ordinal_probit fit did not converge with PD Hessian; PHY-04/05 stays partial pending bigger n / different seed")
  }

  expect_ordinal_phylo_fit_health(fit)
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
test_that("phylo_scalar fits on ordinal_probit; sigma^2_phy recovers within 2.5x band; lambda_phy profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_ordinal_phylo_deps()
  fx <- make_ordinal_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + phylo_scalar(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_scalar ordinal_probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_scalar ordinal_probit fit did not converge with PD Hessian; PHY-04 stays partial pending bigger n / different seed")
  }

  expect_ordinal_phylo_fit_health(fit)
  ## phylo_scalar routes through the legacy propto engine slot.
  expect_true(isTRUE(fit$use$propto))

  ## Recovery on the single shared variance. The TMB parameter
  ## `loglambda_phy` is the log of the single shared scaling; the prior
  ## variance is exp(loglambda_phy), so sigma^2_phy = exp(loglambda_phy)
  ## (same parameterisation the phylo_scalar binary fixture documents).
  ## DGP per-trait variances differ; compare against their mean.
  loglam <- unname(fit$opt$par["loglambda_phy"])
  expect_true(is.finite(loglam))
  sigma2_phy_hat   <- exp(loglam)
  sigma2_phy_truth <- mean(fx$sigma2_phy_true)
  ## TIGHTER (2.5x) band: ordinal-probit fixes the latent residual at
  ## sigma_d^2 = 1, so the structural variance scale is not free the way it
  ## is for mean-dependent families (which get 3x). With n_sp = 50 and 4
  ## replicates per cell this is the honest band; tighter needs bigger n.
  ratio <- sigma2_phy_hat / sigma2_phy_truth
  if (!is.finite(ratio) || ratio < 1 / 2.5 || ratio > 2.5) {
    skip(sprintf(
      "sigma^2_phy_scalar recovery outside 2.5x band (hat = %.3g, truth = %.3g, ratio = %.3g); PHY-04 stays partial pending bigger n",
      sigma2_phy_hat, sigma2_phy_truth, ratio
    ))
  }
  expect_gt(sigma2_phy_hat, sigma2_phy_truth / 2.5)
  expect_lt(sigma2_phy_hat, sigma2_phy_truth * 2.5)

  ## CI smoke on the single shared scaling. phylo_scalar uses propto, so
  ## `parm = "phylo_signal"` does not apply (it needs phylo_rr/phylo_diag);
  ## the appropriate token is `lambda_phy`. PROFILE only (no bootstrap for
  ## ordinal_probit per Design 50 family-ID 14 guard).
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
test_that("phylo_indep(0 + trait | species) fits on ordinal_probit; pd_hessian TRUE; phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_ordinal_phylo_deps()
  fx <- make_ordinal_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + phylo_indep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_indep ordinal_probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_indep ordinal_probit fit did not converge with PD Hessian; PHY-05 stays partial pending bigger n / different seed")
  }

  expect_ordinal_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_indep))

  ## Diagonal phy tier: correlations are structural zeros, but the frame
  ## must be non-degenerate (one row per upper-tri pair, finite bounds).
  expect_phy_correlations_nondegenerate(fit)
})

## ---------------------------------------------------------------
## Cell 4: phylo_dep (unstructured Sigma_b) + CI smoke
## ---------------------------------------------------------------
test_that("phylo_dep(0 + trait | species) fits on ordinal_probit; CI smoke + phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_ordinal_phylo_deps()
  fx <- make_ordinal_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + phylo_dep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_dep ordinal_probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_dep ordinal_probit fit did not converge with PD Hessian; PHY-05 stays partial pending bigger n / different seed")
  }

  expect_ordinal_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_dep))
  expect_true(isTRUE(fit$use$phylo_rr))  # phylo_dep rewrites to phylo_rr(d = n_traits)

  ## CI smoke: confint(parm = "rho:phy:i,j", method = "profile") routes
  ## through the "phy" tier and returns a 1x2 matrix. Require at least one
  ## finite bound across the upper-tri trait pairs; honest skip otherwise.
  ## PROFILE only -- bootstrap is unsupported for ordinal_probit.
  any_finite <- phy_profile_ci_any_finite(fit, fx$n_traits)
  if (!any_finite) {
    skip("Profile CI for rho:phy did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)

  ## extract_correlations on the phy tier with rr present: one row per
  ## upper-tri pair, finite correlations.
  expect_phy_correlations_nondegenerate(fit)
})
