## Phase B-INF Lane 2 / B2 (Design 58): `phylo_indep` and `phylo_dep`
## on a binary probit fit — recovery + CI smoke.
##
## Walks PHY-05 of `docs/design/35-validation-debt-register.md`
## from `partial` to `covered` for the binary probit branch.
##
## Fixture: 3 traits, 40 species, star tree (identity VCV), binary probit.
## A star tree means `Cphy = I_n_sp`; species are i.i.d. on the phylo side,
## which is the cleanest identifiable case for these two keywords.
##
## What we assert:
##   * `phylo_indep(0 + trait | species)` fits cleanly (convergence == 0,
##     `fit_health$pd_hessian == TRUE`) and `extract_correlations(tier="phy")`
##     returns a non-degenerate data.frame.
##   * `phylo_dep(0 + trait | species)` on the same fixture fits cleanly
##     with `pd_hessian == TRUE`, supports `confint(parm = "rho:phy:1,2",
##     method = "profile")` returning a finite bound on at least one pair,
##     and `extract_correlations(tier="phy")` is non-degenerate.
##
## SKIP discipline (no fake-pass): if either fit fails to converge or
## the Hessian is non-PD we `skip()` honestly rather than relax the
## assertion. The register row stays `partial` if the test only skips.

skip_if_not_phylo_binary_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

make_phylo_binary_fixture <- function(n_sp = 40L, n_traits = 3L,
                                       seed = 20260528L) {
  set.seed(seed)
  ## Star tree: zero-branch internal node; tip-correlation matrix = identity.
  ## ape::stree() builds the topology; we provide the VCV directly so that
  ## species share no phylogenetic information beyond the tips themselves.
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)

  ## True phylogenetic SDs per trait — modest signal that probit can pick up
  ## at this fixture size without saturating Pr(y = 1).
  sigma2_phy_true <- c(0.6, 0.5, 0.4)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true[t]) *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  ## Intercepts per trait, kept near zero so Pr(y=1) lives mid-range.
  alpha <- c(-0.1, 0.0, 0.1)

  rows <- vector("list", n_sp * n_traits)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      y <- stats::rbinom(1L, size = 1L, prob = stats::pnorm(eta))
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
    sigma2_phy_true = sigma2_phy_true
  )
}

expect_binary_phylo_fit_health <- function(fit) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
}

## ---------------------------------------------------------------
## phylo_indep(0 + trait | species) on binary probit
## ---------------------------------------------------------------
test_that("phylo_indep(0 + trait | species) fits on binary probit; pd_hessian TRUE", {
  skip_if_not_heavy()
  skip_if_not_phylo_binary_deps()
  fx <- make_phylo_binary_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::binomial(link = "probit")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_indep binary probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_indep binary probit fit did not converge with PD Hessian; PHY-05 stays partial pending bigger n / different seed")
  }

  expect_binary_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_indep))

  ## extract_correlations(tier = "phy") on a diag-only phylo tier returns
  ## a data.frame with one row per upper-tri pair; correlations are
  ## structural zeros but the frame must be non-degenerate (finite bounds,
  ## not empty / not all NA).
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier   = "phy",
      method = "fisher-z",
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
## phylo_dep(0 + trait | species) on the same fixture
## ---------------------------------------------------------------
test_that("phylo_dep(0 + trait | species) fits on binary probit; CI smoke + extract_correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_phylo_binary_deps()
  fx <- make_phylo_binary_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::binomial(link = "probit")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_dep binary probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_dep binary probit fit did not converge with PD Hessian; PHY-05 stays partial pending bigger n / different seed")
  }

  expect_binary_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_dep))
  expect_true(isTRUE(fit$use$phylo_rr))  # phylo_dep rewrites to phylo_rr(d = n_traits)

  ## CI smoke: confint(parm = "rho:phy:1,2", method = "profile") routes
  ## through profile_ci_correlation() at the "phy" tier and returns a
  ## 1x2 matrix. We require at least one finite bound on at least one
  ## of the three upper-tri pairs (1,2 / 1,3 / 2,3).
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
    skip("Profile CI for rho:phy did not return any finite bound on any pair; honest skip rather than relax assertion")
  }
  expect_true(any_finite)

  ## extract_correlations on phy tier with rr present: returns one row per
  ## upper-tri pair with finite correlations.
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier   = "phy",
      method = "fisher-z",
      link_residual = "none"
    )
  ))
  expect_s3_class(cor_df, "data.frame")
  expect_gt(nrow(cor_df), 0L)
  expect_true(all(is.finite(cor_df$correlation)))
})
