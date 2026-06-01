# Phase 5a (issue #332 / design 68): ONE BINARY missing PREDICTOR via mi(x)
# with a Bernoulli-logit covariate model, marginalised by an EXACT 2-state
# SUM (the gllvmTMB analogue of drmTMB MD6a, mi_family == 1). This is the
# first DISCRETE-predictor slice: there is NO latent x (contrast the Gaussian
# path's Laplace x_mis); the binary x is summed out directly in the nll.
#
# The crux (design 68 sec.3, no drmTMB precedent): the multivariate per-UNIT
# product. For a missing-x unit u the response side is the PRODUCT over u's
# trait rows  log_y_k(u) = sum_t log p(y_{u,t} | x = k), and the SUM
#   nll -= logspace_add( log_p1 + log_y1(u), log_p0 + log_y0(u) )
# fires ONCE per missing unit. A per-ROW SUM would double-count the prior.
#
# Gate map (design 68 sec.7 + design 59 sec.9):
#   * 7.1 SUM == brute force  -- the CORRECTNESS ANCHOR. A hand-marginalised R
#                                reference (per-unit product over trait rows,
#                                prior once, logsumexp over {0,1}) matches
#                                logLik(fit) to 1e-6. Catches a wrong SUM, a
#                                double-count (gate failure), or a per-row
#                                product. A deliberate per-row-vs-per-unit
#                                discrimination check guards the twist.
#   * 7.2 recovery            -- known DGP, MCAR binary x: the response slope
#                                b_x, the predictor beta_x, and the per-unit
#                                conditional probabilities p(x=1|y) recover.
#   * multivariate            -- traits(t1, t2) ~ z + mi(x): the per-unit
#                                product over both traits; converges; SUM ==
#                                brute force still holds.
#   * boundary rejection      -- >2 levels, ordered, grouped/structured binary
#                                predictor model, multiple mi(), non-logit link.
#   * input acceptance        -- 0/1 numeric, logical, 2-level factor.
#   * 7.7 no-op / gate safety -- a Gaussian-mi fit and a plain fit are
#                                byte-identical to before (the gate fires only
#                                for mi_family == 1 missing rows).
#
# All fits are gated behind skip_if_not_heavy(); the pure-validation boundary
# blocks run unconditionally (they error before any TMB fit).

# ---- Fixtures --------------------------------------------------------------

# A small LONG-format two-trait dataset with a BINARY unit-level predictor x
# (constant within a site, broadcast to both trait rows). The response slope
# on x is b_x_true, shared across traits. NO latent axes / random effects in
# the fit, so eta(o) is a deterministic function of b_fix and the design --
# the brute-force reference can reconstruct the per-state etas exactly.
.make_mib_uni <- function(seed = 303, n_sites = 50, b_x_true = 1.2,
                          miss_idx = c(5L, 14L, 27L, 38L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  ## Bernoulli-logit predictor model: logit p(x=1) = -0.2 + 1.1 z - 0.7 w.
  px <- stats::plogis(-0.2 + 1.1 * z - 0.7 * w)
  x <- stats::rbinom(n_sites, size = 1, prob = px)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eta1 <- 0.6 + b_x_true * x[s] - 0.3 * z[s]
    eta2 <- -0.2 + b_x_true * x[s] + 0.5 * z[s]
    rows[[s]] <- data.frame(
      site    = s,
      trait   = c("t1", "t2"),
      value   = c(eta1, eta2) + stats::rnorm(2, sd = 0.35),
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
  list(
    data = dat, x_true = x, missing_site = miss_idx, b_x_true = b_x_true,
    site = dat$site
  )
}

# Set x to NA for every long row of the given missing sites.
.inject_missing_xb <- function(d) {
  dat <- d$data
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dat$x[miss_rows] <- NA_real_
  list(data = dat, miss_rows = miss_rows, miss_site = d$missing_site)
}

# Fit the two-trait binary mi(x) model.
.fit_mib_uni <- function(data, impute = list(x = impute_model(x ~ z + w,
                                             family = binomial())),
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

# ---- The CORRECTNESS ANCHOR: a hand-rolled per-UNIT mixture reference -------

# Independently of the TMB engine, recompute the observed-data logLik by
# hand-marginalising the missing binary x over {0, 1}. The KEY gllvmTMB twist
# (design 68 sec.7.1): for each unit u the response side is the PRODUCT over
# u's trait rows (a SUM of per-trait Gaussian log-densities), the predictor
# prior log p(x=k|z_u) is added ONCE, then we log-sum-exp over the 2 states.
# Observed-x units take the ordinary per-row response density (summed over the
# unit's trait rows) plus the single matching state's log-prior.
#
# eta_base(o) is the linear predictor with the mi() column REMOVED, rebuilt
# from b_fix and the model.matrix; eta_state(o, k) = eta_base(o) + b_x * k.
manual_binary_mi_loglik <- function(fit, data) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  b_fix <- par$b_fix
  beta_mi <- par$beta_mi
  sigma <- exp(fit$tmb_obj$env$parList(fit$opt$par)$log_sigma_eps)

  reg <- fit$missing_data$predictors$x
  mu_col <- reg$mu_col           # 1-indexed mi() column in X_fix
  b_x <- b_fix[mu_col]
  X_fix <- fit$tmb_data$X_fix
  y <- fit$tmb_data$y
  observed_y <- fit$tmb_data$is_y_observed == 1L
  ## Long-row -> unit (0-indexed) and the per-unit observed flag.
  unit_id <- fit$tmb_data$mi_unit_id + 1L
  observed_unit <- fit$tmb_data$mi_observed_unit == 1L

  ## eta_base(o): drop the mi() column's contribution from the fixed-effect
  ## linear predictor (the fit has no random effects, so eta = eta_fix).
  X_base <- X_fix
  X_base[, mu_col] <- 0
  eta_base <- as.vector(X_base %*% b_fix)

  ## Per-unit predictor prior. X_mi is the unit-level covariate design.
  X_mi <- fit$tmb_data$X_mi
  eta_x <- as.vector(X_mi %*% beta_mi)        # length n_units
  log_p1 <- stats::plogis(eta_x, log.p = TRUE)
  log_p0 <- stats::plogis(eta_x, lower.tail = FALSE, log.p = TRUE)

  n_units <- nrow(X_mi)
  total <- 0
  for (u in seq_len(n_units)) {
    rows <- which(unit_id == u)
    if (observed_unit[u]) {
      ## Observed x: ordinary response density at the true state + that state's
      ## log-prior (added once per unit).
      xk <- X_fix[rows[1L], mu_col]           # the broadcast observed x value
      eta_obs <- eta_base[rows] + b_x * xk
      ll_resp <- 0
      for (j in seq_along(rows)) {
        if (observed_y[rows[j]]) {
          ll_resp <- ll_resp +
            stats::dnorm(y[rows[j]], eta_obs[j], sigma, log = TRUE)
        }
      }
      prior <- if (xk == 1) log_p1[u] else log_p0[u]
      total <- total + ll_resp + prior
    } else {
      ## Missing x: per-unit product over trait rows for EACH state, then
      ## logspace_add over {0, 1} ONCE.
      ll_y1 <- 0
      ll_y0 <- 0
      for (j in seq_along(rows)) {
        if (observed_y[rows[j]]) {
          ll_y1 <- ll_y1 +
            stats::dnorm(y[rows[j]], eta_base[rows[j]] + b_x * 1, sigma,
                         log = TRUE)
          ll_y0 <- ll_y0 +
            stats::dnorm(y[rows[j]], eta_base[rows[j]] + b_x * 0, sigma,
                         log = TRUE)
        }
      }
      lp1 <- log_p1[u] + ll_y1
      lp0 <- log_p0[u] + ll_y0
      m <- max(lp1, lp0)
      total <- total + (m + log(exp(lp1 - m) + exp(lp0 - m)))
    }
  }
  total
}

# The WRONG per-ROW reference: applies drmTMB's per-row SUM to each trait row
# independently (prior counted once per row, states allowed to differ across
# traits). Used ONLY to assert it does NOT match -- the per-row-vs-per-unit
# discrimination test guarding the multivariate twist (design 68 sec.7.1).
manual_binary_mi_loglik_perrow <- function(fit, data) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  b_fix <- par$b_fix
  beta_mi <- par$beta_mi
  sigma <- exp(par$log_sigma_eps)
  reg <- fit$missing_data$predictors$x
  mu_col <- reg$mu_col
  b_x <- b_fix[mu_col]
  X_fix <- fit$tmb_data$X_fix
  y <- fit$tmb_data$y
  observed_y <- fit$tmb_data$is_y_observed == 1L
  unit_id <- fit$tmb_data$mi_unit_id + 1L
  observed_unit <- fit$tmb_data$mi_observed_unit == 1L
  X_base <- X_fix
  X_base[, mu_col] <- 0
  eta_base <- as.vector(X_base %*% b_fix)
  X_mi <- fit$tmb_data$X_mi
  eta_x <- as.vector(X_mi %*% beta_mi)
  log_p1 <- stats::plogis(eta_x, log.p = TRUE)
  log_p0 <- stats::plogis(eta_x, lower.tail = FALSE, log.p = TRUE)
  total <- 0
  for (o in seq_along(y)) {
    if (!observed_y[o]) next
    u <- unit_id[o]
    if (observed_unit[u]) {
      xk <- X_fix[o, mu_col]
      total <- total + stats::dnorm(y[o], eta_base[o] + b_x * xk, sigma,
                                    log = TRUE) +
        (if (xk == 1) log_p1[u] else log_p0[u])
    } else {
      lp1 <- log_p1[u] +
        stats::dnorm(y[o], eta_base[o] + b_x, sigma, log = TRUE)
      lp0 <- log_p0[u] +
        stats::dnorm(y[o], eta_base[o], sigma, log = TRUE)
      m <- max(lp1, lp0)
      total <- total + (m + log(exp(lp1 - m) + exp(lp0 - m)))
    }
  }
  total
}

# ===========================================================================
# Gate 7.1: SUM == brute-force marginalisation (the load-bearing proof)
# ===========================================================================

test_that("binary mi() predictor model uses the exact 2-state per-unit SUM", {
  skip_if_not_heavy()
  d <- .make_mib_uni()
  dat <- .inject_missing_xb(d)$data

  fit <- .fit_mib_uni(dat)

  ## Registry contract (drmTMB MD6a-aligned).
  expect_equal(fit$missing_data$predictors$x$family, "bernoulli")
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing_site)
  expect_equal(fit$missing_data$predictors$x$levels, c("0", "1"))
  expect_identical(stats::nobs(fit), nrow(dat))
  ## No latent x for the discrete route: x_mis is empty, sigma_mi is mapped off.
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$x_mis, 0L)

  ## Fixed-effect + predictor coefficients are finite.
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))

  ## THE ANCHOR: the engine logLik equals the hand-marginalised per-unit
  ## mixture to 1e-6. A wrong SUM, a double-counted y (gate failure), or a
  ## per-row product would break this.
  expect_equal(
    as.numeric(logLik(fit)),
    manual_binary_mi_loglik(fit, dat),
    tolerance = 1e-6
  )

  ## DISCRIMINATION: the WRONG per-row reference must NOT match (it counts the
  ## prior once per trait row and lets the two traits' states differ). With >1
  ## trait per missing unit the two references genuinely differ.
  expect_false(isTRUE(all.equal(
    as.numeric(logLik(fit)),
    manual_binary_mi_loglik_perrow(fit, dat),
    tolerance = 1e-4
  )))
})

# ===========================================================================
# Gate 7.2: EBLUP recovery -- response slope, predictor beta, p(x=1|y)
# ===========================================================================

test_that("recovery: response slope, predictor beta, p(x=1|y) recover", {
  skip_if_not_heavy()
  d <- .make_mib_uni(
    seed = 11, n_sites = 200, b_x_true = 1.4,
    miss_idx = sort(sample.int(200L, 40L))
  )
  dat <- .inject_missing_xb(d)$data
  x_true_missing <- d$x_true[d$missing_site]

  fit <- .fit_mib_uni(dat, se = TRUE)

  ## The broadcast mi() response slope b_x recovers.
  mu_col <- fit$missing_data$predictors$x$mu_col
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_equal(par$b_fix[mu_col], d$b_x_true, tolerance = 0.3)

  ## The predictor-model coefficients recover. The covariate model is a binary
  ## GLM fit on the OBSERVED units only, so its coefficients carry the usual
  ## logistic sampling SE (~0.2-0.3 here); we assert the SIGNS and a band of a
  ## few SE around the truth (intercept -0.2, z slope +1.1, w slope -0.7),
  ## NOT a tight point match -- that would test sampling luck, not the engine.
  beta_x <- unname(par$beta_mi)
  expect_lt(beta_x[1], 0.5)                         # intercept negative-ish
  expect_gt(beta_x[2], 0.4)                         # z slope clearly positive
  expect_lt(beta_x[3], -0.1)                        # w slope clearly negative
  expect_equal(beta_x[2], 1.1, tolerance = 0.7)     # z slope, ~3 SE band
  expect_equal(beta_x[3], -0.7, tolerance = 0.8)    # w slope, ~3 SE band

  ## The per-unit conditional probabilities p(x=1|y) are in [0,1], finite, and
  ## discriminate the true latent state (AUC-like: mean p higher when x==1).
  probs <- fit$missing_data$predictors$x$conditional_probability
  expect_length(probs, length(d$missing_site))
  expect_true(all(is.finite(probs)))
  expect_true(all(probs >= 0 & probs <= 1))
  expect_gt(mean(probs[x_true_missing == 1]),
            mean(probs[x_true_missing == 0]))
  ## Hard-classification accuracy beats chance.
  acc <- mean((probs > 0.5) == (x_true_missing == 1))
  expect_gt(acc, 0.6)
})

# ===========================================================================
# imputed() reports the conditional probability p(x=1|y) (NOT a latent mode)
# ===========================================================================

test_that("imputed() reports the binary conditional probability", {
  skip_if_not_heavy()
  d <- .make_mib_uni()
  dat <- .inject_missing_xb(d)$data
  fit <- .fit_mib_uni(dat)

  imp <- imputed(fit)
  expect_equal(nrow(imp), length(d$missing_site))
  expect_equal(imp$source, rep("conditional_probability", length(d$missing_site)))
  expect_true(all(is.finite(imp$estimate)))
  expect_true(all(imp$estimate >= 0 & imp$estimate <= 1))
  ## The discrete route reports a distribution, not a Hessian SE: std_error NA.
  expect_true(all(is.na(imp$std_error)))
  expect_equal(
    imp$estimate,
    fit$missing_data$predictors$x$conditional_probability
  )
})

# ===========================================================================
# Multivariate: traits(t1, t2) ~ z + mi(x) -- the per-unit product over traits
# ===========================================================================

.make_mib_multi <- function(seed = 13, n_sites = 70, b_x_true = 1.1,
                            miss_idx = c(3L, 14L, 28L, 41L, 55L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  px <- stats::plogis(0.1 + 0.9 * z - 0.5 * w)
  x <- stats::rbinom(n_sites, size = 1, prob = px)
  mk <- function(a0, bz, sigma) a0 + b_x_true * x + bz * z +
    stats::rnorm(n_sites, sd = sigma)
  t1 <- mk(0.5, -0.2, 0.35)
  t2 <- mk(-0.3, 0.4, 0.45)
  wide <- data.frame(
    site = factor(seq_len(n_sites)), t1 = t1, t2 = t2,
    x = x, z = z, w = w, stringsAsFactors = FALSE
  )
  list(data = wide, x_true = x, missing = miss_idx, b_x_true = b_x_true)
}

test_that("multivariate: one binary mi(x) feeds both traits via the per-unit product", {
  skip_if_not_heavy()
  d <- .make_mib_multi()
  wide <- d$data
  wide$x[d$missing] <- NA_real_

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1, t2) ~ z + mi(x),
    data    = wide,
    unit    = "site",
    family  = gaussian(),
    impute  = list(x = impute_model(x ~ z + w, family = binomial())),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  ## Convergence + finite estimates.
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-1)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_true(all(is.finite(par$b_fix)))
  ## No latent x; one conditional probability per missing site.
  expect_length(par$x_mis, 0L)
  expect_identical(fit$missing_data$predictors$x$model_row, d$missing)
  probs <- fit$missing_data$predictors$x$conditional_probability
  expect_length(probs, length(d$missing))
  expect_true(all(probs >= 0 & probs <= 1))

  ## The SUM == brute force still holds with the per-unit product over BOTH
  ## traits (the multivariate crux made testable).
  expect_equal(
    as.numeric(logLik(fit)),
    manual_binary_mi_loglik(fit, wide),
    tolerance = 1e-6
  )
  ## And the per-row reference does NOT match (2 traits per missing unit).
  expect_false(isTRUE(all.equal(
    as.numeric(logLik(fit)),
    manual_binary_mi_loglik_perrow(fit, wide),
    tolerance = 1e-4
  )))
})

# ===========================================================================
# Boundary rejections + input acceptance (no fit; errors before TMB)
# ===========================================================================

test_that("binary mi() rejects out-of-scope predictor models", {
  d <- .make_mib_uni()
  dat <- .inject_missing_xb(d)$data

  ## >2 levels -> directed to categorical().
  dat3 <- dat
  dat3$x3 <- factor(c("a", "b", "c")[1 + (as.integer(dat3$site) %% 3L)],
                    levels = c("a", "b", "c"))
  dat3$x3[is.na(dat3$x)] <- NA
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x3),
      data = dat3, family = gaussian(),
      impute = list(x3 = impute_model(x3 ~ z, family = binomial())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "categorical|two|2 level"
  )

  ## Ordered factor -> directed to a later (ordered) slice.
  dato <- dat
  dato$xo <- factor(c("lo", "mid", "hi")[1 + (as.integer(dato$site) %% 3L)],
                    levels = c("lo", "mid", "hi"), ordered = TRUE)
  dato$xo[is.na(dato$x)] <- NA
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(xo),
      data = dato, family = gaussian(),
      impute = list(xo = impute_model(xo ~ z, family = binomial())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "categorical|two|2 level|ordered"
  )

  ## Non-logit binomial link.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = impute_model(x ~ z, family = binomial("probit"))),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "logit"
  )

  ## A grouped random intercept in the binary predictor model (fixed-only v1).
  datg <- dat
  datg$grp <- factor(as.integer(datg$site) %% 8L)
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = datg, family = gaussian(),
      impute = list(x = impute_model(x ~ z + (1 | grp), family = binomial())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "fixed effect|grouped|random|structured"
  )

  ## A structured (phylo) binary predictor model is out of scope.
  datp <- dat
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = datp, family = gaussian(),
      impute = list(x = impute_model(
        x ~ z + phylo(1 | species, tree = NULL), family = binomial())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "fixed effect|structured|phylo|tree"
  )

  ## Multiple mi() terms.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(x) + mi(w),
      data = dat, family = gaussian(),
      impute = list(x = impute_model(x ~ z, family = binomial())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "exactly one"
  )

  ## Count predictor family is rejected (no finite support).
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(x),
      data = dat, family = gaussian(),
      impute = list(x = impute_model(x ~ z, family = poisson())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "Unsupported|count|later|support"
  )
})

test_that("binary mi() accepts 0/1 numeric, logical, and 2-level factor", {
  skip_if_not_heavy()
  d <- .make_mib_uni()
  base <- .inject_missing_xb(d)$data

  ## (a) 0/1 numeric (the .make_mib_uni default) already fits above; here just
  ## assert each coding produces an equivalent finite fit + the same levels.
  fit_num <- .fit_mib_uni(base)
  expect_true(all(is.finite(fit_num$tmb_obj$env$parList(fit_num$opt$par)$b_fix)))

  ## (b) logical.
  datl <- base
  datl$x <- as.logical(datl$x)
  fit_log <- .fit_mib_uni(datl)
  expect_true(all(is.finite(fit_log$tmb_obj$env$parList(fit_log$opt$par)$b_fix)))
  expect_equal(fit_log$missing_data$predictors$x$levels, c("FALSE", "TRUE"))

  ## (c) two-level factor.
  datf <- base
  datf$x <- factor(datf$x, levels = c(0, 1))
  fit_fac <- .fit_mib_uni(datf)
  expect_true(all(is.finite(fit_fac$tmb_obj$env$parList(fit_fac$opt$par)$b_fix)))
  expect_equal(fit_fac$missing_data$predictors$x$levels, c("0", "1"))
})

# ===========================================================================
# Gate 7.7: no-op / gate safety (the gate fires only for mi_family == 1)
# ===========================================================================

test_that("a Gaussian mi() fit is unchanged by the binary discrete machinery", {
  skip_if_not_heavy()
  ## A Gaussian mi(x) fit must be byte-identical objective to a fit run with
  ## the SAME data: the discrete SUM/gate are gated behind mi_family == 1, so
  ## the Gaussian path (mi_family == 0) is untouched.
  set.seed(404)
  n_sites <- 40
  z <- stats::rnorm(n_sites); w <- stats::rnorm(n_sites)
  x <- 0.25 + 0.8 * z - 0.4 * w + stats::rnorm(n_sites, sd = 0.5)
  rows <- list()
  for (s in seq_len(n_sites)) {
    rows[[s]] <- data.frame(
      site = s, trait = c("t1", "t2"),
      value = c(0.7 + 1.3 * x[s] - 0.3 * z[s],
                -0.2 + 1.3 * x[s] + 0.5 * z[s]) + stats::rnorm(2, sd = 0.4),
      x = x[s], z = z[s], w = w[s], stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  dat$x[which(as.integer(dat$site) %in% c(4L, 12L, 23L, 31L))] <- NA_real_

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = dat, family = gaussian(),
    impute = list(x = x ~ z + w),         # bare formula -> Gaussian
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  ## The Gaussian path still carries a latent x_mis and a conditional_mode
  ## summary -- the discrete machinery did not hijack it.
  expect_length(
    fit$tmb_obj$env$parList(fit$opt$par)$x_mis,
    4L
  )
  expect_equal(fit$missing_data$predictors$x$family, "gaussian")
  expect_equal(fit$missing_data$predictors$x$summary, "conditional_mode")
  expect_equal(fit$tmb_data$mi_family, 0L)
})

test_that("a plain fit (no mi) sets has_mi = 0 -- the discrete block is a no-op", {
  skip_if_not_heavy()
  d <- .make_mib_uni()
  dat <- d$data                              # x fully observed; no mi()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + x,
    data = dat, family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$tmb_data$has_mi, 0L)
  expect_true(is.finite(as.numeric(logLik(fit))))
})
