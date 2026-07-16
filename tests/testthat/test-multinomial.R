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

test_that("multinomial (K = 3) recovers per-category intercepts and slopes", {
  skip_on_cran()
  df  <- .make_multinomial(seed = 1L, n = 300L, K = 3L)
  fit <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                  family = multinomial(), trait = "trait", unit = "unit")

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(all(fit$tmb_data$family_id_vec == 16L))

  sdf <- summary(fit$sd_report, "fixed")
  est <- sdf[grepl("b_fix", rownames(sdf)), "Estimate"]
  names(est) <- fit$X_fix_names
  # baseline-category contrasts (cats 2, 3 vs reference 1).
  truth <- c("traitmorph:2" = 0.5, "traitmorph:3" = -0.4,
             "traitmorph:2:x" = 1.0, "traitmorph:3:x" = -0.8)
  expect_setequal(names(est), names(truth))
  for (nm in names(truth)) {
    expect_lt(abs(est[[nm]] - truth[[nm]]), 0.4)   # ordinal fixed-effect band
  }
})

test_that("multinomial (K = 4) recovers per-category intercepts and slopes", {
  skip_on_cran()
  b0 <- c(0.4, -0.3, 0.2); b1 <- c(0.9, -0.7, 0.6)
  df  <- .make_multinomial(seed = 11L, n = 600L, K = 4L, b0 = b0, b1 = b1)
  fit <- gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
                  family = multinomial(), trait = "trait", unit = "unit")
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
  expect_true(all(fit$tmb_data$family_id_vec == 16L))
  sdf <- summary(fit$sd_report, "fixed")
  est <- sdf[grepl("b_fix", rownames(sdf)), "Estimate"]
  # 3 intercepts then 3 slopes, in X_fix column order.
  truth <- c(b0, b1)
  names(est) <- fit$X_fix_names
  expect_length(est, 6L)
  for (i in seq_along(truth)) {
    expect_lt(abs(est[[i]] - truth[[i]]), 0.4)
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
