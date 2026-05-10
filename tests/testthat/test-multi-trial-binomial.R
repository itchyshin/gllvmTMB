# Multi-trial binomial (k-of-n) support in the gllvmTMB engine.
#
# Tests the cbind(successes, failures) ~ ... API and the alternative
# weights = n_trials API. Recovery test uses a realistic passerine
# nest-survival exemplar:
#   * 50 nests, 8 eggs per nest -> 400 trials total
#   * mean fledge probability ~ 0.45 (Schmidt & Anderson 1993 reported
#     typical passerine nest-survival around 25-60% per nesting period;
#     Newton 1989, Lifetime Reproduction in Birds, gives clutch sizes of
#     4-10 eggs for songbirds; Mainwaring et al. 2014 nest-survival
#     meta-analysis, Biol. Rev., reports similar ranges).
#   * one continuous covariate (e.g. nest concealment or vegetation
#     density) drives logit-fledge probability with slope on the latent
#     scale.
#
# We verify:
#   1. cbind(succ, fail) ~ ... parses through the multi-fit engine and
#      passes n_trials to TMB.
#   2. Slope estimate is within ~2 SE of the true value across replicate
#      simulations.
#   3. Log-likelihood matches glmmTMB::glmmTMB(cbind(succ, fail) ~ ...,
#      family = binomial) within numerical tolerance on a structurally
#      equivalent model.
#   4. Bernoulli (size = 1) behaviour is unchanged for code paths that
#      do not use cbind() — backward compatibility with the previous
#      hard-coded dbinom(y, 1, p).

skip_if_not_installed("glmmTMB")

# --- Simulation helper: realistic 50-nest x 8-egg dataset --------------
# Stacked as 2 traits (early-clutch / late-clutch) so the multi-trait
# engine sees >=2 trait levels and 0 + trait expands to 2 columns.
sim_nest_survival <- function(seed = 1L,
                              n_nests = 50L, eggs_per_nest = 8L,
                              intercept = c(0.0, -0.2),
                              slope     = c(0.8,  0.5)) {
  set.seed(seed)
  trait_levels <- c("early", "late")
  n_traits <- length(trait_levels)
  ## one row per nest x trait pair (so 50 * 2 = 100 rows, each with 8 eggs).
  conceal <- stats::rnorm(n_nests)               # standardised cover index
  out <- data.frame(
    site    = rep(factor(sprintf("nest_%03d", seq_len(n_nests))), each = n_traits),
    species = rep(factor("placeholder"), n_nests * n_traits),
    trait   = factor(rep(trait_levels, n_nests), levels = trait_levels),
    site_species = factor(rep(sprintf("nest_%03d_sp", seq_len(n_nests)),
                              each = n_traits)),
    conceal = rep(conceal, each = n_traits)
  )
  ti <- as.integer(out$trait)
  eta <- intercept[ti] + slope[ti] * out$conceal
  p_fledge <- plogis(eta)
  out$succ <- stats::rbinom(nrow(out), size = eggs_per_nest, prob = p_fledge)
  out$fail <- eggs_per_nest - out$succ
  out$n_trials <- eggs_per_nest
  out
}

# ----------------------------------------------------------------------
test_that("cbind(succ, fail) parses through the multi-fit engine", {
  df <- sim_nest_survival(seed = 1L)
  fit <- gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + (0 + trait):conceal +
      latent(0 + trait | site, d = 1),
    data    = df,
    family  = binomial(),
    silent  = TRUE
  )
  expect_equal(fit$opt$convergence, 0L)
  ## TMB-side n_trials must be the per-row trial count, not all-ones.
  expect_equal(fit$tmb_data$n_trials, rep(8, nrow(df)))
  ## y is the success count, not the proportion.
  expect_true(all(fit$tmb_data$y == df$succ))
})

# ----------------------------------------------------------------------
test_that("Bernoulli (no cbind) is unchanged: n_trials defaults to 1", {
  set.seed(2L)
  n <- 60L
  ## Two trait levels so 0 + trait expands cleanly.
  trait_levels <- c("a", "b")
  df <- data.frame(
    site    = rep(factor(sprintf("s%02d", seq_len(n))), each = 2L),
    species = factor(rep("placeholder", 2L * n)),
    trait   = factor(rep(trait_levels, n), levels = trait_levels),
    site_species = factor(rep(sprintf("s%02d_sp", seq_len(n)), each = 2L)),
    x       = rep(stats::rnorm(n), each = 2L)
  )
  df$y    <- stats::rbinom(nrow(df), 1, 0.4)
  fit <- gllvmTMB(
    y ~ 0 + trait + (0 + trait):x + latent(0 + trait | site, d = 1),
    data   = df,
    family = binomial(),
    silent = TRUE
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$n_trials, rep(1, nrow(df)))
})

# ----------------------------------------------------------------------
test_that("Multi-trial binomial slope recovery (50 nests x 8 eggs, 30 reps)", {
  skip_on_cran()
  skip_on_covr()
  ## R = 30 replicate datasets. Within +/- 2 SE coverage should hit ~95%
  ## of replicates if SEs are well calibrated; we use a relaxed >=20/30
  ## threshold to keep the test stable across platforms.
  R <- 30L
  ## Recover the "early-trait" slope only (true value 0.8). Late-trait
  ## slope is 0.5 in the simulator but we only check one to keep the
  ## test diagnostic.
  true_slope_early <- 0.8
  hits <- integer(R)
  est  <- numeric(R)
  se   <- numeric(R)
  for (r in seq_len(R)) {
    df <- sim_nest_survival(seed = 100L + r)
    fit <- tryCatch(
      gllvmTMB(
        cbind(succ, fail) ~ 0 + trait + (0 + trait):conceal +
          latent(0 + trait | site, d = 1),
        data    = df,
        family  = binomial(),
        silent  = TRUE
      ),
      error = function(e) NULL
    )
    if (is.null(fit) || fit$opt$convergence != 0L) next
    sd_rep <- summary(fit$sd_report, "fixed")
    ## Find the X_fix column corresponding to early-trait conceal slope.
    col_match <- which(fit$X_fix_names == "traitearly:conceal")
    if (length(col_match) != 1L) next
    b_rows <- which(rownames(sd_rep) == "b_fix")
    if (length(b_rows) < col_match) next
    est[r] <- sd_rep[b_rows[col_match], "Estimate"]
    se[r]  <- sd_rep[b_rows[col_match], "Std. Error"]
    hits[r] <- as.integer(abs(est[r] - true_slope_early) <= 2 * se[r])
  }
  ok <- hits == 1L
  expect_gte(sum(ok), 20L)
  ## Mean estimate should also be close to truth (no obvious bias).
  expect_lt(abs(mean(est[ok]) - true_slope_early), 0.20)
})

# ----------------------------------------------------------------------
test_that("Log-likelihood matches glmmTMB on structurally equivalent fit", {
  skip_on_cran()
  skip_on_covr()
  ## Structural match: same fixed-effects structure (intercept + conceal),
  ## same random structure ((1 | site)), same family. We trigger the
  ## gllvmTMB multi-engine dispatch with the (1 | site) re_int covstruct,
  ## which is the gllvmTMB analogue of a glmmTMB (1 | site) random
  ## intercept. Use 2 trait levels in the simulator but pool them in the
  ## fit so there is one slope and one intercept.
  df <- sim_nest_survival(seed = 7L)
  fit_g <- gllvmTMB(
    cbind(succ, fail) ~ 1 + conceal + (1 | site),
    data    = df,
    family  = binomial(),
    silent  = TRUE
  )
  fit_glmm <- glmmTMB::glmmTMB(
    cbind(succ, fail) ~ 1 + conceal + (1 | site),
    data    = df,
    family  = stats::binomial()
  )
  ll_g    <- as.numeric(stats::logLik(fit_g))
  ll_glmm <- as.numeric(stats::logLik(fit_glmm))
  ## gllvmTMB and glmmTMB use the same TMB binomial density and the same
  ## Laplace approximation, so the log-likelihoods should match within
  ## a small numerical tolerance once both have converged.
  expect_lt(abs(ll_g - ll_glmm), 1e-3)
})

# ----------------------------------------------------------------------
test_that("weights = n_trials (API B) gives the same fit as cbind LHS", {
  skip_on_cran()
  skip_on_covr()
  df <- sim_nest_survival(seed = 3L)
  fit_a <- gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + (0 + trait):conceal +
      latent(0 + trait | site, d = 1),
    data    = df,
    family  = binomial(),
    silent  = TRUE
  )
  fit_b <- gllvmTMB(
    succ ~ 0 + trait + (0 + trait):conceal + latent(0 + trait | site, d = 1),
    data    = df,
    family  = binomial(),
    weights = df$n_trials,
    silent  = TRUE
  )
  expect_equal(fit_a$opt$objective, fit_b$opt$objective, tolerance = 1e-5)
})
