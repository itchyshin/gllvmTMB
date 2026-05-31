# Robustness / edge-case hardening for the SHIPPED missing-data layer
# (Phase 1 response mask + Phase 2a/2b/2c mi() missing predictor). This file
# is ADDITIVE: it covers degenerate / stress / invariance cases the existing
# test-missing-predictor-gaussian.R does NOT, and never edits that file.
#
# Every model-fitting block is gated behind skip_if_not_heavy() (setup.R).
# Pure-validation boundary blocks (they error before any TMB fit) run
# unconditionally. Each assertion is a concrete property -- convergence,
# finiteness, invariance, recovery, or a specific error for an unsupported
# edge -- never a trivially-true check or a widened tolerance.
#
# Fixtures are SELF-CONTAINED (testthat does not share top-level helpers across
# files; only setup.R / helper-*.R are shared), deliberately mirroring the
# .make_mi_uni / .make_mi_grouped / .make_mi_group shapes of the shipped tests
# so the edge cases sit on the same DGP family.

# ---- Self-contained fixtures ----------------------------------------------

# Unit-level (Phase 2a/2b) two-trait Gaussian fixture: x is unit-level
# (constant within a site), shared mi() slope b_x across both traits.
.rob_make_unit <- function(seed = 202, n_sites = 40, b_x = 1.3) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  x <- 0.25 + 0.8 * z - 0.4 * w + stats::rnorm(n_sites, sd = 0.5)
  rows <- vector("list", n_sites)
  for (s in seq_len(n_sites)) {
    eta1 <- 0.7 + b_x * x[s] - 0.3 * z[s]
    eta2 <- -0.2 + b_x * x[s] + 0.5 * z[s]
    rows[[s]] <- data.frame(
      site = s, trait = c("t1", "t2"),
      value = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
      x = x[s], z = z[s], w = w[s], stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  list(data = dat, x = x, b_x = b_x, n_sites = n_sites)
}

# Set x to NA for every long row of the given sites.
.rob_inject_unit <- function(d, miss_sites) {
  dat <- d$data
  dat$x[as.integer(dat$site) %in% miss_sites] <- NA_real_
  dat
}

.rob_fit_unit <- function(data, impute = list(x = x ~ z + w),
                          missing = miss_control(predictor = "model"),
                          se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = data, family = gaussian(),
    impute = impute, missing = missing,
    control = gllvmTMBcontrol(se = se)
  )))
}

# Group-level (Phase 2c) fixture: x is REGION-level (one value per region,
# n_per_region sites per region; region is coarser than site).
.rob_make_group <- function(seed = 404, n_region = 30L, n_per_region = 3L,
                            b_x = 1.2, sigma_x = 0.45) {
  set.seed(seed)
  zr <- stats::rnorm(n_region)
  wr <- stats::rnorm(n_region)
  xr <- 0.3 + 0.7 * zr - 0.4 * wr + stats::rnorm(n_region, sd = sigma_x)
  rows <- list()
  sc <- 0L
  for (r in seq_len(n_region)) {
    for (k in seq_len(n_per_region)) {
      sc <- sc + 1L
      eta1 <- 0.6 + b_x * xr[r] - 0.25 * zr[r]
      eta2 <- -0.3 + b_x * xr[r] + 0.45 * zr[r]
      rows[[sc]] <- data.frame(
        site = sc, region = r, trait = c("t1", "t2"),
        value = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
        x = xr[r], z = zr[r], w = wr[r], stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(sc))
  dat$region <- factor(dat$region, levels = seq_len(n_region))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  list(data = dat, xr = xr, n_region = n_region, b_x = b_x, sigma_x = sigma_x)
}

.rob_inject_group <- function(d, miss_region) {
  dat <- d$data
  dat$x[as.integer(dat$region) %in% miss_region] <- NA_real_
  dat
}

.rob_fit_group <- function(data,
                           impute = list(x = x ~ z + w + mi_group(region)),
                           missing = miss_control(predictor = "model"),
                           se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = data, family = gaussian(),
    impute = impute, missing = missing,
    control = gllvmTMBcontrol(se = se)
  )))
}

# ===========================================================================
# Degenerate covariate-model coverage (no fit -- error before TMB)
# ===========================================================================

test_that("all-x-missing mi() errors: no observed value to fit the predictor model", {
  # With EVERY x missing there is no observed predictor value to estimate the
  # covariate model from. The engine must reject this loudly (not divide by an
  # empty observed set / fit an unidentified mean).
  d <- .rob_make_unit()
  dat <- .rob_inject_unit(d, miss_sites = seq_len(d$n_sites))   # all missing
  expect_error(
    .rob_fit_unit(dat),
    "[Aa]t least one observed"
  )
})

test_that("only-one-observed-x mi() errors: weakly identified covariate model", {
  # One observed unit value cannot identify a 3-coefficient covariate model
  # (intercept + z + w). The guard sum(observed) <= ncol(X_x) must fire rather
  # than silently returning a rank-deficient OLS start.
  d <- .rob_make_unit()
  dat <- .rob_inject_unit(d, miss_sites = setdiff(seq_len(d$n_sites), 5L))
  expect_error(
    .rob_fit_unit(dat, impute = list(x = x ~ z + w)),
    "weakly identified"
  )
})

test_that("intercept-only impute(x ~ 1) converges and recovers the observed-x mean", {
  skip_if_not_heavy()
  # The minimal covariate model: x ~ 1. It must converge, carry exactly ONE
  # covariate coefficient (the predictor mean), and that intercept must recover
  # the mean of the observed x. A unit-level intercept-only model needs >1
  # observed value (sum(observed) > ncol = 1), satisfied by the 36 observed.
  miss_sites <- c(4L, 12L, 23L, 31L)
  d <- .rob_make_unit()
  dat <- .rob_inject_unit(d, miss_sites = miss_sites)
  x_obs_mean <- mean(d$x[-miss_sites])

  fit <- .rob_fit_unit(dat, impute = list(x = x ~ 1))

  expect_identical(fit$missing_data$predictors$x$version, "phase2a")
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_length(par$beta_mi, 1L)                 # intercept only
  expect_true(is.finite(par$beta_mi[[1]]))
  # The intercept IS the predictor mean -- recover the observed-x mean tightly.
  expect_equal(unname(par$beta_mi[[1]]), x_obs_mean, tolerance = 0.1)
  # One latent per missing unit, all finite.
  expect_length(par$x_mis, length(miss_sites))
  expect_true(all(is.finite(fit$missing_data$predictors$x$conditional_mode)))
})

# ===========================================================================
# High missingness (stress: convergence + finiteness, NOT recovery)
# ===========================================================================

test_that("high missingness (~65% of x missing) still converges with finite estimates", {
  skip_if_not_heavy()
  # 65% MCAR missing x: the latent block dominates the design. Assert the fit
  # reaches a stationary point and every estimate / conditional mode is finite.
  # This is a numerical-stability stress, so recovery is NOT asserted.
  n_sites <- 120L
  set.seed(99)
  miss_sites <- sort(sample.int(n_sites, round(0.65 * n_sites)))
  d <- .rob_make_unit(seed = 7, n_sites = n_sites)
  dat <- .rob_inject_unit(d, miss_sites = miss_sites)

  fit <- .rob_fit_unit(dat)

  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_length(par$x_mis, length(miss_sites))
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 5e-2)
  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))
  expect_true(is.finite(par$log_sigma_mi[[1]]))
  modes <- fit$missing_data$predictors$x$conditional_mode
  expect_length(modes, length(miss_sites))
  expect_true(all(is.finite(modes)))
})

# ===========================================================================
# Sentinel-invariance for the mi() placeholder (THE leak detector)
# ===========================================================================

test_that("mi() placeholder value (mi_x_unit at missing) does not change logLik/gradient", {
  skip_if_not_heavy()
  # The missing-x design placeholder mi_x_unit[missing] is a pure SENTINEL: the
  # engine overrides it with the latent x_mis before BOTH the covariate density
  # and the delta-correction (src/gllvmTMB.cpp: mi_x_full(missing) = x_mis).
  # Re-evaluate the SAME fitted parameter vector with that sentinel forced to
  # two wildly different values (0 vs 1e6). If any placeholder leaked past the
  # x_mis override, fn / gradient / inner mode would move. The single-source
  # delta-correction guarantees byte-identical results -- a strong leak
  # detector (the predictor-side analogue of the response-mask sentinel test).
  d <- .rob_make_unit()
  dat <- .rob_inject_unit(d, miss_sites = c(4L, 12L, 23L, 31L))
  fit <- .rob_fit_unit(dat)

  td <- fit$tmb_data
  missing_pos <- fit$tmb_data$mi_missing_index + 1L   # 0-based -> 1-based
  expect_gt(length(missing_pos), 0L)
  par <- fit$opt$par
  rand <- fit$random

  build_obj <- function(sentinel) {
    tdx <- td
    tdx$mi_x_unit[missing_pos] <- sentinel
    TMB::MakeADFun(
      data = tdx,
      parameters = fit$tmb_params,
      map = fit$tmb_map,
      random = if (length(rand)) rand else NULL,
      DLL = "gllvmTMB",
      silent = TRUE
    )
  }
  obj0 <- build_obj(0)
  obj1 <- build_obj(1e6)

  # Warm the lazy inner Laplace solve identically on both objects (the first
  # gr() after construction can differ at ~1e-15 in iterate state; after one
  # fn()+gr() the inner mode is byte-identical). This mirrors the shipped
  # response-mask sentinel test -- a TMB inner-solver caching artefact, NOT a
  # tolerance widening.
  invisible(obj0$fn(par)); invisible(obj0$gr(par))
  invisible(obj1$fn(par)); invisible(obj1$gr(par))

  fn0 <- obj0$fn(par); gr0 <- obj0$gr(par)
  fn1 <- obj1$fn(par); gr1 <- obj1$gr(par)

  expect_identical(fn0, fn1)                          # byte-identical logLik
  expect_identical(gr0, gr1)                          # byte-identical gradient
  expect_identical(obj0$env$last.par, obj1$env$last.par)  # inner mode identical
})

# ===========================================================================
# Overlapping missingness: a whole unit missing-y AND missing-x
# ===========================================================================

test_that("a unit fully y-masked AND missing-x converges with sane output", {
  skip_if_not_heavy()
  # Harder than the shipped both-missing test (which masks only ONE trait row
  # of a both-missing unit): here BOTH trait rows of a missing-x unit are
  # response-masked, so that unit contributes ZERO response likelihood yet its
  # x is still latent. Assert: convergence, nobs == observed-y, the x EBLUP is
  # still defined for every missing unit (including the fully-masked one), and
  # residuals are NA exactly at the masked rows.
  d <- .rob_make_unit(seed = 9, n_sites = 50)
  miss_sites <- c(6L, 18L, 33L)
  dat <- .rob_inject_unit(d, miss_sites = miss_sites)
  y_miss_rows <- which(as.integer(dat$site) == 6L)   # BOTH trait rows of unit 6
  dat$value[y_miss_rows] <- NA_real_
  observed_y <- !is.na(dat$value)

  fit <- .rob_fit_unit(
    dat,
    missing = miss_control(response = "include", predictor = "model")
  )

  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-1)
  expect_identical(stats::nobs(fit), sum(observed_y))
  expect_true(all(is.finite(fit$tmb_obj$env$parList(fit$opt$par)$b_fix)))
  # x EBLUP defined for every missing unit -- including the fully-y-masked one.
  expect_length(
    fit$missing_data$predictors$x$conditional_mode,
    length(miss_sites)
  )
  expect_true(all(is.finite(fit$missing_data$predictors$x$conditional_mode)))
  res <- residuals(fit, type = "randomized_quantile", seed = 1)
  expect_true(all(is.na(res$residual[y_miss_rows])))
  expect_true(all(!is.na(res$residual[setdiff(seq_len(nrow(dat)), y_miss_rows)])))
})

# ===========================================================================
# Phase 2b grouped covariate model: unused / non-contiguous group levels
# ===========================================================================

test_that("grouped mi() drops an unused, non-contiguous group level (no phantom RE)", {
  skip_if_not_heavy()
  # A (1 | grp) covariate model whose grouping factor has an UNUSED extra level
  # and NON-CONTIGUOUS level ordering must not allocate a phantom random
  # intercept for the empty level. Assert n_group counts only USED levels, the
  # recorded levels exclude the unused one, and the random-intercept vector has
  # exactly that length -- the grouped block is index-safe under unused levels.
  set.seed(303)
  n_sites <- 64L
  n_used <- 8L
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  grp_id <- rep(seq_len(n_used), length.out = n_sites)
  group_shift <- stats::rnorm(n_used, sd = 0.6)
  x <- 0.2 + 0.7 * z - 0.3 * w + group_shift[grp_id] +
    stats::rnorm(n_sites, sd = 0.4)
  rows <- vector("list", n_sites)
  for (s in seq_len(n_sites)) {
    eta1 <- 0.6 + 1.25 * x[s] - 0.25 * z[s]
    eta2 <- -0.3 + 1.25 * x[s] + 0.45 * z[s]
    rows[[s]] <- data.frame(
      site = s, trait = c("t1", "t2"),
      value = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
      x = x[s], z = z[s], w = w[s], grp = grp_id[s],
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  # Non-contiguous ordering with an UNUSED extra level "99".
  dat$grp <- factor(
    dat$grp,
    levels = c("3", "1", "99", "8", "2", "5", "4", "6", "7")
  )
  expect_identical(nlevels(dat$grp), 9L)             # 8 used + 1 unused
  dat$x[as.integer(dat$site) %in% c(5L, 17L, 28L, 39L, 52L)] <- NA_real_

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = dat, family = gaussian(),
    impute = list(x = x ~ z + w + (1 | grp)),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  rnd <- fit$missing_data$predictors$x$random
  expect_identical(fit$missing_data$predictors$x$version, "phase2b")
  expect_true(isTRUE(rnd$enabled))
  # Only the 8 USED levels get a random intercept; "99" is dropped.
  expect_identical(rnd$n_group, n_used)
  expect_false("99" %in% rnd$levels)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_length(par$u_mi_group, n_used)
  expect_true(all(is.finite(par$u_mi_group)))
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
})

# ===========================================================================
# Phase 2c group level: boundary + a fully-missing group
# ===========================================================================

test_that("group-level mi(): a single-level group key is rejected", {
  # A mi_group() whose key has only one level cannot define a coarser level.
  # This errors before any TMB fit, so it runs unconditionally.
  d <- .rob_make_group()
  dat <- .rob_inject_group(d, miss_region = c(2L, 9L, 17L, 24L))
  dat$region <- factor(rep(1L, nrow(dat)))           # collapse to one group
  expect_error(
    .rob_fit_group(dat),
    "two"
  )
})

test_that("group-level mi(): a group whose x is entirely missing gets one latent", {
  skip_if_not_heavy()
  # Phase 2c with several WHOLE regions missing-x (all sites, all trait rows).
  # The latent count must be one per missing GROUP (not per unit, not per long
  # row), the registry must track exactly the missing regions, and the fit must
  # converge with finite estimates. A fully-missing group is the natural
  # group-level degenerate that a per-unit fixture cannot express.
  miss_region <- c(2L, 9L, 17L, 24L)
  d <- .rob_make_group()
  dat <- .rob_inject_group(d, miss_region = miss_region)

  fit <- .rob_fit_group(dat)

  expect_identical(fit$missing_data$predictors$x$version, "phase2c")
  expect_identical(stats::nobs(fit), nrow(dat))
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  # ONE latent per missing GROUP even though each region spans
  # n_per_region sites x 2 traits = 6 long rows.
  expect_length(par$x_mis, length(miss_region))
  expect_identical(fit$missing_data$predictors$x$model_row, miss_region)
  expect_identical(
    fit$missing_data$predictors$x$counts$missing,
    length(miss_region)
  )
  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))
  expect_true(is.finite(par$log_sigma_mi[[1]]))
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
  # Every per-group conditional mode is finite.
  expect_length(
    fit$missing_data$predictors$x$conditional_mode,
    length(miss_region)
  )
  expect_true(all(is.finite(fit$missing_data$predictors$x$conditional_mode)))
})
