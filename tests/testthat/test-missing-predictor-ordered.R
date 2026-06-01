# Phase 5b (issue #332 / design 68 sec.1.2): ONE ORDERED missing PREDICTOR via
# mi(score) with a cumulative-logit covariate model, marginalised by an EXACT
# K-state SUM (the gllvmTMB analogue of drmTMB MD6b, mi_family == 2). This
# EXTENDS Phase 5a binary: there is still NO latent x (the discrete x is summed
# out directly in the nll); the M x 2 accumulator generalises to M x K; the
# single-column delta-swap generalises to the FULL-SWAP via a stacked state
# design X_fix_state (an ordered factor expands to K-1 contrast columns).
#
# The crux (design 68 sec.3, no drmTMB precedent): the multivariate per-UNIT
# product. For a missing-x unit u the response side is the PRODUCT over u's
# trait rows  log_y_k(u) = sum_t log p(y_{u,t} | x = k), and the SUM
#   nll -= logspace_add_over_k( log p(x=k|z_u) + log_y_k(u) )
# fires ONCE per missing unit. A per-ROW SUM would double-count the K-state
# prior.
#
# The ONE cutpoint subtlety (design 68 sec.1.2): the ordered PREDICTOR keeps
# K-1 FREE cutpoints (theta_ord(0) is a free base, theta_ord(1..K-2) are log-
# increments), MIRRORING drmTMB -- NOT gllvmTMB's fid-14 tau_1 = 0 response
# convention. The predictor link is cumulative LOGIT.
#
# Gate map (design 68 sec.7 + design 59 sec.9):
#   * 7.1 SUM == brute force  -- the CORRECTNESS ANCHOR. A hand-marginalised R
#                                reference (per-unit product over trait rows,
#                                cumulative-logit prior once, logsumexp over the
#                                K states with the FULL-SWAP per-state eta)
#                                matches logLik(fit) to 1e-6. Catches a wrong
#                                K-state SUM, a double-count (gate failure), a
#                                per-row product, or a wrong cutpoint
#                                reconstruction. A per-row-vs-per-unit
#                                discrimination check guards the twist.
#   * 7.2 recovery            -- known DGP, MCAR ordered x: the response slope
#                                b_fix, the predictor beta_x, the cutpoints, and
#                                the per-unit expected category score recover.
#   * multivariate            -- traits(t1, t2) ~ z + mi(score): the per-unit
#                                product over both traits across K states;
#                                converges; SUM == brute force still holds.
#   * boundary rejection      -- 2-level ordered (-> binary), unordered factor
#                                (-> categorical), grouped/structured ordered
#                                predictor model, multiple mi().
#   * input acceptance        -- ordered factor (>=3 levels), integer scores.
#   * 7.7 no-op / gate safety -- a binary-mi fit, a Gaussian-mi fit, and a plain
#                                fit are byte-identical to before (the gate and
#                                the K-state block fire only for mi_family == 2).
#
# All fits are gated behind skip_if_not_heavy(); the pure-validation boundary
# blocks run unconditionally (they error before any TMB fit).

# ---- Fixtures --------------------------------------------------------------

# A small LONG-format two-trait dataset with an ORDERED unit-level predictor
# `score` (3 levels low/medium/high, constant within a site, broadcast to both
# trait rows). The per-state response effect is the ordered-factor contrast,
# shared across traits. NO latent axes / random effects in the fit, so eta(o)
# is a deterministic function of b_fix and the design -- the brute-force
# reference can reconstruct the per-state etas exactly via the state design.
.make_mio_uni <- function(seed = 707, n_sites = 60,
                          miss_idx = c(5L, 14L, 27L, 41L, 53L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  ## Cumulative-logit ordered predictor model (NO intercept; cutpoints carry
  ## the location): a latent eta_x = 1.1 z - 0.7 w cut at fixed thresholds.
  eta_x <- 1.1 * z - 0.7 * w
  score_int <- cut(
    eta_x + stats::rnorm(n_sites, sd = 0.5),
    breaks = c(-Inf, -0.6, 0.6, Inf),
    labels = FALSE
  )
  ## Per-state response effect (ordered category effect), shared across traits.
  score_effect <- c(-0.5, 0.2, 0.8)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eff <- score_effect[score_int[s]]
    eta1 <- 0.6 + eff - 0.3 * z[s]
    eta2 <- -0.2 + eff + 0.5 * z[s]
    rows[[s]] <- data.frame(
      site    = s,
      trait   = c("t1", "t2"),
      value   = c(eta1, eta2) + stats::rnorm(2, sd = 0.30),
      score   = score_int[s],
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
  ## Ordered factor with 3 levels.
  dat$score <- ordered(
    c("low", "medium", "high")[dat$score],
    levels = c("low", "medium", "high")
  )
  list(
    data = dat, score_true = score_int, missing_site = miss_idx,
    site = dat$site
  )
}

# A LONG-format two-trait dataset whose ordered `score` is drawn from a GENUINE
# cumulative-logit model (so the fitted beta_x + cutpoints recover the
# GENERATING values, not an artifact of cut()-on-noisy-latent). The predictor
# model has NO intercept (cutpoints carry the location), matching the engine's
# K-1-free-cutpoint parametrisation. eta_x = b_z z + b_w w; the K=3 category is
# sampled from P(score=k|z) = F(c_k - eta_x) - F(c_{k-1} - eta_x), F = plogis.
.make_mio_cumlogit <- function(seed = 21, n_sites = 300,
                               b_z = 1.1, b_w = -0.7,
                               cutpoints = c(-0.8, 0.8),
                               n_miss = 45L) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  eta_x <- b_z * z + b_w * w
  ## Cumulative-logit cell probabilities, then sample the category per unit.
  p1 <- stats::plogis(cutpoints[1] - eta_x)
  p2 <- stats::plogis(cutpoints[2] - eta_x) - p1
  p3 <- 1 - stats::plogis(cutpoints[2] - eta_x)
  score_int <- vapply(seq_len(n_sites), function(s) {
    sample.int(3L, size = 1L, prob = c(p1[s], p2[s], p3[s]))
  }, integer(1))
  ## Per-state response effect, shared across traits.
  score_effect <- c(-0.5, 0.2, 0.8)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eff <- score_effect[score_int[s]]
    rows[[s]] <- data.frame(
      site  = s, trait = c("t1", "t2"),
      value = c(0.6 + eff - 0.3 * z[s], -0.2 + eff + 0.5 * z[s]) +
        stats::rnorm(2, sd = 0.30),
      score = score_int[s], z = z[s], w = w[s],
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site  <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  dat$score <- ordered(c("low", "medium", "high")[dat$score],
                       levels = c("low", "medium", "high"))
  miss_idx <- sort(sample.int(n_sites, n_miss))
  list(data = dat, score_true = score_int, missing_site = miss_idx,
       b_z = b_z, b_w = b_w, cutpoints = cutpoints)
}

# Set score to NA for every long row of the given missing sites.
.inject_missing_xo <- function(d) {
  dat <- d$data
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dat$score[miss_rows] <- NA
  list(data = dat, miss_rows = miss_rows, miss_site = d$missing_site)
}

# Fit the two-trait ordered mi(score) model.
.fit_mio_uni <- function(data,
                         impute = list(score = impute_model(
                           score ~ z + w, family = cumulative_logit())),
                         missing = miss_control(predictor = "model"),
                         se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(score),
    data    = data,
    family  = gaussian(),
    impute  = impute,
    missing = missing,
    control = gllvmTMBcontrol(se = se)
  )))
}

# Reconstruct cutpoints c_1, ..., c_{K-1} from the K-1 FREE raw vector
# theta_ord = (c_1, log-increments...). MUST match the C++ reconstruction
# (design 68 sec.1.2: K-1 free, NOT tau_1 = 0).
.cutpoints_from_theta <- function(theta) {
  out <- numeric(length(theta))
  if (length(theta) == 0L) return(out)
  out[1L] <- theta[1L]
  if (length(theta) > 1L) {
    for (j in 2:length(theta)) out[j] <- out[j - 1L] + exp(theta[j])
  }
  out
}

# Cumulative-logit cell log-probabilities (the predictor prior), per the design
# 68 sec.1.2 stable form: state 1 = log F(c_1 - eta), state K = log(1 - F(c_{K-1}
# - eta)), middle = log[F(c_k - eta) - F(c_{k-1} - eta)]. F = plogis.
.ordered_logprob_matrix <- function(eta, cutpoints) {
  K <- length(cutpoints) + 1L
  out <- matrix(NA_real_, nrow = length(eta), ncol = K)
  out[, 1L] <- stats::plogis(cutpoints[1L] - eta, log.p = TRUE)
  if (K > 2L) {
    for (k in 2:(K - 1L)) {
      upper <- stats::plogis(cutpoints[k] - eta)
      lower <- stats::plogis(cutpoints[k - 1L] - eta)
      out[, k] <- log(pmax(upper - lower, .Machine$double.eps))
    }
  }
  out[, K] <- stats::plogis(cutpoints[K - 1L] - eta,
                            lower.tail = FALSE, log.p = TRUE)
  out
}

# ---- The CORRECTNESS ANCHOR: a hand-rolled per-UNIT K-state mixture ---------
#
# Independently of the TMB engine, recompute the observed-data logLik by
# hand-marginalising the missing ordered `score` over its K states. The KEY
# gllvmTMB twist (design 68 sec.7.1): for each unit u the response side is the
# PRODUCT over u's trait rows (a SUM of per-trait Gaussian log-densities), the
# cumulative-logit prior log p(score=k|z_u) is added ONCE, then we log-sum-exp
# over the K states. The per-state response eta uses the FULL-SWAP via the
# stacked state design X_fix_state (state fast, o_local*K + k), so the ordered
# factor's K-1 contrast columns are all forced to state k at once. Observed-x
# units take the ordinary per-row response density plus the single matching
# state's log-prior.
manual_ordered_mi_loglik <- function(fit) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  b_fix <- par$b_fix
  beta_mi <- par$beta_mi
  theta_ord <- par$theta_ord
  sigma <- exp(par$log_sigma_eps)

  reg <- fit$missing_data$predictors$score
  K <- reg$n_state

  X_fix <- fit$tmb_data$X_fix
  y <- fit$tmb_data$y
  observed_y <- fit$tmb_data$is_y_observed == 1L
  unit_id <- fit$tmb_data$mi_unit_id + 1L           # 1-indexed long-row -> unit
  observed_unit <- fit$tmb_data$mi_observed_unit == 1L
  ## The per-state fixed-effect linear predictor uses the FULL-SWAP. eta(o) is
  ## the assembled fixed-effect linear predictor (no random effects here).
  eta_obs <- as.vector(X_fix %*% b_fix)

  ## Stacked state design (filtered to missing-unit long rows). mi_state_row(o)
  ## (0-indexed) gives the base row of the K-block for long row o, or a sentinel
  ## (< 0) for observed-unit rows. X_fix_state row (o_state_base + k) is the long
  ## fixed design of row o with `score` forced to level (k+1).
  X_fix_state <- fit$tmb_data$X_fix_state
  mi_state_row <- fit$tmb_data$mi_state_row          # 0-indexed base or sentinel

  ## Per-unit predictor prior (cumulative logit). X_mi is the unit-level
  ## intercept-free covariate design.
  X_mi <- fit$tmb_data$X_mi
  eta_x <- as.vector(X_mi %*% beta_mi)               # length n_units
  cutpoints <- .cutpoints_from_theta(theta_ord)
  log_prior <- .ordered_logprob_matrix(eta_x, cutpoints)   # n_units x K

  ## The observed integer score per unit (1..K) at observed units.
  x_unit_int <- fit$tmb_data$mi_x_unit               # 1..K observed, placeholder else

  n_units <- nrow(X_mi)
  total <- 0
  for (u in seq_len(n_units)) {
    rows <- which(unit_id == u)
    if (observed_unit[u]) {
      ## Observed score: ordinary response density at eta(o) + that state's
      ## log-prior (added once per unit).
      state <- as.integer(round(x_unit_int[u]))      # 1..K
      ll_resp <- 0
      for (o in rows) {
        if (observed_y[o]) {
          ll_resp <- ll_resp + stats::dnorm(y[o], eta_obs[o], sigma, log = TRUE)
        }
      }
      total <- total + ll_resp + log_prior[u, state]
    } else {
      ## Missing score: per-unit product over trait rows for EACH state via the
      ## full-swap, then logspace_add over the K states ONCE.
      log_terms <- log_prior[u, ]
      for (o in rows) {
        if (!observed_y[o]) next
        base <- mi_state_row[o]                       # 0-indexed K-block base
        for (k in seq_len(K)) {
          eta_state <- eta_obs[o] -
            sum(X_fix[o, ] * b_fix) +
            sum(X_fix_state[base + k, ] * b_fix)
          log_terms[k] <- log_terms[k] +
            stats::dnorm(y[o], eta_state, sigma, log = TRUE)
        }
      }
      m <- max(log_terms)
      total <- total + (m + log(sum(exp(log_terms - m))))
    }
  }
  total
}

# The WRONG per-ROW reference: applies a per-row K-state SUM to each trait row
# independently (prior counted once per row, states allowed to differ across
# traits). Used ONLY to assert it does NOT match -- the per-row-vs-per-unit
# discrimination test guarding the multivariate twist (design 68 sec.7.1).
manual_ordered_mi_loglik_perrow <- function(fit) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  b_fix <- par$b_fix
  beta_mi <- par$beta_mi
  theta_ord <- par$theta_ord
  sigma <- exp(par$log_sigma_eps)
  reg <- fit$missing_data$predictors$score
  K <- reg$n_state
  X_fix <- fit$tmb_data$X_fix
  y <- fit$tmb_data$y
  observed_y <- fit$tmb_data$is_y_observed == 1L
  unit_id <- fit$tmb_data$mi_unit_id + 1L
  observed_unit <- fit$tmb_data$mi_observed_unit == 1L
  eta_obs <- as.vector(X_fix %*% b_fix)
  X_fix_state <- fit$tmb_data$X_fix_state
  mi_state_row <- fit$tmb_data$mi_state_row
  X_mi <- fit$tmb_data$X_mi
  eta_x <- as.vector(X_mi %*% beta_mi)
  cutpoints <- .cutpoints_from_theta(theta_ord)
  log_prior <- .ordered_logprob_matrix(eta_x, cutpoints)
  x_unit_int <- fit$tmb_data$mi_x_unit
  total <- 0
  for (o in seq_along(y)) {
    if (!observed_y[o]) next
    u <- unit_id[o]
    if (observed_unit[u]) {
      state <- as.integer(round(x_unit_int[u]))
      total <- total + stats::dnorm(y[o], eta_obs[o], sigma, log = TRUE) +
        log_prior[u, state]
    } else {
      base <- mi_state_row[o]
      log_terms <- log_prior[u, ]
      for (k in seq_len(K)) {
        eta_state <- eta_obs[o] - sum(X_fix[o, ] * b_fix) +
          sum(X_fix_state[base + k, ] * b_fix)
        log_terms[k] <- log_terms[k] +
          stats::dnorm(y[o], eta_state, sigma, log = TRUE)
      }
      m <- max(log_terms)
      total <- total + (m + log(sum(exp(log_terms - m))))
    }
  }
  total
}

# ===========================================================================
# Gate 7.1: K-state SUM == brute-force marginalisation (the load-bearing proof)
# ===========================================================================

test_that("ordered mi() predictor model uses the exact K-state per-unit SUM", {
  skip_if_not_heavy()
  d <- .make_mio_uni()
  dat <- .inject_missing_xo(d)$data

  fit <- .fit_mio_uni(dat)

  ## Registry contract (drmTMB MD6b-aligned).
  expect_equal(fit$missing_data$predictors$score$family, "ordinal")
  expect_identical(fit$missing_data$predictors$score$model_row, d$missing_site)
  expect_equal(fit$missing_data$predictors$score$levels,
               c("low", "medium", "high"))
  expect_equal(fit$missing_data$predictors$score$n_state, 3L)
  expect_identical(stats::nobs(fit), nrow(dat))
  ## No latent x for the discrete route: x_mis is empty, sigma_mi is mapped off.
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$x_mis, 0L)

  ## K-1 FREE cutpoints (design 68 sec.1.2): theta_ord has K-1 = 2 entries.
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_length(par$theta_ord, 2L)
  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))
  expect_true(all(is.finite(par$theta_ord)))

  ## THE ANCHOR: the engine logLik equals the hand-marginalised per-unit K-state
  ## mixture to 1e-6. A wrong K-state SUM, a double-counted y (gate failure), a
  ## per-row product, or a wrong cutpoint reconstruction would break this.
  expect_equal(
    as.numeric(logLik(fit)),
    manual_ordered_mi_loglik(fit),
    tolerance = 1e-6
  )

  ## DISCRIMINATION: the WRONG per-row reference must NOT match (it counts the
  ## K-state prior once per trait row and lets the two traits' states differ).
  expect_false(isTRUE(all.equal(
    as.numeric(logLik(fit)),
    manual_ordered_mi_loglik_perrow(fit),
    tolerance = 1e-4
  )))
})

# ===========================================================================
# Gate 7.2: recovery -- response slope, predictor beta, cutpoints, expected score
# ===========================================================================

test_that("recovery: response slope, predictor beta, cutpoints, expected score", {
  skip_if_not_heavy()
  ## Draw the ordered predictor from a GENUINE cumulative-logit model so the
  ## fitted beta_x + cutpoints recover the GENERATING values (Design 59 sec.9
  ## joint-estimation check). The predictor model has no intercept; the cutpoints
  ## carry the location -- the engine's K-1-free-cutpoint parametrisation.
  d <- .make_mio_cumlogit(seed = 21, n_sites = 300,
                          b_z = 1.1, b_w = -0.7, cutpoints = c(-0.8, 0.8),
                          n_miss = 45L)
  dat <- .inject_missing_xo(d)$data
  score_true_missing <- d$score_true[d$missing_site]

  fit <- .fit_mio_uni(dat, se = TRUE)
  par <- fit$tmb_obj$env$parList(fit$opt$par)

  ## The response slope on z recovers (the analysis-model fixed effect).
  bnames <- names(par$b_fix)
  bz_resp <- par$b_fix[grepl("z", bnames)]
  expect_true(all(is.finite(bz_resp)))

  ## The predictor-model coefficients recover the SIGNS + a band around the
  ## GENERATING cumulative-logit slopes (z slope +1.1, w slope -0.7). The
  ## predictor model is a cumulative-logit GLM on the observed units, so its
  ## coefficients carry the usual sampling SE (~0.15-0.2 here at n=300).
  beta_x <- unname(par$beta_mi)
  expect_gt(beta_x[1], 0.4)                         # z slope clearly positive
  expect_lt(beta_x[2], -0.1)                        # w slope clearly negative
  expect_equal(beta_x[1], d$b_z, tolerance = 0.5)   # z slope, ~3 SE band
  expect_equal(beta_x[2], d$b_w, tolerance = 0.5)   # w slope, ~3 SE band

  ## Cutpoints recover the GENERATING values within bands, finite + strictly
  ## increasing (the K-1 free reconstruction).
  cutpoints <- .cutpoints_from_theta(par$theta_ord)
  expect_length(cutpoints, 2L)
  expect_true(all(is.finite(cutpoints)))
  expect_lt(cutpoints[1], cutpoints[2])
  expect_equal(cutpoints[1], d$cutpoints[1], tolerance = 0.5)
  expect_equal(cutpoints[2], d$cutpoints[2], tolerance = 0.5)

  ## The per-unit expected category score is in [1, K], finite, and tracks the
  ## true ordered value (monotone: higher true state => higher expected score).
  est <- imputed(fit)$estimate
  expect_length(est, length(d$missing_site))
  expect_true(all(is.finite(est)))
  expect_true(all(est >= 1 & est <= 3))
  expect_gt(mean(est[score_true_missing == 3]),
            mean(est[score_true_missing == 1]))

  ## The conditional category probabilities per missing unit sum to 1.
  probs <- fit$missing_data$predictors$score$conditional_probabilities
  expect_equal(nrow(probs), length(d$missing_site))
  expect_equal(ncol(probs), 3L)
  expect_equal(rowSums(probs), rep(1, length(d$missing_site)), tolerance = 1e-8)
})

# ===========================================================================
# imputed() reports the conditional expected score (NOT a latent mode)
# ===========================================================================

test_that("imputed() reports the ordered conditional expected score", {
  skip_if_not_heavy()
  d <- .make_mio_uni()
  dat <- .inject_missing_xo(d)$data
  fit <- .fit_mio_uni(dat)

  imp <- imputed(fit)
  expect_equal(nrow(imp), length(d$missing_site))
  expect_equal(imp$source,
               rep("conditional_expected_score", length(d$missing_site)))
  expect_true(all(is.finite(imp$estimate)))
  expect_true(all(imp$estimate >= 1 & imp$estimate <= 3))
  ## The discrete route reports a distribution, not a Hessian SE: std_error NA.
  expect_true(all(is.na(imp$std_error)))
  expect_equal(imp$uncertainty_status,
               rep("discrete_no_se", length(d$missing_site)))
})

# ===========================================================================
# Multivariate: traits(t1, t2) ~ z + mi(score) -- per-unit product over traits
# ===========================================================================

.make_mio_multi <- function(seed = 31, n_sites = 80,
                            miss_idx = c(3L, 14L, 28L, 41L, 55L, 70L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  eta_x <- 0.9 * z - 0.5 * w
  score_int <- cut(
    eta_x + stats::rnorm(n_sites, sd = 0.5),
    breaks = c(-Inf, -0.5, 0.5, Inf), labels = FALSE
  )
  score_effect <- c(-0.4, 0.1, 0.7)
  mk <- function(a0, bz, sigma) {
    a0 + score_effect[score_int] + bz * z + stats::rnorm(n_sites, sd = sigma)
  }
  t1 <- mk(0.5, -0.2, 0.30)
  t2 <- mk(-0.3, 0.4, 0.40)
  wide <- data.frame(
    site = factor(seq_len(n_sites)), t1 = t1, t2 = t2,
    z = z, w = w, stringsAsFactors = FALSE
  )
  wide$score <- ordered(c("low", "medium", "high")[score_int],
                        levels = c("low", "medium", "high"))
  list(data = wide, score_true = score_int, missing = miss_idx)
}

test_that("multivariate: one ordered mi(score) feeds both traits via the per-unit product", {
  skip_if_not_heavy()
  d <- .make_mio_multi()
  wide <- d$data
  wide$score[d$missing] <- NA

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1, t2) ~ z + mi(score),
    data    = wide,
    unit    = "site",
    family  = gaussian(),
    impute  = list(score = impute_model(score ~ z + w,
                                        family = cumulative_logit())),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  ## Convergence + finite estimates.
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-1)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_true(all(is.finite(par$b_fix)))
  ## No latent x; K-1 free cutpoints; one expected score per missing site.
  expect_length(par$x_mis, 0L)
  expect_length(par$theta_ord, 2L)
  expect_identical(fit$missing_data$predictors$score$model_row, d$missing)
  est <- imputed(fit)$estimate
  expect_length(est, length(d$missing))
  expect_true(all(est >= 1 & est <= 3))

  ## The SUM == brute force still holds with the per-unit product over BOTH
  ## traits across the K states (the multivariate crux made testable).
  expect_equal(
    as.numeric(logLik(fit)),
    manual_ordered_mi_loglik(fit),
    tolerance = 1e-6
  )
  ## And the per-row reference does NOT match (2 traits per missing unit).
  expect_false(isTRUE(all.equal(
    as.numeric(logLik(fit)),
    manual_ordered_mi_loglik_perrow(fit),
    tolerance = 1e-4
  )))
})

# ===========================================================================
# Boundary rejections + input acceptance (no fit; errors before TMB)
# ===========================================================================

test_that("ordered mi() rejects out-of-scope predictor models", {
  d <- .make_mio_uni()
  dat <- .inject_missing_xo(d)$data

  ## 2-level ordered factor -> directed to binary().
  dat2 <- dat
  dat2$score2 <- ordered(
    c("lo", "hi")[1 + (as.integer(dat2$site) %% 2L)],
    levels = c("lo", "hi")
  )
  dat2$score2[is.na(dat2$score)] <- NA
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(score2),
      data = dat2, family = gaussian(),
      impute = list(score2 = impute_model(score2 ~ z,
                                          family = cumulative_logit())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "three|binom|2 level|two"
  )

  ## Unordered factor -> directed to categorical().
  datu <- dat
  datu$scoreu <- factor(c("a", "b", "c")[1 + (as.integer(datu$site) %% 3L)],
                        levels = c("a", "b", "c"))
  datu$scoreu[is.na(datu$score)] <- NA
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(scoreu),
      data = datu, family = gaussian(),
      impute = list(scoreu = impute_model(scoreu ~ z,
                                          family = cumulative_logit())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "ordered predictor|categorical"
  )

  ## A grouped random intercept in the ordered predictor model (fixed-only v1).
  datg <- dat
  datg$grp <- factor(as.integer(datg$site) %% 8L)
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(score),
      data = datg, family = gaussian(),
      impute = list(score = impute_model(score ~ z + (1 | grp),
                                         family = cumulative_logit())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "fixed effect|grouped|random|structured"
  )

  ## A structured (phylo) ordered predictor model is out of scope.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(score),
      data = dat, family = gaussian(),
      impute = list(score = impute_model(
        score ~ z + phylo(1 | species, tree = NULL),
        family = cumulative_logit())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "fixed effect|structured|phylo|tree"
  )

  ## Multiple mi() terms.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(score) + mi(z),
      data = dat, family = gaussian(),
      impute = list(score = impute_model(score ~ w,
                                         family = cumulative_logit())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "exactly one"
  )

  ## Empty observed category (sparse ordered factor) -> the >=3-populated guard.
  dats <- dat
  ## Collapse "medium" into "low" but keep the 3-level ordered factor: the
  ## middle category is now empty among observed values.
  lev <- c("low", "medium", "high")
  collapsed <- ifelse(as.character(dat$score) == "medium", "low",
                      as.character(dat$score))
  dats$score <- ordered(collapsed, levels = lev)
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dats$score[miss_rows] <- NA
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(score),
      data = dats, family = gaussian(),
      impute = list(score = impute_model(score ~ z,
                                         family = cumulative_logit())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "Every ordered predictor category|empty|appear at least once"
  )
})

test_that("ordered mi() accepts an ordered factor and integer scores", {
  skip_if_not_heavy()
  d <- .make_mio_uni()
  base <- .inject_missing_xo(d)$data

  ## (a) ordered factor (the .make_mio_uni default) fits with the right levels.
  fit_fac <- .fit_mio_uni(base)
  expect_equal(fit_fac$missing_data$predictors$score$levels,
               c("low", "medium", "high"))
  expect_true(all(is.finite(fit_fac$tmb_obj$env$parList(fit_fac$opt$par)$b_fix)))

  ## (b) integer scores 1..K.
  dati <- base
  dati$score <- as.integer(dati$score)             # 1, 2, 3, NA preserved
  fit_int <- .fit_mio_uni(dati)
  expect_equal(fit_int$missing_data$predictors$score$n_state, 3L)
  expect_true(all(is.finite(fit_int$tmb_obj$env$parList(fit_int$opt$par)$b_fix)))
  ## Same expected-score imputation as the ordered-factor coding (same data).
  expect_equal(
    imputed(fit_int)$estimate,
    imputed(fit_fac)$estimate,
    tolerance = 1e-4
  )
})

# ===========================================================================
# Gate 7.7: no-op / gate safety (the gate + K-state block fire only for mi_family==2)
# ===========================================================================

test_that("a binary mi() fit is unchanged by the ordered K-state machinery", {
  skip_if_not_heavy()
  ## A binary mi(x) fit (Phase 5a) must be untouched by the ordered block: the
  ## K-state SUM/state-design are gated behind mi_family == 2.
  set.seed(404)
  n_sites <- 50
  z <- stats::rnorm(n_sites); w <- stats::rnorm(n_sites)
  px <- stats::plogis(-0.2 + 1.1 * z - 0.7 * w)
  x <- stats::rbinom(n_sites, size = 1, prob = px)
  rows <- list()
  for (s in seq_len(n_sites)) {
    rows[[s]] <- data.frame(
      site = s, trait = c("t1", "t2"),
      value = c(0.6 + 1.2 * x[s] - 0.3 * z[s],
                -0.2 + 1.2 * x[s] + 0.5 * z[s]) + stats::rnorm(2, sd = 0.35),
      x = x[s], z = z[s], w = w[s], stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  dat$x[which(as.integer(dat$site) %in% c(5L, 14L, 27L, 38L))] <- NA_real_

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = dat, family = gaussian(),
    impute = list(x = impute_model(x ~ z + w, family = binomial())),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  expect_equal(fit$tmb_data$mi_family, 1L)
  expect_equal(fit$missing_data$predictors$x$family, "bernoulli")
  expect_equal(fit$missing_data$predictors$x$summary, "conditional_probability")
  ## The ordered state-design / cutpoint params are stubs for the binary route.
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 0L)
  expect_true(is.finite(as.numeric(logLik(fit))))
})

test_that("a Gaussian mi() fit is unchanged by the ordered K-state machinery", {
  skip_if_not_heavy()
  set.seed(405)
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

  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$x_mis, 4L)
  expect_equal(fit$missing_data$predictors$x$family, "gaussian")
  expect_equal(fit$missing_data$predictors$x$summary, "conditional_mode")
  expect_equal(fit$tmb_data$mi_family, 0L)
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 0L)
})

test_that("a plain fit (no mi) sets has_mi = 0 -- the ordered block is a no-op", {
  skip_if_not_heavy()
  d <- .make_mio_uni()
  dat <- d$data                              # score fully observed; no mi()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + score,
    data = dat, family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$tmb_data$has_mi, 0L)
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 0L)
  expect_true(is.finite(as.numeric(logLik(fit))))
})
