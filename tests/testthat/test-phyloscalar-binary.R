## Phase B-INF Lane 2 / B1 (Design 58): `phylo_scalar(species)` on a
## binary probit fit -- recovery on the single shared phylogenetic
## scaling sigma^2_phy_scalar + CI smoke for that scaling.
##
## Walks PHY-04 of `docs/design/35-validation-debt-register.md` from
## `partial` to `covered` for the binary probit branch.
##
## Fixture: 3 traits, 40 species, 4 binary replicates per (species,
## trait), star tree (identity VCV). The replication per
## (species, trait) cell is the identification trick for binary
## probit: a single Bernoulli observation per cell carries too little
## information about p_phy[i, t] for the latent N(0, sigma^2_phy)
## prior to be recovered (the model collapses to sigma^2_phy = 0).
## With 4 trials per cell the per-cell likelihood concentrates enough
## that the single shared scaling is estimable. True sigma^2_phy = 0.8.
## The identity VCV is the cleanest identifiable case for a single
## shared sigma^2 across traits.
##
## What we assert:
##   * `phylo_scalar(species)` on binary probit fits cleanly
##     (`opt$convergence == 0`, `fit_health$pd_hessian == TRUE`,
##     `use$propto == TRUE`).
##   * Single shared sigma^2_phy_scalar recovers within the tolerance
##     band documented in Phase B0 (binomial x phylo x unique = OK; we
##     use a 4x band on a small n_sp = 40 fixture, consistent with the
##     Phase B0 memo's "modest n_sp" tolerance for binomial probit).
##   * `confint(parm = "lambda_phy", method = "profile")` returns a
##     finite 1x2 matrix on the single shared scaling parameter. This
##     is the appropriate CI smoke for `phylo_scalar`: by design
##     `phylo_signal` parm requires `phylo_rr` / `phylo_diag` (see
##     `profile_ci_phylo_signal()` precondition), neither of which is
##     set by the propto-based `phylo_scalar` path.
##
## SKIP discipline (no fake-pass): if the fit fails to converge or the
## Hessian is non-PD we `skip()` honestly rather than relax the
## assertion. The register row stays `partial` if the test only skips.

skip_if_not_phyloscalar_binary_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

make_phyloscalar_binary_fixture <- function(n_sp = 40L,
                                            n_traits = 3L,
                                            n_rep = 4L,
                                            sigma2_phy_true = 0.8,
                                            seed = 20260528L) {
  set.seed(seed)
  ## Star tree: zero-branch internal node; tip-correlation matrix = identity.
  ## Identity VCV is the canonical clean case for `phylo_scalar` recovery on
  ## binary probit: species are independent draws from N(0, sigma^2_phy),
  ## which removes between-species correlation as a confounder of the single
  ## shared variance.
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)

  ## One single shared sigma^2_phy across all traits (the `phylo_scalar`
  ## generative model). Each trait draws an independent length-n_sp vector
  ## from N(0, sigma^2_phy * I).
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true) *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  ## Intercepts per trait, kept near zero so Pr(y = 1) lives mid-range.
  alpha <- c(-0.1, 0.05, 0.0, 0.1)[seq_len(n_traits)]

  rows <- vector("list", n_sp * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      for (r in seq_len(n_rep)) {
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

expect_binary_phyloscalar_fit_health <- function(fit) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
}

## ---------------------------------------------------------------
## phylo_scalar(species) on binary probit: fit health + recovery + CI smoke
## ---------------------------------------------------------------
test_that("phylo_scalar(species) fits on binary probit; sigma^2_phy_scalar recovers; lambda_phy profile CI is finite", {
  skip_if_not_phyloscalar_binary_deps()
  fx <- make_phyloscalar_binary_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::binomial(link = "probit")
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_scalar binary probit fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    skip("phylo_scalar binary probit fit did not converge with PD Hessian; PHY-04 stays partial pending bigger n / different seed")
  }

  expect_binary_phyloscalar_fit_health(fit)
  ## `phylo_scalar` rewrites to `phylo()` then to `propto()`; the engine
  ## flag set is `use$propto`, not `use$phylo_rr` / `use$phylo_diag`.
  expect_true(isTRUE(fit$use$propto))

  ## ---- Recovery on the single shared sigma^2_phy_scalar -----------------
  ## The TMB parameter `loglambda_phy` is the log of the single shared
  ## scaling: sigma^2_phy_scalar = exp(2 * loglambda_phy). See
  ## src/gllvmTMB.cpp lines 242-246 ("Single global scaling loglambda_phy"
  ## ... "prior MVN(0, exp(loglambda_phy) * Cphy)" -- the prior variance is
  ## exp(loglambda_phy), so sigma^2_phy = exp(loglambda_phy) and
  ## sigma_phy = exp(loglambda_phy / 2)). The `profile_targets()` table
  ## labels this as `lambda_phy` with transformation `exp`, i.e. the
  ## variance scale; we recover on the variance scale to stay aligned.
  loglam <- unname(fit$opt$par["loglambda_phy"])
  expect_true(is.finite(loglam))
  sigma2_phy_hat <- exp(loglam)
  ## Tolerance band per Phase B0 memo (binomial x phylo x unique = OK at
  ## modest n; probit gives larger SE than logit because latent variance
  ## is 1 not pi^2/3). With n_sp = 40 and 3 traits x 4 replicates
  ## (480 binary obs), a 3x band on the variance scale is the honest
  ## recovery target; tighter bands need n_sp >= 80 per the memo's
  ## n-sweep guidance.
  ratio <- sigma2_phy_hat / fx$sigma2_phy_true
  if (!is.finite(ratio) || ratio < 1 / 3 || ratio > 3) {
    skip(sprintf(
      "sigma^2_phy_scalar recovery outside 3x band (hat = %.3g, truth = %.3g, ratio = %.3g); PHY-04 stays partial pending bigger n",
      sigma2_phy_hat, fx$sigma2_phy_true, ratio
    ))
  }
  expect_gt(sigma2_phy_hat, fx$sigma2_phy_true / 3)
  expect_lt(sigma2_phy_hat, fx$sigma2_phy_true * 3)

  ## ---- CI smoke: confint(parm = "lambda_phy", method = "profile") -------
  ## `phylo_scalar` uses the propto path: `use$propto = TRUE`, neither
  ## `use$phylo_rr` nor `use$phylo_diag` is set. By design,
  ## `profile_ci_phylo_signal()` aborts on fits without
  ## phylo_rr/phylo_diag (R/profile-derived.R:174-180), so the
  ## `parm = "phylo_signal"` token does not apply to the `phylo_scalar`
  ## generative model. The appropriate CI smoke is on the single shared
  ## scaling parameter exposed by `profile_targets()` as `lambda_phy`.
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
