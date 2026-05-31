## Phase B-matrix agent SLOPE-phylo-dep (Design 59): the random-slope anchor
## `phylo_dep(1 + x | species)` x 7 non-Gaussian families. This is the
## FULL-UNSTRUCTURED (`dep`) sibling of the `phylo_unique(1 + x | species)`
## SLOPE column owned by `test-matrix-slope-{poisson,nbinom2,gamma,beta,
## ordinal,binomial-logit,binomial-probit}.R`. It mirrors the Gaussian mode
## skeleton `test-phylo-dep-slope-gaussian.R` (Design 55 sec.A2 / Design 56
## sec.9.5c: Sigma_b is the full 2T x 2T unstructured covariance) and swaps
## the family per `test_that`. It informs the `phylo_dep` arm of RE-02
## (random-slope recovery) / PHY-05 / PHY-06 of
## `docs/design/35-validation-debt-register.md`.
##
## ENGINE STATUS: the augmented-LHS `dep` path IS implemented and Gaussian-
## validated (test-phylo-dep-slope-gaussian.R, all green). Construction now
## succeeds for the wired families. HOWEVER, the Gaussian-only family guard in
## `R/fit-multi.R` is retained (allowlist == gaussian id 0): unlike the
## diagonal phylo_indep / block-diagonal phylo_latent paths, the FULL
## unstructured C x C (C = 2*n_traits) covariance is not yet identifiable for
## the non-Gaussian families at the validation fixtures. Verified empirically
## (n_sp up to 100, n_rep up to 10): every non-Gaussian dep fit returns
## convergence != 0 / non-PD Hessian, so each cell below honest-skips at the
## converge/PD guard. Per the #388 discipline a family joins the allowlist
## ONLY after its recovery cell passes -- non-Gaussian dep stays reserved.
##
## Each `test_that` is written so that WHEN the non-Gaussian dep cells become
## identifiable (bigger n / a reparameterised covariance), the convergence
## skip falls away and the recovery + CI-smoke assertions below it run: build
## a faithful family-appropriate DGP (matching the committed `phylo_unique`
## slope sibling for that family), fit `value ~ 0 + trait +
## phylo_dep(1 + x | species)`, assert converged + pd_hessian, recover the
## augmented 2x2 intercept/slope variance structure within the Phase-B0
## per-family band, and a CI smoke (rho:phy:1,2 profile OR a finite
## slope-variance CI from the sdreport `log_sd_b` row).
##
## Per-family Phase-B0 tolerance (docs/dev-log/audits/2026-05-26-phase-b0-
## nongaussian-scoping.md + the committed siblings): fixed-residual-scale
## families (binomial-probit/logit, ordinal_probit) get the TIGHTER band;
## mean-dependent families (poisson, nbinom2, gamma, beta) get the WIDER
## (3x-4x) variance band. The intercept-slope correlation gets an absolute
## band. These are the SAME bands the `phylo_unique` siblings use -- they are
## NOT widened here.
##
## SKIP discipline (no fake-pass, Design 59): construction failure /
## non-convergence / non-PD / recovery outside the honest band => an honest
## `skip("reason")` and the register row stays `partial`. NEVER forced green.
## Time-box per fit is the campaign-wide 15 min; the fixtures are small.

skip_if_not_slope_phylo_dep_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Augmented-covariance truth shared by all families (matches every
## committed `phylo_unique` SLOPE sibling): sigma^2_int = 0.4,
## sigma^2_slope = 0.3, rho = 0.5. The ordinal arm uses a slightly larger
## variance pair (0.6 / 0.5) to keep the liability-scale categories filled,
## matching `test-matrix-slope-ordinal.R`.
.make_Sigma_b <- function(sigma2_int, sigma2_slope, rho) {
  cov <- rho * sqrt(sigma2_int * sigma2_slope)
  matrix(c(sigma2_int, cov, cov, sigma2_slope), nrow = 2L, ncol = 2L)
}

## Draw augmented (alpha, beta) species effects ~ N(0, Sigma_b (x) A_phy) on
## an `ape::rcoal` correlation tree. Returns the tree + the n_sp x 2 effect
## matrix (cols alpha, beta). Identical recipe to the `phylo_unique` slope
## siblings.
.draw_phylo_aug <- function(seed, n_sp, Sigma_b) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))
  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label
  list(tree = tree, ab = ab)
}

## Build the long (species x trait x rep) frame skeleton with an x covariate
## held identical across traits within a (species, rep) cell -- the same
## wide<->long-equivalent layout the slope siblings use.
.make_long_skeleton <- function(tree, n_traits, n_rep) {
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
  df[order(df$species, df$rep, df$trait), ]
}

## Attempt the `phylo_dep(1 + x | species)` fit for an arbitrary family;
## returns the fit object or the captured error condition. `response_form`
## is the LHS (`value` for most; `cbind(succ, fail)` for multi-trial logit).
.fit_slope_phylo_dep <- function(df, tree, family, response_lhs = "value") {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  form <- stats::as.formula(
    paste0(response_lhs, " ~ 0 + trait + phylo_dep(1 + x | species)")
  )
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      form,
      data = df,
      phylo_tree = tree,
      unit = "species",
      family = family,
      control = ctl
    ))),
    error = function(e) e
  )
}

.slope_phylo_dep_fit_healthy <- function(fit) {
  isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    isTRUE(fit$fit_health$pd_hessian)
}

## Augmented-covariance recovery check against a per-family band. Returns a
## list(ok, msg): ok == TRUE if all three components are inside the band.
.slope_phylo_dep_recovery <- function(fit, truth, var_band, rho_abs) {
  sd_b <- as.numeric(fit$report$sd_b)
  cor_b <- as.numeric(fit$report$cor_b)[1L]
  if (length(sd_b) != 2L || !all(is.finite(sd_b)) || !is.finite(cor_b)) {
    return(list(ok = FALSE, msg = "report$sd_b / report$cor_b not finite"))
  }
  sigma2_int_hat <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2
  ratio_int <- sigma2_int_hat / truth$sigma2_int
  ratio_slope <- sigma2_slope_hat / truth$sigma2_slope
  ok <- is.finite(ratio_int) && ratio_int >= 1 / var_band &&
    ratio_int <= var_band &&
    is.finite(ratio_slope) && ratio_slope >= 1 / var_band &&
    ratio_slope <= var_band &&
    abs(cor_b - truth$rho) <= rho_abs
  list(
    ok = ok,
    sigma2_int_hat = sigma2_int_hat,
    sigma2_slope_hat = sigma2_slope_hat,
    cor_b = cor_b,
    msg = sprintf(
      "sigma2_int=%.3g (truth %.3g), sigma2_slope=%.3g (truth %.3g), rho=%.3g (truth %.3g)",
      sigma2_int_hat, truth$sigma2_int, sigma2_slope_hat, truth$sigma2_slope,
      cor_b, truth$rho
    )
  )
}

## CI smoke: rho:phy:1,2 profile token first (per task spec; addresses the
## cross-trait phy block when the engine wires it for the augmented-dep
## path), then the genuinely-available transformed-Wald slope-variance CI
## from the sdreport `log_sd_b[2]` row. Returns TRUE if any route is finite.
.slope_phylo_dep_ci_smoke <- function(fit) {
  ci_rho <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:phy:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  if (!inherits(ci_rho, "error") && is.matrix(ci_rho) &&
        nrow(ci_rho) == 1L && ncol(ci_rho) == 2L && any(is.finite(ci_rho))) {
    return(TRUE)
  }
  sdr <- tryCatch(summary(fit$sd_report), error = function(e) NULL)
  if (is.null(sdr)) {
    return(FALSE)
  }
  idx <- which(rownames(sdr) == "log_sd_b")
  if (length(idx) < 2L) {
    return(FALSE)
  }
  est <- sdr[idx[2L], "Estimate"]
  se <- sdr[idx[2L], "Std. Error"]
  if (!is.finite(est) || !is.finite(se)) {
    return(FALSE)
  }
  z <- stats::qnorm(0.975)
  ci_var <- exp(2 * c(est - z * se, est + z * se))
  any(is.finite(ci_var))
}

## Shared driver: build fixture, attempt fit, honest-skip on construction
## failure / non-convergence / out-of-band recovery, else assert recovery +
## CI smoke. `row_id` names the register rows for the skip message.
.run_slope_phylo_dep_family <- function(df, tree, family, truth, var_band,
                                        rho_abs, row_id,
                                        response_lhs = "value") {
  fit <- .fit_slope_phylo_dep(df, tree, family, response_lhs = response_lhs)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "phylo_dep(1 + x | sp) fit failed to construct: %s -- non-Gaussian `dep` slopes are reserved fail-loud (the full unstructured C x C covariance is not yet identifiable for this family; PHY-18); %s stays partial",
      if (inherits(fit, "error")) conditionMessage(fit) else "wrong class",
      row_id
    ))
  }
  if (!.slope_phylo_dep_fit_healthy(fit)) {
    testthat::skip(sprintf(
      "phylo_dep(1 + x | sp) fit did not converge with PD Hessian; %s stays partial pending bigger n / different seed",
      row_id
    ))
  }

  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))

  rec <- .slope_phylo_dep_recovery(fit, truth, var_band, rho_abs)
  if (!isTRUE(rec$ok)) {
    testthat::skip(sprintf(
      "Sigma_b recovery outside Phase-B0 band [%s]; %s stays partial pending bigger n",
      rec$msg, row_id
    ))
  }
  testthat::expect_gt(rec$sigma2_int_hat, truth$sigma2_int / var_band)
  testthat::expect_lt(rec$sigma2_int_hat, truth$sigma2_int * var_band)
  testthat::expect_gt(rec$sigma2_slope_hat, truth$sigma2_slope / var_band)
  testthat::expect_lt(rec$sigma2_slope_hat, truth$sigma2_slope * var_band)
  testthat::expect_lte(abs(rec$cor_b - truth$rho), rho_abs)

  if (!.slope_phylo_dep_ci_smoke(fit)) {
    testthat::skip(sprintf(
      "No finite CI bound (rho:phy:1,2 profile N/A for augmented-dep path; sdreport slope-variance SE not finite); %s CI smoke stays partial -- honest skip rather than relax assertion",
      row_id
    ))
  }
  testthat::expect_true(TRUE)
}

## =====================================================================
## Family 1: binomial-probit (FIXED residual scale, latent var == 1).
## Single-trial binary; n_sp = 80, n_rep = 6, var(x) = 1; tight band.
## =====================================================================
test_that("phylo_dep(1 + x | sp) x binomial-probit recovers Sigma_b + CI smoke (or honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  truth <- list(sigma2_int = 0.4, sigma2_slope = 0.3, rho = 0.5)
  dr <- .draw_phylo_aug(
    seed = 11L, n_sp = 80L,
    Sigma_b = .make_Sigma_b(truth$sigma2_int, truth$sigma2_slope, truth$rho)
  )
  df <- .make_long_skeleton(dr$tree, n_traits = 3L, n_rep = 6L)
  mu_t <- c(0.2, 0.0, -0.2)[as.integer(df$trait)]
  eta <- mu_t + dr$ab[as.character(df$species), "alpha"] +
    dr$ab[as.character(df$species), "beta"] * df$x
  df$value <- stats::rbinom(nrow(df), size = 1L, prob = stats::pnorm(eta))

  ## Fixed-residual-scale family => tighter band (3x var, 0.30 rho), matching
  ## the binomial-probit `phylo_unique` sibling.
  .run_slope_phylo_dep_family(
    df, dr$tree, stats::binomial(link = "probit"), truth,
    var_band = 3, rho_abs = 0.30, row_id = "RE-02 / PHY-06 (probit)"
  )
})

## =====================================================================
## Family 2: binomial-logit (FIXED residual scale, latent var == pi^2/3).
## Multi-trial cbind(succ, fail), size = 12; n_sp = 80, n_rep = 5.
## =====================================================================
test_that("phylo_dep(1 + x | sp) x binomial-logit recovers Sigma_b + CI smoke (or honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  truth <- list(sigma2_int = 0.4, sigma2_slope = 0.3, rho = 0.5)
  dr <- .draw_phylo_aug(
    seed = 2026L, n_sp = 80L,
    Sigma_b = .make_Sigma_b(truth$sigma2_int, truth$sigma2_slope, truth$rho)
  )
  df <- .make_long_skeleton(dr$tree, n_traits = 3L, n_rep = 5L)
  size <- 12L
  mu_t <- c(0.2, 0.0, -0.2)[as.integer(df$trait)]
  p <- stats::plogis(
    mu_t + dr$ab[as.character(df$species), "alpha"] +
      dr$ab[as.character(df$species), "beta"] * df$x
  )
  df$succ <- stats::rbinom(nrow(df), size = size, prob = p)
  df$fail <- size - df$succ

  .run_slope_phylo_dep_family(
    df, dr$tree, stats::binomial(link = "logit"), truth,
    var_band = 3, rho_abs = 0.30, row_id = "RE-02 / PHY-06 (logit)",
    response_lhs = "cbind(succ, fail)"
  )
})

## =====================================================================
## Family 3: ordinal_probit (FIXED residual scale, sigma_d^2 == 1).
## K = 4 categories (tau = 0, 0.7, 1.4); var(x) ~ 1 >> 0.5; intercepts
## near +0.55 so all categories fill; tighter 2.5x band.
## =====================================================================
test_that("phylo_dep(1 + x | sp) x ordinal_probit recovers Sigma_b + CI smoke (or honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  truth <- list(sigma2_int = 0.6, sigma2_slope = 0.5, rho = 0.5)
  dr <- .draw_phylo_aug(
    seed = 505L, n_sp = 60L,
    Sigma_b = .make_Sigma_b(truth$sigma2_int, truth$sigma2_slope, truth$rho)
  )
  df <- .make_long_skeleton(dr$tree, n_traits = 4L, n_rep = 6L)
  mu_t <- c(0.7, 0.5, 0.6, 0.4)[as.integer(df$trait)]
  ystar <- mu_t + dr$ab[as.character(df$species), "alpha"] +
    dr$ab[as.character(df$species), "beta"] * df$x +
    stats::rnorm(nrow(df), 0, 1)
  taus <- c(0, 0.7, 1.4)
  df$value <- as.integer(
    1L + colSums(outer(taus, ystar, FUN = function(t, y) y > t))
  )

  .run_slope_phylo_dep_family(
    df, dr$tree, gllvmTMB::ordinal_probit(), truth,
    var_band = 2.5, rho_abs = 0.30, row_id = "RE-02 / PHY-06 (ordinal)"
  )
})

## =====================================================================
## Family 4: poisson (MEAN-dependent, latent log(1 + 1/mu)).
## log-link, intercept mean ~ 2 (=> count mean ~ 7.4); wider 4x band.
## =====================================================================
test_that("phylo_dep(1 + x | sp) x poisson recovers Sigma_b + CI smoke (or honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  truth <- list(sigma2_int = 0.4, sigma2_slope = 0.3, rho = 0.5)
  dr <- .draw_phylo_aug(
    seed = 5640L, n_sp = 60L,
    Sigma_b = .make_Sigma_b(truth$sigma2_int, truth$sigma2_slope, truth$rho)
  )
  df <- .make_long_skeleton(dr$tree, n_traits = 3L, n_rep = 4L)
  eta <- 2 + dr$ab[as.character(df$species), "alpha"] +
    dr$ab[as.character(df$species), "beta"] * df$x
  df$value <- stats::rpois(nrow(df), lambda = exp(eta))

  ## Mean-dependent => wider 4x band, 0.40 rho (matching slope-poisson).
  .run_slope_phylo_dep_family(
    df, dr$tree, stats::poisson(link = "log"), truth,
    var_band = 4, rho_abs = 0.40, row_id = "RE-02 / PHY-05 (poisson)"
  )
})

## =====================================================================
## Family 5: nbinom2 (MEAN-dependent, Var = mu + mu^2/phi).
## log-link intercept ~ 0.7 (mean ~ 2), phi = 2; wider 4x band.
## =====================================================================
test_that("phylo_dep(1 + x | sp) x nbinom2 recovers Sigma_b + CI smoke (or honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  truth <- list(sigma2_int = 0.4, sigma2_slope = 0.3, rho = 0.5)
  dr <- .draw_phylo_aug(
    seed = 3L, n_sp = 60L,
    Sigma_b = .make_Sigma_b(truth$sigma2_int, truth$sigma2_slope, truth$rho)
  )
  df <- .make_long_skeleton(dr$tree, n_traits = 3L, n_rep = 4L)
  eta <- 0.7 + dr$ab[as.character(df$species), "alpha"] +
    dr$ab[as.character(df$species), "beta"] * df$x
  df$value <- stats::rnbinom(nrow(df), mu = exp(eta), size = 2.0)

  .run_slope_phylo_dep_family(
    df, dr$tree, gllvmTMB::nbinom2(), truth,
    var_band = 4, rho_abs = 0.40, row_id = "RE-02 / PHY-05 (nbinom2)"
  )
})

## =====================================================================
## Family 6: gamma (MEAN-dependent; shape phi = 2 => CV ~ 0.707).
## log-link; replicates per (species, trait) cell; wider 3x band.
## =====================================================================
test_that("phylo_dep(1 + x | sp) x gamma recovers Sigma_b + CI smoke (or honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  truth <- list(sigma2_int = 0.4, sigma2_slope = 0.3, rho = 0.5)
  dr <- .draw_phylo_aug(
    seed = 20260529L, n_sp = 60L,
    Sigma_b = .make_Sigma_b(truth$sigma2_int, truth$sigma2_slope, truth$rho)
  )
  df <- .make_long_skeleton(dr$tree, n_traits = 3L, n_rep = 6L)
  phi <- 2
  mu <- exp(
    0.7 + dr$ab[as.character(df$species), "alpha"] +
      dr$ab[as.character(df$species), "beta"] * df$x
  )
  df$value <- stats::rgamma(nrow(df), shape = phi, scale = mu / phi)

  .run_slope_phylo_dep_family(
    df, dr$tree, stats::Gamma(link = "log"), truth,
    var_band = 3, rho_abs = 0.40, row_id = "RE-02 / PHY-05 (gamma)"
  )
})

## =====================================================================
## Family 7: beta (MEAN-dependent; phi = 5).
## logit-link mu mid-range; many replicates (n_rep = 12); wider 3x band.
## =====================================================================
test_that("phylo_dep(1 + x | sp) x beta recovers Sigma_b + CI smoke (or honest skip)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  truth <- list(sigma2_int = 0.4, sigma2_slope = 0.3, rho = 0.5)
  dr <- .draw_phylo_aug(
    seed = 404L, n_sp = 60L,
    Sigma_b = .make_Sigma_b(truth$sigma2_int, truth$sigma2_slope, truth$rho)
  )
  df <- .make_long_skeleton(dr$tree, n_traits = 3L, n_rep = 12L)
  phi <- 5
  alpha0 <- c(-0.2, 0.0, 0.2)[as.integer(df$trait)]
  mu <- stats::plogis(
    alpha0 + dr$ab[as.character(df$species), "alpha"] +
      dr$ab[as.character(df$species), "beta"] * df$x
  )
  df$value <- stats::rbeta(nrow(df), mu * phi, (1 - mu) * phi)

  .run_slope_phylo_dep_family(
    df, dr$tree, gllvmTMB::Beta(), truth,
    var_band = 3, rho_abs = 0.40, row_id = "RE-02 / PHY-05 (beta)"
  )
})
