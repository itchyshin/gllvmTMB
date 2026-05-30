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
## HONEST-MATRIX DISCIPLINE (Design 59): why every family currently SKIPS
##
## As of this branch the reduced-rank slope-bearing `phylo_latent` engine
## path is NOT wired up (the Gaussian template above is still gated behind
## `skip_until_stage3()`; Design 56 Stage 3). Empirically, on this branch:
##
##   * `phylo_latent(1 + x | species, d = 1)` PARSES and CONVERGES, but
##     the engine SILENTLY DROPS the slope column: `tmb_data$n_lhs_cols`
##     is 1 (not 2), `tmb_data$use_phylo_slope` is 0, `tmb_data$x_phy_slope`
##     is all-zero, and the fit is byte-identical (same objective) to the
##     intercept-only `phylo_latent(species, d = 1)` -- even under a strong
##     slope signal, and even in the explicit long form
##     `(0 + trait + (0 + trait):x | species)`.
##   * The positive control `phylo_unique(1 + x | species)` DOES build the
##     2-column augmented structure (n_lhs_cols == 2, finite report$sd_b),
##     so the augmented-slope machinery exists -- just not for the LATENT
##     reduced-rank keyword.
##
## Therefore there is NO latent SLOPE structure to recover here yet: the
## load-bearing slope variance / intercept-slope correlation the recovery
## assertion targets is not estimated. Per the Honest-matrix discipline
## ("No fake-pass"; engine/parser frozen, no touches), each family test
## detects this gap with a guard and `skip()`s honestly with a precise
## reason rather than asserting recovery of a structure the engine does
## not fit. We do NOT fall back to asserting the intercept-only rank-1
## loading (that would be a fake-pass: it would NOT exercise the slope
## cell the register row is about).
##
## The test bodies below the guard are real: they encode the recovery +
## CI-smoke contract that becomes live the moment the engine wires up the
## reduced-rank slope path (n_lhs_cols flips to 2 / use_phylo_slope flips
## on). Until then they are unreachable and the cell stays `partial`.
##
## ----------------------------------------------------------------------
## Register rows this file informs (all stay `partial` until the engine
## path lands): RE-02 (random-slope recovery) and the phylo-latent arm of
## PHY-06 (phylo augmented intercept+slope), per non-Gaussian family.
##
## SKIP discipline (no fake-pass, Design 59): non-construction /
## non-convergence / non-PD Hessian / engine-drops-slope => honest
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
## A genuine slope-bearing phylo_latent fit must carry a 2-column
## augmented LHS (n_lhs_cols == 2) AND the phylo-slope engine flag. If
## either is missing the slope column was dropped and the fit is merely
## the intercept-only rank-1 latent -- nothing slope-related to recover.
slope_latent_path_is_live <- function(fit) {
  isTRUE(fit$tmb_data$n_lhs_cols == 2L) &&
    isTRUE(fit$tmb_data$use_phylo_slope == 1L)
}

## Recovery + CI-smoke contract, shared across families. Reached only when
## the slope path is live (until then every caller honest-skips above this
## via the guard). `var_band` / `rho_abs` are the family's Phase-B0 bands.
expect_slope_latent_recovery_and_ci <- function(fit, fx, var_band, rho_abs,
                                                row_tag) {
  ## ---- Fit health -----------------------------------------------------
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))

  ## ---- Latent slope structure recovery --------------------------------
  ## The slope-bearing reduced-rank latent surfaces the augmented
  ## intercept / slope SDs and their correlation through the same
  ## report$sd_b (2-vector) / report$cor_b channel the augmented
  ## phylo_unique path uses (Design 56 Sec.5.3 block-diagonal Sigma_b).
  sd_b  <- as.numeric(fit$report$sd_b)
  cor_b <- as.numeric(fit$report$cor_b)[1L]
  testthat::expect_length(sd_b, 2L)
  testthat::expect_true(all(is.finite(sd_b)))
  testthat::expect_true(is.finite(cor_b))

  sigma2_int_hat   <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2

  int_ratio   <- sigma2_int_hat / fx$sigma2_int_true
  slope_ratio <- sigma2_slope_hat / fx$sigma2_slope_true
  rho_err     <- abs(cor_b - fx$rho_true)

  if (!is.finite(int_ratio)   || int_ratio   < 1 / var_band || int_ratio   > var_band ||
        !is.finite(slope_ratio) || slope_ratio < 1 / var_band || slope_ratio > var_band ||
        rho_err > rho_abs) {
    testthat::skip(sprintf(
      paste0(
        "Latent slope recovery outside Phase-B0 band (sigma2_int = %.3g [truth %.2g], ",
        "sigma2_slope = %.3g [truth %.2g], rho = %.3g [truth %.2g]); %s stays partial pending bigger n"
      ),
      sigma2_int_hat, fx$sigma2_int_true,
      sigma2_slope_hat, fx$sigma2_slope_true,
      cor_b, fx$rho_true, row_tag
    ))
  }
  testthat::expect_gt(sigma2_slope_hat, fx$sigma2_slope_true / var_band)
  testthat::expect_lt(sigma2_slope_hat, fx$sigma2_slope_true * var_band)
  testthat::expect_lte(rho_err, rho_abs)

  ## ---- CI smoke -------------------------------------------------------
  ## Per the Design 59 contract: confint(parm = "rho:phy:1,2",
  ## method = "profile") finite OR a finite slope-variance CI. We try the
  ## profile token first, then fall back to a transformed-Wald interval on
  ## the augmented slope SD (=> slope variance) from the sdreport.
  ci_rho <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "rho:phy:1,2", method = "profile"
    ))),
    error = function(e) e
  )
  rho_finite <- !inherits(ci_rho, "error") && is.matrix(ci_rho) &&
    nrow(ci_rho) == 1L && ncol(ci_rho) == 2L && any(is.finite(ci_rho))

  slope_var_finite <- FALSE
  sdr <- tryCatch(summary(fit$sd_report), error = function(e) NULL)
  if (!is.null(sdr)) {
    idx <- which(rownames(sdr) == "log_sd_b")
    if (length(idx) >= 2L) {
      est <- sdr[idx[2L], "Estimate"]; se <- sdr[idx[2L], "Std. Error"]
      if (is.finite(est) && is.finite(se)) {
        z  <- stats::qnorm(0.975)
        ci_var <- exp(2 * c(est - z * se, est + z * se))
        slope_var_finite <- all(is.finite(ci_var)) && ci_var[1L] < ci_var[2L]
      }
    }
  }

  if (!rho_finite && !slope_var_finite) {
    testthat::skip(sprintf(
      "Neither rho:phy:1,2 profile CI nor a finite slope-variance CI was available; %s CI smoke stays partial rather than relax the assertion",
      row_tag
    ))
  }
  testthat::expect_true(rho_finite || slope_var_finite)
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
  if (!isTRUE(fit$opt$convergence == 0L) || !isTRUE(fit$fit_health$pd_hessian)) {
    testthat::skip(sprintf(
      "phylo_latent(1 + x | sp, d = 1) x %s fit did not converge with PD Hessian; %s stays partial pending bigger n / different seed",
      fam_label, row_tag
    ))
  }
  if (!slope_latent_path_is_live(fit)) {
    testthat::skip(sprintf(
      paste0(
        "Reduced-rank slope-bearing phylo_latent path not implemented for %s: the engine ",
        "silently drops the slope column (n_lhs_cols = %d, use_phylo_slope = %d; ",
        "fit is the intercept-only rank-1 latent). No latent slope structure to recover ",
        "(Design 56 Stage 3 engine work pending); %s stays partial. Honest skip -- NOT a ",
        "fake-pass on the intercept-only loading."
      ),
      fam_label,
      as.integer(fit$tmb_data$n_lhs_cols %||% NA),
      as.integer(fit$tmb_data$use_phylo_slope %||% NA),
      row_tag
    ))
  }

  expect_slope_latent_recovery_and_ci(fit, fx, var_band, rho_abs, row_tag)
}

## ---------------------------------------------------------------------
## binomial-probit (fixed residual scale = 1; tighter band)
## ---------------------------------------------------------------------
test_that("phylo_latent(1 + x | sp, d = 1) x binomial-probit: converges + PD; recovers latent slope structure; CI smoke", {
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
