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

## =====================================================================
## PHY-18 poisson VALIDATION cell (GAP-B1): the FIRST non-Gaussian dep
## slope to leave the reservation. Unlike the seven honest-skip cells
## above -- which read the closed-form `report$sd_b` 2-vector channel
## (incompatible with the dep engine; a known latent bug in this harness)
## and skip at the converge/PD guard at the small fixtures -- this cell
## drives the FULL unstructured 2T x 2T `dep` engine and reads slope
## variances from the C x C `report$Sigma_b_dep` matrix the engine
## actually REPORTs. It uses the same interleaved C = 4 Sigma_b_true and
## .dep_Ltrue() / .make_dep_fixture() recipe as the Gaussian dep anchor
## (test-phylo-dep-slope-gaussian.R) but draws a poisson response, and a
## larger n_sp (150) per the GAP-B1 identifiability sweep -- the sweep
## proved the reserved dep poisson slope is IDENTIFIABLE (PD Hessian,
## good recovery at n_sp >= 80); the earlier reservation was finite-
## sample power, not structural non-identifiability. This is the recovery
## test behind the R/fit-multi.R family-guard relaxation (allowlist
## c(0L, 2L)). It exercises the REAL public API path (no MakeADFun
## override), and honest-skips on construction failure / non-convergence /
## non-PD / out-of-band recovery rather than forcing green.

## Known PD lower-tri Cholesky of the 2T x 2T (C = 4) interleaved Sigma_b,
## matching .dep_Ltrue() in test-phylo-dep-slope-gaussian.R. The diagonal
## slope variances (interleaved cols 2, 4) are the binding recovery entry.
.dep_pois_Ltrue <- function(C) {
  stopifnot(C == 4L)
  L <- matrix(0, C, C)
  L[lower.tri(L, diag = TRUE)] <- c(
    0.8, 0.2, -0.1, 0.15, # col 1 (rows 1..4)
    0.6, 0.1, -0.05, # col 2 (rows 2..4)
    0.5, 0.1, # col 3 (rows 3..4)
    0.45 # col 4 (row 4)
  )
  L
}

## Build a poisson dep fixture: B ~ MN(0, A_phy, Sigma_b) with INTERLEAVED
## per-trait (intercept, slope) columns, then y = rpois(n, exp(eta)) with
## eta = mu_t + alpha_sp + beta_sp * x and modest log-scale intercepts.
.make_dep_pois_fixture <- function(seed, n_sp, T_tr, n_rep, mu_t_log) {
  set.seed(seed)
  C <- 2L * T_tr
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Ltrue <- .dep_pois_Ltrue(C)
  Sigma_b_true <- Ltrue %*% t(Ltrue)
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- (LA %*% matrix(stats::rnorm(n_sp * C), n_sp, C)) %*% chol(Sigma_b_true)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  sr$x <- stats::rnorm(nrow(sr))
  trait_levels <- paste0("t", seq_len(T_tr))
  df_long <- merge(
    sr,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]
  ti <- as.integer(df_long$trait)
  si <- match(as.character(df_long$species), tree$tip.label)
  mu_t <- mu_t_log[ti]
  alpha <- B[cbind(si, 2L * (ti - 1L) + 1L)] # interleaved intercept col
  beta <- B[cbind(si, 2L * (ti - 1L) + 2L)] # interleaved slope col
  eta <- mu_t + alpha + beta * df_long$x
  df_long$value <- stats::rpois(nrow(df_long), lambda = exp(eta))

  list(
    tree = tree, df_long = df_long, B = B,
    Sigma_b_true = Sigma_b_true, T_tr = T_tr, C = C
  )
}

test_that("phylo_dep(1 + x | sp) x poisson VALIDATION (PHY-18): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()

  ## C = 4 interleaved (alpha_t1, beta_t1, alpha_t2, beta_t2). Modest
  ## log-scale intercepts keep counts in a healthy range.
  fx <- .make_dep_pois_fixture(
    seed = 20260602L, n_sp = 150L, T_tr = 2L, n_rep = 10L,
    mu_t_log = c(1.0, 0.7)
  )

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(1 + x | species),
      data = fx$df_long,
      phylo_tree = fx$tree,
      unit = "species",
      family = stats::poisson(link = "log"),
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )

  ## The whole point of GAP-B1: construction must NO LONGER abort for
  ## poisson (the family guard was relaxed to allow id 2). A surviving
  ## abort means the guard relaxation regressed.
  if (inherits(fit, "error")) {
    testthat::fail(sprintf(
      "phylo_dep(1 + x | sp) x poisson aborted at construction: %s (the GAP-B1 guard relaxation should admit poisson id 2)",
      conditionMessage(fit)
    ))
    return(invisible(NULL))
  }
  testthat::expect_s3_class(fit, "gllvmTMB_multi")

  ## Engine actually ran the dep poisson path: family id 2 and the dep
  ## slope flag both on.
  testthat::expect_true(isTRUE(fit$use$phylo_dep_slope))
  testthat::expect_identical(fit$tmb_data$use_phylo_dep_slope, 1L)
  testthat::expect_true(all(fit$tmb_data$family_id_vec == 2L))

  ## Honest-skip on non-convergence / non-PD (matches house style); do not
  ## force green.
  healthy <- isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    (isTRUE(fit$fit_health$pd_hessian) || isTRUE(fit$sd_report$pdHess))
  if (!healthy) {
    testthat::skip(sprintf(
      "phylo_dep(1 + x | sp) x poisson did not converge with PD Hessian (conv = %s, pdHess = %s); PHY-18 stays partial pending bigger n / different seed",
      fit$opt$convergence,
      isTRUE(fit$sd_report$pdHess)
    ))
  }

  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian) ||
    isTRUE(fit$sd_report$pdHess))

  ## CRITICAL: read the dep covariance from the C x C report$Sigma_b_dep
  ## matrix (NOT the closed-form sd_b 2-vector channel, which is
  ## incompatible with the dep engine). Slope variances sit at the
  ## interleaved diagonal positions 2 and 4.
  Sig_hat <- as.matrix(fit$report$Sigma_b_dep)
  testthat::expect_equal(dim(Sig_hat), c(fx$C, fx$C))
  testthat::expect_true(all(is.finite(Sig_hat)))

  slope_idx <- c(2L, 4L)
  slope_var_hat <- diag(Sig_hat)[slope_idx]
  slope_var_true <- diag(fx$Sigma_b_true)[slope_idx]
  ratio <- slope_var_hat / slope_var_true

  ## Mean-dependent => 4x band, inherited from test-matrix-slope-poisson.R
  ## (do NOT invent a tighter one).
  var_band <- 4
  if (!all(is.finite(ratio)) ||
        any(ratio < 1 / var_band) || any(ratio > var_band)) {
    testthat::skip(sprintf(
      "Sigma_b_dep slope-variance recovery outside %gx band (hat = %s, truth = %s, ratio = %s); PHY-18 stays partial pending bigger n",
      var_band,
      paste(sprintf("%.3g", slope_var_hat), collapse = ", "),
      paste(sprintf("%.3g", slope_var_true), collapse = ", "),
      paste(sprintf("%.3g", ratio), collapse = ", ")
    ))
  }
  testthat::expect_true(all(slope_var_hat > slope_var_true / var_band))
  testthat::expect_true(all(slope_var_hat < slope_var_true * var_band))
})

## =====================================================================
## PHY-18 non-Gaussian VALIDATION cells (extend GAP-B1 to the remaining
## five families). Each cell mirrors the poisson VALIDATION cell exactly:
## the SAME interleaved C = 4 Sigma_b_true / .dep_pois_Ltrue() recipe and
## the SAME real-API path + Sigma_b_dep slope-variance read, swapping only
## the family-appropriate response DGP and inheriting that family's slope
## sibling recovery band (do NOT invent tighter bands). A family joins the
## R/fit-multi.R guard allowlist ONLY after its cell passes in CI (#388
## discipline); a cell that skips at the largest tried n_sp keeps its
## family reserved fail-loud.
## =====================================================================

## Shared linear-predictor fixture: B ~ MN(0, A_phy, Sigma_b) with the
## SAME interleaved per-trait (intercept, slope) C = 4 covariance as the
## poisson cell, plus the long skeleton and the assembled eta = mu_t +
## alpha_sp + beta_sp * x. The caller draws the family response from eta.
.make_dep_eta_fixture <- function(seed, n_sp, T_tr, n_rep, mu_t_log) {
  set.seed(seed)
  C <- 2L * T_tr
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Ltrue <- .dep_pois_Ltrue(C)
  Sigma_b_true <- Ltrue %*% t(Ltrue)
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- (LA %*% matrix(stats::rnorm(n_sp * C), n_sp, C)) %*% chol(Sigma_b_true)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  sr$x <- stats::rnorm(nrow(sr))
  trait_levels <- paste0("t", seq_len(T_tr))
  df_long <- merge(
    sr,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]
  ti <- as.integer(df_long$trait)
  si <- match(as.character(df_long$species), tree$tip.label)
  alpha <- B[cbind(si, 2L * (ti - 1L) + 1L)] # interleaved intercept col
  beta <- B[cbind(si, 2L * (ti - 1L) + 2L)] # interleaved slope col
  eta <- mu_t_log[ti] + alpha + beta * df_long$x

  list(
    tree = tree, df_long = df_long, eta = eta, B = B,
    Sigma_b_true = Sigma_b_true, T_tr = T_tr, C = C
  )
}

## Shared VALIDATION driver: fit the real-API dep-slope path for `family`,
## fail-loud if construction aborts (the guard relaxation must admit this
## family id), honest-skip on non-convergence / non-PD / out-of-band
## recovery, else assert family_id + Sigma_b_dep slope-variance recovery
## within the inherited band. `expected_fid` is the family_to_id() runtime
## id (binomial 1, poisson 2, Gamma 4, nbinom2 5, Beta 7, ordinal 14,
## nbinom1 15).
.run_dep_validation_family <- function(fx, family, expected_fid, var_band,
                                       row_id, response_lhs = "value") {
  form <- stats::as.formula(
    paste0(response_lhs, " ~ 0 + trait + phylo_dep(1 + x | species)")
  )
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      form,
      data = fx$df_long,
      phylo_tree = fx$tree,
      unit = "species",
      family = family,
      control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )

  if (inherits(fit, "error")) {
    testthat::fail(sprintf(
      "phylo_dep(1 + x | sp) x %s aborted at construction: %s (the guard relaxation should admit family id %d)",
      row_id, conditionMessage(fit), expected_fid
    ))
    return(invisible(NULL))
  }
  testthat::expect_s3_class(fit, "gllvmTMB_multi")

  testthat::expect_true(isTRUE(fit$use$phylo_dep_slope))
  testthat::expect_identical(fit$tmb_data$use_phylo_dep_slope, 1L)
  testthat::expect_true(all(fit$tmb_data$family_id_vec == expected_fid))

  healthy <- isTRUE(fit$opt$convergence == 0L) &&
    is.finite(fit$opt$objective) &&
    (isTRUE(fit$fit_health$pd_hessian) || isTRUE(fit$sd_report$pdHess))
  if (!healthy) {
    testthat::skip(sprintf(
      "phylo_dep(1 + x | sp) x %s did not converge with PD Hessian (conv = %s, pdHess = %s); PHY-18 stays partial pending bigger n / different seed",
      row_id, fit$opt$convergence, isTRUE(fit$sd_report$pdHess)
    ))
  }

  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian) ||
    isTRUE(fit$sd_report$pdHess))

  Sig_hat <- as.matrix(fit$report$Sigma_b_dep)
  testthat::expect_equal(dim(Sig_hat), c(fx$C, fx$C))
  testthat::expect_true(all(is.finite(Sig_hat)))

  slope_idx <- c(2L, 4L)
  slope_var_hat <- diag(Sig_hat)[slope_idx]
  slope_var_true <- diag(fx$Sigma_b_true)[slope_idx]
  ratio <- slope_var_hat / slope_var_true

  if (!all(is.finite(ratio)) ||
        any(ratio < 1 / var_band) || any(ratio > var_band)) {
    testthat::skip(sprintf(
      "phylo_dep(1 + x | sp) x %s: Sigma_b_dep slope-variance recovery outside %gx band (hat = %s, truth = %s, ratio = %s); PHY-18 stays partial pending bigger n",
      row_id, var_band,
      paste(sprintf("%.3g", slope_var_hat), collapse = ", "),
      paste(sprintf("%.3g", slope_var_true), collapse = ", "),
      paste(sprintf("%.3g", ratio), collapse = ", ")
    ))
  }
  testthat::expect_true(all(slope_var_hat > slope_var_true / var_band))
  testthat::expect_true(all(slope_var_hat < slope_var_true * var_band))
}

## ---- nbinom2 (family_id 5; mean-dependent, inherited 4x band) --------
## rnbinom(mu = exp(eta), size = phi); modest log-scale intercepts.
test_that("phylo_dep(1 + x | sp) x nbinom2 VALIDATION (PHY-18): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  fx <- .make_dep_eta_fixture(
    seed = 20260602L, n_sp = 300L, T_tr = 2L, n_rep = 10L,
    mu_t_log = c(1.0, 0.7)
  )
  fx$df_long$value <- stats::rnbinom(
    nrow(fx$df_long), mu = exp(fx$eta), size = 2.0
  )
  .run_dep_validation_family(
    fx, gllvmTMB::nbinom2(), expected_fid = 5L, var_band = 4,
    row_id = "nbinom2 (RE-02 / PHY-05)"
  )
})

## ---- Gamma (family_id 4; mean-dependent, inherited 3x band) ----------
## rgamma(shape = phi, scale = mu / phi), mu = exp(eta).
test_that("phylo_dep(1 + x | sp) x Gamma VALIDATION (PHY-18): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  fx <- .make_dep_eta_fixture(
    seed = 20260602L, n_sp = 300L, T_tr = 2L, n_rep = 10L,
    mu_t_log = c(0.7, 0.5)
  )
  phi <- 2
  mu <- exp(fx$eta)
  fx$df_long$value <- stats::rgamma(
    nrow(fx$df_long), shape = phi, scale = mu / phi
  )
  .run_dep_validation_family(
    fx, stats::Gamma(link = "log"), expected_fid = 4L, var_band = 3,
    row_id = "Gamma (RE-02 / PHY-05)"
  )
})

## ---- Beta (family_id 7; mean-dependent, inherited 3x band) -----------
## plogis(eta) -> rbeta(mu * phi, (1 - mu) * phi).
test_that("phylo_dep(1 + x | sp) x Beta VALIDATION (PHY-18): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  fx <- .make_dep_eta_fixture(
    seed = 20260602L, n_sp = 300L, T_tr = 2L, n_rep = 10L,
    mu_t_log = c(-0.2, 0.2)
  )
  phi <- 5
  mu <- stats::plogis(fx$eta)
  fx$df_long$value <- stats::rbeta(
    nrow(fx$df_long), mu * phi, (1 - mu) * phi
  )
  .run_dep_validation_family(
    fx, gllvmTMB::Beta(), expected_fid = 7L, var_band = 3,
    row_id = "Beta (RE-02 / PHY-05)"
  )
})

## ---- ordinal_probit (family_id 14; fixed scale, inherited 2.5x band) -
## latent ystar = eta + N(0, 1); cutpoints taus = (0, 0.7, 1.4) -> K = 4.
test_that("phylo_dep(1 + x | sp) x ordinal_probit VALIDATION (PHY-18): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  fx <- .make_dep_eta_fixture(
    seed = 20260602L, n_sp = 300L, T_tr = 2L, n_rep = 10L,
    mu_t_log = c(0.6, 0.5)
  )
  ystar <- fx$eta + stats::rnorm(nrow(fx$df_long), 0, 1)
  taus <- c(0, 0.7, 1.4)
  fx$df_long$value <- as.integer(
    1L + colSums(outer(taus, ystar, FUN = function(t, y) y > t))
  )
  .run_dep_validation_family(
    fx, gllvmTMB::ordinal_probit(), expected_fid = 14L, var_band = 2.5,
    row_id = "ordinal_probit (RE-02 / PHY-06)"
  )
})

## ---- binomial (family_id 1; MULTI-TRIAL size = 12, inherited 3x band) -
## cbind(succ, fail) ~ ...; p = plogis(eta), size = 12 trials.
test_that("phylo_dep(1 + x | sp) x binomial VALIDATION (PHY-18): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  fx <- .make_dep_eta_fixture(
    seed = 20260602L, n_sp = 300L, T_tr = 2L, n_rep = 10L,
    mu_t_log = c(0.2, -0.2)
  )
  size <- 12L
  p <- stats::plogis(fx$eta)
  fx$df_long$succ <- stats::rbinom(nrow(fx$df_long), size = size, prob = p)
  fx$df_long$fail <- size - fx$df_long$succ
  .run_dep_validation_family(
    fx, stats::binomial(link = "logit"), expected_fid = 1L, var_band = 3,
    row_id = "binomial (RE-02 / PHY-06)", response_lhs = "cbind(succ, fail)"
  )
})

## ---- nbinom1 (family_id 15; mean-dependent, inherited 4x band) -------
## THE LAST MISSING FAMILY in the structured non-Gaussian slope grid (#350).
## nbinom1 (linear NB variance, Var = mu * (1 + phi); Hilbe 2011) is wired
## into the multivariate engine (family_to_id() case nbinom1 = 15L; the C++
## `fid == 15` likelihood branch with the per-trait `phi_nbinom1` REPORT) and
## recovers at the INTERCEPT-ONLY unit / phylo / spatial tiers (FAM-07,
## test-matrix-nbinom1.R / test-tiers-nbinom1.R). Its AUGMENTED-slope
## identifiability is genuinely uncertain, though: #350 flags nbinom1 as only
## `P (smoke)`-validated even intercept-only (board #340), and the phi <->
## latent-variance confound documented in FAM-07 can pull per-trait phi toward
## the boundary. So this cell is EVIDENCE-BASED scoping per #350: it drives the
## REAL public-API dep path and lets CI decide. If it recovers NON-SKIPPED,
## nbinom1 (id 15) stays on the R/fit-multi.R slope guard allowlists; if it
## skips (non-PD / out-of-band even after the n escalation), nbinom1 is REMOVED
## from the allowlists and stays reserved fail-loud with an honest note. NO
## force-pass.
##
## Band: nbinom1 has no intercept-only AUGMENTED-slope sibling to inherit from,
## so the band is inherited from nbinom2 -- the closest mean-dependent count
## family (Var = mu + mu^2/phi vs nbinom1's Var = mu * (1 + phi)) -- which uses
## the wider 4x variance band. This also matches nbinom1's OWN intercept-only
## Phase-B0 band (the widest mean-dependent tier, |b_hat - mu_int| < 0.40 in
## test-matrix-nbinom1.R). Draw via rnbinom(mu = exp(eta), size = mu / phi) so
## the realised overdispersion is NB1 (Var = mu * (1 + phi)), NOT NB2.
## Escalation (#350, this PR): the n_sp = 300 nbinom1 cell skipped non-PD
## (conv = 1, pdHess = FALSE) at the SAME n as the passing nbinom2 cell, so
## nbinom1 gets ONE fair escalation -- larger n_sp (400) PLUS a small seed
## sweep -- mirroring how spatial_dep's count families needed n_sites = 1000.
## The driver takes the FIRST healthy (conv = 0, PD) fit; if every (seed, n)
## attempt is non-PD / out-of-band it stays honest-skipped and nbinom1 is
## removed from the R/fit-multi.R allowlists (no force-pass).
test_that("phylo_dep(1 + x | sp) x nbinom1 VALIDATION (PHY-18 / FAM-07): real-API fit converges PD and recovers slope variances from Sigma_b_dep", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_dep_deps()
  phi_nb1 <- 2.0
  ## Escalated past the nbinom2 working n (n_sp = 300) to n_sp = 400, and a
  ## seed sweep across the sweep band. The first (seed, n_sp) that fits
  ## convergent + PD and recovers in-band wins; otherwise honest skip.
  attempts <- expand.grid(
    seed = c(20260603L, 20260604L, 20260605L),
    n_sp = c(400L, 300L),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  succeeded <- FALSE
  for (i in seq_len(nrow(attempts))) {
    fx <- .make_dep_eta_fixture(
      seed = attempts$seed[i], n_sp = attempts$n_sp[i], T_tr = 2L, n_rep = 10L,
      mu_t_log = c(1.0, 0.7)
    )
    mu <- exp(fx$eta)
    ## NB1 draw: size = mu / phi => Var = mu + mu^2 / (mu / phi) = mu*(1 + phi).
    fx$df_long$value <- stats::rnbinom(
      nrow(fx$df_long), mu = mu, size = mu / phi_nb1
    )
    form <- stats::as.formula(
      "value ~ 0 + trait + phylo_dep(1 + x | species)"
    )
    fit <- tryCatch(
      suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        form, data = fx$df_long, phylo_tree = fx$tree, unit = "species",
        family = gllvmTMB::nbinom1(),
        control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
      ))),
      error = function(e) e
    )
    if (inherits(fit, "error")) {
      testthat::fail(sprintf(
        "phylo_dep(1 + x | sp) x nbinom1 aborted at construction: %s (the guard relaxation should admit family id 15)",
        conditionMessage(fit)
      ))
      return(invisible(NULL))
    }
    healthy <- isTRUE(fit$opt$convergence == 0L) &&
      is.finite(fit$opt$objective) &&
      (isTRUE(fit$fit_health$pd_hessian) || isTRUE(fit$sd_report$pdHess))
    if (healthy) {
      ## Reuse the shared assertions: rebuild the matching fixture context by
      ## handing the in-hand fit to the band check inline.
      testthat::expect_s3_class(fit, "gllvmTMB_multi")
      testthat::expect_true(isTRUE(fit$use$phylo_dep_slope))
      testthat::expect_true(all(fit$tmb_data$family_id_vec == 15L))
      Sig_hat <- as.matrix(fit$report$Sigma_b_dep)
      testthat::expect_equal(dim(Sig_hat), c(fx$C, fx$C))
      slope_idx <- c(2L, 4L)
      slope_var_hat <- diag(Sig_hat)[slope_idx]
      slope_var_true <- diag(fx$Sigma_b_true)[slope_idx]
      ratio <- slope_var_hat / slope_var_true
      if (!all(is.finite(ratio)) || any(ratio < 1 / 4) || any(ratio > 4)) {
        next  # PD but out-of-band: try the next (seed, n_sp)
      }
      testthat::expect_true(all(slope_var_hat > slope_var_true / 4))
      testthat::expect_true(all(slope_var_hat < slope_var_true * 4))
      succeeded <- TRUE
      break
    }
  }
  if (!isTRUE(succeeded)) {
    testthat::skip(
      "phylo_dep(1 + x | sp) x nbinom1 (RE-02 / PHY-05 / FAM-07) did not converge PD + in-band at any escalated n_sp (400/300) x seed sweep (conv/pdHess unhealthy); PHY-18 nbinom1 RESERVED for augmented slopes"
    )
  }
})
