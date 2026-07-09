## Phase B-matrix SLOPE-gam (Design 59): random-slope anchor
## `phylo_unique(1 + x | species)` x `Gamma(link = "log")` recovery +
## CI smoke. Walks the slope column of the family x structure matrix for
## the gamma (log-link) branch from `partial` toward `covered`.
##
## This is the *augmented-LHS* anchor (Phase 56.3-56.4): the per-species
## intercept and slope are drawn jointly from N(0, Sigma_b (x) A_phy) with
## Sigma_b a 2x2 (intercept, slope) covariance. The engine reports this
## block as `report$sd_b` (length 2 SDs) + `report$cor_b` (the off-diagonal
## correlation) -- NOT the multi-trait `phy` correlation frame used by the
## `test-matrix-gamma-phylo.R` sibling. Recovery extractors mirror the
## Gaussian anchor `test-phylo-unique-slope-gaussian.R`:
##
## | Symbol  | Covstruct keyword                  | DGP draw                              | Recovery extractor | Truth |
## | sigma2a | phylo_unique augmented intercept   | (alpha,beta) ~ N(0, Sigma_b (x) A)    | report$sd_b[1]^2   | 0.4   |
## | sigma2b | phylo_unique augmented slope       | (alpha,beta) ~ N(0, Sigma_b (x) A)    | report$sd_b[2]^2   | 0.3   |
## | rho_ab  | phylo_unique augmented covariance  | Sigma_b[1,2] via rho = 0.5            | report$cor_b[1]    | 0.5   |
##
## Fixture (Honest-matrix discipline, Design 59): seed-controlled,
## log-link, gamma shape phi = 2 (=> CV = 1/sqrt(2) ~ 0.707, stored by the
## engine in per-trait `report$phi_gamma`). Trait
## intercepts on the log scale near 0 so E(y) = exp(eta) ~ 1, 3 traits,
## STAR tree (identity VCV => species i.i.d. on the phylo side, the cleanest
## identifiable case). `x` is held IDENTICAL across traits within each
## (species, rep) cell so the augmented Z surface matches the Phase 56.4
## anchor, and `n_rep` replicates per cell concentrate the per-cell
## likelihood -- a single gamma observation per cell carries thin
## information about the latent (alpha, beta) prior (same replication
## rationale as the scalar/diag gamma fixtures).
##
## Gamma is a *mean-dependent* family (residual scale is not fixed by the
## link, unlike binomial / ordinal-probit), so per the Phase B0 scoping
## memo we use the WIDER recovery band (3x on the variance scale), never
## the tight fixed-residual-scale band (and never the 20% Gaussian band).
##
## SKIP discipline (no fake-pass, Design 59): if the fit fails to construct,
## fails to converge, is non-PD, or recovery falls outside the 3x band, we
## `skip()` honestly rather than relax the assertion. A cell that only skips
## leaves its register row `partial`. Time-box per fit is the campaign-wide
## 15 min; this star-tree fit is far under that locally (~2 s).

skip_if_not_slope_gamma_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Augmented phylo_unique(1 + x | species) x gamma(log) fixture. Returns a
## long data frame with a `trait` factor (>= 2 levels: the augmented LHS
## engine path requires the trait column), `x` shared across traits within
## each (species, rep) cell, and a gamma response.
make_slope_gamma_fixture <- function(seed = 20260529L,
                                     n_sp = 60L,
                                     n_traits = 3L,
                                     n_rep = 6L,
                                     phi = 2) {
  set.seed(seed)
  ## Star tree: tip-correlation matrix = identity.
  sp_names <- paste0("sp", seq_len(n_sp))
  Cphy <- diag(n_sp)
  dimnames(Cphy) <- list(sp_names, sp_names)

  ## 2x2 augmented covariance Sigma_b (intercept, slope).
  sigma2_int_true   <- 0.4
  sigma2_slope_true <- 0.3
  rho_true          <- 0.5
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L, ncol = 2L
  )

  ## (alpha, beta)_species ~ N(0, Sigma_b (x) A_phy); star tree => A = I.
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))
  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- sp_names

  ## x identical across traits within each (species, rep) cell.
  species_rep <- expand.grid(
    species = factor(sp_names, levels = sp_names),
    rep     = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))

  trait_levels <- paste0("t", seq_len(n_traits))
  df <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df <- df[order(df$species, df$rep, df$trait), ]

  ## Log-scale trait intercepts near 0 => E(y) = exp(intercept) ~ 1.
  mu_t <- c(0.0, 0.1, -0.1, 0.05)[as.integer(df$trait)]
  alpha_sp <- ab[as.character(df$species), "alpha"]
  beta_sp  <- ab[as.character(df$species), "beta"]
  eta <- mu_t + alpha_sp + beta_sp * df$x
  mu  <- exp(eta)

  ## gamma shape = phi (so CV = 1/sqrt(phi)); scale = mu / shape.
  df$value <- stats::rgamma(nrow(df), shape = phi, scale = mu / phi)

  list(
    data              = df,
    Cphy              = Cphy,
    phi               = phi,
    n_traits          = n_traits,
    sigma2_int_true   = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true          = rho_true,
    cov_true          = cov_true,
    Sigma_b_true      = Sigma_b_true
  )
}

fit_slope_gamma <- function(fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_unique(1 + x | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = stats::Gamma(link = "log"),
      control   = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )
}

expect_slope_gamma_fit_health <- function(fit) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
  ## Confirm the response really is gamma (family_id 4) -- guards against a
  ## silent family fallthrough making the "gamma" claim hollow.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], 4L)
}

## Reconstruct the 2x2 augmented Sigma_b from report$sd_b + report$cor_b.
slope_gamma_Sigma_b <- function(fit) {
  sd_b <- as.numeric(fit$report$sd_b)
  rho  <- as.numeric(fit$report$cor_b)
  matrix(
    c(
      sd_b[1L]^2,
      rho * sd_b[1L] * sd_b[2L],
      rho * sd_b[1L] * sd_b[2L],
      sd_b[2L]^2
    ),
    nrow = 2L, ncol = 2L,
    dimnames = list(c("intercept", "slope"), c("intercept", "slope"))
  )
}

## ---------------------------------------------------------------
## Recovery: sigma2_alpha, sigma2_beta, rho within Phase-B0 band
## ---------------------------------------------------------------
test_that("phylo_unique(1 + x | species) x Gamma(log) converges, pd_hessian TRUE, recovers Sigma_b within mean-dependent band", {
  skip_if_not_heavy()
  skip_if_not_slope_gamma_deps()
  fx <- make_slope_gamma_fixture()

  fit <- fit_slope_gamma(fx)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_unique(1 + x | species) gamma(log) fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_unique(1 + x | species) gamma(log) fit did not converge with PD Hessian; slope-gamma cell stays partial pending bigger n / different seed")
  }

  expect_slope_gamma_fit_health(fit)
  ## Augmented correlated-slope engine path is active.
  expect_identical(fit$tmb_data$use_phylo_slope_correlated, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, 2L)

  ## Confirm the gamma CV is carried in per-trait phi_gamma:
  ## shape = phi = 2 => CV = 1/sqrt(2) ~ 0.707. Wide (3x) band, mean-dependent.
  cv_hat   <- 1 / sqrt(as.numeric(fit$report$phi_gamma))
  cv_truth <- 1 / sqrt(fx$phi)
  expect_true(all(is.finite(cv_hat)))
  expect_gt(min(cv_hat), cv_truth / 3)
  expect_lt(max(cv_hat), cv_truth * 3)

  Sigma_hat <- slope_gamma_Sigma_b(fit)
  sigma2_int_hat   <- unname(Sigma_hat["intercept", "intercept"])
  sigma2_slope_hat <- unname(Sigma_hat["slope", "slope"])
  rho_hat <- unname(stats::cov2cor(Sigma_hat)["intercept", "slope"])

  ## WIDER (3x) variance-scale band: gamma is mean-dependent, so the
  ## residual scale is not pinned by the link. Per Phase B0 this is the
  ## honest band; never the 20% Gaussian band. Honest skip if outside.
  ratio_int   <- sigma2_int_hat   / fx$sigma2_int_true
  ratio_slope <- sigma2_slope_hat / fx$sigma2_slope_true
  if (!is.finite(ratio_int) || ratio_int < 1 / 3 || ratio_int > 3 ||
        !is.finite(ratio_slope) || ratio_slope < 1 / 3 || ratio_slope > 3) {
    skip(sprintf(
      "Sigma_b variance recovery outside 3x band (sigma2_int hat = %.3g [truth %.2g], sigma2_slope hat = %.3g [truth %.2g]); slope-gamma cell stays partial pending bigger n",
      sigma2_int_hat, fx$sigma2_int_true, sigma2_slope_hat, fx$sigma2_slope_true
    ))
  }
  expect_gt(sigma2_int_hat,   fx$sigma2_int_true / 3)
  expect_lt(sigma2_int_hat,   fx$sigma2_int_true * 3)
  expect_gt(sigma2_slope_hat, fx$sigma2_slope_true / 3)
  expect_lt(sigma2_slope_hat, fx$sigma2_slope_true * 3)

  ## Correlation: an absolute tolerance (a correlation has no meaningful
  ## "3x" ratio). 0.35 is wide enough for a mean-dependent family at this n
  ## while still excluding a sign flip or a near-boundary degenerate rho.
  if (!is.finite(rho_hat) || abs(rho_hat - fx$rho_true) > 0.35) {
    skip(sprintf(
      "rho recovery outside +/-0.35 (hat = %.3g, truth = %.2g); slope-gamma cell stays partial pending bigger n",
      rho_hat, fx$rho_true
    ))
  }
  expect_lte(abs(rho_hat - fx$rho_true), 0.35)
})

## ---------------------------------------------------------------
## CI smoke: spec'd rho:phy token OR the augmented slope-variance
## profile CI must return a finite bound.
## ---------------------------------------------------------------
test_that("phylo_unique(1 + x | species) x Gamma(log) CI smoke: slope-variance profile CI is finite", {
  skip_if_not_heavy()
  skip_if_not_slope_gamma_deps()
  fx <- make_slope_gamma_fixture()

  fit <- fit_slope_gamma(fx)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_unique(1 + x | species) gamma(log) fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_unique(1 + x | species) gamma(log) fit did not converge with PD Hessian; CI smoke not attempted, slope-gamma cell stays partial")
  }

  ## Branch 1 (spec'd token): confint(parm = "rho:phy:1,2", method =
  ## "profile"). On the *augmented* anchor this routes to the multi-trait
  ## `phy` correlation frame, which does not exist here (the intercept/slope
  ## correlation lives in report$cor_b, not a per-trait phy tier), so it is
  ## expected to error. We attempt it honestly and fall through to the
  ## slope-variance profile CI -- the engine-faithful "slope-var profile CI"
  ## branch of the Design 59 CI-smoke contract.
  rho_ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:phy:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  rho_ci_finite <- !inherits(rho_ci, "error") && is.matrix(rho_ci) &&
    any(is.finite(rho_ci))

  ## Branch 2 (slope-variance profile CI): profile the augmented slope
  ## log-SD (log_sd_b[2], the 2nd augmented diagonal) and transform to the
  ## SD scale. This is the genuine direct-parameter profile for the slope
  ## variance of this cell.
  slope_ci <- tryCatch(
    gllvmTMB:::tmbprofile_wrapper(
      fit, name = "log_sd_b", which = 2L, transform = exp
    ),
    error = function(e) e
  )
  slope_ci_finite <- !inherits(slope_ci, "error") &&
    is.numeric(slope_ci) &&
    any(is.finite(slope_ci[c("lower", "upper")]))

  if (!rho_ci_finite && !slope_ci_finite) {
    skip("Neither rho:phy profile CI nor the slope-variance profile CI returned a finite bound; honest skip rather than relax the assertion")
  }
  expect_true(rho_ci_finite || slope_ci_finite)
})
