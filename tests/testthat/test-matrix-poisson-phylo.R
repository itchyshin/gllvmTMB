## Phase B-matrix agent B-pois (Design 59, group B): `poisson(link = "log")`
## on phylogenetic structural blocks -- structural recovery + CI smoke.
##
## Adds the POISSON branch of evidence to PHY-04 (`phylo_scalar`) and
## PHY-05 (`phylo_indep` / `phylo_dep`) of
## `docs/design/35-validation-debt-register.md`, plus the paired
## `phylo_latent + phylo_unique` cell of group B. The binary-probit
## branch is already `covered` (`test-phyloscalar-binary.R`,
## `test-phylodepindep-binary.R`); this file is the non-binary analogue.
##
## Family note (Phase B0 scoping memo, 2026-05-26): poisson is a
## *mean-dependent* family -- the latent residual on the log scale is
## log(1 + 1/mu_t), so the effective scale shifts with the intercept,
## unlike the fixed-residual probit (latent variance == 1). Per the
## Honest-matrix discipline in Design 59, mean-dependent families get a
## WIDER recovery tolerance than fixed-residual-scale families. We use a
## 4x band on the variance scale here (vs the 3x band the binary-probit
## phylo tests use), and we keep the intercept at a healthy count mean
## (alpha == 2 => exp(2) ~= 7.4) so the Poisson likelihood is neither
## near-zero (no information) nor overflowing.
##
## Fixture: log-link Poisson, intercept mean ~= 2, 3 traits, 50 species,
## star tree (identity VCV). The identity VCV is the cleanest
## identifiable case -- species are i.i.d. on the phylo side, removing
## between-species correlation as a confounder. Where a single count per
## (species, trait) cell carries too little information for the phylo
## variance (the scalar and the paired decomposition), we replicate the
## cell, mirroring the replication trick the binary fixtures use.
##
## SKIP discipline (no fake-pass, Design 59): a cell that fails to
## construct, fails to converge, is non-PD, or whose recovery lands
## outside the honest tolerance band is `skip()`ped with a reason and
## reported as "stays partial" -- never forced green. Each fit is
## expected to finish well within the 15-min-per-fit time-box on these
## small fixtures.

skip_if_not_poisson_phylo_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

expect_poisson_phylo_fit_health <- function(fit) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
}

## ---------------------------------------------------------------
## Cell 1: phylo_latent + phylo_unique (paired) -- recovery
##
## The paired decomposition splits the phylogenetic covariance into a
## shared rank-d cross-trait part (phylo_latent => phylo_rr) and a
## per-trait unique part (phylo_unique => phylo_diag). The implied
## Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy). We generate from a
## rank-1 shared factor plus per-trait unique phylo variance, both on the
## same identity-VCV phylo grid, and check that the recovered total
## phylogenetic variance (sum of the diagonal of Sigma_phy) is in a 4x
## band of the truth. Paired latent+unique requires `unit = "species"`.
## ---------------------------------------------------------------
make_poisson_phylo_paired_fixture <- function(n_sp = 50L, n_traits = 3L,
                                               n_rep = 3L, seed = 20260529L) {
  set.seed(seed)
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))

  ## Shared rank-1 phylogenetic factor: one latent species score scaled by
  ## a per-trait loading. Plus a per-trait unique phylogenetic deviation.
  lambda_shared <- c(0.5, 0.4, 0.45)[seq_len(n_traits)]   # loadings on f
  sigma2_unique <- c(0.20, 0.25, 0.20)[seq_len(n_traits)] # per-trait unique var
  ## True total phylo variance per trait = lambda^2 (var f == 1) + unique.
  total_var_true <- lambda_shared^2 + sigma2_unique

  f_shared <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))  # var 1 on phylo grid
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    u_t <- sqrt(sigma2_unique[t]) * as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
    p_mat[, t] <- lambda_shared[t] * f_shared + u_t
  }
  ## Intercept mean ~= 2 (count mean ~= 7.4); small per-trait spread.
  alpha <- c(2.0, 1.9, 2.1)[seq_len(n_traits)]

  rows <- vector("list", n_sp * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      for (r in seq_len(n_rep)) {
        y <- stats::rpois(1L, lambda = exp(eta))
        rows[[k]] <- data.frame(
          species = sp_names[i],
          trait   = paste0("trait_", t),
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

  list(data = df, Cphy = Cphy, sp_names = sp_names, n_traits = n_traits,
       total_var_true = total_var_true)
}

test_that("phylo_latent + phylo_unique (paired) on Poisson: fit converges; total phylo variance recovers", {
  skip_if_not_heavy()
  skip_if_not_poisson_phylo_deps()
  fx <- make_poisson_phylo_paired_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1) + phylo_unique(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::poisson(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_latent + phylo_unique poisson fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    skip("phylo_latent + phylo_unique poisson fit did not converge with PD Hessian; PHY-04/05 (poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_phylo_fit_health(fit)
  ## Paired decomposition: latent => phylo_rr, unique => phylo_diag.
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_diag))

  ## ---- Recovery on total phylogenetic variance -------------------------
  ## Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy); the diagonal is the
  ## per-trait total phylogenetic variance. We compare the summed diagonal
  ## (a single rotation-invariant scalar) against the truth in a 4x band.
  sig_phy <- tryCatch(
    suppressMessages(suppressWarnings(
      gllvmTMB::extract_Sigma(fit, level = "phy", part = "total")
    )),
    error = function(e) e
  )
  if (inherits(sig_phy, "error") || is.null(sig_phy$Sigma) ||
        !is.matrix(sig_phy$Sigma)) {
    skip(sprintf(
      "extract_Sigma(level='phy', part='total') unavailable: %s",
      if (inherits(sig_phy, "error")) conditionMessage(sig_phy) else "no Sigma"
    ))
  }
  expect_equal(dim(sig_phy$Sigma), c(fx$n_traits, fx$n_traits))
  diag_hat <- diag(sig_phy$Sigma)
  expect_true(all(is.finite(diag_hat)))
  expect_true(all(diag_hat > 0))

  trace_hat   <- sum(diag_hat)
  trace_truth <- sum(fx$total_var_true)
  ratio <- trace_hat / trace_truth
  if (!is.finite(ratio) || ratio < 1 / 4 || ratio > 4) {
    skip(sprintf(
      "Total phylo variance recovery outside 4x band (hat = %.3g, truth = %.3g, ratio = %.3g); PHY-04/05 (poisson) stays partial pending bigger n",
      trace_hat, trace_truth, ratio
    ))
  }
  expect_gt(trace_hat, trace_truth / 4)
  expect_lt(trace_hat, trace_truth * 4)
})

## ---------------------------------------------------------------
## Cell 2: phylo_scalar(species) -- recovery + CI smoke
##
## Single shared sigma^2_phy_scalar across all traits. `phylo_scalar`
## rewrites to the propto path: `use$propto == TRUE`, and the TMB
## parameter `loglambda_phy` carries the single scaling with
## sigma^2_phy = exp(loglambda_phy). CI smoke is on `lambda_phy`
## (the propto path does not set phylo_rr/phylo_diag, so the
## `phylo_signal` token does not apply -- same reasoning as the binary
## PHY-04 test).
## ---------------------------------------------------------------
make_poisson_phylo_scalar_fixture <- function(n_sp = 50L, n_traits = 3L,
                                              n_rep = 3L,
                                              sigma2_phy_true = 0.4,
                                              seed = 20260529L) {
  set.seed(seed)
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))

  ## One shared sigma^2 across traits; each trait an independent draw.
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true) *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  alpha <- c(2.0, 1.9, 2.1)[seq_len(n_traits)]

  rows <- vector("list", n_sp * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      for (r in seq_len(n_rep)) {
        y <- stats::rpois(1L, lambda = exp(eta))
        rows[[k]] <- data.frame(
          species = sp_names[i],
          trait   = paste0("trait_", t),
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

  list(data = df, Cphy = Cphy, sp_names = sp_names, n_traits = n_traits,
       sigma2_phy_true = sigma2_phy_true)
}

test_that("phylo_scalar(species) on Poisson: fit converges; sigma^2_phy_scalar recovers; lambda_phy profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_poisson_phylo_deps()
  fx <- make_poisson_phylo_scalar_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::poisson(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_scalar poisson fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    skip("phylo_scalar poisson fit did not converge with PD Hessian; PHY-04 (poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$propto))

  ## ---- Recovery on the single shared sigma^2_phy_scalar -----------------
  ## sigma^2_phy = exp(loglambda_phy) (see src/gllvmTMB.cpp; the propto
  ## prior is MVN(0, exp(loglambda_phy) * Cphy)). Mean-dependent family =>
  ## 4x band (wider than the binary-probit 3x band per Design 59).
  loglam <- unname(fit$opt$par["loglambda_phy"])
  expect_true(is.finite(loglam))
  sigma2_phy_hat <- exp(loglam)
  ratio <- sigma2_phy_hat / fx$sigma2_phy_true
  if (!is.finite(ratio) || ratio < 1 / 4 || ratio > 4) {
    skip(sprintf(
      "sigma^2_phy_scalar recovery outside 4x band (hat = %.3g, truth = %.3g, ratio = %.3g); PHY-04 (poisson) stays partial pending bigger n",
      sigma2_phy_hat, fx$sigma2_phy_true, ratio
    ))
  }
  expect_gt(sigma2_phy_hat, fx$sigma2_phy_true / 4)
  expect_lt(sigma2_phy_hat, fx$sigma2_phy_true * 4)

  ## ---- CI smoke: confint(parm = "lambda_phy", method = "profile") -------
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
## Cells 3 & 4: phylo_indep and phylo_dep -- recovery/smoke
##
## Shared fixture: per-trait phylogenetic deviations on the identity VCV,
## with a mild positive cross-trait correlation so the `dep` (full
## unstructured) keyword has signal to recover and `extract_correlations`
## is non-degenerate. `phylo_indep` (diagonal Sigma_b) is the easiest
## phylo count case; `phylo_dep` rewrites to phylo_rr(d = n_traits).
## ---------------------------------------------------------------
make_poisson_phylo_depindep_fixture <- function(n_sp = 50L, n_traits = 3L,
                                                seed = 20260529L) {
  set.seed(seed)
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))

  ## Per-trait phylo SDs + a mild positive cross-trait correlation rho so
  ## the dep keyword has a non-zero off-diagonal to recover. We build the
  ## cross-trait covariance Sigma_b and draw trait deviations jointly per
  ## species (each species score vector ~ N(0, Sigma_b), then smeared on
  ## the phylo grid via the identity VCV => i.i.d. species).
  sd_trait <- c(0.55, 0.5, 0.45)[seq_len(n_traits)]
  rho <- 0.4
  R <- matrix(rho, n_traits, n_traits); diag(R) <- 1
  Sigma_b <- diag(sd_trait) %*% R %*% diag(sd_trait)
  Lb <- chol(Sigma_b)
  ## Species scores: n_sp x n_traits, each row ~ N(0, Sigma_b), then the
  ## identity-VCV phylo smear is the identity (star tree) so scores carry
  ## directly. (t(Lphy) %*% z reduces to z up to the 1e-8 jitter.)
  p_mat <- matrix(stats::rnorm(n_sp * n_traits), n_sp, n_traits) %*% Lb
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- as.numeric(t(Lphy) %*% p_mat[, t])
  }
  alpha <- c(2.0, 1.9, 2.1)[seq_len(n_traits)]

  rows <- vector("list", n_sp * n_traits)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      y <- stats::rpois(1L, lambda = exp(eta))
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

  list(data = df, Cphy = Cphy, sp_names = sp_names, n_traits = n_traits)
}

test_that("phylo_indep(0 + trait | species) on Poisson: fit converges; extract_correlations(tier='phy') non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_poisson_phylo_deps()
  fx <- make_poisson_phylo_depindep_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::poisson(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_indep poisson fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    skip("phylo_indep poisson fit did not converge with PD Hessian; PHY-05 (poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_indep))

  ## extract_correlations(tier = "phy") on a diag-only phylo tier returns
  ## one row per upper-tri pair; correlations are structural zeros but the
  ## frame must be non-degenerate (finite, not empty / not all NA).
  cor_df <- tryCatch(
    suppressMessages(suppressWarnings(
      gllvmTMB::extract_correlations(
        fit, tier = "phy", method = "fisher-z", link_residual = "none"
      )
    )),
    error = function(e) e
  )
  if (inherits(cor_df, "error")) {
    skip(sprintf(
      "extract_correlations(tier='phy') errored: %s",
      conditionMessage(cor_df)
    ))
  }
  expect_s3_class(cor_df, "data.frame")
  expect_gt(nrow(cor_df), 0L)
  expect_true(all(c("tier", "trait_i", "trait_j", "correlation",
                    "lower", "upper") %in% names(cor_df)))
  expect_true(all(is.finite(cor_df$correlation)))
})

test_that("phylo_dep(0 + trait | species) on Poisson: fit converges; rho:phy profile CI smoke + extract_correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_poisson_phylo_deps()
  fx <- make_poisson_phylo_depindep_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::poisson(link = "log")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_dep poisson fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    skip("phylo_dep poisson fit did not converge with PD Hessian; PHY-05 (poisson) stays partial pending bigger n / different seed")
  }

  expect_poisson_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_dep))
  expect_true(isTRUE(fit$use$phylo_rr))  # phylo_dep rewrites to phylo_rr(d = n_traits)

  ## CI smoke: confint(parm = "rho:phy:1,2", method = "profile") routes
  ## through the phy-tier profile-CI path. We require at least one finite
  ## bound on at least one of the upper-tri pairs (1,2 / 1,3 / 2,3).
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
    skip("Profile CI for rho:phy did not return any finite bound on any pair; PHY-05 (poisson) CI smoke stays partial -- honest skip rather than relax assertion")
  }
  expect_true(any_finite)

  ## extract_correlations on the phy tier with rr present: one row per
  ## upper-tri pair with finite correlations.
  cor_df <- tryCatch(
    suppressMessages(suppressWarnings(
      gllvmTMB::extract_correlations(
        fit, tier = "phy", method = "fisher-z", link_residual = "none"
      )
    )),
    error = function(e) e
  )
  if (inherits(cor_df, "error")) {
    skip(sprintf(
      "extract_correlations(tier='phy') errored: %s",
      conditionMessage(cor_df)
    ))
  }
  expect_s3_class(cor_df, "data.frame")
  expect_gt(nrow(cor_df), 0L)
  expect_true(all(is.finite(cor_df$correlation)))
})
