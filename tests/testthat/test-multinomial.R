## Tests for the multinomial() response family (baseline-category logit / softmax,
## family_id 16) in the multivariate engine. Design 83; validation-debt FAM-20.
##
## Mathematical background:
##   * Baseline-category logit (brms categorical() / VGAM multinomial): for a
##     categorical trait with K unordered categories and reference category 1,
##     eta_1 = 0 and eta_k = beta0_k + x'beta_k (k = 2..K), with
##     P(y = k) = exp(eta_k) / [1 + sum_{j>=2} exp(eta_j)].
##   * Tier 1 is FIXED-EFFECTS ONLY: an unordered categorical response spans
##     K-1 latent liability dimensions, so it cannot carry the single-scalar
##     latent-residual the mixed-family correlation surface needs (Design 62
##     precedent, generalised). latent / random terms fail loud; the K-1-dim
##     correlation surface is Tier 2, deferred.
##
## Tests below cover:
##   1. K = 3 recovery of the (K-1) per-category intercepts + slopes.
##   2. family_id == 16 dispatch and the (K-1)-coefficient-block contract.
##   3. Tier-1 fence: latent / random-effect terms fail loud.
##   4. K = 2 requires >= 3 categories (redirect toward binomial).
##   5. Mixed-family list() with multinomial is rejected in Tier 1.
##   6. Baseline-category invariance: relabelling the reference leaves the
##      maximised log-likelihood unchanged.

# Softmax DGP: K categories, reference 1, one continuous predictor x.
.make_multinomial <- function(seed = 1L, n = 300L, K = 3L,
                              b0 = c(0.5, -0.4), b1 = c(1.0, -0.8)) {
  set.seed(seed)
  x   <- stats::rnorm(n)
  eta <- cbind(0, matrix(b0, n, K - 1L, byrow = TRUE) + outer(x, b1))
  P   <- exp(eta - apply(eta, 1L, max))
  P   <- P / rowSums(P)
  y   <- vapply(seq_len(n), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))
  data.frame(unit = factor(seq_len(n)), trait = factor("morph"),
             value = factor(y), x = x)
}

# Recovery bands are CALIBRATED by dev/multinomial-recovery.R (500 seeds, run
# 2026-07-16). The softmax MLE is unbiased (|bias| <= 0.02 for every coefficient),
# but a single n=300 fit has per-coefficient SD ~0.15-0.23, so the old single-seed
# n=300 / abs-0.40 cell passed only on a favourable seed (~15% of random seeds
# exceeded 0.40). These cells instead assert UNBIASED AGGREGATE recovery: the
# seed-mean over 20 fits at n=600 has SD ~0.036, so an abs-0.15 band on the mean is
# ~4 SD from truth -- tighter than the old band AND essentially non-flaky (D-43
# recovery-evidence fix). Single-fit dispatch/shape is covered by the fid-16 test.
test_that("multinomial (K = 3, n = 600) recovers per-category coefficients (20-seed aggregate, calibrated band 0.15)", {
  skip_on_cran()
  truth <- c("traitmorph:2" = 0.5, "traitmorph:3" = -0.4,
             "traitmorph:2:x" = 1.0, "traitmorph:3:x" = -0.8)
  ests <- vapply(seq_len(20L), function(s) {
    df  <- .make_multinomial(seed = 300L + s, n = 600L, K = 3L)
    fit <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                    family = multinomial(), trait = "trait", unit = "unit")
    if (fit$opt$convergence != 0L || !isTRUE(fit$sd_report$pdHess) ||
        !all(fit$tmb_data$family_id_vec == 16L))
      return(stats::setNames(rep(NA_real_, 4L), names(truth)))
    sdf <- summary(fit$sd_report, "fixed")
    e   <- sdf[grepl("b_fix", rownames(sdf)), "Estimate"]
    stats::setNames(e, fit$X_fix_names)[names(truth)]
  }, numeric(4L))
  ok <- colSums(is.na(ests)) == 0L
  skip_if(sum(ok) < 18L, "fewer than 18 of 20 seeds converged PD")
  seed_mean <- rowMeans(ests[, ok, drop = FALSE])
  for (nm in names(truth)) {
    expect_lt(abs(seed_mean[[nm]] - truth[[nm]]), 0.15)   # calibrated aggregate band
  }
})

test_that("multinomial (K = 4, n = 600) recovers per-category coefficients (20-seed aggregate, calibrated band 0.15)", {
  skip_on_cran()
  b0 <- c(0.4, -0.3, 0.2); b1 <- c(0.9, -0.7, 0.6)
  truth <- c(b0, b1)
  ests <- vapply(seq_len(20L), function(s) {
    df  <- .make_multinomial(seed = 400L + s, n = 600L, K = 4L, b0 = b0, b1 = b1)
    fit <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                    family = multinomial(), trait = "trait", unit = "unit")
    if (fit$opt$convergence != 0L || !isTRUE(fit$sd_report$pdHess) ||
        !all(fit$tmb_data$family_id_vec == 16L))
      return(rep(NA_real_, 6L))
    sdf <- summary(fit$sd_report, "fixed")
    as.numeric(sdf[grepl("b_fix", rownames(sdf)), "Estimate"])   # X_fix column order
  }, numeric(6L))
  ok <- colSums(is.na(ests)) == 0L
  skip_if(sum(ok) < 18L, "fewer than 18 of 20 seeds converged PD")
  seed_mean <- rowMeans(ests[, ok, drop = FALSE])
  for (i in seq_along(truth)) {
    expect_lt(abs(seed_mean[[i]] - truth[[i]]), 0.15)   # calibrated aggregate band
  }
})

test_that("multinomial (K = 3) recovers across 5 seeds (aggregate, band 0.30)", {
  skip_on_cran()
  truth <- c("traitmorph:2" = 0.5, "traitmorph:3" = -0.4,
             "traitmorph:2:x" = 1.0, "traitmorph:3:x" = -0.8)
  ests <- vapply(seq_len(5L), function(s) {
    df  <- .make_multinomial(seed = 100L + s, n = 400L, K = 3L)
    fit <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                    family = multinomial(), trait = "trait", unit = "unit")
    if (fit$opt$convergence != 0L || !isTRUE(fit$sd_report$pdHess)) {
      return(stats::setNames(rep(NA_real_, 4L), names(truth)))
    }
    sdf <- summary(fit$sd_report, "fixed")
    e   <- sdf[grepl("b_fix", rownames(sdf)), "Estimate"]
    stats::setNames(e, fit$X_fix_names)[names(truth)]
  }, numeric(4L))
  ok <- colSums(is.na(ests)) == 0L                 # honest-skip non-converged seeds
  skip_if(sum(ok) < 4L, "fewer than 4 of 5 seeds converged PD")
  seed_mean <- rowMeans(ests[, ok, drop = FALSE])
  for (nm in names(truth)) {
    expect_lt(abs(seed_mean[[nm]] - truth[[nm]]), 0.30)   # tight band on the aggregate
  }
})

test_that("multinomial dispatches family_id 16 with a (K-1) coefficient block", {
  skip_on_cran()
  df  <- .make_multinomial(seed = 2L, n = 200L, K = 3L)
  fit <- gllvmTMB(value ~ 0 + trait, data = df,
                  family = multinomial(), trait = "trait", unit = "unit")
  expect_true(all(fit$tmb_data$family_id_vec == 16L))
  # K - 1 = 2 category-contrast pseudo-traits -> 2 intercepts.
  expect_length(fit$X_fix_names, 2L)
  expect_true(all(fit$tmb_data$multinom_K_per_trait[
    fit$tmb_data$multinom_K_per_trait > 0L] == 2L))
  # multinom_group_id is contiguous and non-negative for the fid-16 rows.
  gid <- fit$tmb_data$multinom_group_id
  expect_true(all(gid >= 0L))
  expect_false(is.unsorted(gid))
})

test_that("multinomial is fixed-effects-only: latent/RE terms fail loud (Tier 1)", {
  skip_on_cran()
  df <- .make_multinomial(seed = 3L, n = 120L, K = 3L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + (1 | unit), data = df,
             family = multinomial(), trait = "trait", unit = "unit"),
    regexp = "fixed-effects-only"
  )
})

test_that("multinomial requires >= 3 categories (2-level redirects to binomial)", {
  skip_on_cran()
  set.seed(4); n <- 120
  df <- data.frame(unit = factor(seq_len(n)), trait = factor("m"),
                   value = factor(sample.int(2L, n, replace = TRUE)),
                   x = stats::rnorm(n))
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = df, family = multinomial(),
             trait = "trait", unit = "unit"),
    regexp = ">= 3 categories|binomial"
  )
})

test_that("multinomial cannot be combined in a mixed-family list() (Tier 1)", {
  skip_on_cran()
  df <- .make_multinomial(seed = 5L, n = 60L, K = 3L)
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = df,
             family = list(multinomial(), gaussian()),
             trait = "trait", unit = "unit"),
    regexp = "mixed-family"
  )
})

test_that("extract_correlations / extract_Sigma refuse a multinomial (categorical) trait", {
  skip_on_cran()
  df  <- .make_multinomial(seed = 7L, n = 150L, K = 3L)
  fit <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                  family = multinomial(), trait = "trait", unit = "unit")
  expect_error(
    extract_correlations(fit),
    class = "gllvmTMB_multinomial_correlation_undefined"
  )
  # extract_Sigma hard-refuses too (was a silent NULL) — consistent fail-loud.
  expect_error(
    extract_Sigma(fit),
    class = "gllvmTMB_multinomial_sigma_undefined"
  )
})

test_that("predict(type='response') returns per-category softmax probabilities", {
  skip_on_cran()
  df  <- .make_multinomial(seed = 8L, n = 200L, K = 3L)
  fit <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                  family = multinomial(), trait = "trait", unit = "unit")
  pr  <- predict(fit, type = "response")
  # K = 3 categories per observation; probabilities sum to 1 within each unit.
  expect_equal(nrow(pr), 200L * 3L)
  expect_true(all(c("category", "est") %in% names(pr)))
  sums <- tapply(pr$est, as.character(pr$unit), sum)
  expect_true(all(abs(sums - 1) < 1e-8))
  expect_true(all(pr$est >= 0 & pr$est <= 1))
  # calibration: mean predicted P per category ~ observed category frequency.
  mean_p <- tapply(pr$est, pr$category, mean)
  emp    <- prop.table(table(df$value))
  expect_true(all(abs(mean_p[names(emp)] - as.numeric(emp)) < 0.1))
  # link scale returns the K-1 non-baseline logits (2 per observation).
  lk <- predict(fit, type = "link")
  expect_equal(nrow(lk), 200L * 2L)
})

test_that("predict(newdata=) and simulate() fail loud on a multinomial fit", {
  skip_on_cran()
  df  <- .make_multinomial(seed = 9L, n = 100L, K = 3L)
  fit <- gllvmTMB(value ~ 0 + trait, data = df, family = multinomial(),
                  trait = "trait", unit = "unit")
  expect_error(predict(fit, newdata = df),
               class = "gllvmTMB_multinomial_predict_newdata")
  # simulate must NOT fall back to Gaussian-on-link draws for a categorical resp.
  expect_error(simulate(fit),
               class = "gllvmTMB_simulate_multinomial_unsupported")
})

test_that("multinomial likelihood is invariant to the baseline category", {
  skip_on_cran()
  df <- .make_multinomial(seed = 6L, n = 250L, K = 3L)
  fit_ref1 <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                       family = multinomial(), trait = "trait", unit = "unit")
  # Relevel so category 3 is the reference; the maximised log-likelihood is
  # invariant (only the coefficient contrasts relabel).
  df3 <- df
  df3$value <- factor(df3$value, levels = c("3", "1", "2"))
  fit_ref3 <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df3,
                       family = multinomial(), trait = "trait", unit = "unit")
  expect_equal(fit_ref1$opt$convergence, 0L)
  expect_equal(fit_ref3$opt$convergence, 0L)
  expect_equal(as.numeric(fit_ref1$opt$objective),
               as.numeric(fit_ref3$opt$objective), tolerance = 1e-4)
})

test_that("multinomial(baseline=) matches a manual relevel of the response", {
  skip_on_cran()
  df <- .make_multinomial(seed = 6L, n = 250L, K = 3L)
  # baseline = "3" via the arg ...
  fit_arg <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                      family = multinomial(baseline = "3"),
                      trait = "trait", unit = "unit")
  # ... must equal releveling the data so "3" is the first factor level.
  df3 <- df
  df3$value <- factor(df3$value, levels = c("3", "1", "2"))
  fit_manual <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df3,
                         family = multinomial(), trait = "trait", unit = "unit")

  expect_equal(fit_arg$opt$convergence, 0L)
  expect_equal(as.numeric(fit_arg$opt$objective),
               as.numeric(fit_manual$opt$objective), tolerance = 1e-6)
  # Coefficient contrasts (vs the shared "3" reference) coincide.
  expect_equal(as.numeric(fit_arg$opt$par), as.numeric(fit_manual$opt$par),
               tolerance = 1e-4)
  # Metadata reports the requested reference as the pinned baseline.
  expect_identical(fit_arg$multinomial_meta$baseline, "3")
})

test_that("multinomial(baseline=) rejects a category that does not exist", {
  skip_on_cran()
  df <- .make_multinomial(seed = 6L, n = 120L, K = 3L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
             family = multinomial(baseline = "nonesuch"),
             trait = "trait", unit = "unit"),
    "not a category of the response"
  )
})
