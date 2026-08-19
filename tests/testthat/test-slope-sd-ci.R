## Tests for slope_sd_ci() -- Slice 1 (diagonal route) only.
##
## Scope: `theta_diag_B_slope`, the ordinary augmented random-slope
## diagonal (Psi) companion. See R/slope-sd-ci.R for the full scope
## statement and dev/fable-extractor-recommendation.md /
## dev/slope-interval-feasibility-RESULTS.md for the design this
## implements.

## ---- Helper: the verified Route B fixture (feasibility probe) -----
## Identical to make_ordinary_latent_rr_fixture() in
## test-ordinary-latent-random-regression.R, but with explicit
## idiosyncratic Psi noise added on top of the loadings term so the
## diagonal companion sits away from the zero boundary (matches
## dev/slope-interval-feasibility-RESULTS.md's "Route B").

make_slope_ci_fixture <- function(
  seed = 9101L, n_ind = 50L, n_traits = 3L, n_rep = 6L
) {
  set.seed(seed)
  trait_levels <- paste0("t", seq_len(n_traits))
  individuals <- paste0("id", seq_len(n_ind))
  df <- expand.grid(
    individual = factor(individuals, levels = individuals),
    rep = seq_len(n_rep),
    trait = factor(trait_levels, levels = trait_levels),
    KEEP.OUT.ATTRS = FALSE
  )
  df$session_id <- factor(paste(df$individual, df$rep, sep = "_"))
  sessions <- unique(df[c("individual", "rep", "session_id")])
  sessions$temperature <- stats::rnorm(nrow(sessions))
  df <- merge(
    df, sessions,
    by = c("individual", "rep", "session_id"), sort = FALSE
  )

  alpha <- c(0.2, -0.1, 0.05)[seq_len(n_traits)]
  beta <- c(0.3, -0.2, 0.1)[seq_len(n_traits)]
  Lambda_aug <- matrix(
    c(
      0.45, 0.00, 0.18, 0.25, -0.30, 0.00,
      0.10, -0.18, 0.35, 0.00, -0.08, 0.20
    )[seq_len(2L * n_traits * 2L)],
    nrow = 2L * n_traits, ncol = 2L, byrow = TRUE
  )
  z <- matrix(stats::rnorm(2L * n_ind), nrow = 2L)
  psi_sd <- rep(0.2, 2L * n_traits)
  psi_noise <- matrix(
    stats::rnorm(2L * n_traits * n_ind, sd = psi_sd),
    nrow = 2L * n_traits, ncol = n_ind
  )
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    tt <- as.integer(df$trait[o])
    ii <- as.integer(df$individual[o])
    base <- 2L * (tt - 1L)
    coeff <- Lambda_aug %*% z[, ii] + psi_noise[, ii]
    eta[o] <- alpha[tt] +
      beta[tt] * df$temperature[o] +
      coeff[base + 1L] +
      coeff[base + 2L] * df$temperature[o]
  }
  df$value <- eta + stats::rnorm(nrow(df), sd = 0.35)
  list(data = df, n_traits = n_traits)
}

## ---- Helper: deterministic mock fit for the kill-switch guards -----
## Bypasses TMB entirely so each guard is tested against an exact,
## hand-built `sd_report`/`opt$par` -- the house pattern used by
## test-loading-ci.R's mock_loading_delta_fit().

## `slope_theta` / `slope_se` are the SLOPE-coordinate values a caller
## wants `ci$theta` / `ci$se_theta` to come back as -- one entry per
## trait. Internally these are interleaved with a healthy, unrelated
## intercept entry at the odd positions, matching the real
## `theta_diag_B_slope` packing (intercept, slope) per trait
## (`R/fit-multi.R` ~4116-4121: `base = 2 * trait_id`), so the guard
## tests exercise the SAME extraction path `slope_sd_ci()` uses on a
## real fit, not a hand-simplified stand-in.
mock_slope_ci_fit <- function(slope_theta, slope_se, pdHess = TRUE,
                               n_traits = length(slope_theta),
                               rr_present = FALSE,
                               phylo_dep_slope = FALSE,
                               rr_shared_var_slope = NULL) {
  stopifnot(length(slope_theta) == n_traits, length(slope_se) == n_traits)
  trait_names <- paste0("t", seq_len(n_traits))
  theta_full <- se_full <- numeric(2L * n_traits)
  for (t in seq_len(n_traits)) {
    theta_full[2L * t - 1L] <- -1.5   # intercept coordinate (unused by the guards)
    se_full[2L * t - 1L]    <- 0.3
    theta_full[2L * t]      <- slope_theta[t]
    se_full[2L * t]         <- slope_se[t]
  }
  par_names <- rep("theta_diag_B_slope", 2L * n_traits)
  cov_fixed <- diag(se_full^2, nrow = length(se_full))
  report <- NULL
  if (!is.null(rr_shared_var_slope)) {
    stopifnot(length(rr_shared_var_slope) == n_traits)
    diag_full <- numeric(2L * n_traits)
    diag_full[seq(2L, 2L * n_traits, by = 2L)] <- rr_shared_var_slope
    report <- list(Sigma_B_slope = diag(diag_full, nrow = 2L * n_traits))
  }
  structure(
    list(
      use = list(
        diag_B_slope = TRUE,
        diag_B_slope_col = "x",
        rr_B_slope = rr_present,
        phylo_dep_slope = phylo_dep_slope
      ),
      data = data.frame(trait = factor(trait_names, levels = trait_names)),
      trait_col = "trait",
      opt = list(par = stats::setNames(theta_full, par_names)),
      report = report,
      sd_report = structure(
        list(cov.fixed = cov_fixed, pdHess = pdHess),
        class = "sdreport"
      )
    ),
    class = "gllvmTMB_multi"
  )
}

## ---- (a) Happy path: recovers a known-truth slope SD -----------------

test_that("slope_sd_ci() recovers a known-truth slope SD with a finite interval", {
  testthat::skip_on_cran()
  fx <- make_slope_ci_fixture()

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 2),
    data = fx$data,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS")
    )
  )))
  expect_true(isTRUE(fit$sd_report$pdHess))

  ## This fixture has BOTH theta_diag_B_slope and theta_rr_B_slope (the
  ## default `latent()` combination), so the call itself warns.
  expect_true(isTRUE(fit$use$rr_B_slope))
  expect_warning(
    ci <- slope_sd_ci(fit),
    "shared random-slope loadings component"
  )
  expect_s3_class(ci, "gllvmTMB_slope_ci")
  expect_identical(nrow(ci), fx$n_traits)
  expect_identical(as.character(ci$trait), paste0("t", seq_len(fx$n_traits)))
  expect_true(all(ci$term == "temperature"))
  expect_true(all(ci$status == "ok"))
  expect_true(all(is.finite(ci$lower)) && all(is.finite(ci$upper)))
  expect_true(all(ci$lower < ci$estimate & ci$estimate < ci$upper))
  expect_identical(ci$interval_status, rep("wald_uncalibrated", fx$n_traits))
  expect_identical(ci$method, rep("wald_log_scale", fx$n_traits))
  expect_identical(attr(ci, "calibrated"), FALSE)

  ## True psi_sd = 0.2 on every augmented coordinate (construction); a
  ## single-seed point estimate should land in the same order of
  ## magnitude and, on this verified fixture, inside the reported CI.
  expect_true(all(ci$estimate > 0.05 & ci$estimate < 0.5))
  expect_true(all(ci$lower <= 0.2 & 0.2 <= ci$upper))

  ## `component`/`total_sd`: the returned `estimate` is only the unique
  ## (Psi) piece on this fixture (a rank-2 latent() term also carries a
  ## shared loadings block), so `total_sd` -- read from the already-
  ## REPORT()ed fit$report$Sigma_B_slope -- must be strictly larger.
  expect_true(all(ci$component == "unique_psi"))
  expect_true(all(is.finite(ci$total_sd)))
  expect_true(all(ci$total_sd > ci$estimate))
  ## Independently cross-checked total marginal slope SD on this exact
  ## fixture/seed (adversarial review pass, computed directly from
  ## fit$report$Sigma_B_slope without going through slope_sd_ci()).
  expect_equal(ci$total_sd, c(0.3878717, 0.2924811, 0.3294379), tolerance = 1e-5)

  ## scale = "variance" is consistent with scale = "sd" (same fit);
  ## total_sd stays on the SD scale regardless of `scale`.
  ci_var <- suppressWarnings(slope_sd_ci(fit, scale = "variance"))
  expect_equal(ci_var$estimate, ci$estimate^2, tolerance = 1e-10)
  expect_equal(ci_var$theta, ci$theta, tolerance = 1e-10)
  expect_equal(ci_var$se_theta, ci$se_theta, tolerance = 1e-10)
  expect_equal(ci_var$lower, ci$lower^2, tolerance = 1e-10)
  expect_equal(ci_var$upper, ci$upper^2, tolerance = 1e-10)
  expect_equal(ci_var$total_sd, ci$total_sd, tolerance = 1e-10)

  ## print() surfaces the fence and the rr_B_slope caveat, and the caveat
  ## is now backed by in-band `component`/`total_sd` columns that survive
  ## `$estimate`, `subset()`, and column selection -- unlike a print-only
  ## caveat, which does not.
  out <- capture.output(print(ci))
  expect_true(any(grepl("wald_uncalibrated|Wald", out)))
  expect_true(any(grepl("UNIQUE", out)))
  est_only <- ci$estimate
  expect_true(is.numeric(est_only) && !inherits(est_only, "gllvmTMB_slope_ci"))
  sub <- subset(ci, status == "ok")
  expect_true(all(c("component", "total_sd") %in% names(sub)))
  expect_true(all(sub$component == "unique_psi"))
})

## ---- (b) Kill-switch guards: each must FAIL before it exists ---------
## For each guard we first show a "wrong" computation (naive exp()/delta
## method with no gate) WOULD produce a plausible-looking numeric
## interval from the degenerate input, then show slope_sd_ci() itself
## suppresses it via the guard.

test_that("slope_sd_ci() guard: non-PD Hessian -> NA interval + warning (guard proven to fire)", {
  fit <- mock_slope_ci_fit(
    slope_theta = c(-1.6, -1.55),
    slope_se    = c(0.32, 0.31),
    pdHess = FALSE
  )

  ## Without the pdHess gate, a naive delta-method CI from this exact
  ## se_theta would be perfectly finite -- proving the guard, not a
  ## vacuous fixture.
  slope_ix <- which(names(fit$opt$par) == "theta_diag_B_slope")[c(2L, 4L)]
  naive_lower <- exp(fit$opt$par[slope_ix] - 1.96 * c(0.32, 0.31))
  expect_true(all(is.finite(naive_lower)))

  expect_warning(
    ci <- slope_sd_ci(fit),
    "not positive-definite"
  )
  expect_true(all(ci$status == "no_pd_hessian"))
  expect_true(all(is.na(ci$lower)))
  expect_true(all(is.na(ci$upper)))
  ## Point estimates remain available (house line: non-PD Hessian
  ## disqualifies SEs, not point estimates).
  expect_true(all(is.finite(ci$estimate)))
  expect_true(all(is.finite(ci$theta)))
})

test_that("slope_sd_ci() guard: non-finite se_theta -> NA interval + warning (guard proven to fire)", {
  fit <- mock_slope_ci_fit(
    slope_theta = c(-1.6, -1.55),
    slope_se    = c(NaN, 0.31),
    pdHess = TRUE
  )

  ## Without the finiteness gate, exp(theta +/- z*NaN) is NaN -- not a
  ## "plausible-looking" number, but confirming the raw computation
  ## really does propagate the NaN rather than silently resolving it.
  naive <- exp(-1.6 - 1.96 * NaN)
  expect_true(is.nan(naive))

  expect_warning(
    ci <- slope_sd_ci(fit),
    "non-finite"
  )
  expect_identical(ci$status, c("se_nonfinite", "ok"))
  expect_true(is.na(ci$lower[1]) && is.na(ci$upper[1]))
  expect_false(is.na(ci$lower[2]) || is.na(ci$upper[2]))
  ## Point estimate for the affected row is still returned.
  expect_true(is.finite(ci$estimate[1]))
})

test_that("slope_sd_ci() guard: se_theta = Inf -> NA interval, not a finite zero (guard proven to fire)", {
  ## Unlike NaN, se_theta = Inf makes the NAIVE lower bound a FINITE,
  ## publishable-looking zero -- exactly the "plausible garbage" failure
  ## mode, distinct from the NaN case above where the naive number is
  ## itself NaN and so obviously unusable.
  naive_lower <- exp(-1.6 - 1.96 * Inf)
  expect_identical(naive_lower, 0)

  fit <- mock_slope_ci_fit(
    slope_theta = c(-1.6, -1.55),
    slope_se    = c(Inf, 0.31),
    pdHess = TRUE
  )
  expect_warning(
    ci <- slope_sd_ci(fit),
    "non-finite"
  )
  expect_identical(ci$status, c("se_nonfinite", "ok"))
  expect_true(is.na(ci$lower[1]) && is.na(ci$upper[1]))
  expect_true(is.finite(ci$estimate[1]))
})

test_that("slope_sd_ci() guard: se_theta > 10 (se_blowup) -> NA interval + warning (guard proven to fire)", {
  ## Values in the ballpark of the observed degenerate fit
  ## (theta = -13.548, se = 61883.69) cited in the task brief.
  fit <- mock_slope_ci_fit(
    slope_theta = c(-13.548, -1.55),
    slope_se    = c(61883.69, 0.31),
    pdHess = TRUE
  )

  ## Without the guard, this is exactly the "plausible-looking garbage"
  ## failure mode: a FINITE numeric interval that spans an astronomically
  ## wide range and carries no information.
  z <- stats::qnorm(0.975)
  naive_lower <- exp(-13.548 - z * 61883.69)
  naive_upper <- exp(-13.548 + z * 61883.69)
  expect_true(is.finite(naive_lower) || naive_lower == 0)
  expect_true(is.infinite(naive_upper) || naive_upper > 1e6)

  expect_warning(
    ci <- slope_sd_ci(fit),
    "exceeds 10"
  )
  expect_identical(ci$status, c("se_blowup", "ok"))
  expect_true(is.na(ci$lower[1]) && is.na(ci$upper[1]))
  expect_false(is.na(ci$lower[2]) || is.na(ci$upper[2]))
  expect_true(is.finite(ci$estimate[1]))
})

test_that("slope_sd_ci() guard: near-zero SD relative to siblings -> NA interval + warning (guard proven to fire, se_blowup does NOT catch this)", {
  ## A genuinely collapsed slope SD, but with a perfectly ordinary,
  ## well-identified SE -- se_theta > 10 does NOT fire here, so this is
  ## an INDEPENDENT failure mode from the se_blowup guard above. Without
  ## a relative-to-siblings check this would return a clean, tight,
  ## "ok"-looking interval around a number that is, in truth, zero.
  fit <- mock_slope_ci_fit(
    slope_theta = c(-20, -1.55, -1.4),
    slope_se    = c(0.5, 0.31, 0.28),
    pdHess = TRUE
  )

  naive_status_would_be_ok <- 0.5 <= 10   # the se_blowup threshold alone
  expect_true(naive_status_would_be_ok)
  naive_interval <- exp(c(-20 - 1.96 * 0.5, -20 + 1.96 * 0.5))
  expect_true(all(is.finite(naive_interval)))

  expect_warning(
    ci <- slope_sd_ci(fit),
    "1% of this fit's largest"
  )
  expect_identical(ci$status, c("near_zero_relative", "ok", "ok"))
  expect_true(is.na(ci$lower[1]) && is.na(ci$upper[1]))
  expect_false(is.na(ci$lower[2]) || is.na(ci$upper[2]))
  expect_true(is.finite(ci$estimate[1]))

  ## A single-trait fit has no siblings to compare against -- the check
  ## does not (cannot) fire, and se_blowup alone still governs status.
  fit1 <- mock_slope_ci_fit(slope_theta = -20, slope_se = 0.5)
  ci1 <- slope_sd_ci(fit1)
  expect_identical(ci1$status, "ok")
})

## ---- (c) Slice 2: previously-deferred routes now RETURN intervals ----
## via ADREPORT()ed quantities read off sdreport() (src/gllvmTMB.cpp:
## `sd_b` in the theta_dep_chol branch, `sd_rr_B_slope`,
## `sd_B_slope_total`). See R/slope-sd-ci.R's module header and
## dev/S6-slope-sd-ci-review.md for why a hand-indexed R-side Jacobian
## was rejected in favour of this route.

## ---- Mock builders for the two ADREPORT-based routes. TMB's own
## `summary.sdreport(object, "report")` only reads `object$value` /
## `object$sd` (both named/ordered by the ADREPORT variable name), so a
## hand-built `sd_report` with those two fields plus `pdHess` dispatches
## through the REAL `TMB:::summary.sdreport` method -- these mocks
## exercise the same code path a real fit does, not a hand-simplified
## stand-in.

mock_phylo_dep_slope_fit <- function(slope_est, slope_se, pdHess = TRUE,
                                      n_traits = length(slope_est),
                                      slope_cols = "x") {
  stopifnot(length(slope_est) == n_traits, length(slope_se) == n_traits)
  trait_names <- paste0("t", seq_len(n_traits))
  stride <- 2L # s = 1 (single slope)
  C <- stride * n_traits
  est_full <- se_full <- numeric(C)
  for (t in seq_len(n_traits)) {
    est_full[stride * (t - 1L) + 1L] <- 0.4 # intercept coordinate (unused)
    se_full[stride * (t - 1L) + 1L]  <- 0.1
    est_full[stride * (t - 1L) + 2L] <- slope_est[t]
    se_full[stride * (t - 1L) + 2L]  <- slope_se[t]
  }
  structure(
    list(
      use = list(
        diag_B_slope = FALSE,
        rr_B_slope = FALSE,
        phylo_dep_slope = TRUE,
        phylo_dep_slope_cols = slope_cols
      ),
      data = data.frame(trait = factor(trait_names, levels = trait_names)),
      trait_col = "trait",
      opt = list(par = numeric(0)),
      report = list(sd_b = est_full),
      sd_report = structure(
        list(
          pdHess = pdHess,
          value = stats::setNames(est_full, rep("sd_b", C)),
          sd = se_full
        ),
        class = "sdreport"
      )
    ),
    class = "gllvmTMB_multi"
  )
}

mock_rr_only_slope_fit <- function(slope_est, slope_se, pdHess = TRUE,
                                    n_traits = length(slope_est),
                                    slope_col = "x") {
  stopifnot(length(slope_est) == n_traits, length(slope_se) == n_traits)
  trait_names <- paste0("t", seq_len(n_traits))
  n_lhs <- 2L * n_traits
  est_full <- se_full <- numeric(n_lhs)
  for (t in seq_len(n_traits)) {
    est_full[2L * t - 1L] <- 0.4
    se_full[2L * t - 1L]  <- 0.1
    est_full[2L * t]      <- slope_est[t]
    se_full[2L * t]       <- slope_se[t]
  }
  structure(
    list(
      use = list(
        diag_B_slope = FALSE,
        rr_B_slope = TRUE,
        rr_B_slope_col = slope_col,
        phylo_dep_slope = FALSE
      ),
      data = data.frame(trait = factor(trait_names, levels = trait_names)),
      trait_col = "trait",
      opt = list(par = numeric(0)),
      report = list(sd_rr_B_slope = est_full),
      sd_report = structure(
        list(
          pdHess = pdHess,
          value = stats::setNames(est_full, rep("sd_rr_B_slope", n_lhs)),
          sd = se_full
        ),
        class = "sdreport"
      )
    ),
    class = "gllvmTMB_multi"
  )
}

## ---- (c.1) Phylogenetic Cholesky route: guards (mock-based) ----------

test_that("slope_sd_ci() phylo_dep route: non-PD Hessian -> NA interval", {
  fit <- mock_phylo_dep_slope_fit(c(0.25, 0.30), c(0.06, 0.07), pdHess = FALSE)
  expect_warning(ci <- slope_sd_ci(fit), "not positive-definite")
  expect_true(all(ci$status == "no_pd_hessian"))
  expect_true(all(is.na(ci$lower)) && all(is.na(ci$upper)))
  expect_true(all(is.finite(ci$estimate)))
  expect_identical(ci$method, rep("wald_log_scale_adreport", 2L))
})

test_that("slope_sd_ci() phylo_dep route: non-finite se -> NA interval", {
  fit <- mock_phylo_dep_slope_fit(c(0.25, 0.30), c(NaN, 0.07))
  expect_warning(ci <- slope_sd_ci(fit), "non-finite")
  expect_identical(ci$status, c("se_nonfinite", "ok"))
  expect_true(is.na(ci$lower[1]) && is.na(ci$upper[1]))
  expect_false(is.na(ci$lower[2]) || is.na(ci$upper[2]))
})

test_that("slope_sd_ci() phylo_dep route: se_blowup -> NA interval", {
  fit <- mock_phylo_dep_slope_fit(c(1.5e-6, 0.30), c(9200, 0.07))
  expect_warning(ci <- slope_sd_ci(fit), "exceeds 10")
  expect_identical(ci$status, c("se_blowup", "ok"))
  expect_true(is.na(ci$lower[1]) && is.na(ci$upper[1]))
})

test_that("slope_sd_ci() phylo_dep route: near-zero-relative collapse -> NA interval", {
  fit <- mock_phylo_dep_slope_fit(
    c(1e-9, 0.30, 0.28), c(4e-10, 0.07, 0.06)
  )
  expect_warning(ci <- slope_sd_ci(fit), "1% of this fit's largest")
  expect_identical(ci$status, c("near_zero_relative", "ok", "ok"))
})

## ---- (c.2) Phylogenetic Cholesky route: real recovery + ADREPORT
## cross-check. Heavy-gated (GLLVMTMB_HEAVY_TESTS=1) following the house
## convention for every other phylo_dep model fit in this package
## (test-phylo-dep-slope-gaussian.R).

test_that("slope_sd_ci() phylo_dep route recovers a known-truth slope SD, and its ADREPORT matches an independently constructed sqrt(diag(Sigma_b_dep))", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")

  set.seed(778L)
  n_sp <- 70L
  T_tr <- 2L
  n_rep <- 6L
  C <- 2L * T_tr
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  ## Same L as test-phylo-dep-slope-gaussian.R's .dep_Ltrue(): slope SDs
  ## (diagonal entries at positions 2 and 4) are sqrt(0.2^2 + 0.6^2) and
  ## 0.45 respectively -- i.e. genuinely off-diagonal-dependent for trait 1.
  L <- matrix(0, C, C)
  L[lower.tri(L, diag = TRUE)] <- c(
    0.8, 0.2, -0.1, 0.15,
    0.6, 0.1, -0.05,
    0.5, 0.1,
    0.45
  )
  Sigma_b_true <- L %*% t(L)
  slope_sd_true <- sqrt(diag(Sigma_b_true))[c(2L, 4L)]

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
    sr, data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df_long <- df_long[order(df_long$species, df_long$rep, df_long$trait), ]
  ti <- as.integer(df_long$trait)
  si <- match(as.character(df_long$species), tree$tip.label)
  mu_t <- seq(1, by = -0.5, length.out = T_tr)[ti]
  alpha <- B[cbind(si, 2L * (ti - 1L) + 1L)]
  beta <- B[cbind(si, 2L * (ti - 1L) + 2L)]
  df_long$value <- mu_t + alpha + beta * df_long$x +
    stats::rnorm(nrow(df_long), sd = 0.3)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait + (0 + trait):x | species),
    data = df_long, phylo_tree = tree, unit = "species",
    control = gllvmTMBcontrol(se = TRUE)
  )))
  expect_true(isTRUE(fit$use$phylo_dep_slope))
  expect_true(isTRUE(fit$sd_report$pdHess))

  ci <- slope_sd_ci(fit)
  expect_s3_class(ci, "gllvmTMB_slope_ci")
  expect_identical(nrow(ci), T_tr)
  expect_true(all(ci$status == "ok"))
  expect_identical(ci$method, rep("wald_log_scale_adreport", T_tr))
  expect_true(all(ci$component == "total"))
  expect_equal(ci$total_sd, ci$estimate)
  expect_equal(ci$total_lower, ci$lower)
  expect_equal(ci$total_upper, ci$upper)

  ## Recovery: the true slope SDs fall inside the reported CIs.
  expect_true(all(ci$lower <= slope_sd_true & slope_sd_true <= ci$upper))

  ## THE cross-check the review demanded: the ADREPORTed sd_b, as read by
  ## slope_sd_ci(), must equal an INDEPENDENTLY constructed
  ## sqrt(diag(Sigma_b_dep)) computed directly from fit$report -- exactly
  ## the test shape that would have caught the 2/5/8-vs-2/4/6 packing bug.
  Sigma_b_dep_hat <- as.matrix(fit$report$Sigma_b_dep)
  independent_sd_b <- sqrt(diag(Sigma_b_dep_hat))
  slope_positions <- seq(2L, C, by = 2L)
  expect_equal(ci$estimate, independent_sd_b[slope_positions], tolerance = 1e-6)
})

## ---- (c.3) Loadings-only route: guards (mock-based) -------------------

test_that("slope_sd_ci() loadings-only route: non-PD Hessian -> NA interval", {
  fit <- mock_rr_only_slope_fit(c(0.25, 0.30), c(0.06, 0.07), pdHess = FALSE)
  expect_warning(ci <- slope_sd_ci(fit), "not positive-definite")
  expect_true(all(ci$status == "no_pd_hessian"))
  expect_true(all(is.na(ci$lower)) && all(is.na(ci$upper)))
  expect_identical(ci$component, rep("total", 2L))
})

test_that("slope_sd_ci() loadings-only route: non-finite se -> NA interval", {
  fit <- mock_rr_only_slope_fit(c(0.25, 0.30), c(NaN, 0.07))
  expect_warning(ci <- slope_sd_ci(fit), "non-finite")
  expect_identical(ci$status, c("se_nonfinite", "ok"))
})

test_that("slope_sd_ci() loadings-only route: se_blowup -> NA interval", {
  fit <- mock_rr_only_slope_fit(c(1.5e-6, 0.30), c(9200, 0.07))
  expect_warning(ci <- slope_sd_ci(fit), "exceeds 10")
  expect_identical(ci$status, c("se_blowup", "ok"))
})

test_that("slope_sd_ci() loadings-only route: near-zero-relative collapse -> NA interval", {
  fit <- mock_rr_only_slope_fit(c(1e-9, 0.30, 0.28), c(4e-10, 0.07, 0.06))
  expect_warning(ci <- slope_sd_ci(fit), "1% of this fit's largest")
  expect_identical(ci$status, c("near_zero_relative", "ok", "ok"))
})

## ---- (c.4) Loadings-only route: real recovery + ADREPORT cross-check.
## NOT heavy (a plain Gaussian latent() fit, matching the fixture already
## used for the diagonal route's recovery test above) -- runs in the
## default suite.

test_that("slope_sd_ci() loadings-only route recovers a known-truth slope SD, and its ADREPORT matches an independently constructed sqrt(diag(Sigma_B_slope))", {
  testthat::skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  fx <- make_slope_ci_fixture(seed = 9101L, n_ind = 60L, n_traits = 3L, n_rep = 6L)

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 +
      trait +
      (0 + trait):temperature +
      latent(0 + trait + (0 + trait):temperature | individual, d = 2, unique = FALSE),
    data = fx$data,
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    control = gllvmTMBcontrol(
      se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS")
    )
  )))
  expect_true(isTRUE(fit$use$rr_B_slope))
  expect_false(isTRUE(fit$use$diag_B_slope))
  expect_true(isTRUE(fit$sd_report$pdHess))

  ci <- slope_sd_ci(fit)
  expect_s3_class(ci, "gllvmTMB_slope_ci")
  expect_identical(nrow(ci), fx$n_traits)
  expect_true(all(ci$status == "ok"))
  expect_identical(ci$method, rep("wald_log_scale_adreport", fx$n_traits))
  expect_true(all(ci$component == "total"))
  expect_equal(ci$total_sd, ci$estimate)

  ## Cross-check: ADREPORTed sd_rr_B_slope (as read by slope_sd_ci()) must
  ## equal an INDEPENDENTLY constructed sqrt(diag(Sigma_B_slope)) from
  ## fit$report -- the same test shape as the phylo route above.
  Sigma_B_slope_hat <- as.matrix(fit$report$Sigma_B_slope)
  independent_sd <- sqrt(diag(Sigma_B_slope_hat))
  n_lhs <- 2L * fx$n_traits
  slope_positions <- seq(2L, n_lhs, by = 2L)
  expect_equal(ci$estimate, independent_sd[slope_positions], tolerance = 1e-6)

  ## The fixture's shared-loadings-only DGP (Route B's Lambda_aug block,
  ## no idiosyncratic Psi noise on this path) puts the recovered slope SD
  ## in a similar order of magnitude to the diagonal-route fixture.
  expect_true(all(ci$estimate > 0.01 & ci$estimate < 1))
})

test_that("slope_sd_ci() refuses a fit with no augmented random-slope term at all", {
  fit <- mock_slope_ci_fit(
    slope_theta = c(-1.6, -1.55),
    slope_se    = c(0.32, 0.31)
  )
  fit$use$diag_B_slope <- FALSE
  fit$use$rr_B_slope <- FALSE

  expect_error(slope_sd_ci(fit), "no augmented random-slope structure")
})

## ---- (d) Argument validation ------------------------------------------

test_that("slope_sd_ci() validates fit class and level", {
  expect_error(slope_sd_ci(1L), "must be a multi-trait")

  fit <- mock_slope_ci_fit(
    slope_theta = -1.6,
    slope_se    = 0.32
  )
  expect_error(slope_sd_ci(fit, level = 1.5), "single number in \\(0, 1\\)")
  expect_error(slope_sd_ci(fit, level = c(0.9, 0.95)), "single number in \\(0, 1\\)")
})
