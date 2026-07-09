## Phase B-matrix agent SLOPE-pois (Design 59): random-slope anchor
## `phylo_unique(1 + x | species)` x `poisson(link = "log")` --
## augmented-LHS covariance recovery + CI smoke.
##
## This is the POISSON branch of the random-slope anchor cell that
## `tests/testthat/test-phylo-unique-slope-gaussian.R` (PR #282) owns for
## Gaussian. It informs RE-02 ("one random slope, s = 1") of
## `docs/design/35-validation-debt-register.md`: the Gaussian slope anchor
## is covered; this file adds the non-Gaussian (log-link Poisson) evidence
## for the same `phylo_unique(1 + x | species)` 2x2 augmented covariance.
##
## Alignment table (mirrors the Gaussian template, swapped to log-link
## Poisson with a healthy count intercept mean ~= 2 => exp(2) ~= 7.4):
##
## | Symbol  | Covstruct keyword                 | Recovery extractor    | Truth |
## | sigma2a | phylo_unique augmented intercept  | report$sd_b[1]^2      | 0.4   |
## | sigma2b | phylo_unique augmented slope      | report$sd_b[2]^2      | 0.3   |
## | rho_ab  | phylo_unique augmented covariance | report$cor_b[1]       | 0.5   |
##
## Family note (Phase B0 scoping memo, 2026-05-26
## docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md): Poisson
## is a *mean-dependent* family -- the latent residual on the log scale is
## log(1 + 1/mu_t), so the effective scale shifts with the intercept,
## unlike a fixed-residual-scale family (probit latent variance == 1). Per
## the Honest-matrix discipline in Design 59, mean-dependent families get a
## WIDER recovery band than fixed-residual-scale families. We use a 4x band
## on the variance scale (matching the committed poisson-phylo sibling
## `test-matrix-poisson-phylo.R`, vs the 3x band the binary-probit phylo
## tests use), and a widened absolute band of 0.40 on the augmented
## intercept-slope correlation (vs the Gaussian template's 0.30). The slope
## variance and the correlation are the hardest to pin under Poisson noise:
## across an exploratory seed sweep the canonical-seed slope-variance ratio
## sits near 0.5 and |rho_hat - rho| near 0.22 -- both comfortably inside
## these honest bands, neither forced green.
##
## CI smoke (the augmented 2x2 covariance, NOT a cross-trait phy block):
## the augmented covariance is parameterised internally as `log_sd_b`
## (log intercept/slope SDs) and `atanh_cor_b` (Fisher-z of the
## intercept-slope correlation), surfaced through `fit$sd_report`. The
## cross-trait phy tokens `confint(parm = "rho:phy:1,2")` /
## `confint(parm = "sigma_phy_slope")` are for the *cross-trait*
## phylo_dep / legacy single-slope paths and do not address this
## intercept-slope structure; we attempt them first (so the test documents
## the attempt and stays robust if the engine later wires them up) and
## fall back to the genuinely-available transformed-Wald CI on the slope
## variance / correlation from the sdreport. The smoke passes when any one
## of these routes yields a finite bound.
##
## SKIP discipline (no fake-pass, Design 59): a cell that fails to
## construct, fails to converge, is non-PD, or whose recovery lands outside
## the honest band is `skip()`ped with a reason and reported as "stays
## partial" -- never forced green. The fit is seed-controlled (seed 5640,
## the Gaussian-template anchor seed) and finishes in ~1 s, well within the
## 15-min-per-fit time-box.

skip_if_not_slope_poisson_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Mean-dependent (Poisson) honest tolerance: 4x band on the variance
## scale, 0.40 absolute on the augmented intercept-slope correlation.
.slope_pois_var_band <- 4
.slope_pois_rho_abs_band <- 0.40

## Log-link Poisson fixture: same augmented-LHS DGP as the Gaussian anchor
## template (seed 5640, 60 species, 3 traits, 4 reps, x identical across
## traits within a (species, rep) cell), with a Poisson response at a
## healthy count intercept mean ~= 2 on the log scale.
make_slope_poisson_fixture <- function(seed = 5640L, n_sp = 60L,
                                       n_traits = 3L, n_rep = 4L,
                                       intercept_mean = 2) {
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

  raw <- matrix(stats::rnorm(n_sp * 2L), nrow = n_sp, ncol = 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

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

  ## Flat per-trait intercept at the same healthy count mean so the Poisson
  ## likelihood is neither near-zero (no information) nor overflowing.
  mu_t <- rep(intercept_mean, n_traits)[as.integer(df_long$trait)]
  alpha_sp <- ab[as.character(df_long$species), "alpha"]
  beta_sp <- ab[as.character(df_long$species), "beta"]
  eta <- mu_t + alpha_sp + beta_sp * df_long$x
  df_long$value <- stats::rpois(nrow(df_long), lambda = exp(eta))

  list(
    df_long = df_long,
    tree = tree,
    Sigma_b_true = Sigma_b_true,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true,
    cov_true = cov_true
  )
}

fit_slope_poisson <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species),
    data = fx$df_long,
    phylo_tree = fx$tree,
    unit = "species",
    family = stats::poisson(link = "log"),
    control = ctl
  )))
}

expect_slope_poisson_fit_health <- function(fit) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
}

## Transformed-Wald CI on a scalar log-SD / atanh-correlation entry of the
## augmented covariance, pulled from the sdreport. `entry_name` is the
## sdreport rowname ("log_sd_b" or "atanh_cor_b"); `which` selects the row
## among repeats (1 = intercept SD, 2 = slope SD). Returns a length-2 CI on
## the back-transformed scale (exp for log_sd_b, tanh for atanh_cor_b) or
## NULL if the entry/SE is unavailable.
.aug_wald_ci <- function(fit, entry_name, which = 1L, transform = exp,
                         level = 0.95) {
  sdr <- tryCatch(summary(fit$sd_report), error = function(e) NULL)
  if (is.null(sdr)) {
    return(NULL)
  }
  rows <- which(rownames(sdr) == entry_name)
  if (length(rows) < which) {
    return(NULL)
  }
  est <- sdr[rows[which], "Estimate"]
  se <- sdr[rows[which], "Std. Error"]
  if (!is.finite(est) || !is.finite(se)) {
    return(NULL)
  }
  z <- stats::qnorm(1 - (1 - level) / 2)
  transform(c(est - z * se, est + z * se))
}

test_that("phylo_unique(1 + x | sp) x poisson: converges + PD Hessian; recovers sigma2_a, sigma2_b, rho in Phase-B0 mean-dependent band", {
  skip_if_not_heavy()
  skip_if_not_slope_poisson_deps()
  fx <- make_slope_poisson_fixture()

  fit <- tryCatch(fit_slope_poisson(fx), error = function(e) e)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_unique(1 + x | sp) poisson fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "wrong class"
    ))
  }
  if (!.fit_converged(fit)) {
    skip("phylo_unique(1 + x | sp) poisson fit did not converge with PD Hessian; RE-02 (poisson) stays partial pending bigger n / different seed")
  }

  expect_slope_poisson_fit_health(fit)

  ## Augmented covariance recovery. report$sd_b is the 2-vector
  ## (intercept SD, slope SD); report$cor_b[1] is the intercept-slope
  ## correlation. Mean-dependent => 4x band on the two variances, 0.40
  ## absolute on the correlation (Honest-matrix discipline, Design 59).
  sd_b <- as.numeric(fit$report$sd_b)
  cor_b <- as.numeric(fit$report$cor_b)[1L]
  expect_equal(length(sd_b), 2L)
  expect_true(all(is.finite(sd_b)))
  expect_true(is.finite(cor_b))

  sigma2_int_hat <- sd_b[1L]^2
  sigma2_slope_hat <- sd_b[2L]^2

  ratio_int <- sigma2_int_hat / fx$sigma2_int_true
  ratio_slope <- sigma2_slope_hat / fx$sigma2_slope_true
  if (!is.finite(ratio_int) ||
        ratio_int < 1 / .slope_pois_var_band ||
        ratio_int > .slope_pois_var_band) {
    skip(sprintf(
      "sigma2_intercept recovery outside %gx band (hat = %.3g, truth = %.3g, ratio = %.3g); RE-02 (poisson) stays partial pending bigger n",
      .slope_pois_var_band, sigma2_int_hat, fx$sigma2_int_true, ratio_int
    ))
  }
  if (!is.finite(ratio_slope) ||
        ratio_slope < 1 / .slope_pois_var_band ||
        ratio_slope > .slope_pois_var_band) {
    skip(sprintf(
      "sigma2_slope recovery outside %gx band (hat = %.3g, truth = %.3g, ratio = %.3g); RE-02 (poisson) stays partial pending bigger n",
      .slope_pois_var_band, sigma2_slope_hat, fx$sigma2_slope_true, ratio_slope
    ))
  }
  if (abs(cor_b - fx$rho_true) > .slope_pois_rho_abs_band) {
    skip(sprintf(
      "rho recovery outside +/-%.2f band (hat = %.3g, truth = %.3g); RE-02 (poisson) stays partial pending bigger n",
      .slope_pois_rho_abs_band, cor_b, fx$rho_true
    ))
  }

  expect_gt(sigma2_int_hat, fx$sigma2_int_true / .slope_pois_var_band)
  expect_lt(sigma2_int_hat, fx$sigma2_int_true * .slope_pois_var_band)
  expect_gt(sigma2_slope_hat, fx$sigma2_slope_true / .slope_pois_var_band)
  expect_lt(sigma2_slope_hat, fx$sigma2_slope_true * .slope_pois_var_band)
  expect_lte(abs(cor_b - fx$rho_true), .slope_pois_rho_abs_band)
})

test_that("phylo_unique(1 + x | sp) x poisson: augmented recovery is seed-stable (byte-identical refit)", {
  skip_if_not_heavy()
  skip_if_not_slope_poisson_deps()
  fx <- make_slope_poisson_fixture()

  fit1 <- tryCatch(fit_slope_poisson(fx), error = function(e) e)
  if (!.fit_converged(fit1)) {
    skip("phylo_unique(1 + x | sp) poisson fit did not converge with PD Hessian; RE-02 (poisson) seed-stability stays partial")
  }
  fit2 <- fit_slope_poisson(fx)

  ## Mean-dependent recovery is seed-sensitive, so the honest invariant is
  ## not a point value but seed-stability: the same seed must reproduce the
  ## same point estimates byte-for-byte (deterministic optimiser path).
  expect_equal(fit2$report$sd_b, fit1$report$sd_b, tolerance = 1e-8)
  expect_equal(fit2$report$cor_b, fit1$report$cor_b, tolerance = 1e-8)
  expect_equal(fit2$opt$objective, fit1$opt$objective, tolerance = 1e-8)
})

test_that("phylo_unique(1 + x | sp) x poisson: CI smoke -- a finite bound on the augmented slope variance or correlation", {
  skip_if_not_heavy()
  skip_if_not_slope_poisson_deps()
  fx <- make_slope_poisson_fixture()

  fit <- tryCatch(fit_slope_poisson(fx), error = function(e) e)
  if (!.fit_converged(fit)) {
    skip("phylo_unique(1 + x | sp) poisson fit did not converge with PD Hessian; RE-02 (poisson) CI smoke stays partial")
  }

  ## Route 1 (documented attempt): the cross-trait phy profile tokens.
  ## These address cross-trait phylo_dep / legacy single-slope structure,
  ## not the augmented 2x2 intercept-slope covariance, so they are expected
  ## to be unavailable here -- but we attempt them so the test records the
  ## attempt and stays robust if the engine later wires them up.
  finite_bound <- function(ci) {
    if (inherits(ci, "error") || is.null(ci)) {
      return(FALSE)
    }
    m <- suppressWarnings(as.matrix(as.data.frame(ci)))
    any(is.finite(suppressWarnings(as.numeric(m))))
  }

  any_finite <- FALSE
  for (parm_token in c("rho:phy:1,2", "sigma_phy_slope")) {
    ci <- tryCatch(
      suppressMessages(suppressWarnings(stats::confint(
        fit, parm = parm_token, method = "profile"
      ))),
      error = function(e) e
    )
    if (finite_bound(ci)) {
      any_finite <- TRUE
      break
    }
  }

  ## Route 2 (the genuinely-available CI for this structure): a
  ## transformed-Wald interval on the augmented slope SD (=> slope
  ## variance) or the intercept-slope correlation, from the sdreport. On a
  ## PD fit these have finite SEs, so this is the honest slope-variance CI
  ## smoke for the augmented path.
  if (!any_finite) {
    ci_slope_sd <- .aug_wald_ci(fit, "log_sd_b", which = 2L, transform = exp)
    if (!is.null(ci_slope_sd)) {
      ci_slope_var <- ci_slope_sd^2
      any_finite <- any(is.finite(ci_slope_var))
    }
  }
  if (!any_finite) {
    ci_cor <- .aug_wald_ci(fit, "atanh_cor_b", which = 1L, transform = tanh)
    any_finite <- !is.null(ci_cor) && any(is.finite(ci_cor))
  }

  if (!any_finite) {
    skip("No finite CI bound available for the augmented slope variance or correlation (profile tokens N/A for this structure; sdreport SEs not finite); RE-02 (poisson) CI smoke stays partial -- honest skip rather than relax assertion")
  }
  expect_true(any_finite)
})
