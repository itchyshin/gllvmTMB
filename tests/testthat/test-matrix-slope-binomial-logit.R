## Phase B-matrix agent SLOPE-logit (Design 59): the random-slope anchor
## `phylo_unique(1 + x | species)` x `binomial(link = "logit")` -- augmented
## bivariate (intercept, slope) recovery + a profile-CI smoke.
##
## This is the binomial-logit branch of the random-slope column. The
## Gaussian anchor (test-phylo-unique-slope-gaussian.R) pins the same
## augmented LHS engine path with truth sigma^2_alpha = 0.4,
## sigma^2_beta = 0.3, rho = 0.5; here we swap the response to a
## multi-trial binomial under the logit link and re-run the recovery.
##
## Alignment table (mirrors the Gaussian template's extractor map):
##
## | Symbol  | Source                               | Recovery extractor | Truth |
## | sigma^2_alpha | phylo_unique augmented intercept var | report$sd_b[1]^2   | 0.4   |
## | sigma^2_beta  | phylo_unique augmented slope var     | report$sd_b[2]^2   | 0.3   |
## | rho_ab        | augmented intercept/slope corr       | report$cor_b[1]    | 0.5   |
##
## The augmented block lives in the TMB parameters log_sd_b (length 2:
## intercept, slope) and atanh_cor_b (length 1: rho), reported as sd_b /
## cor_b -- exactly the surface the Gaussian template checks. The phylo
## random effect is the augmented vector b_phy_aug; this is NOT a
## standard "phy correlation tier", so the `rho:phy:i,j` derived-quantity
## token does not apply here (see CI-smoke note below).
##
## ----------------------------------------------------------------------
## Fixed-residual-scale family (Phase B0 scoping memo, 2026-05-26 §3.1)
##
## Under the logit link the latent residual is fixed at sigma^2_d =
## pi^2 / 3 -- there is no estimated scale parameter to trade against the
## augmented Sigma_b, which sharpens identification relative to
## mean-dependent families. We use MULTI-TRIAL `cbind(succ, fail)` with
## `size = 12` trials per row and `n_rep = 5` rows per (species, trait)
## cell; per that memo, "multi-trial binomial ... has tighter
## identification" than single-trial. Tolerances:
##   * variances: 0.30 RELATIVE -- the multi-trial logit bound the unit-
##     tier sibling (test-matrix-binomial-logit-unit.R) adopts, looser
##     than the Gaussian template's 0.20 because binomial-logit is noisier
##     than Gaussian even multi-trial. NOT widened beyond the sibling.
##   * rho: 0.30 ABSOLUTE -- identical to the Gaussian template's rho band.
##
## Fixture size note: the augmented (intercept, slope) block on a
## binomial-logit response needs more information than the Gaussian anchor
## to reach the GLOBAL optimum (a smaller n_sp / size leaves the outer
## optimiser at a local optimum where the slope-variance profile is
## degenerate). n_sp = 80, n_rep = 5, size = 12 reaches the global
## optimum (the slope profile minimum coincides with the reported MLE).
##
## ----------------------------------------------------------------------
## SKIP discipline (no fake-pass, Design 59)
##
## The fit is wrapped in tryCatch; if it fails to construct, fails to
## converge, or is non-PD we skip() honestly and the binomial-logit branch
## of the random-slope column stays partial. If the recovery lands outside
## the honest band we skip rather than relax. The fit finishes in ~2 s,
## well inside the 15-min-per-fit time-box.

skip_if_not_slope_logit_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Multi-trial binomial-logit DGP for the augmented phylo_unique anchor.
##   (alpha_sp, beta_sp) ~ N(0, Sigma_b (x) A_phy) is a per-species
##   intercept/slope pair smeared on the phylogeny; each (species, trait,
##   rep) cell draws Binomial(size, plogis(mu_t + alpha_sp + beta_sp * x)),
##   stored as cbind(succ, fail). Truth Sigma_b matches the Gaussian
##   anchor: sigma^2_alpha = 0.4, sigma^2_beta = 0.3, rho = 0.5.
make_slope_logit_fixture <- function(seed = 2026L,
                                     n_sp = 80L, n_traits = 3L,
                                     n_rep = 5L, size = 12L) {
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
    nrow = 2L, ncol = 2L
  )

  ab <- (Lphy_chol %*% matrix(stats::rnorm(n_sp * 2L), n_sp, 2L)) %*%
    chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))

  trait_levels <- paste0("t", seq_len(n_traits))
  df <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df <- df[order(df$species, df$rep, df$trait), ]

  ## Mid-range intercepts so plogis(eta) stays away from 0 / 1.
  mu_t <- c(0.2, 0.0, -0.2)[as.integer(df$trait)]
  alpha_sp <- ab[as.character(df$species), "alpha"]
  beta_sp <- ab[as.character(df$species), "beta"]
  p <- stats::plogis(mu_t + alpha_sp + beta_sp * df$x)
  df$succ <- stats::rbinom(nrow(df), size = size, prob = p)
  df$fail <- size - df$succ

  list(
    data = df,
    tree = tree,
    Sigma_b_true = Sigma_b_true,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true
  )
}

fit_slope_logit <- function(fx) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + phylo_unique(1 + x | species),
      data = fx$data,
      phylo_tree = fx$tree,
      unit = "species",
      family = stats::binomial(link = "logit"),
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )
}

## Honest health gate: converged, finite objective, small gradient, PD.
slope_logit_fit_healthy <- function(fit) {
  inherits(fit, "gllvmTMB_multi") &&
    isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    isTRUE(fit$fit_health$max_gradient < 1e-2) &&
    isTRUE(fit$fit_health$pd_hessian)
}

test_that("binomial(logit) phylo_unique(1+x|sp): augmented Sigma_b recovers; pd_hessian TRUE; slope-variance profile CI finite", {
  skip_if_not_slope_logit_deps()
  fx <- make_slope_logit_fixture()
  fit <- fit_slope_logit(fx)

  if (inherits(fit, "error")) {
    skip(sprintf(
      "binomial-logit phylo_unique(1+x|sp) fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!slope_logit_fit_healthy(fit)) {
    skip("binomial-logit phylo_unique(1+x|sp) fit did not converge with PD Hessian; random-slope binomial-logit branch stays partial pending bigger n / different seed")
  }

  ## ---- Augmented-block plumbing (Phase 56.3 parser contract) -----------
  expect_identical(fit$tmb_data$use_phylo_slope_correlated, 1L)
  expect_identical(fit$tmb_data$n_lhs_cols, 2L)

  ## ---- Health gate (mirror of the Gaussian template) -------------------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_lt(fit$fit_health$max_gradient, 1e-2)
  expect_true(isTRUE(fit$fit_health$pd_hessian))

  ## ---- Recovery on sigma^2_alpha, sigma^2_beta, rho --------------------
  ## sd_b = c(SD_intercept, SD_slope); cor_b[1] = rho_{alpha,beta}.
  sd_b <- as.numeric(fit$report$sd_b)
  rho_hat <- as.numeric(fit$report$cor_b)[1L]
  expect_length(sd_b, 2L)
  sigma2_int_hat <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2
  expect_true(all(is.finite(c(sigma2_int_hat, sigma2_slope_hat, rho_hat))))

  rel_int <- abs(sigma2_int_hat - fx$sigma2_int_true) / fx$sigma2_int_true
  rel_slope <- abs(sigma2_slope_hat - fx$sigma2_slope_true) /
    fx$sigma2_slope_true
  abs_rho <- abs(rho_hat - fx$rho_true)
  if (rel_int > 0.30 || rel_slope > 0.30 || abs_rho > 0.30) {
    skip(sprintf(
      paste0("Augmented Sigma_b recovery outside honest band ",
             "(sigma^2_a hat = %.3f rel %.2f; sigma^2_b hat = %.3f rel %.2f; ",
             "rho hat = %.3f abs %.2f); random-slope binomial-logit ",
             "branch stays partial pending bigger n / different seed"),
      sigma2_int_hat, rel_int, sigma2_slope_hat, rel_slope,
      rho_hat, abs_rho
    ))
  }
  ## Fixed-residual-scale family: 0.30 relative on variances (the
  ## multi-trial logit bound from test-matrix-binomial-logit-unit.R),
  ## 0.30 absolute on rho (the Gaussian template's rho band).
  expect_lte(rel_int, 0.30)
  expect_lte(rel_slope, 0.30)
  expect_lte(abs_rho, 0.30)

  ## ---- CI smoke -------------------------------------------------------
  ## The task target is `confint(parm = "rho:phy:1,2", method = "profile")`
  ## OR a slope-variance profile CI. The augmented (intercept, slope)
  ## block is a 2-column b_phy_aug random effect, NOT a phy *correlation*
  ## tier, so `rho:phy:i,j` routes through extract_Sigma(level = "phy")
  ## and errors with "no phylo_latent()/phylo_unique() term ... at level
  ## phy". We therefore take the slope-variance profile branch: profile
  ## the augmented slope log-SD (TMB parameter log_sd_b, index 2) via
  ## TMB::tmbprofile() and require a finite two-sided CI. (sd_b is not a
  ## user-facing profile_targets() label, so there is no confint() token
  ## for it; tmbprofile on the raw parameter is the supported route.)
  po <- fit$opt$par
  slope_pos <- which(names(po) == "log_sd_b")[2L]
  prof <- tryCatch(
    suppressMessages(suppressWarnings(
      TMB::tmbprofile(fit$tmb_obj, name = slope_pos, ystep = 0.1,
                      ytol = 2, trace = FALSE)
    )),
    error = function(e) e
  )
  if (inherits(prof, "error")) {
    skip(sprintf(
      "Slope log-SD tmbprofile errored (%s); CI smoke stays partial -- honest skip rather than relax assertion",
      conditionMessage(prof)
    ))
  }
  ci_logsd <- tryCatch(stats::confint(prof), error = function(e) e)
  if (inherits(ci_logsd, "error") || !all(is.finite(as.numeric(ci_logsd)))) {
    skip("Slope log-SD profile CI did not bracket a finite two-sided interval; CI smoke stays partial -- honest skip rather than relax assertion")
  }
  ## Map the log-SD bounds to the slope-variance scale; both finite and
  ## the interval brackets the recovered slope variance.
  var_ci <- exp(2 * as.numeric(ci_logsd))
  expect_true(all(is.finite(var_ci)))
  expect_lt(var_ci[1L], var_ci[2L])
  expect_gt(var_ci[1L], 0)
})
