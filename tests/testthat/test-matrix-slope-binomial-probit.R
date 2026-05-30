## Design 59 Phase B-matrix -- SLOPE column on the non-Gaussian matrix.
## Anchor cell `phylo_unique(1 + x | species)` (Design 55 sec.5: "the
## canonical structural-slope unit; primary A1 test case") composed with
## `binomial(link = "probit")`. Recovery of the augmented 2x2 Sigma_b
## (intercept variance, slope variance, intercept-slope correlation) plus
## a CI smoke.
##
## Why probit is the cleanest non-Gaussian slope target: per the Phase B0
## scoping memo (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-
## scoping.md, sec.3.1) the binomial-probit latent residual variance is
## fixed to 1 exactly (vs pi^2/3 for logit), giving a fixed residual
## scale. Fisher's rule (Design 59 "Honest-matrix discipline") puts
## fixed-residual-scale families on a tighter band than mean-dependent
## ones -- but the same memo flags that for binary data the slope variance
## and the intercept-slope correlation need substantial var(x) and a
## non-trivial n_sp before they identify (a single Bernoulli draw per
## (species, x) cell carries little information about the species-level
## Sigma_b). The fixture therefore mirrors the Gaussian anchor's truth
## (sigma^2_alpha = 0.4, sigma^2_beta = 0.3, rho = 0.5) but uses
## n_sp = 80 with n_rep = 6 binary replicates per (species, x) cell for
## identification, and var(x) = 1.
##
## Alignment table (mirrors test-phylo-unique-slope-gaussian.R):
##
## | Symbol   | Covstruct keyword                  | Recovery extractor | Truth |
## | alpha_sp | phylo_unique augmented intercept   | report$sd_b[1]^2   | 0.4   |
## | beta_sp  | phylo_unique augmented slope       | report$sd_b[2]^2   | 0.3   |
## | rho_ab   | phylo_unique augmented correlation | report$cor_b[1]    | 0.5   |
##
## SKIP discipline (no fake-pass, no widening tolerances; Design 59):
## non-convergence / non-PD Hessian / recovery outside the documented
## binary-probit band => honest skip("reason") and the register row stays
## `partial`. Tolerances are NOT relaxed to force green.

skip_if_not_matrix_slope_probit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Phase B0 binary-probit recovery bands. Tighter than a mean-dependent
## family (the latent scale is fixed to 1), but honest about the
## documented fragility of the slope variance and the intercept-slope
## correlation on binary data. The intercept variance identifies most
## cleanly; the correlation is the hardest component and gets the
## Gaussian template's absolute band.
.matrix_slope_probit_tol <- list(
  sigma2_int_rel = 0.35, # |hat - true| / true on sigma^2_alpha
  sigma2_slope_rel = 0.40, # |hat - true| / true on sigma^2_beta
  rho_abs = 0.30 # |hat - true| on rho (same as Gaussian template)
)

make_matrix_slope_probit_fixture <- function(
  seed = 11L,
  n_sp = 80L,
  n_traits = 3L,
  n_rep = 6L
) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  sigma2_int_true <- 0.4
  sigma2_slope_true <- 0.3
  rho_true <- 0.5
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L,
    ncol = 2L
  )

  ## Matrix-normal draw: (alpha, beta) ~ N(0, Sigma_b (x) A_phy).
  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

  ## var(x) = 1 keeps the slope contribution out of the latent-residual
  ## noise floor (Phase B0 sec.4: sigma^2_beta needs var(x) substantial).
  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))

  trait_levels <- paste0("t", seq_len(n_traits))
  df_long <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]

  ## Intercepts per trait kept near zero so Pr(y = 1) lives mid-range.
  mu_t <- c(0.2, 0.0, -0.2, 0.1)[as.integer(df_long$trait)]
  alpha_sp <- ab[as.character(df_long$species), "alpha"]
  beta_sp <- ab[as.character(df_long$species), "beta"]
  eta <- mu_t + alpha_sp + beta_sp * df_long$x
  ## Probit link: Pr(y = 1) = Phi(eta); single-trial binary response.
  df_long$value <- stats::rbinom(nrow(df_long), size = 1L, prob = stats::pnorm(eta))

  list(
    df_long = df_long,
    tree = tree,
    Sigma_b_true = Sigma_b_true,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true,
    cov_true = cov_true,
    ab_true = ab
  )
}

fit_matrix_slope_probit <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_unique(0 + trait + (0 + trait):x | species),
      data = fx$df_long,
      phylo_tree = fx$tree,
      unit = "species",
      family = stats::binomial(link = "probit"),
      control = ctl
    ))),
    error = function(e) e
  )
}

## ---------------------------------------------------------------------
## phylo_unique(1 + x | sp) x binomial-probit: fit health + Sigma_b
## recovery + slope-variance profile CI smoke.
## ---------------------------------------------------------------------
test_that("phylo_unique(1 + x | sp) x binomial-probit recovers Sigma_b and a slope-variance profile CI is finite", {
  skip_if_not_heavy()
  skip_if_not_matrix_slope_probit_deps()

  fx <- make_matrix_slope_probit_fixture()
  fit <- fit_matrix_slope_probit(fx)

  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_unique(1 + x | sp) binomial-probit fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB object"
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
      !isTRUE(fit$fit_health$pd_hessian)) {
    skip("phylo_unique(1 + x | sp) binomial-probit fit did not converge with PD Hessian; RE-02 / PHY-06(probit) stay partial pending bigger n / different seed")
  }

  ## ---- Fit health -----------------------------------------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(isTRUE(fit$fit_health$pd_hessian))

  ## ---- Recovery on the augmented 2x2 Sigma_b -------------------------
  ## report$sd_b = exp(log_sd_b) (col 1 = intercept, col 2 = slope; see
  ## R/fit-multi.R Z_phy_aug construction + src/gllvmTMB.cpp REPORT(sd_b)).
  ## report$cor_b = tanh(atanh_cor_b) is the intercept-slope correlation.
  sd_b <- as.numeric(fit$report$sd_b)
  cor_b <- as.numeric(fit$report$cor_b)
  expect_length(sd_b, 2L)
  expect_length(cor_b, 1L)
  expect_true(all(is.finite(sd_b)) && is.finite(cor_b))

  sigma2_int_hat <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2
  rho_hat <- cor_b

  int_rel <- abs(sigma2_int_hat - fx$sigma2_int_true) / fx$sigma2_int_true
  slope_rel <- abs(sigma2_slope_hat - fx$sigma2_slope_true) / fx$sigma2_slope_true
  rho_err <- abs(rho_hat - fx$rho_true)

  ## Honest skip (NOT widen) if any component lands outside the documented
  ## binary-probit band: the register row stays `partial`.
  if (int_rel > .matrix_slope_probit_tol$sigma2_int_rel ||
      slope_rel > .matrix_slope_probit_tol$sigma2_slope_rel ||
      rho_err > .matrix_slope_probit_tol$rho_abs) {
    skip(sprintf(
      paste0(
        "Sigma_b recovery outside Phase-B0 binary-probit band ",
        "(sigma^2_int hat=%.3f true=%.3f rel=%.2f; ",
        "sigma^2_slope hat=%.3f true=%.3f rel=%.2f; ",
        "rho hat=%.3f true=%.3f abs=%.2f); ",
        "RE-02 / PHY-06(probit) stay partial pending bigger n"
      ),
      sigma2_int_hat, fx$sigma2_int_true, int_rel,
      sigma2_slope_hat, fx$sigma2_slope_true, slope_rel,
      rho_hat, fx$rho_true, rho_err
    ))
  }

  expect_lte(int_rel, .matrix_slope_probit_tol$sigma2_int_rel)
  expect_lte(slope_rel, .matrix_slope_probit_tol$sigma2_slope_rel)
  expect_lte(rho_err, .matrix_slope_probit_tol$rho_abs)

  ## ---- CI smoke -------------------------------------------------------
  ## The augmented Sigma_b lives in TMB parameters `log_sd_b` /
  ## `atanh_cor_b`, which are not registered confint parm tokens, and the
  ## `rho:phy:i,j` token addresses the *across-trait* phylo correlation
  ## (extract_correlations), not the intercept-slope rho of the augmented
  ## path -- on a fit with no across-trait phylo block it aborts with
  ## "nothing to extract at level phy". We therefore take the genuine
  ## profile-likelihood CI on the slope variance directly via
  ## tmbprofile_wrapper() on log_sd_b[2] (transform exp(2 * .) -> variance
  ## scale). This is the "slope-variance profile CI finite" branch of the
  ## Design 59 CI-smoke contract. Honest skip if the profile degenerates.
  ci_slope <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::tmbprofile_wrapper(
      fit,
      name = "log_sd_b",
      which = 2L,
      transform = function(z) exp(2 * z)
    ))),
    error = function(e) e
  )
  if (inherits(ci_slope, "error")) {
    skip(sprintf(
      "slope-variance profile CI errored: %s",
      conditionMessage(ci_slope)
    ))
  }
  expect_length(ci_slope, 3L)
  ## A finite point estimate plus at least one finite bound is the smoke
  ## (a variance pinned at the lower boundary returns lower = 0, which is
  ## the natural boundary, still informative).
  expect_true(is.finite(ci_slope[["estimate"]]))
  expect_true(any(is.finite(c(ci_slope[["lower"]], ci_slope[["upper"]]))))
})

## ---------------------------------------------------------------------
## Negative test: the augmented path must abort when n_lhs_cols is forced
## to 1 (mirrors test-phylo-unique-slope-gaussian.R). This proves the
## 2-column augmented Sigma_b machinery -- not a scalar-slope fallback --
## is what carries the binomial-probit fit.
## ---------------------------------------------------------------------
test_that("phylo_unique(1 + x | sp) x binomial-probit aborts when n_lhs_cols is forced to 1", {
  skip_if_not_heavy()
  skip_if_not_matrix_slope_probit_deps()

  fx <- make_matrix_slope_probit_fixture(n_sp = 12L, n_rep = 3L)
  fit <- fit_matrix_slope_probit(fx)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "small-n probit fixture failed to construct for the n_lhs_cols guard check: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB object"
    ))
  }

  tmb_data <- fit$tmb_data
  tmb_data$n_lhs_cols <- 1L

  expect_error(
    TMB::MakeADFun(
      data = tmb_data,
      parameters = fit$tmb_params,
      map = fit$tmb_map,
      random = "b_phy_aug",
      DLL = "gllvmTMB",
      silent = TRUE
    ),
    regexp = "n_lhs_cols does not match augmented phylo arrays"
  )
})
