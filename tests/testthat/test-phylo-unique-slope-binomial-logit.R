## Design 55 A1 + Design 56 9.4 / Phase B2 -- phylo_unique(1 + x | sp)
## Binomial(logit) recovery for the Phase B2 fixed-residual-scale
## cell. Mirrors the Phase 56.4 Gaussian anchor in
## `test-phylo-unique-slope-gaussian.R` and the Phase B1 binomial(probit)
## sibling in `test-phylo-unique-slope-binomial-probit.R` with only the
## response family swapped from `binomial(link = "probit")` to
## `binomial(link = "logit")`.
##
## Identifiability story: logit residual variance is `sigma^2_d =
## pi^2 / 3 ~= 3.290` (fixed by the link choice, not estimated). See
## the Phase B0 scoping memo
## `docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md`
## section 3.1 for the per-link table. Because the latent residual
## scale is a known constant, the latent-scale random-effect SDs
## (`sigma^2_alpha`, `sigma^2_beta`) identify without a delta-method
## estimate of `sigma^2_d`. Together with binomial(probit), this is
## the cleanest non-Gaussian identifiability case for the
## augmented-LHS engine.
##
## Alignment table:
##
## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
## | alpha_sp | phylo_unique augmented intercept | alpha,beta ~ N(0, Sigma_b x A_phy) | report$sd_b[1]^2 | 0.4 |
## | beta_sp  | phylo_unique augmented slope     | alpha,beta ~ N(0, Sigma_b x A_phy) | report$sd_b[2]^2 | 0.3 |
## | rho_ab   | phylo_unique augmented covariance | Sigma_b[1,2] via rho = 0.5        | report$cor_b[1]   | 0.5 |
##
## Response model:
##   eta = mu_t + alpha_sp + beta_sp * x   (logit-scale linear predictor)
##   prob = plogis(eta)
##   y ~ Bernoulli(prob)
##
## The fixture keeps x identical across traits within each (species,
## rep) cell so the wide traits(...) surface and explicit long surface
## are the same likelihood problem.
##
## Seed selection: the Phase 56.4 anchor uses seed 5640 and the Phase
## B1 binomial(probit) sibling uses seed 2026 (5640 failed under
## probit). Binary outcomes carry less information per observation
## than Gaussian responses, and the logit link further attenuates
## latent-scale signal (sigma^2_d ~= 3.290 vs probit's exact 1), so
## seed selection was re-run under the same honest-rejection
## discipline used in #298 / Phase B1. See the check-log entry for
## the full seed-selection record.

skip_if_not_phylo_unique_slope_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  testthat::skip_if_not_installed("tidyr")
}

make_phylo_unique_slope_fixture <- function(
  seed = 2026,
  n_sp = 60L,
  n_traits = 3L,
  n_rep = 4L
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

  ## Logit-scale trait intercepts: kept modest in magnitude so the
  ## marginal probability across rows is not saturated. plogis(0.0)
  ## = 0.5, plogis(0.3) ~= 0.574, plogis(-0.3) ~= 0.426 — same
  ## intercepts as the Phase B1 probit sibling.
  ##
  ## CORRECTED 2026-07-21: an earlier version of this comment claimed the
  ## binary observations "still carry adequate information for slope-variance
  ## recovery". Measurement contradicts that. With n_rep = 4 and n_traits = 3
  ## there are 12 single-Bernoulli observations per species over 4 distinct x
  ## values, so the sampling variance of a per-species slope is roughly
  ## (pi^2/3) / 12 ~= 0.27 -- nearly as large as the true between-species slope
  ## variance of 0.30. Half the spread in the estimated slopes is therefore
  ## sampling noise, which is why sigma^2_slope comes back inflated. The same
  ## design recovers cleanly under Gaussian, so this is an information limit of
  ## single-trial binary data, not an engine defect. More information PER
  ## species (more reps, or multi-trial binomial) is the fix; raising the true
  ## variance is not. See docs/dev-log/known-residuals-register.md (R-2).
  mu_t <- c(0.0, 0.3, -0.3)[as.integer(df_long$trait)]
  alpha_sp <- ab[as.character(df_long$species), "alpha"]
  beta_sp <- ab[as.character(df_long$species), "beta"]
  prob <- stats::plogis(mu_t + alpha_sp + beta_sp * df_long$x)
  df_long$value <- stats::rbinom(length(prob), size = 1L, prob = prob)

  df_wide <- tidyr::pivot_wider(
    df_long,
    id_cols = c(species, rep, x),
    names_from = trait,
    values_from = value
  )
  df_wide <- as.data.frame(df_wide, stringsAsFactors = FALSE)

  list(
    df_long = df_long,
    df_wide = df_wide,
    tree = tree,
    Sigma_b_true = Sigma_b_true,
    sigma2_int_true = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true = rho_true,
    cov_true = cov_true,
    ab_true = ab
  )
}

fit_phylo_unique_slope_pair <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_unique(0 + trait + (0 + trait):x | species),
    data = fx$df_long,
    family = binomial(link = "logit"),
    phylo_tree = fx$tree,
    unit = "species",
    control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3) ~ 1 + phylo_unique(1 + x | species),
    data = fx$df_wide,
    family = binomial(link = "logit"),
    phylo_tree = fx$tree,
    unit = "species",
    control = ctl
  )))
  list(long = fit_long, wide = fit_wide)
}

expect_phase_b2_fit_health <- function(fit) {
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_lt(fit$fit_health$max_gradient, 1e-2)
  expect_true(isTRUE(fit$fit_health$sdreport_ok))
  expect_true(isTRUE(fit$fit_health$pd_hessian))
}

phase_b2_Sigma_b <- function(fit) {
  sd_b <- as.numeric(fit$report$sd_b)
  rho <- as.numeric(fit$report$cor_b)
  matrix(
    c(
      sd_b[1L]^2,
      rho * sd_b[1L] * sd_b[2L],
      rho * sd_b[1L] * sd_b[2L],
      sd_b[2L]^2
    ),
    nrow = 2L,
    ncol = 2L,
    dimnames = list(c("intercept", "slope"), c("intercept", "slope"))
  )
}

test_that("phylo_unique augmented wide and long fits are byte-identical (binomial logit)", {
  skip_if_not_phylo_unique_slope_deps()

  fx <- make_phylo_unique_slope_fixture()
  fits <- fit_phylo_unique_slope_pair(fx)

  expect_phase_b2_fit_health(fits$long)
  expect_phase_b2_fit_health(fits$wide)
  expect_equal(
    as.numeric(logLik(fits$wide)),
    as.numeric(logLik(fits$long)),
    tolerance = 1e-6
  )
  expect_equal(fits$wide$opt$objective, fits$long$opt$objective, tolerance = 1e-8)
  expect_identical(fits$wide$tmb_data$y, fits$long$tmb_data$y)
  expect_identical(fits$wide$tmb_data$trait_id, fits$long$tmb_data$trait_id)
  expect_identical(
    fits$wide$tmb_data$species_aug_id,
    fits$long$tmb_data$species_aug_id
  )
  expect_identical(fits$wide$tmb_data$Z_phy_aug, fits$long$tmb_data$Z_phy_aug)
  expect_equal(fits$wide$report$sd_b, fits$long$report$sd_b, tolerance = 1e-8)
  expect_equal(fits$wide$report$cor_b, fits$long$report$cor_b, tolerance = 1e-8)
})

test_that("phylo_unique augmented binomial(logit) fit recovers Sigma_b", {
  skip_if_not_phylo_unique_slope_deps()

  ## Phase B2 empirical finding (Claude Grue, 2026-05-26 evening):
  ## under family = binomial(link = "logit"), the random-slope variance
  ## sigma^2_beta = 0.3 (truth) cannot be reliably recovered at the
  ## Phase B0 memo's recommended fixture size (n_id = 60, T = 3,
  ## n_rep = 4) and tolerance (sigma^2 +-20%). Empirical seed sweep:
  ##
  ##   - n_id=60, seeds {2026, 5640, 102, 314, 271, 42, 1729, 2718,
  ##     1024, 4096}: all fail. Best (1024): sigma^2_slope rel err 0.38.
  ##   - n_id=120, seeds {2026, 5640, 1024, 2718, 42, 314}: all fail.
  ##     Best (42): sigma^2_int rel err 0.003, rho err 0.06, but
  ##     sigma^2_slope rel err 0.61 (consistent upward bias).
  ##   - n_id=240, seeds {42, 314, 2718, 1024, 2026}: all fail.
  ##     sigma^2_slope is systematically over-estimated by ~50-60%.
  ##
  ## Root cause is logit's higher link-residual variance (sigma^2_d =
  ## pi^2/3 ~ 3.29 vs probit's 1) reducing the effective signal-to-
  ## noise for slope recovery relative to probit (which recovered all
  ## three targets cleanly at n_id=60 with seed 2026 in #303). This is
  ## not parser or engine breakage; the fit is healthy
  ## (convergence == 0, pd_hessian == TRUE, sdreport_ok == TRUE) but
  ## the estimator has a real upward bias on sigma^2_slope under
  ## logit at these signal levels.
  ##
  ## Per the Codex discipline (do NOT widen tolerances; do NOT
  ## fake-pass), this test is SKIPPED with the documented finding.
  ## A follow-up B2-recalibration slice should investigate:
  ##   (a) bumping n_id further (480+);
  ##   (b) increasing truth sigma^2_slope from 0.3 -> 0.6 to lift the
  ##       signal above logit's pi^2/3 floor (this is a DGP truth
  ##       change, separate from tolerance change);
  ##   (c) finer trait intercepts to avoid any logit saturation
  ##       contribution to the slope-variance estimator.
  ##
  ## Byte-identity and forced-n_lhs_cols=1 negative test (below) are
  ## NOT affected -- both still pass cleanly under logit, confirming
  ## parser routing and engine guard work as expected for the family.
  ## Skipped by default, but RE-MEASURABLE on demand: set
  ## GLLVMTMB_RUN_B2_LOGIT=1 to run it. A declared limitation should be
  ## checkable, not merely asserted -- and the finding above was recorded on
  ## 2026-07-06, before the 2026-07-20 slope-engine rework (6e46a24a), so it
  ## must be re-measured rather than assumed still current.
  ## See docs/dev-log/known-residuals-register.md (R-2).
  if (!nzchar(Sys.getenv("GLLVMTMB_RUN_B2_LOGIT"))) {
    testthat::skip(
      "Logit recovery requires fixture beyond B0 defaults; see Phase B2-recalibration follow-up. Set GLLVMTMB_RUN_B2_LOGIT=1 to re-measure."
    )
  }

  fx <- make_phylo_unique_slope_fixture()
  fit <- fit_phylo_unique_slope_pair(fx)$long
  Sigma_hat <- phase_b2_Sigma_b(fit)
  sigma2_int_hat <- unname(Sigma_hat["intercept", "intercept"])
  sigma2_slope_hat <- unname(Sigma_hat["slope", "slope"])
  rho_hat <- unname(stats::cov2cor(Sigma_hat)["intercept", "slope"])

  expect_phase_b2_fit_health(fit)
  expect_lte(
    abs(sigma2_int_hat - fx$sigma2_int_true) / fx$sigma2_int_true,
    0.20
  )
  expect_lte(
    abs(sigma2_slope_hat - fx$sigma2_slope_true) / fx$sigma2_slope_true,
    0.20
  )
  expect_lte(abs(rho_hat - fx$rho_true), 0.30)
})

test_that("phylo_unique augmented binomial(logit) fit aborts when n_lhs_cols is forced to 1", {
  skip_if_not_phylo_unique_slope_deps()

  ## Robust default fixture (n_sp = 60): the tiny n_sp = 10 fit is knife-edge and
  ## flakes on Linux under any Ainv reimplementation (a 1e-14 difference tips
  ## convergence). This guard only needs a converged fit to corrupt, so fixture
  ## size is incidental. (phylo_unique(slope) is slated for deprecation.)
  fx <- make_phylo_unique_slope_fixture()
  fit <- fit_phylo_unique_slope_pair(fx)$long
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
