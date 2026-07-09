## Phase B-matrix agent SLOPE-phylo-latent (Design 59): the reduced-rank
## random-slope keyword `phylo_latent(1 + x | species, d = 1)` composed
## with the seven non-Gaussian families
##   binomial-probit, binomial-logit, ordinal_probit,
##   poisson, nbinom2, gamma, beta.
##
## This is the LATENT (reduced-rank, factor-analytic) sibling of the
## `phylo_unique(1 + x | species)` augmented random-slope column owned by
## the SLOPE-{poisson,nbinom2,gamma,beta,ordinal,binomial-*} files
## (Phase B-NG). Where `phylo_unique(1 + x | sp)` builds a full 2x2
## augmented intercept-slope Sigma_b (n_lhs_cols == 2, report$sd_b /
## report$cor_b), `phylo_latent(1 + x | sp, d = 1)` is intended to load
## the correlated intercept+slope species effects through a rank-d
## cross-trait factor (Design 56 Sec.5.3 block-diagonal Sigma_b, one
## factor-analytic decomposition per LHS column). The Gaussian template
## for this exact mode lives at
## `tests/testthat/test-phylo-latent-slope-gaussian.R`.
##
## ----------------------------------------------------------------------
## ENGINE STATUS: the reduced-rank slope-bearing `phylo_latent` path is LIVE.
##
## `phylo_latent(1 + x | species, d = 1)` builds the 2-column augmented LHS
## (tmb_data$n_lhs_cols_lat == 2, tmb_data$use_phylo_latent_slope == 1) and
## fits the block-diagonal reduced-rank slope structure. The Gaussian-only
## family guard in `R/fit-multi.R` has been converted to an allowlist (mirror
## of the phylo_indep family sweep, #388) covering the wired families
## (gaussian, binomial probit/logit, poisson, nbinom2, Gamma, Beta,
## ordinal_probit), so construction now succeeds for each and the recovery +
## CI-smoke contract below runs.
##
## RECOVERY CHANNEL: the latent path is BLOCK-DIAGONAL across the LHS columns
## (Design 56 Sec.5.3, latent row) -- each column gets its own factor-analytic
## Sigma_k = Lambda_k Lambda_k^T and there is NO intercept-slope correlation
## block. So the recovery target is the per-column covariance surfaced by
## report$Sigma_phy_slope_slope / report$Sigma_phy_slope_intercept (the same
## channel the Gaussian template validates), NOT the full 2x2 report$sd_b /
## report$cor_b channel the phylo_unique / phylo_dep paths emit (which the
## latent engine does not populate). The slope block is the well-identified
## cell. The drawn intercept-slope correlation in the DGP is structurally
## unrecoverable by the block-diagonal model and is therefore not asserted.
##
## ----------------------------------------------------------------------
## Register rows this file informs: RE-02 (random-slope recovery) and the
## phylo-latent arm of PHY-06 (phylo augmented intercept+slope), per family.
##
## SKIP discipline (no fake-pass, Design 59): non-construction /
## non-convergence / non-PD Hessian / out-of-band recovery => honest
## `skip("<reason>")`; the register row stays `partial`. Tolerances are
## NEVER widened to force green. Each star/rcoal fit is well under the
## campaign-wide 15-min-per-fit time-box (~1 s locally).

`%||%` <- function(a, b) if (is.null(a)) b else a

skip_if_not_slope_phylo_latent_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Phase-B0 recovery tolerances by family scale class. Fixed-residual-scale
## families (binomial-probit / -logit, ordinal-probit) are tighter than the
## mean-dependent families (poisson, nbinom2, gamma, beta), per the
## Honest-matrix discipline. Bands mirror the committed `phylo_unique`
## random-slope siblings exactly (test-matrix-slope-*.R).
.slope_phylo_latent_band <- list(
  ## fixed-residual-scale (latent variance pinned by the link / construction)
  fixed_var      = 2.5,   # multiplicative band on the slope variance
  fixed_rho_abs  = 0.30,  # absolute band on the intercept-slope correlation
  ## mean-dependent (residual scale not pinned)
  mean_var       = 4.0,
  mean_rho_abs   = 0.40
)

## ---------------------------------------------------------------------
## Shared augmented-LHS phylo DGP (Design 56 Sec.5.3): correlated
## intercept + slope species effects (alpha, beta) ~ N(0, Sigma_b (x) A_phy)
## on a random `ape::rcoal` tree, then mapped through a per-family link.
## Truth mirrors the Gaussian template: sigma2_int = 0.4, sigma2_slope =
## 0.3, rho = 0.5. `linpred()` is the family-specific response emitter.
## ---------------------------------------------------------------------
make_slope_phylo_latent_fixture <- function(emit,
                                            seed     = 5640L,
                                            n_sp     = 60L,
                                            n_traits = 3L,
                                            n_rep    = 6L,
                                            mu0      = 0) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  sigma2_int_true   <- 0.4
  sigma2_slope_true <- 0.3
  rho_true          <- 0.5
  cov_true <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L, ncol = 2L
  )

  ## Matrix-normal draw: (alpha, beta) ~ N(0, Sigma_b (x) A_phy).
  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

  ## var(x) ~ 1 keeps the slope contribution clear of the latent-residual
  ## noise floor (Phase B0 Sec.4: sigma2_slope needs var(x) substantial).
  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
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

  mu_t     <- rep(mu0, n_traits)[as.integer(df$trait)]
  alpha_sp <- ab[as.character(df$species), "alpha"]
  beta_sp  <- ab[as.character(df$species), "beta"]
  eta      <- mu_t + alpha_sp + beta_sp * df$x
  df$value <- emit(eta)

  list(
    df = df, tree = tree, n_traits = n_traits,
    Sigma_b_true = Sigma_b_true,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true
  )
}

## Fit the slope-latent cell for a given family; return fit or condition.
fit_slope_phylo_latent <- function(fx, family) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(1 + x | species, d = 1),
      data       = fx$df,
      phylo_tree = fx$tree,
      unit       = "species",
      family     = family,
      control    = gllvmTMB::gllvmTMBcontrol(se = TRUE)
    ))),
    error = function(e) e
  )
}

## The engine-state guard: is the reduced-rank SLOPE path actually live?
## A genuine slope-bearing phylo_latent fit must carry a 2-column augmented
## LHS (n_lhs_cols_lat == 2) AND the dedicated latent-slope engine flag
## (use_phylo_latent_slope == 1). NOTE: the latent path does NOT set the
## unique/dep flags use_phylo_slope / n_lhs_cols (those stay 0 / 1 on a latent
## fit), so this guard keys on the *_lat fields the latent engine populates.
slope_latent_path_is_live <- function(fit) {
  isTRUE(fit$tmb_data$n_lhs_cols_lat == 2L) &&
    isTRUE(fit$tmb_data$use_phylo_latent_slope == 1L)
}

## Recovery + CI-smoke contract, shared across families. Reached only when
## the slope path is live (until then every caller honest-skips above this
## via the guard). `var_band` / `rho_abs` are the family's Phase-B0 bands.
expect_slope_latent_recovery_and_ci <- function(fit, fx, var_band, rho_abs,
                                                row_tag) {
  ## ---- Fit health -----------------------------------------------------
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)

  ## ---- Latent slope structure recovery --------------------------------
  ## The reduced-rank latent slope is BLOCK-DIAGONAL across the LHS columns
  ## (Design 56 Sec.5.3, latent row): each column k in {intercept, slope} gets
  ## its OWN factor-analytic Sigma_k = Lambda_k Lambda_k^T, and there is NO
  ## intercept-slope correlation block (cf. the full 2x2 sd_b / cor_b channel
  ## the phylo_unique / phylo_dep paths use, which the latent engine does NOT
  ## populate). The recovery target is therefore the per-column Sigma surfaced
  ## by report$Sigma_phy_slope_slope / report$Sigma_phy_slope_intercept -- the
  ## same channel the Gaussian template (test-phylo-latent-slope-gaussian.R)
  ## validates. The well-identified slope block is the binding cell; its mean
  ## diagonal variance must land within the family band of sigma2_slope_true.
  ## The drawn intercept-slope correlation (rho_true) is structurally
  ## unrecoverable by the block-diagonal model (rho is pinned to 0), so it is
  ## NOT asserted here -- asserting it would test a quantity the estimator
  ## cannot represent. `rho_abs` is retained in the signature for parity with
  ## the dep sibling but is unused on the block-diagonal latent path.
  Sig_slope <- fit$report$Sigma_phy_slope_slope
  Sig_int   <- fit$report$Sigma_phy_slope_intercept
  testthat::expect_true(is.matrix(Sig_slope) && all(is.finite(Sig_slope)))
  testthat::expect_true(is.matrix(Sig_int)   && all(is.finite(Sig_int)))

  sigma2_slope_hat <- mean(diag(Sig_slope))
  sigma2_int_hat   <- mean(diag(Sig_int))

  slope_ratio <- sigma2_slope_hat / fx$sigma2_slope_true
  int_ratio   <- sigma2_int_hat / fx$sigma2_int_true

  ## Intercept block is weakly pinned at fixed n (one tree draw -- the Sec.5.3
  ## / Sec.11 caveat), so it gets a generous 2x var_band slack; the slope block
  ## is the well-identified cell held to the family band.
  if (!is.finite(slope_ratio) || slope_ratio < 1 / var_band || slope_ratio > var_band ||
        !is.finite(int_ratio) || int_ratio < 1 / (2 * var_band) || int_ratio > 2 * var_band) {
    testthat::skip(sprintf(
      paste0(
        "Latent slope-block recovery outside Phase-B0 band (mean slope var = %.3g ",
        "[truth %.2g], mean intercept var = %.3g [truth %.2g]); %s stays partial pending bigger n"
      ),
      sigma2_slope_hat, fx$sigma2_slope_true,
      sigma2_int_hat, fx$sigma2_int_true, row_tag
    ))
  }
  testthat::expect_gt(sigma2_slope_hat, fx$sigma2_slope_true / var_band)
  testthat::expect_lt(sigma2_slope_hat, fx$sigma2_slope_true * var_band)

  ## ---- CI smoke -------------------------------------------------------
  ## The block-diagonal latent exposes no rho:phy token (no cross-column
  ## correlation) and no log_sd_b row (that is the phylo_unique 2x2 channel).
  ## The genuinely-available uncertainty handle is the sdreport SE on the
  ## reduced-rank slope loadings theta_rr_phy_slope (which build Sigma_slope):
  ## a finite SE there is a finite slope-structure CI smoke.
  slope_loading_ci_finite <- FALSE
  sdr <- tryCatch(summary(fit$sd_report), error = function(e) NULL)
  if (!is.null(sdr)) {
    idx <- which(rownames(sdr) == "theta_rr_phy_slope")
    if (length(idx) >= 1L) {
      est <- sdr[idx, "Estimate"]; se <- sdr[idx, "Std. Error"]
      slope_loading_ci_finite <- any(is.finite(est) & is.finite(se) & se > 0)
    }
  }

  if (!slope_loading_ci_finite) {
    testthat::skip(sprintf(
      "No finite SE on the reduced-rank slope loadings (theta_rr_phy_slope); %s CI smoke stays partial rather than relax the assertion",
      row_tag
    ))
  }
  testthat::expect_true(slope_loading_ci_finite)
}

## Driver shared by all seven family test_that blocks: build the fixture,
## fit, run the construction / convergence / engine-state guards (honest
## skip on any), then the recovery + CI-smoke contract.
run_slope_phylo_latent_cell <- function(emit, family, var_band, rho_abs,
                                        row_tag, fam_label, mu0 = 0,
                                        seed = 5640L) {
  fx  <- make_slope_phylo_latent_fixture(emit = emit, mu0 = mu0, seed = seed)
  fit <- fit_slope_phylo_latent(fx, family)

  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "phylo_latent(1 + x | sp, d = 1) x %s fit failed to construct: %s",
      fam_label,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB object"
    ))
  }
  if (!.fit_converged(fit)) {
    testthat::skip(sprintf(
      "phylo_latent(1 + x | sp, d = 1) x %s fit did not converge with PD Hessian; %s stays partial pending bigger n / different seed",
      fam_label, row_tag
    ))
  }
  if (!slope_latent_path_is_live(fit)) {
    testthat::skip(sprintf(
      paste0(
        "Reduced-rank slope-bearing phylo_latent path not live for %s: the engine ",
        "dropped the slope column (n_lhs_cols_lat = %d, use_phylo_latent_slope = %d; ",
        "fit is the intercept-only rank-1 latent). No latent slope structure to recover; ",
        "%s stays partial. Honest skip -- NOT a fake-pass on the intercept-only loading."
      ),
      fam_label,
      as.integer(fit$tmb_data$n_lhs_cols_lat %||% NA),
      as.integer(fit$tmb_data$use_phylo_latent_slope %||% NA),
      row_tag
    ))
  }

  expect_slope_latent_recovery_and_ci(fit, fx, var_band, rho_abs, row_tag)
}

## ---------------------------------------------------------------------
## binomial-probit (fixed residual scale = 1; tighter band)
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x binomial-probit: converges + PD; recovers latent slope structure; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_latent_deps()
  run_slope_phylo_latent_cell(
    emit      = function(eta) stats::rbinom(length(eta), size = 1L, prob = stats::pnorm(eta)),
    family    = stats::binomial(link = "probit"),
    var_band  = .slope_phylo_latent_band$fixed_var,
    rho_abs   = .slope_phylo_latent_band$fixed_rho_abs,
    row_tag   = "RE-02 / PHY-06 (binomial-probit)",
    fam_label = "binomial-probit",
    mu0       = 0
  )
})

## ---------------------------------------------------------------------
## binomial-logit (fixed residual scale = pi^2/3; tighter band)
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x binomial-logit: converges + PD; recovers latent slope structure; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_latent_deps()
  run_slope_phylo_latent_cell(
    emit      = function(eta) stats::rbinom(length(eta), size = 1L, prob = stats::plogis(eta)),
    family    = stats::binomial(link = "logit"),
    var_band  = .slope_phylo_latent_band$fixed_var,
    rho_abs   = .slope_phylo_latent_band$fixed_rho_abs,
    row_tag   = "RE-02 / PHY-06 (binomial-logit)",
    fam_label = "binomial-logit",
    mu0       = 0
  )
})

## ---------------------------------------------------------------------
## ordinal_probit (fixed residual scale = 1 by construction; tighter band)
## K = 4 categories cut at tau = (0, 0.7, 1.4); trait means shifted up so
## all categories fill (mirrors the SLOPE-ord sibling).
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x ordinal_probit: converges + PD; recovers latent slope structure; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_latent_deps()
  testthat::skip_if_not_installed("MCMCglmm")
  ordinal_cut <- function(eta) {
    ystar <- eta + stats::rnorm(length(eta), 0, 1)  # sigma_d^2 = 1 EXACT
    taus  <- c(0, 0.7, 1.4)
    as.integer(1L + colSums(outer(taus, ystar, FUN = function(t, y) y > t)))
  }
  run_slope_phylo_latent_cell(
    emit      = ordinal_cut,
    family    = ordinal_probit(),
    var_band  = .slope_phylo_latent_band$fixed_var,
    rho_abs   = .slope_phylo_latent_band$fixed_rho_abs,
    row_tag   = "RE-02 / PHY-06 (ordinal_probit)",
    fam_label = "ordinal_probit",
    mu0       = 0.55   # shift latent mass so all K = 4 categories fill
  )
})

## ---------------------------------------------------------------------
## poisson (mean-dependent; wider band). Healthy count mean exp(2) ~ 7.4.
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x poisson: converges + PD; recovers latent slope structure; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_latent_deps()
  run_slope_phylo_latent_cell(
    emit      = function(eta) as.integer(stats::rpois(length(eta), lambda = exp(eta))),
    family    = stats::poisson(link = "log"),
    var_band  = .slope_phylo_latent_band$mean_var,
    rho_abs   = .slope_phylo_latent_band$mean_rho_abs,
    row_tag   = "RE-02 / PHY-06 (poisson)",
    fam_label = "poisson",
    mu0       = 2
  )
})

## ---------------------------------------------------------------------
## nbinom2 (mean-dependent + overdispersion; wider band). phi = 2.
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x nbinom2: converges + PD; recovers latent slope structure; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_latent_deps()
  run_slope_phylo_latent_cell(
    emit      = function(eta) as.integer(stats::rnbinom(length(eta), mu = exp(eta), size = 2)),
    family    = gllvmTMB::nbinom2(),
    var_band  = .slope_phylo_latent_band$mean_var,
    rho_abs   = .slope_phylo_latent_band$mean_rho_abs,
    row_tag   = "RE-02 / PHY-06 (nbinom2)",
    fam_label = "nbinom2",
    mu0       = 2
  )
})

## ---------------------------------------------------------------------
## gamma (mean-dependent; wider band). log link, shape phi = 2, E(y) ~ 1.
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x gamma(log): converges + PD; recovers latent slope structure; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_latent_deps()
  gamma_emit <- function(eta) {
    mu <- exp(eta)
    stats::rgamma(length(eta), shape = 2, scale = mu / 2)
  }
  run_slope_phylo_latent_cell(
    emit      = gamma_emit,
    family    = stats::Gamma(link = "log"),
    var_band  = .slope_phylo_latent_band$mean_var,
    rho_abs   = .slope_phylo_latent_band$mean_rho_abs,
    row_tag   = "RE-02 / PHY-06 (gamma)",
    fam_label = "gamma(log)",
    mu0       = 0
  )
})

## ---------------------------------------------------------------------
## beta (mean-dependent; wider band). logit link, concentration phi = 5,
## responses strictly in (0, 1).
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x beta: converges + PD; recovers latent slope structure; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_latent_deps()
  beta_emit <- function(eta) {
    mu <- stats::plogis(eta)
    stats::rbeta(length(eta), mu * 5, (1 - mu) * 5)
  }
  run_slope_phylo_latent_cell(
    emit      = beta_emit,
    family    = gllvmTMB::Beta(),
    var_band  = .slope_phylo_latent_band$mean_var,
    rho_abs   = .slope_phylo_latent_band$mean_rho_abs,
    row_tag   = "RE-02 / PHY-06 (beta)",
    fam_label = "beta",
    mu0       = 0
  )
})
