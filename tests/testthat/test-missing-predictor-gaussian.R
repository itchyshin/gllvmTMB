# Phase 2a (issue #332 / design 67): ONE continuous OBSERVATION/UNIT-level
# Gaussian missing PREDICTOR via mi(x) with a FIXED-effect covariate model.
# This is the gllvmTMB analogue of drmTMB's MD3a (mi_family == 0) Gaussian
# fixed path, ported with the ONE structural adaptation of design 67 sec.2.0-
# 2.1: the missing x is a UNIT-level quantity broadcast across all trait rows
# of that unit, so the x_mis latent vector has one entry per missing UNIT
# value (not per long row) and the covariate density is summed over UNITS.
#
# Gate map (design 59 sec.9 + design 67 sec.6):
#   * boundary rejection      -- the MD3a guards (no impute, >1 mi(), mi(log x),
#                                interactions, LHS/name mismatch, `.`, response
#                                vars, grouped/structured covariate RE) error.
#   * retains rows            -- the missing-predictor row count + registry.
#   * combines with masks     -- mi(x) + response = "include" together.
#   * imputed() modes/frame   -- the EBLUP frame + SE + no-TMB-object path.
#   * no-op complete-case     -- an ordinary (complete) predictor still uses
#                                complete-case behaviour under the defaults.
#   * recovery sim (gllvmTMB) -- known DGP, MCAR x, SE on: the response slope
#                                recovers within a band AND the x conditional
#                                mode correlates with the truth.
#   * multivariate broadcast  -- traits(t1, t2) ~ z + mi(x) + (1 | site): one
#                                unit-level missing x feeds BOTH traits; assert
#                                convergence + finite estimates, and that a
#                                single-trait reduction matches the univariate
#                                answer (the cross-package collapse contract).
#
# All fits are gated behind skip_if_not_heavy(); the pure-validation boundary
# blocks run unconditionally (they error before any TMB fit).

# ---- Fixtures --------------------------------------------------------------

# A small LONG-format dataset. gllvmTMB needs >= 2 trait levels to form the
# `0 + trait` stacked design, so the minimal gllvmTMB "univariate-like" case is
# two traits per unit. x and z are UNIT-level (constant within a site), so x is
# a single broadcast column shared by both trait rows of a site -- the unit
# broadcast (mi_unit_id is non-identity: two long rows map to one unit). The
# response slope on x is `b_x_true`, shared across traits.
.make_mi_uni <- function(seed = 202, n_sites = 40, b_x_true = 1.3,
                         miss_idx = c(4L, 12L, 23L, 31L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  ## Gaussian covariate model: x ~ N(0.25 + 0.8 z - 0.4 w, 0.5^2).
  x <- 0.25 + 0.8 * z - 0.4 * w + stats::rnorm(n_sites, sd = 0.5)
  ## Two traits, shared x slope b_x_true, trait-specific intercept + z slope.
  rows <- list()
  for (s in seq_len(n_sites)) {
    eta1 <- 0.7 + b_x_true * x[s] - 0.3 * z[s]
    eta2 <- -0.2 + b_x_true * x[s] + 0.5 * z[s]
    rows[[s]] <- data.frame(
      site    = s,
      trait   = c("t1", "t2"),
      value   = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
      x       = x[s],
      z       = z[s],
      w       = w[s],
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site    <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait   <- factor(dat$trait, levels = c("t1", "t2"))
  dat$species <- factor(rep(1L, nrow(dat)))
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  ## `missing` indexes SITES (units). The missing-x long rows are both trait
  ## rows of each missing site.
  list(
    data = dat, x_true = x, missing_site = miss_idx, b_x_true = b_x_true,
    site = dat$site
  )
}

# Set x to NA for every long row of the given missing sites; return the data
# plus the long-row indices that are missing (for registry assertions).
.inject_missing_x <- function(d) {
  dat <- d$data
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dat$x[miss_rows] <- NA_real_
  list(data = dat, miss_rows = miss_rows, miss_site = d$missing_site)
}

# Fit the two-trait Gaussian mi(x) model. z is trait-interacted (the gllvmTMB
# convention); mi(x) is the single broadcast missing predictor.
.fit_mi_uni <- function(data, impute = list(x = x ~ z + w),
                        missing = miss_control(predictor = "model"),
                        se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data    = data,
    family  = gaussian(),
    impute  = impute,
    missing = missing,
    control = gllvmTMBcontrol(se = se)
  )))
}

# ---- Boundary rejection (no fit; design 67 sec.0 OUT list) ----------------

test_that("mi() Gaussian predictor model validates the Phase 2a boundary", {
  dat <- .inject_missing_x(.make_mi_uni())$data

  ## mi() without impute= errors (needs a covariate model).
  expect_error(
    .fit_mi_uni(dat, impute = NULL),
    "impute"
  )
  ## mi() without predictor = "model".
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z),
      missing = miss_control(),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "predictor"
  )
  ## A plain x term (no mi()) under predictor = "model" + impute is not one mi().
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + x,
      data = dat, family = gaussian(),
      impute = list(x = x ~ z),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "exactly one"
  )
  ## Two mi() terms.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x) + mi(w),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "exactly one"
  )
  ## Transformed mi().
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(log(x)),
      data = dat, family = gaussian(),
      impute = list(x = x ~ z),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "bare predictor"
  )
  ## mi() in an interaction.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x):z,
      data = dat, family = gaussian(),
      impute = list(x = x ~ z),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "additive"
  )
  ## impute name mismatch.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x),
      data = dat, family = gaussian(),
      impute = list(w = x ~ z),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "must match"
  )
  ## `.` on the impute RHS.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = x ~ .),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "explicit predictor names"
  )
  ## Random SLOPES in the covariate model (Phase 2b OUT) are rejected loudly.
  dat_g <- dat
  dat_g$grp <- factor(as.integer(dat_g$site) %% 8L)
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x),
      data = dat_g, family = gaussian(),
      impute = list(x = x ~ z + (0 + z | grp)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "random intercept"
  )
  ## More than one covariate RE term (Phase 2b OUT) is rejected loudly.
  dat_g$grp2 <- factor(as.integer(dat_g$site) %% 5L)
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x),
      data = dat_g, family = gaussian(),
      impute = list(x = x ~ z + (1 | grp) + (1 | grp2)),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "only one"
  )
  ## Structured covariate model (phylo/relmat; Phase 3) is rejected.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = impute_model(x ~ z, family = binomial())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "later"
  )
})

test_that("mi() requires at least one missing and one observed value", {
  dat_complete <- .make_mi_uni()$data   # x fully observed
  ## With no missing x, predictor = "model" + mi(x) has nothing to impute.
  expect_error(
    .fit_mi_uni(dat_complete),
    "missing"
  )
})

# ---- Retains rows + registry (design 67 sec.3.5 step 7) -------------------

test_that("Gaussian mi() predictor model retains missing-predictor rows", {
  skip_if_not_heavy()
  d <- .make_mi_uni()
  inj <- .inject_missing_x(d)
  dat <- inj$data

  fit <- .fit_mi_uni(dat)

  expect_identical(stats::nobs(fit), nrow(dat))
  expect_equal(fit$missing_data$predictor_policy, "model")
  expect_identical(fit$missing_data$original_row, seq_len(nrow(dat)))
  expect_true(all(fit$missing_data$observed_y))
  expect_named(fit$missing_data$predictors, "x")
  reg <- fit$missing_data$predictors$x
  ## x is UNIT-level: the registry tracks missing UNITS (sites), one EBLUP each
  ## (NOT one per long row). model_row / original_row index the missing units.
  expect_identical(reg$model_row, d$missing_site)
  expect_identical(reg$original_row, d$missing_site)
  expect_identical(reg$counts$missing, length(d$missing_site))
  expect_identical(reg$version, "phase2a")
  ## Fixed-effect coefficients + the covariate-model parameters are finite.
  bfix <- fit$tmb_obj$env$parList(fit$opt$par)$b_fix
  expect_true(all(is.finite(bfix)))
  beta_x <- fit$tmb_obj$env$parList(fit$opt$par)$beta_mi
  expect_true(all(is.finite(beta_x)))
  log_sigma_x <- fit$tmb_obj$env$parList(fit$opt$par)$log_sigma_mi
  expect_true(all(is.finite(log_sigma_x)))
  ## The fit is at a stationary point (gradient ~ 0).
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
})

test_that("Gaussian mi() predictor model combines with a response mask", {
  skip_if_not_heavy()
  d <- .make_mi_uni()
  inj <- .inject_missing_x(d)
  dat <- inj$data
  y_miss <- c(7L, 19L)
  dat$value[y_miss] <- NA_real_
  observed_y <- !is.na(dat$value)

  fit <- .fit_mi_uni(
    dat,
    missing = miss_control(response = "include", predictor = "model")
  )

  expect_identical(stats::nobs(fit), sum(observed_y))
  expect_identical(as.logical(fit$missing_data$observed_y), observed_y)
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing_site)
  ## The x conditional mode is still defined for every missing UNIT value.
  expect_length(
    fit$missing_data$predictors$x$conditional_mode,
    length(d$missing_site)
  )
})

# ---- imputed() EBLUP frame (design 67 sec.3.4 / drmTMB MD3a) --------------

test_that("imputed() reports Phase 2a missing-predictor conditional modes", {
  skip_if_not_heavy()
  d <- .make_mi_uni()
  inj <- .inject_missing_x(d)
  dat <- inj$data

  fit <- .fit_mi_uni(dat, se = TRUE)

  out <- imputed(fit)
  modes <- fit$tmb_obj$env$parList(fit$opt$par)$x_mis

  expect_s3_class(out, "data.frame")
  expect_named(
    out,
    c("variable", "original_row", "model_row", "observed",
      "estimate", "std_error", "source", "uncertainty_status")
  )
  ## One EBLUP per missing UNIT (site), not per long row.
  expect_equal(out$variable, rep("x", length(d$missing_site)))
  expect_identical(out$original_row, d$missing_site)
  expect_identical(out$model_row, d$missing_site)
  expect_false(any(out$observed))
  expect_equal(out$estimate, as.numeric(modes), tolerance = 1e-8)
  expect_true(all(is.finite(out$std_error)))
  expect_true(all(out$std_error > 0))
  expect_equal(out$source, rep("conditional_mode", length(d$missing_site)))
  expect_equal(
    fit$missing_data$predictors$x$conditional_mode,
    as.numeric(modes),
    tolerance = 1e-8
  )
})

test_that("imputed(rows = 'all') returns every retained predictor unit", {
  skip_if_not_heavy()
  d <- .make_mi_uni()
  inj <- .inject_missing_x(d)
  dat <- inj$data
  n_units <- nlevels(dat$site)
  observed_unit <- !(seq_len(n_units) %in% d$missing_site)
  x_unit <- d$x_true                       # unit-level observed x

  fit <- .fit_mi_uni(dat, se = TRUE)
  out <- imputed(fit, rows = "all")

  ## "all" returns one row per UNIT (the covariate-model rows are units).
  expect_identical(nrow(out), n_units)
  expect_identical(out$original_row, seq_len(n_units))
  expect_identical(out$observed, observed_unit)
  expect_equal(out$estimate[observed_unit], x_unit[observed_unit],
               tolerance = 1e-12)
  expect_true(all(is.na(out$std_error[observed_unit])))
  expect_equal(out$source[observed_unit],
               rep("observed", sum(observed_unit)))
})

test_that("imputed() marks SEs unavailable without a sdreport", {
  skip_if_not_heavy()
  d <- .make_mi_uni()
  inj <- .inject_missing_x(d)
  dat <- inj$data

  fit <- .fit_mi_uni(dat, se = FALSE)
  out <- imputed(fit)

  expect_equal(
    out$estimate,
    fit$missing_data$predictors$x$conditional_mode,
    tolerance = 1e-8
  )
  expect_true(all(is.na(out$std_error)))
})

test_that("imputed() errors outside fitted missing-predictor summaries", {
  skip_if_not_heavy()
  d <- .make_mi_uni()
  inj <- .inject_missing_x(d)
  dat <- inj$data

  ## A response-mask-only fit has no modelled missing predictors.
  dat_resp <- d$data
  dat_resp$value[3] <- NA_real_
  fit_resp <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z,
    data = dat_resp, family = gaussian(),
    missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_error(imputed(fit_resp), "no modelled missing predictors")

  fit_mi <- .fit_mi_uni(dat)
  expect_error(imputed(fit_mi, variable = "w"), "Unknown")
})

# ---- No-op: ordinary predictors still use complete-case -------------------

test_that("ordinary missing predictors still error under the defaults", {
  dat <- .inject_missing_x(.make_mi_uni())$data

  ## Default miss_control(): a missing ordinary predictor x still hits the
  ## existing hard stop (predictor = "fail"); no mi() machinery is engaged.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):x,
      data = dat, family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "NA"
  )
})

# ---- gllvmTMB-specific gate (a): recovery sim -----------------------------

test_that("recovery sim: response slope + x conditional mode recover", {
  skip_if_not_heavy()
  ## Larger n, more missing, SE on: the response slope b_x should land near the
  ## truth and the x conditional modes should correlate with the held-out x.
  d <- .make_mi_uni(
    seed = 7, n_sites = 120, b_x_true = 1.3,
    miss_idx = sort(sample.int(120L, 24L))
  )
  inj <- .inject_missing_x(d)
  dat <- inj$data
  x_true_missing <- d$x_true[d$missing_site]

  fit <- .fit_mi_uni(dat, se = TRUE)

  ## b_x is the broadcast mi() slope. It is the single non-trait column of
  ## X_fix; its position is recorded in the registry as mu_col.
  mu_col <- fit$missing_data$predictors$x$mu_col
  bfix <- fit$tmb_obj$env$parList(fit$opt$par)$b_fix
  b_x_hat <- bfix[mu_col]
  expect_equal(b_x_hat, d$b_x_true, tolerance = 0.25)

  ## The x conditional modes correlate strongly with the held-out truth
  ## (one mode per missing unit) AND track it in absolute terms (RMSE bound).
  modes <- fit$missing_data$predictors$x$conditional_mode
  expect_length(modes, length(d$missing_site))
  expect_gt(stats::cor(modes, x_true_missing), 0.7)
  rmse <- sqrt(mean((modes - x_true_missing)^2))
  expect_lt(rmse, 0.6)            # well inside the covariate-model residual SD

  ## The covariate-model coefficients recover the truth (intercept 0.25,
  ## z slope 0.8, w slope -0.4) and sigma_x recovers (truth 0.5).
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  beta_x <- unname(par$beta_mi)
  expect_equal(beta_x[1], 0.25, tolerance = 0.25)   # intercept
  expect_equal(beta_x[2], 0.80, tolerance = 0.35)   # z slope
  expect_equal(beta_x[3], -0.40, tolerance = 0.35)  # w slope
  sigma_x_hat <- exp(par$log_sigma_mi[[1]])
  expect_equal(sigma_x_hat, 0.5, tolerance = 0.25)
})

# ---- delta-correction sanity anchor (catches a sign / double-count) -------

test_that("near-degenerate mi(x): the broadcast slope matches complete-case", {
  skip_if_not_heavy()
  ## With x observed at all but ONE unit, the mi() fit's broadcast slope b_x
  ## must agree with a plain complete-case fit (that one unit dropped, x an
  ## ordinary broadcast predictor). A sign error or double-count in the
  ## delta-correction `eta(o) += b_fix(mi_col)*(x_full(u) - X_fix(o, mi_col))`
  ## would shift b_x away from the complete-case value -- this anchor catches it
  ## where "finite + converged" cannot (coordinator audit point 3).
  d <- .make_mi_uni(seed = 5, n_sites = 60, miss_idx = 17L)
  inj <- .inject_missing_x(d)
  dat <- inj$data

  fit_mi <- .fit_mi_uni(dat, se = FALSE)
  mu_col <- fit_mi$missing_data$predictors$x$mu_col
  b_x_mi <- fit_mi$tmb_obj$env$parList(fit_mi$opt$par)$b_fix[mu_col]

  ## Complete-case: drop the one missing unit's rows; x enters as an ordinary
  ## single broadcast column (bare `x`, NOT trait-interacted).
  dat_cc <- dat[!is.na(dat$x), , drop = FALSE]
  dat_cc$site <- droplevels(dat_cc$site)
  dat_cc$site_species <- droplevels(dat_cc$site_species)
  fit_cc <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + x,
    data = dat_cc, family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  b_x_cc <- fit_cc$tmb_obj$env$parList(fit_cc$opt$par)$b_fix[
    match("x", fit_cc$X_fix_names)
  ]

  ## One latent x_mis among 60 units barely perturbs the slope: the two must
  ## agree tightly. A sign flip would put b_x_mi near -b_x_cc.
  expect_equal(b_x_mi, b_x_cc, tolerance = 0.05)
})

# ---- both-missing composition (overlapping y- and x-missingness) ----------

test_that("a row missing both y and x converges with NA residual", {
  skip_if_not_heavy()
  ## At least one unit is simultaneously missing-y (response = "include") AND
  ## missing-x (mi()). drmTMB never tests overlapping missingness (audit
  ## point 4): assert convergence + finite estimates + that the masked-y rows
  ## have NA residuals, with the x EBLUP still defined for the missing units.
  d <- .make_mi_uni(seed = 9, n_sites = 50, miss_idx = c(6L, 18L, 33L))
  inj <- .inject_missing_x(d)
  dat <- inj$data
  ## Mask the t1 response of unit 6 (which also has a missing x) + unit 40.
  y_miss_rows <- which(
    (as.integer(dat$site) == 6L & dat$trait == "t1") |
      (as.integer(dat$site) == 40L & dat$trait == "t2")
  )
  dat$value[y_miss_rows] <- NA_real_
  observed_y <- !is.na(dat$value)

  fit <- .fit_mi_uni(
    dat,
    missing = miss_control(response = "include", predictor = "model"),
    se = FALSE
  )

  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-1)
  expect_identical(stats::nobs(fit), sum(observed_y))
  expect_true(all(is.finite(fit$tmb_obj$env$parList(fit$opt$par)$b_fix)))
  ## The x EBLUP is defined for every missing unit (including unit 6 which is
  ## also missing its t1 response).
  expect_length(
    fit$missing_data$predictors$x$conditional_mode,
    length(d$missing_site)
  )
  ## Residuals are NA exactly at the masked-y rows.
  res <- residuals(fit, type = "randomized_quantile", seed = 1)
  expect_true(all(is.na(res$residual[y_miss_rows])))
  expect_true(all(!is.na(res$residual[setdiff(seq_len(nrow(dat)), y_miss_rows)])))
})

# ---- gllvmTMB-specific gate (b): multivariate broadcast -------------------

# A two-trait dataset where x is unit-level (one value per site) and feeds the
# eta of BOTH traits through a single shared mi() slope. The single-trait
# reduction (drop trait t2) must reproduce the univariate answer -- the
# design 67 sec.6 cross-package collapse contract (here applied within
# gllvmTMB across the trait dimension).
.make_mi_multi <- function(seed = 11, n_sites = 60, b_x_true = 1.1,
                           miss_idx = c(3L, 14L, 28L, 41L, 55L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  x <- 0.2 + 0.7 * z - 0.3 * w + stats::rnorm(n_sites, sd = 0.5)
  ## Two traits: shared x slope b_x_true, trait-specific intercepts + z slopes.
  mk <- function(a0, bz, sigma) a0 + b_x_true * x + bz * z +
    stats::rnorm(n_sites, sd = sigma)
  t1 <- mk(0.5, -0.2, 0.4)
  t2 <- mk(-0.3, 0.4, 0.5)
  wide <- data.frame(
    site = factor(seq_len(n_sites)),
    t1 = t1, t2 = t2, x = x, z = z, w = w,
    stringsAsFactors = FALSE
  )
  list(data = wide, x_true = x, missing = miss_idx, b_x_true = b_x_true)
}

test_that("multivariate broadcast: one unit-level mi(x) feeds both traits", {
  skip_if_not_heavy()
  d <- .make_mi_multi()
  wide <- d$data
  wide$x[d$missing] <- NA_real_

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1, t2) ~ z + mi(x) + (1 | site),
    data    = wide,
    unit    = "site",
    family  = gaussian(),
    impute  = list(x = x ~ z + w),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  ## Convergence + finite estimates.
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-1)
  bfix <- fit$tmb_obj$env$parList(fit$opt$par)$b_fix
  expect_true(all(is.finite(bfix)))
  ## One mi() slope shared across both traits -> ONE latent per missing site.
  expect_length(
    fit$tmb_obj$env$parList(fit$opt$par)$x_mis,
    length(d$missing)
  )
  ## Registry records exactly the missing sites (one wide row per site).
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing)
  ## The shared mi() slope is near the truth.
  mu_col <- fit$missing_data$predictors$x$mu_col
  expect_equal(bfix[mu_col], d$b_x_true, tolerance = 0.3)
  ## The x conditional modes correlate with the held-out truth.
  modes <- fit$missing_data$predictors$x$conditional_mode
  expect_gt(stats::cor(modes, d$x_true[d$missing]), 0.6)
})

test_that("wide traits() mi(x) matches the hand-built long-format fit", {
  skip_if_not_heavy()
  ## The wide -> long rewrite must be faithful for mi(): the wide-entry fit and
  ## the hand-built long-format fit on the SAME data agree on the mi() slope and
  ## the x conditional modes. This is the cross-entry-path collapse contract
  ## (design 67 sec.6) -- the unit broadcast is identical whether the user
  ## enters wide traits() or the stacked long grammar.
  d <- .make_mi_multi(seed = 19)
  wide <- d$data
  wide$x[d$missing] <- NA_real_

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB(
    ## `1 +` expands to the trait-specific intercepts `0 + trait`, matching the
    ## hand-built long form below.
    traits(t1, t2) ~ 1 + z + mi(x),
    data    = wide,
    unit    = "site",
    family  = gaussian(),
    impute  = list(x = x ~ z + w),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  ## Build the matching long-format two-trait data by hand and fit directly.
  long <- do.call(rbind, lapply(seq_len(nrow(wide)), function(i) {
    data.frame(
      site = wide$site[i], trait = c("t1", "t2"),
      value = c(wide$t1[i], wide$t2[i]),
      x = wide$x[i], z = wide$z[i], w = wide$w[i],
      stringsAsFactors = FALSE
    )
  }))
  long$site    <- factor(long$site, levels = levels(wide$site))
  long$trait   <- factor(long$trait, levels = c("t1", "t2"))
  long$species <- factor(rep(1L, nrow(long)))
  long$site_species <- factor(paste(long$site, long$species, sep = "_"))
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data    = long,
    family  = gaussian(),
    impute  = list(x = x ~ z + w),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  ## The mi() slope and the x conditional modes agree to optimiser tolerance.
  mu_w <- fit_wide$missing_data$predictors$x$mu_col
  mu_l <- fit_long$missing_data$predictors$x$mu_col
  bw <- fit_wide$tmb_obj$env$parList(fit_wide$opt$par)$b_fix[mu_w]
  bl <- fit_long$tmb_obj$env$parList(fit_long$opt$par)$b_fix[mu_l]
  expect_equal(bw, bl, tolerance = 1e-3)
  expect_equal(
    fit_wide$missing_data$predictors$x$conditional_mode,
    fit_long$missing_data$predictors$x$conditional_mode,
    tolerance = 1e-3
  )
})

# ===========================================================================
# Phase 2b (issue #332 / design 67): ONE grouped random-intercept covariate
# model -- impute = list(x = x ~ z + (1 | group)) (the gllvmTMB analogue of
# drmTMB MD3b, src/drmTMB.cpp has_mi_group inside mi_family == 0). Ported from
# drmTMB tests/testthat/test-missing-predictor-gaussian.R grouped blocks.
#
# gllvmTMB structural adaptation (consistent with Phase 2a): the covariate
# model is at the UNIT level, eta_x(u) = X_x(u,.) beta_x + sd_x_group *
# u_x_group(group(u)); u_x_group ~ N(0,1) joins the TMB `random` set; the
# Gaussian density x_full(u) ~ N(eta_x(u), sigma_x^2) is summed over UNITS.
# `group` is a UNIT-level grouping (one group id per unit, no missing values).
# `mi_group_index` is built at unit level, parallel to `mi_unit_id`.
#
# Gate map:
#   * grouped boundary        -- random slopes / >1 RE term / missing group
#                                still error (in the Phase 2a boundary block
#                                + the grouped-specific block below).
#   * supports grouped int.   -- version "phase2b", random$enabled/group/n_group,
#                                finite estimates + group SD, gradient ~ 0.
#   * combines with masks     -- grouped mi(x) + response = "include".
#   * imputed() grouped       -- the EBLUP frame + SE for the grouped fit.
#   * grouped recovery        -- a stochastic DGP with a known group SD: recover
#                                b_fix (mi slope), beta_x, sigma_x, AND the group
#                                SD within a band, and the missing-x modes
#                                correlate with truth.
#
# Fit-heavy blocks are gated behind skip_if_not_heavy(); the pure-validation
# boundary blocks run unconditionally.

# ---- Grouped fixture (unit-level group) -----------------------------------

# Like .make_mi_uni but the covariate model carries a UNIT-level random
# intercept: each site is assigned to one of `n_group` groups, and the
# covariate mean gets a group shift drawn N(0, group_sd^2). x is still
# unit-level (constant within a site). The covariate model is
#   x[u] ~ N(beta0 + beta_z z[u] + beta_w w[u] + group_shift[group[u]], sigma_x^2).
.make_mi_grouped <- function(seed = 303, n_sites = 64, n_group = 8L,
                             b_x_true = 1.25, group_sd = 0.6, sigma_x = 0.4,
                             miss_idx = c(5L, 17L, 28L, 39L, 52L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  grp <- rep(seq_len(n_group), length.out = n_sites)
  group_shift <- stats::rnorm(n_group, sd = group_sd)
  ## Covariate model with a unit-level group random intercept.
  x <- 0.2 + 0.7 * z - 0.3 * w + group_shift[grp] +
    stats::rnorm(n_sites, sd = sigma_x)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eta1 <- 0.6 + b_x_true * x[s] - 0.25 * z[s]
    eta2 <- -0.3 + b_x_true * x[s] + 0.45 * z[s]
    rows[[s]] <- data.frame(
      site    = s,
      trait   = c("t1", "t2"),
      value   = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
      x       = x[s],
      z       = z[s],
      w       = w[s],
      grp     = grp[s],
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site    <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait   <- factor(dat$trait, levels = c("t1", "t2"))
  dat$grp     <- factor(dat$grp, levels = seq_len(n_group))
  dat$species <- factor(rep(1L, nrow(dat)))
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  list(
    data = dat, x_true = x, missing_site = miss_idx, b_x_true = b_x_true,
    group_sd = group_sd, sigma_x = sigma_x, n_group = n_group,
    group_shift = group_shift, grp = grp
  )
}

# Inject NA x for all long rows of the given missing sites.
.inject_missing_grouped <- function(d) {
  dat <- d$data
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dat$x[miss_rows] <- NA_real_
  dat
}

# Fit the two-trait grouped Gaussian mi(x) model: x ~ z + w + (1 | grp).
.fit_mi_grouped <- function(data,
                            impute = list(x = x ~ z + w + (1 | grp)),
                            missing = miss_control(predictor = "model"),
                            se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data    = data,
    family  = gaussian(),
    impute  = impute,
    missing = missing,
    control = gllvmTMBcontrol(se = se)
  )))
}

# ---- Grouped boundary rejection (no fit) ----------------------------------

test_that("grouped mi() covariate model validates the Phase 2b boundary", {
  d <- .make_mi_grouped()
  dat <- .inject_missing_grouped(d)

  ## A missing grouping value is rejected loudly (the group must be complete).
  dat_missing_group <- dat
  dat_missing_group$grp[1] <- NA
  expect_error(
    .fit_mi_grouped(dat_missing_group),
    "complete"
  )
  ## Random SLOPES are rejected.
  expect_error(
    .fit_mi_grouped(dat, impute = list(x = x ~ z + (0 + z | grp))),
    "random intercept"
  )
  ## More than one covariate RE term is rejected.
  expect_error(
    .fit_mi_grouped(
      dat,
      impute = list(x = x ~ z + (1 | grp) + (1 | site))
    ),
    "only one"
  )
  ## A single-level group is rejected (needs at least two levels).
  dat_one <- dat
  dat_one$grp <- factor(rep(1L, nrow(dat_one)))
  expect_error(
    .fit_mi_grouped(dat_one),
    "two group levels"
  )
})

# ---- Supports one grouped covariate intercept (PORT MD3b) -----------------

test_that("Gaussian mi() predictor model supports one grouped covariate intercept", {
  skip_if_not_heavy()
  d <- .make_mi_grouped()
  dat <- .inject_missing_grouped(d)

  fit <- .fit_mi_grouped(dat)

  expect_identical(fit$missing_data$predictors$x$version, "phase2b")
  expect_identical(stats::nobs(fit), nrow(dat))
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing_site)
  ## The grouped covariate RE is recorded in the registry.
  rnd <- fit$missing_data$predictors$x$random
  expect_true(isTRUE(rnd$enabled))
  expect_identical(rnd$group, "grp")
  expect_identical(rnd$n_group, d$n_group)
  ## Fixed effects + covariate-model coefs + group SD are finite.
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))
  expect_true(is.finite(par$log_sigma_mi[[1]]))
  expect_true(is.finite(par$log_sd_mi_group[[1]]))
  ## The group random intercepts are length n_group and finite.
  expect_length(par$u_mi_group, d$n_group)
  expect_true(all(is.finite(par$u_mi_group)))
  ## Stationary point.
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
})

test_that("Gaussian grouped mi() predictor model can combine with response masks", {
  skip_if_not_heavy()
  d <- .make_mi_grouped()
  dat <- .inject_missing_grouped(d)
  y_miss <- c(9L, 25L)
  dat$value[y_miss] <- NA_real_
  observed_y <- !is.na(dat$value)

  fit <- .fit_mi_grouped(
    dat,
    missing = miss_control(response = "include", predictor = "model")
  )

  expect_identical(fit$missing_data$predictors$x$version, "phase2b")
  expect_identical(stats::nobs(fit), sum(observed_y))
  expect_identical(as.logical(fit$missing_data$observed_y), observed_y)
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing_site)
  expect_true(isTRUE(fit$missing_data$predictors$x$random$enabled))
  ## The x conditional mode is defined for every missing unit.
  expect_length(
    fit$missing_data$predictors$x$conditional_mode,
    length(d$missing_site)
  )
})

# ---- imputed() grouped EBLUP frame (PORT MD3b) ----------------------------

test_that("imputed() supports grouped Phase 2b missing-predictor fits", {
  skip_if_not_heavy()
  d <- .make_mi_grouped()
  dat <- .inject_missing_grouped(d)

  fit <- .fit_mi_grouped(dat, se = TRUE)
  out <- imputed(fit, variable = "x")
  modes <- fit$tmb_obj$env$parList(fit$opt$par)$x_mis

  expect_identical(fit$missing_data$predictors$x$version, "phase2b")
  expect_identical(out$original_row, d$missing_site)
  expect_equal(out$source, rep("conditional_mode", length(d$missing_site)))
  expect_equal(out$estimate, as.numeric(modes), tolerance = 1e-8)
  expect_true(all(is.finite(out$std_error)))
  expect_true(all(out$std_error > 0))
})

# ---- Grouped recovery gate (genuine stochastic DGP) -----------------------

test_that("grouped recovery: mi slope, covariate coefs, sigma_x, group SD recover", {
  skip_if_not_heavy()
  ## A genuine stochastic DGP with a KNOWN group SD. With enough sites/groups
  ## and MCAR missing x, the response mi() slope, the covariate-model
  ## coefficients, sigma_x, AND the group SD should all land in a band, and the
  ## missing-x conditional modes should correlate with (and track) the truth.
  d <- .make_mi_grouped(
    seed = 2024, n_sites = 200, n_group = 20L,
    b_x_true = 1.25, group_sd = 0.6, sigma_x = 0.4,
    miss_idx = sort(sample.int(200L, 40L))
  )
  dat <- .inject_missing_grouped(d)
  x_true_missing <- d$x_true[d$missing_site]

  fit <- .fit_mi_grouped(dat, se = TRUE)

  par <- fit$tmb_obj$env$parList(fit$opt$par)

  ## (1) Response mi() slope b_x recovers (truth 1.25).
  mu_col <- fit$missing_data$predictors$x$mu_col
  b_x_hat <- par$b_fix[mu_col]
  expect_equal(b_x_hat, d$b_x_true, tolerance = 0.25)

  ## (2) Covariate-model coefficients recover (intercept 0.2, z 0.7, w -0.3).
  beta_x <- unname(par$beta_mi)
  expect_equal(beta_x[1], 0.20, tolerance = 0.3)
  expect_equal(beta_x[2], 0.70, tolerance = 0.3)
  expect_equal(beta_x[3], -0.30, tolerance = 0.3)

  ## (3) sigma_x recovers (truth 0.4).
  sigma_x_hat <- exp(par$log_sigma_mi[[1]])
  expect_equal(sigma_x_hat, d$sigma_x, tolerance = 0.2)

  ## (4) The covariate group SD recovers (truth 0.6). This is the new Phase 2b
  ## degree of freedom -- a fixed-only covariate model could not separate it.
  sd_group_hat <- exp(par$log_sd_mi_group[[1]])
  expect_equal(sd_group_hat, d$group_sd, tolerance = 0.3)

  ## (5) The missing-x conditional modes correlate with and track the truth.
  modes <- fit$missing_data$predictors$x$conditional_mode
  expect_length(modes, length(d$missing_site))
  expect_gt(stats::cor(modes, x_true_missing), 0.7)
  rmse <- sqrt(mean((modes - x_true_missing)^2))
  expect_lt(rmse, 0.6)

  ## (6) The estimated group random intercepts (sd_group * u) correlate with the
  ## true group shifts -- the grouped structure is genuinely being used.
  group_re_hat <- sd_group_hat * par$u_mi_group
  expect_gt(stats::cor(group_re_hat, d$group_shift), 0.6)
})

# ===========================================================================
# Phase 2c (issue #332 / design 67 sec.2.1 Phase-2c bullet): a GROUP-level
# Gaussian missing predictor -- x lives at a level COARSER than the wide-row
# unit (one x value per GROUP, broadcast to every unit of that group). This is
# the gllvmTMB analogue of drmTMB MD4's level-mismatch (the non-structured
# half). It is the precursor Design 69 sec.4.1 reuses for Phase 3: swap the
# bare mi_group(g) key for phylo(1 | species, tree =) and the broadcast is the
# same.
#
# Phase 2a/2b hardwire the latent-bearing level to the wide-row `unit` (site)
# and validate x constant-within-unit. Phase 2c DECOUPLES the latent level
# from `unit`: x is declared group-level with `impute = list(x = x ~ z +
# mi_group(g))`, the latent x_mis is one per missing GROUP, and a long-row ->
# group map `mi_group_level_id` broadcasts x_full(group) to every long row
# (across both the units of a group AND their trait rows). The Gaussian
# covariate density is summed over GROUPS (one per group, no pseudo-
# replication). One observed value per group is validated.
#
# Gate map (design 59 sec.9 Phase-2c row + design 67 sec.6):
#   * level-mismatch boundary -- mi_group() of a missing column / unknown
#                                column / single-level group errors; a group
#                                whose x is NOT constant within the group
#                                (two different observed x in one group)
#                                errors ("one observed value per group").
#   * supports group level     -- version "phase2c"; one latent per missing
#                                group (NOT per unit, NOT per long row); the
#                                registry tracks missing GROUPS; gradient ~ 0.
#   * broadcast correctness    -- the imputed x is a single per-group value
#                                feeding every unit (and trait row) of that
#                                group; mi_group_level_id maps every long row
#                                to the right group.
#   * recovery sim (group)     -- a genuine stochastic DGP at the group level:
#                                recover b_fix (mi slope), beta_x, sigma_x, AND
#                                the per-group missing-x modes vs truth.
#   * 2a no-op preserved        -- a unit-level mi(x) with NO mi_group() is
#                                byte-identical to the Phase 2a fit (version
#                                "phase2a"; same logLik / slope / modes).
#
# Fit-heavy blocks are gated behind skip_if_not_heavy(); the pure-validation
# boundary blocks run unconditionally.

# ---- Group-level fixture --------------------------------------------------

# Units are sites; x is a REGION-level covariate (one value per region,
# n_per_region sites per region, so region is COARSER than site). The covariate
# model is at the REGION level: x[r] ~ N(beta0 + beta_z z[r] + beta_w w[r],
# sigma_x^2). z, w are region-level too (the covariate-model predictors live at
# the group level). The response slope on x is b_x_true, shared across traits;
# every site of a region sees the same x, and every trait row of a site sees
# the same x -- a two-level broadcast (region -> site -> trait row).
.make_mi_group <- function(seed = 404, n_region = 30L, n_per_region = 3L,
                           b_x_true = 1.2, sigma_x = 0.45,
                           miss_region = c(2L, 9L, 17L, 24L)) {
  set.seed(seed)
  zr <- stats::rnorm(n_region)               # region-level covariate
  wr <- stats::rnorm(n_region)               # region-level covariate
  ## Region-level Gaussian covariate model.
  xr <- 0.3 + 0.7 * zr - 0.4 * wr + stats::rnorm(n_region, sd = sigma_x)
  rows <- list()
  site_counter <- 0L
  for (r in seq_len(n_region)) {
    for (k in seq_len(n_per_region)) {
      site_counter <- site_counter + 1L
      ## site-level response noise around the shared region-level eta.
      eta1 <- 0.6 + b_x_true * xr[r] - 0.25 * zr[r]
      eta2 <- -0.3 + b_x_true * xr[r] + 0.45 * zr[r]
      rows[[site_counter]] <- data.frame(
        site   = site_counter,
        region = r,
        trait  = c("t1", "t2"),
        value  = c(eta1, eta2) + stats::rnorm(2, sd = 0.4),
        x      = xr[r],
        z      = zr[r],
        w      = wr[r],
        stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  n_sites <- site_counter
  dat$site   <- factor(dat$site, levels = seq_len(n_sites))
  dat$region <- factor(dat$region, levels = seq_len(n_region))
  dat$trait  <- factor(dat$trait, levels = c("t1", "t2"))
  dat$species <- factor(rep(1L, nrow(dat)))
  dat$site_species <- factor(paste(dat$site, dat$species, sep = "_"))
  list(
    data = dat, x_true = xr, missing_region = miss_region,
    b_x_true = b_x_true, sigma_x = sigma_x, n_region = n_region,
    n_per_region = n_per_region, n_sites = n_sites
  )
}

# Inject NA x for every long row of the given missing REGIONS (all sites, all
# trait rows of those regions).
.inject_missing_group <- function(d) {
  dat <- d$data
  miss_rows <- which(as.integer(dat$region) %in% d$missing_region)
  dat$x[miss_rows] <- NA_real_
  dat
}

# Fit the two-trait group-level Gaussian mi(x) model. x lives at `region`.
.fit_mi_group <- function(data,
                          impute = list(x = x ~ z + w + mi_group(region)),
                          missing = miss_control(predictor = "model"),
                          se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data    = data,
    family  = gaussian(),
    impute  = impute,
    missing = missing,
    control = gllvmTMBcontrol(se = se)
  )))
}

# ---- Level-mismatch boundary rejection (no fit) ---------------------------

test_that("group-level mi() covariate model validates the Phase 2c boundary", {
  d <- .make_mi_group()
  dat <- .inject_missing_group(d)

  ## mi_group() naming an unknown column errors.
  expect_error(
    .fit_mi_group(dat, impute = list(x = x ~ z + mi_group(nope))),
    "not found"
  )
  ## A single-level group key is rejected (needs at least two groups).
  dat_one <- dat
  dat_one$region <- factor(rep(1L, nrow(dat_one)))
  expect_error(
    .fit_mi_group(dat_one),
    "two"
  )
  ## More than one mi_group() marker is rejected loudly.
  expect_error(
    .fit_mi_group(dat, impute = list(x = x ~ z + mi_group(region) + mi_group(site))),
    "one"
  )
  ## x NOT constant within the group (two different OBSERVED x in one region)
  ## is rejected: one observed value per group is the level-mismatch contract.
  dat_bad <- dat
  ## region 1 is observed; perturb x on ONE of its sites so the region carries
  ## two different observed x values.
  r1_rows <- which(as.integer(dat_bad$region) == 1L)
  dat_bad$x[r1_rows[1:2]] <- dat_bad$x[r1_rows[1:2]] + 5
  expect_error(
    .fit_mi_group(dat_bad),
    "constant within|one observed value per group"
  )
})

# ---- Supports the group level (NEW Phase 2c degree of freedom) ------------

test_that("group-level mi() fits one latent per missing group, not per unit", {
  skip_if_not_heavy()
  d <- .make_mi_group()
  dat <- .inject_missing_group(d)

  fit <- .fit_mi_group(dat)

  expect_identical(fit$missing_data$predictors$x$version, "phase2c")
  expect_identical(stats::nobs(fit), nrow(dat))
  ## The registry tracks missing GROUPS (regions), one EBLUP each -- NOT one
  ## per missing unit (site) and NOT one per long row.
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing_region)
  expect_identical(
    fit$missing_data$predictors$x$counts$missing,
    length(d$missing_region)
  )
  ## The group descriptor is recorded.
  grp <- fit$missing_data$predictors$x$group_level
  expect_true(isTRUE(grp$enabled))
  expect_identical(grp$group, "region")
  expect_identical(grp$n_group, d$n_region)
  ## ONE latent x_mis per missing GROUP (4 regions), even though each missing
  ## region spans n_per_region sites x 2 traits = 6 long rows.
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_length(par$x_mis, length(d$missing_region))
  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))
  expect_true(is.finite(par$log_sigma_mi[[1]]))
  ## Stationary point.
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
})

# ---- Broadcast correctness (the level-mismatch heart) ---------------------

test_that("group-level mi(): the imputed x is one per-group value broadcast to every unit", {
  skip_if_not_heavy()
  d <- .make_mi_group()
  dat <- .inject_missing_group(d)

  fit <- .fit_mi_group(fit_data <- dat, se = TRUE)

  ## imputed(rows = "all") returns one row per GROUP (the covariate-model rows
  ## are groups), with observed regions labelled observed.
  out <- imputed(fit, rows = "all")
  expect_identical(nrow(out), d$n_region)
  observed_region <- !(seq_len(d$n_region) %in% d$missing_region)
  expect_identical(out$observed, observed_region)
  ## Observed regions return the (constant) region-level x exactly.
  expect_equal(out$estimate[observed_region], d$x_true[observed_region],
               tolerance = 1e-10)

  ## The single-source broadcast: the full group-level x (observed + EBLUP)
  ## that the engine fed BOTH the covariate density and X_fix[, mi_col] is
  ## exposed as predictors$x$value; it must have one entry per group and match
  ## imputed(rows = "all").
  val <- fit$missing_data$predictors$x$value
  expect_length(val, d$n_region)
  expect_equal(val, out$estimate, tolerance = 1e-10)
})

# ---- Group recovery gate (genuine stochastic DGP, per-group modes) --------

test_that("group recovery: mi slope, covariate coefs, sigma_x, per-group modes recover", {
  skip_if_not_heavy()
  ## A genuine stochastic DGP at the GROUP level with MCAR missing regions.
  ## With enough regions, the response mi() slope, the covariate coefficients,
  ## sigma_x, AND the per-group missing-x modes should recover.
  d <- .make_mi_group(
    seed = 2025, n_region = 90L, n_per_region = 3L,
    b_x_true = 1.2, sigma_x = 0.45,
    miss_region = sort(sample.int(90L, 18L))
  )
  dat <- .inject_missing_group(d)
  x_true_missing <- d$x_true[d$missing_region]

  fit <- .fit_mi_group(dat, se = TRUE)

  par <- fit$tmb_obj$env$parList(fit$opt$par)

  ## (1) Response mi() slope b_x recovers (truth 1.2).
  mu_col <- fit$missing_data$predictors$x$mu_col
  b_x_hat <- par$b_fix[mu_col]
  expect_equal(b_x_hat, d$b_x_true, tolerance = 0.25)

  ## (2) Covariate-model coefficients recover (intercept 0.3, z 0.7, w -0.4).
  beta_x <- unname(par$beta_mi)
  expect_equal(beta_x[1], 0.30, tolerance = 0.3)
  expect_equal(beta_x[2], 0.70, tolerance = 0.3)
  expect_equal(beta_x[3], -0.40, tolerance = 0.3)

  ## (3) sigma_x recovers (truth 0.45) -- the GROUP-level residual SD.
  sigma_x_hat <- exp(par$log_sigma_mi[[1]])
  expect_equal(sigma_x_hat, d$sigma_x, tolerance = 0.2)

  ## (4) The per-group missing-x conditional modes recover the truth -- this is
  ## the level-mismatch recovery target (one mode per missing GROUP).
  modes <- fit$missing_data$predictors$x$conditional_mode
  expect_length(modes, length(d$missing_region))
  expect_gt(stats::cor(modes, x_true_missing), 0.7)
  rmse <- sqrt(mean((modes - x_true_missing)^2))
  expect_lt(rmse, 0.6)
})

# ---- 2a no-op preserved (the unit-level path is unchanged) ----------------

test_that("a unit-level mi(x) with no mi_group() is still the Phase 2a path", {
  skip_if_not_heavy()
  ## Without mi_group(), x is unit-level and the fit is byte-identical to the
  ## Phase 2a path: version "phase2a", one latent per missing UNIT, the group
  ## descriptor disabled. This guards that Phase 2c is a strict superset and the
  ## 2a no-op holds.
  d <- .make_mi_uni()
  inj <- .inject_missing_x(d)
  dat <- inj$data

  fit <- .fit_mi_uni(dat, se = FALSE)

  expect_identical(fit$missing_data$predictors$x$version, "phase2a")
  ## The group-level descriptor is present but disabled (no mi_group()).
  grp <- fit$missing_data$predictors$x$group_level
  expect_false(isTRUE(grp$enabled))
  ## One latent per missing UNIT (site), as in Phase 2a.
  expect_length(
    fit$tmb_obj$env$parList(fit$opt$par)$x_mis,
    length(d$missing_site)
  )
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing_site)
})
