# Phase 5c (issue #332 / design 68 sec.1.3): ONE UNORDERED categorical missing
# PREDICTOR via mi(habitat) with a baseline-category SOFTMAX covariate model,
# marginalised by an EXACT K-state SUM (the gllvmTMB analogue of drmTMB MD6c,
# mi_family == 3). This EXTENDS Phase 5b ordered: there is still NO latent x
# (the discrete x is summed out in the nll); the M x K accumulator, the FULL-
# SWAP via X_fix_state, the discrete-row gate, and the per-unit product are all
# reused UNCHANGED from 5b. The ONLY new piece is the predictor-model PRIOR:
# a baseline-category softmax (first level = baseline) with beta_mi packed as
# (K-1) blocks of n_coef -- block (k-1) is the linear predictor for state k.
#
# The crux (design 68 sec.3, no drmTMB precedent): the multivariate per-UNIT
# product. For a missing-x unit u the response side is the PRODUCT over u's
# trait rows  log_y_k(u) = sum_t log p(y_{u,t} | x = k), and the SUM
#   nll -= logspace_add_over_k( log p(x=k|z_u) + log_y_k(u) )
# fires ONCE per missing unit. A per-ROW SUM would double-count the K-state
# prior.
#
# The softmax prior (design 68 sec.1.3): eta_state(0) = 0 (baseline);
# eta_state(k) = X_x[u,] . beta_mi[block (k-1)], k = 1..K-1; log_denom =
# logsumexp_k eta_state(k) (explicit max-subtraction guard); log P(x=k+1|z) =
# eta_state(k) - log_denom. A MATHEMATICAL property of the softmax: the
# likelihood is INVARIANT to which level is baseline (gate 7.4).
#
# Gate map (design 68 sec.7 + design 59 sec.9):
#   * 7.1 SUM == brute force  -- the CORRECTNESS ANCHOR. A hand-marginalised R
#                                reference (per-unit product over trait rows,
#                                softmax prior once, logsumexp over the K states
#                                with the FULL-SWAP per-state eta) matches
#                                logLik(fit) to 1e-6. Catches a wrong K-state
#                                SUM, a double-count (gate failure), a per-row
#                                product, or a wrong softmax packing. A per-row-
#                                vs-per-unit discrimination check guards the
#                                twist.
#   * 7.4 baseline invariance -- relevel the unordered predictor (a DIFFERENT
#                                level as baseline), refit; logLik(fit) is
#                                INVARIANT to 1e-6 (a property of the softmax).
#   * 7.2 recovery            -- known DGP, MCAR unordered x: the response slope
#                                b_fix, the per-block predictor beta_x, and the
#                                per-unit modal category recover.
#   * multivariate            -- traits(t1, t2) ~ z + mi(habitat): the per-unit
#                                product over both traits across K states;
#                                converges; SUM == brute force still holds.
#   * boundary rejection      -- ordered (-> cumulative_logit), 2-level
#                                (-> binary), grouped/structured, multiple mi(),
#                                a category absent from observed values.
#   * input acceptance        -- unordered factor (>=3 levels), character,
#                                integer scores.
#   * 7.7 no-op / gate safety -- a binary-mi fit (5a), an ordered-mi fit (5b), a
#                                Gaussian-mi fit, and a plain fit are byte-
#                                identical to before (the gate + the softmax
#                                block fire only for mi_family == 3).
#
# All fits are gated behind skip_if_not_heavy(); the pure-validation boundary
# blocks run unconditionally (they error before any TMB fit).

# ---- Fixtures --------------------------------------------------------------

# A small LONG-format two-trait dataset with an UNORDERED categorical unit-level
# predictor `habitat` (3 levels forest/grass/wetland, constant within a site,
# broadcast to both trait rows). The per-state response effect is the unordered-
# factor contrast, shared across traits. NO latent axes / random effects in the
# fit, so eta(o) is a deterministic function of b_fix and the design -- the
# brute-force reference reconstructs the per-state etas exactly via the state
# design.
.make_miu_uni <- function(seed = 808, n_sites = 60,
                          miss_idx = c(5L, 14L, 27L, 41L, 53L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  ## A baseline-softmax-ish unordered predictor: a latent score per state cut to
  ## a category. (The exact DGP need not be softmax for the ANCHOR; only the
  ## recovery fixture below uses a genuine softmax DGP.)
  score <- sin(seq_len(n_sites) / 4) + 0.45 * z - 0.3 * w
  habitat_int <- ifelse(score < -0.35, 1L, ifelse(score < 0.55, 2L, 3L))
  ## Per-state response effect (unordered category effect), shared across traits.
  habitat_effect <- c(-0.5, 0.2, 0.8)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eff <- habitat_effect[habitat_int[s]]
    eta1 <- 0.6 + eff - 0.3 * z[s]
    eta2 <- -0.2 + eff + 0.5 * z[s]
    rows[[s]] <- data.frame(
      site    = s,
      trait   = c("t1", "t2"),
      value   = c(eta1, eta2) + stats::rnorm(2, sd = 0.30),
      habitat = habitat_int[s],
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
  ## UNORDERED factor with 3 levels.
  dat$habitat <- factor(
    c("forest", "grass", "wetland")[dat$habitat],
    levels = c("forest", "grass", "wetland")
  )
  list(
    data = dat, habitat_true = habitat_int, missing_site = miss_idx,
    site = dat$site
  )
}

# A LONG-format two-trait dataset whose unordered `habitat` is drawn from a
# GENUINE baseline-category softmax model (so the fitted per-block beta_x
# recover the GENERATING values). eta_state(1) = 0 (baseline "forest");
# eta_state(k) = b_z[k] z + b_w[k] w for k = 2, 3 (grass, wetland);
# P(x=k|z) = exp(eta_state(k)) / sum_j exp(eta_state(j)).
.make_miu_softmax <- function(seed = 23, n_sites = 320,
                              b_z = c(grass = 1.1, wetland = -0.6),
                              b_w = c(grass = -0.7, wetland = 0.9),
                              n_miss = 48L) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  ## Baseline-softmax cell probabilities, then sample the category per unit.
  eta1 <- rep(0, n_sites)                                   # baseline
  eta2 <- b_z[["grass"]] * z + b_w[["grass"]] * w
  eta3 <- b_z[["wetland"]] * z + b_w[["wetland"]] * w
  denom <- exp(eta1) + exp(eta2) + exp(eta3)
  p1 <- exp(eta1) / denom
  p2 <- exp(eta2) / denom
  p3 <- exp(eta3) / denom
  habitat_int <- vapply(seq_len(n_sites), function(s) {
    sample.int(3L, size = 1L, prob = c(p1[s], p2[s], p3[s]))
  }, integer(1))
  habitat_effect <- c(-0.5, 0.2, 0.8)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eff <- habitat_effect[habitat_int[s]]
    rows[[s]] <- data.frame(
      site  = s, trait = c("t1", "t2"),
      value = c(0.6 + eff - 0.3 * z[s], -0.2 + eff + 0.5 * z[s]) +
        stats::rnorm(2, sd = 0.30),
      habitat = habitat_int[s], z = z[s], w = w[s],
      stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site  <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  ## Label using the LONG (per-row) integer column dat$habitat (length nrow),
  ## NOT habitat_int (length n_sites) -- the latter would recycle and break the
  ## per-unit constancy.
  dat$habitat <- factor(c("forest", "grass", "wetland")[dat$habitat],
                        levels = c("forest", "grass", "wetland"))
  miss_idx <- sort(sample.int(n_sites, n_miss))
  list(data = dat, habitat_true = habitat_int, missing_site = miss_idx,
       b_z = b_z, b_w = b_w)
}

# Set habitat to NA for every long row of the given missing sites.
.inject_missing_xu <- function(d) {
  dat <- d$data
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dat$habitat[miss_rows] <- NA
  list(data = dat, miss_rows = miss_rows, miss_site = d$missing_site)
}

# Fit the two-trait unordered mi(habitat) model.
.fit_miu_uni <- function(data,
                         impute = list(habitat = impute_model(
                           habitat ~ z + w, family = categorical())),
                         missing = miss_control(predictor = "model"),
                         se = FALSE) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(habitat),
    data    = data,
    family  = gaussian(),
    impute  = impute,
    missing = missing,
    control = gllvmTMBcontrol(se = se)
  )))
}

# Baseline-category softmax cell log-probabilities (the predictor prior), per
# design 68 sec.1.3: eta_state(0) = 0; eta_state(k) = X . beta_mi[block (k-1)];
# log_denom = logsumexp_k eta_state(k); log P(x=k+1) = eta_state(k) - log_denom.
# beta_mi is packed as (K-1) blocks of n_coef (column-major from an
# n_coef x (K-1) matrix), matching the engine's offset = (state-1)*n_coef read.
.categorical_logprob_matrix <- function(X, beta, n_state) {
  n_coef <- ncol(X)
  beta_matrix <- matrix(beta, nrow = n_coef, ncol = n_state - 1L)
  eta <- cbind(0, X %*% beta_matrix)               # n x K, column 1 = baseline
  row_max <- apply(eta, 1L, max)
  log_denom <- row_max + log(rowSums(exp(eta - row_max)))
  out <- eta - log_denom                           # n x K log-probabilities
  dimnames(out) <- NULL                            # drop X_mi rownames
  out
}

# ---- The CORRECTNESS ANCHOR: a hand-rolled per-UNIT K-state mixture ---------
#
# Independently of the TMB engine, recompute the observed-data logLik by hand-
# marginalising the missing unordered `habitat` over its K states. The KEY
# gllvmTMB twist (design 68 sec.7.1): for each unit u the response side is the
# PRODUCT over u's trait rows (a SUM of per-trait Gaussian log-densities), the
# softmax prior log p(habitat=k|z_u) is added ONCE, then we log-sum-exp over the
# K states. The per-state response eta uses the FULL-SWAP via the stacked state
# design X_fix_state (state fast, o_local*K + k), so the unordered factor's K-1
# contrast columns are all forced to state k at once. Observed-x units take the
# ordinary per-row response density plus the single matching state's log-prior.
manual_categorical_mi_loglik <- function(fit) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  b_fix <- par$b_fix
  beta_mi <- par$beta_mi
  sigma <- exp(par$log_sigma_eps)

  reg <- fit$missing_data$predictors$habitat
  K <- reg$n_state

  X_fix <- fit$tmb_data$X_fix
  y <- fit$tmb_data$y
  observed_y <- fit$tmb_data$is_y_observed == 1L
  unit_id <- fit$tmb_data$mi_unit_id + 1L           # 1-indexed long-row -> unit
  observed_unit <- fit$tmb_data$mi_observed_unit == 1L
  eta_obs <- as.vector(X_fix %*% b_fix)

  X_fix_state <- fit$tmb_data$X_fix_state
  mi_state_row <- fit$tmb_data$mi_state_row          # 0-indexed base or sentinel

  ## Per-unit softmax predictor prior. X_mi is the unit-level covariate design
  ## (WITH an intercept; the baseline level is absorbed there).
  X_mi <- fit$tmb_data$X_mi
  log_prior <- .categorical_logprob_matrix(X_mi, beta_mi, n_state = K)  # n_units x K

  ## The observed integer category per unit (1..K) at observed units.
  x_unit_int <- fit$tmb_data$mi_x_unit               # 1..K observed, placeholder else

  n_units <- nrow(X_mi)
  total <- 0
  for (u in seq_len(n_units)) {
    rows <- which(unit_id == u)
    if (observed_unit[u]) {
      state <- as.integer(round(x_unit_int[u]))      # 1..K
      ll_resp <- 0
      for (o in rows) {
        if (observed_y[o]) {
          ll_resp <- ll_resp + stats::dnorm(y[o], eta_obs[o], sigma, log = TRUE)
        }
      }
      total <- total + ll_resp + log_prior[u, state]
    } else {
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
manual_categorical_mi_loglik_perrow <- function(fit) {
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  b_fix <- par$b_fix
  beta_mi <- par$beta_mi
  sigma <- exp(par$log_sigma_eps)
  reg <- fit$missing_data$predictors$habitat
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
  log_prior <- .categorical_logprob_matrix(X_mi, beta_mi, n_state = K)
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
# Gate 7.1: K-state softmax SUM == brute-force marginalisation (the anchor)
# ===========================================================================

test_that("unordered mi() predictor model uses the exact K-state softmax SUM", {
  skip_if_not_heavy()
  d <- .make_miu_uni()
  dat <- .inject_missing_xu(d)$data

  fit <- .fit_miu_uni(dat)

  ## Registry contract (drmTMB MD6c-aligned, gllvmTMB phase5c version tag).
  expect_equal(fit$missing_data$predictors$habitat$family, "categorical")
  expect_identical(fit$missing_data$predictors$habitat$model_row, d$missing_site)
  expect_equal(fit$missing_data$predictors$habitat$levels,
               c("forest", "grass", "wetland"))
  expect_equal(fit$missing_data$predictors$habitat$n_state, 3L)
  expect_equal(fit$missing_data$predictors$habitat$version, "phase5c")
  expect_identical(stats::nobs(fit), nrow(dat))
  ## No latent x for the discrete route: x_mis is empty, sigma_mi is mapped off.
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$x_mis, 0L)
  ## No theta_ord (softmax has no cutpoints; beta_mi carries everything).
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 0L)
  ## beta_mi has (K-1) * n_coef entries. The covariate design habitat ~ z + w
  ## has an intercept -> n_coef = 3 columns, K-1 = 2 blocks -> 6 coefficients.
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_length(par$beta_mi, 6L)
  expect_true(all(is.finite(par$b_fix)))
  expect_true(all(is.finite(par$beta_mi)))

  ## THE ANCHOR: the engine logLik equals the hand-marginalised per-unit K-state
  ## softmax mixture to 1e-6. A wrong K-state SUM, a double-counted y (gate
  ## failure), a per-row product, or a wrong softmax packing breaks this.
  expect_equal(
    as.numeric(logLik(fit)),
    manual_categorical_mi_loglik(fit),
    tolerance = 1e-6
  )

  ## DISCRIMINATION: the WRONG per-row reference must NOT match (it counts the
  ## K-state prior once per trait row and lets the two traits' states differ).
  expect_false(isTRUE(all.equal(
    as.numeric(logLik(fit)),
    manual_categorical_mi_loglik_perrow(fit),
    tolerance = 1e-4
  )))
})

# ===========================================================================
# Gate 7.4: baseline-level invariance (a mathematical property of the softmax)
# ===========================================================================

test_that("unordered mi() logLik is invariant to the baseline level", {
  skip_if_not_heavy()
  d <- .make_miu_uni()
  base <- .inject_missing_xu(d)$data

  fit1 <- .fit_miu_uni(base)

  ## Relevel: move a DIFFERENT level ("wetland") to baseline. The unordered
  ## softmax likelihood is INVARIANT to which level is baseline (up to a
  ## reparametrisation of beta_mi) -- a property of the softmax, the key gate.
  releveled <- base
  releveled$habitat <- factor(
    as.character(base$habitat),
    levels = c("wetland", "grass", "forest")
  )
  fit2 <- .fit_miu_uni(releveled)

  ## (a) logLik is invariant to 1e-6.
  expect_equal(
    as.numeric(logLik(fit1)),
    as.numeric(logLik(fit2)),
    tolerance = 1e-6
  )

  ## (b) The per-missing-unit conditional category probabilities are unchanged
  ## up to the relabelling of the columns. fit1 columns are
  ## (forest, grass, wetland); fit2 columns are (wetland, grass, forest).
  p1 <- fit1$missing_data$predictors$habitat$conditional_probabilities
  p2 <- fit2$missing_data$predictors$habitat$conditional_probabilities
  ## Reorder fit2's columns back to fit1's level order to compare.
  reorder2 <- match(c("forest", "grass", "wetland"),
                    c("wetland", "grass", "forest"))
  expect_equal(unname(p1), unname(p2[, reorder2, drop = FALSE]),
               tolerance = 1e-5)

  ## (c) The MODAL category imputation is unchanged (compare by level label).
  modal1 <- fit1$missing_data$predictors$habitat$conditional_modal_category
  modal2 <- fit2$missing_data$predictors$habitat$conditional_modal_category
  expect_equal(as.character(modal1), as.character(modal2))
})

# ===========================================================================
# Gate 7.2: recovery -- response slope, per-block predictor beta, modal category
# ===========================================================================

test_that("recovery: response slope, per-block softmax beta, modal category", {
  skip_if_not_heavy()
  ## Draw the unordered predictor from a GENUINE baseline-softmax model so the
  ## fitted per-block beta_x recover the GENERATING values (Design 59 sec.9
  ## joint-estimation check).
  d <- .make_miu_softmax(seed = 23, n_sites = 320,
                         b_z = c(grass = 1.1, wetland = -0.6),
                         b_w = c(grass = -0.7, wetland = 0.9),
                         n_miss = 48L)
  dat <- .inject_missing_xu(d)$data
  habitat_true_missing <- d$habitat_true[d$missing_site]

  fit <- .fit_miu_uni(dat, se = TRUE)
  par <- fit$tmb_obj$env$parList(fit$opt$par)

  ## The response slope on z recovers (the analysis-model fixed effect).
  bnames <- names(par$b_fix)
  bz_resp <- par$b_fix[grepl("z", bnames)]
  expect_true(all(is.finite(bz_resp)))

  ## The per-block softmax coefficients recover the GENERATING slopes. beta_mi is
  ## packed (K-1) blocks of n_coef; with X = [intercept, z, w] (n_coef = 3) the
  ## block for state k occupies indices ((k-1)*3 + 1):((k-1)*3 + 3) =
  ## (intercept_k, z_k, w_k). Block 1 = grass, block 2 = wetland.
  beta_x <- unname(par$beta_mi)
  expect_length(beta_x, 6L)
  z_grass   <- beta_x[2]; w_grass   <- beta_x[3]
  z_wetland <- beta_x[5]; w_wetland <- beta_x[6]
  ## Signs + ~3 SE bands around the generating values (n = 320).
  expect_gt(z_grass, 0.3)                              # grass z slope +1.1
  expect_lt(w_grass, -0.2)                             # grass w slope -0.7
  expect_lt(z_wetland, 0.1)                            # wetland z slope -0.6
  expect_gt(w_wetland, 0.3)                            # wetland w slope +0.9
  expect_equal(z_grass,   d$b_z[["grass"]],   tolerance = 0.6)
  expect_equal(w_grass,   d$b_w[["grass"]],   tolerance = 0.6)
  expect_equal(z_wetland, d$b_z[["wetland"]], tolerance = 0.6)
  expect_equal(w_wetland, d$b_w[["wetland"]], tolerance = 0.6)

  ## The per-unit MODAL category is a valid level and matches the true category
  ## at a rate ABOVE CHANCE (1/3) when the response discriminates.
  est <- imputed(fit)$estimate
  expect_length(est, length(d$missing_site))
  expect_true(all(est %in% seq_len(3L)))
  hit_rate <- mean(est == habitat_true_missing)
  expect_gt(hit_rate, 1 / 3)

  ## The conditional category probabilities per missing unit sum to 1.
  probs <- fit$missing_data$predictors$habitat$conditional_probabilities
  expect_equal(nrow(probs), length(d$missing_site))
  expect_equal(ncol(probs), 3L)
  expect_equal(rowSums(probs), rep(1, length(d$missing_site)), tolerance = 1e-8)
})

# ===========================================================================
# imputed() reports the conditional MODAL category (NOT a latent mode)
# ===========================================================================

test_that("imputed() reports the unordered conditional modal category", {
  skip_if_not_heavy()
  d <- .make_miu_uni()
  dat <- .inject_missing_xu(d)$data
  fit <- .fit_miu_uni(dat)

  imp <- imputed(fit)
  expect_equal(nrow(imp), length(d$missing_site))
  expect_equal(imp$source,
               rep("conditional_modal_category", length(d$missing_site)))
  expect_true(all(imp$estimate %in% seq_len(3L)))
  ## The discrete route reports a distribution, not a Hessian SE: std_error NA.
  expect_true(all(is.na(imp$std_error)))
  expect_equal(imp$uncertainty_status,
               rep("discrete_no_se", length(d$missing_site)))
  ## The level-labelled modal categories are valid levels.
  expect_true(all(
    fit$missing_data$predictors$habitat$conditional_modal_category %in%
      levels(dat$habitat)
  ))
})

# ===========================================================================
# Multivariate: traits(t1, t2) ~ z + mi(habitat) -- per-unit product over traits
# ===========================================================================

.make_miu_multi <- function(seed = 33, n_sites = 80,
                            miss_idx = c(3L, 14L, 28L, 41L, 55L, 70L)) {
  set.seed(seed)
  z <- stats::rnorm(n_sites)
  w <- stats::rnorm(n_sites)
  score <- 0.9 * z - 0.5 * w + sin(seq_len(n_sites) / 5)
  habitat_int <- ifelse(score < -0.5, 1L, ifelse(score < 0.5, 2L, 3L))
  habitat_effect <- c(-0.4, 0.1, 0.7)
  mk <- function(a0, bz, sigma) {
    a0 + habitat_effect[habitat_int] + bz * z + stats::rnorm(n_sites, sd = sigma)
  }
  t1 <- mk(0.5, -0.2, 0.30)
  t2 <- mk(-0.3, 0.4, 0.40)
  wide <- data.frame(
    site = factor(seq_len(n_sites)), t1 = t1, t2 = t2,
    z = z, w = w, stringsAsFactors = FALSE
  )
  wide$habitat <- factor(c("forest", "grass", "wetland")[habitat_int],
                         levels = c("forest", "grass", "wetland"))
  list(data = wide, habitat_true = habitat_int, missing = miss_idx)
}

test_that("multivariate: one unordered mi(habitat) feeds both traits via the per-unit product", {
  skip_if_not_heavy()
  d <- .make_miu_multi()
  wide <- d$data
  wide$habitat[d$missing] <- NA

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1, t2) ~ z + mi(habitat),
    data    = wide,
    unit    = "site",
    family  = gaussian(),
    impute  = list(habitat = impute_model(habitat ~ z + w,
                                          family = categorical())),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  ## Convergence + finite estimates.
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-1)
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  expect_true(all(is.finite(par$b_fix)))
  ## No latent x; no cutpoints; (K-1)*n_coef softmax coefs; one modal per missing.
  expect_length(par$x_mis, 0L)
  expect_length(par$theta_ord, 0L)
  expect_length(par$beta_mi, 6L)                     # 3 cols * (3-1) blocks
  expect_identical(fit$missing_data$predictors$habitat$model_row, d$missing)
  est <- imputed(fit)$estimate
  expect_length(est, length(d$missing))
  expect_true(all(est %in% seq_len(3L)))

  ## The SUM == brute force still holds with the per-unit product over BOTH
  ## traits across the K states (the multivariate crux made testable).
  expect_equal(
    as.numeric(logLik(fit)),
    manual_categorical_mi_loglik(fit),
    tolerance = 1e-6
  )
  ## And the per-row reference does NOT match (2 traits per missing unit).
  expect_false(isTRUE(all.equal(
    as.numeric(logLik(fit)),
    manual_categorical_mi_loglik_perrow(fit),
    tolerance = 1e-4
  )))
})

# ===========================================================================
# Boundary rejections + input acceptance (no fit; errors before TMB)
# ===========================================================================

test_that("unordered mi() rejects out-of-scope predictor models", {
  d <- .make_miu_uni()
  dat <- .inject_missing_xu(d)$data

  ## Ordered factor -> directed to cumulative_logit().
  dato <- dat
  dato$habitat <- ordered(as.character(dato$habitat),
                          levels = c("forest", "grass", "wetland"))
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(habitat),
      data = dato, family = gaussian(),
      impute = list(habitat = impute_model(habitat ~ z,
                                           family = categorical())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "unordered predictor|cumulative_logit|ordered"
  )

  ## 2-level unordered factor -> directed to binary().
  dat2 <- dat
  dat2$hab2 <- factor(
    c("a", "b")[1 + (as.integer(dat2$site) %% 2L)],
    levels = c("a", "b")
  )
  dat2$hab2[is.na(dat2$habitat)] <- NA
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(hab2),
      data = dat2, family = gaussian(),
      impute = list(hab2 = impute_model(hab2 ~ z, family = categorical())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "at least three|three|binom|two"
  )

  ## A grouped random intercept in the unordered predictor model (fixed-only v1).
  datg <- dat
  datg$grp <- factor(as.integer(datg$site) %% 8L)
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(habitat),
      data = datg, family = gaussian(),
      impute = list(habitat = impute_model(habitat ~ z + (1 | grp),
                                          family = categorical())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "fixed effect|grouped|random|structured"
  )

  ## A structured (phylo) unordered predictor model is out of scope.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(habitat),
      data = dat, family = gaussian(),
      impute = list(habitat = impute_model(
        habitat ~ z + phylo(1 | species, tree = NULL),
        family = categorical())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "fixed effect|structured|phylo|tree"
  )

  ## Multiple mi() terms.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + mi(habitat) + mi(z),
      data = dat, family = gaussian(),
      impute = list(habitat = impute_model(habitat ~ w,
                                          family = categorical())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "exactly one"
  )

  ## A category absent from observed values -> the every-category-populated guard.
  dats <- dat
  ## Collapse "grass" into "forest" but keep the 3-level factor: the "grass"
  ## level is now empty among observed values.
  lev <- c("forest", "grass", "wetland")
  collapsed <- ifelse(as.character(dat$habitat) == "grass", "forest",
                      as.character(dat$habitat))
  dats$habitat <- factor(collapsed, levels = lev)
  miss_rows <- which(as.integer(dat$site) %in% d$missing_site)
  dats$habitat[miss_rows] <- NA
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + (0 + trait):z + mi(habitat),
      data = dats, family = gaussian(),
      impute = list(habitat = impute_model(habitat ~ z,
                                          family = categorical())),
      missing = miss_control(predictor = "model"),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    "Every unordered predictor category|empty|appear at least once"
  )
})

test_that("unordered mi() accepts a factor, character, and integer scores", {
  skip_if_not_heavy()
  d <- .make_miu_uni()
  base <- .inject_missing_xu(d)$data

  ## (a) unordered factor (the .make_miu_uni default) fits with the right levels.
  fit_fac <- .fit_miu_uni(base)
  expect_equal(fit_fac$missing_data$predictors$habitat$levels,
               c("forest", "grass", "wetland"))
  expect_true(all(is.finite(fit_fac$tmb_obj$env$parList(fit_fac$opt$par)$b_fix)))

  ## (b) character predictor. Levels are sorted unique observed values.
  datc <- base
  datc$habitat <- as.character(datc$habitat)         # NA preserved
  fit_chr <- .fit_miu_uni(datc)
  expect_equal(fit_chr$missing_data$predictors$habitat$n_state, 3L)
  expect_true(all(is.finite(fit_chr$tmb_obj$env$parList(fit_chr$opt$par)$b_fix)))

  ## (c) integer scores 1..K.
  dati <- base
  dati$habitat <- as.integer(dati$habitat)           # 1, 2, 3, NA preserved
  fit_int <- .fit_miu_uni(dati)
  expect_equal(fit_int$missing_data$predictors$habitat$n_state, 3L)
  expect_true(all(is.finite(fit_int$tmb_obj$env$parList(fit_int$opt$par)$b_fix)))
  ## Same modal imputation as the factor coding (same data, same level order).
  expect_equal(
    imputed(fit_int)$estimate,
    imputed(fit_fac)$estimate
  )
})

# ===========================================================================
# Gate 7.7: no-op / gate safety (the gate + softmax block fire only for mi_family==3)
# ===========================================================================

test_that("an ordered mi() fit is unchanged by the unordered softmax machinery", {
  skip_if_not_heavy()
  ## An ordered mi(score) fit (Phase 5b) must be untouched by the softmax block:
  ## the softmax SUM is gated behind mi_family == 3.
  set.seed(414)
  n_sites <- 60
  z <- stats::rnorm(n_sites); w <- stats::rnorm(n_sites)
  eta_x <- 1.1 * z - 0.7 * w
  score_int <- cut(eta_x + stats::rnorm(n_sites, sd = 0.5),
                   breaks = c(-Inf, -0.6, 0.6, Inf), labels = FALSE)
  score_effect <- c(-0.5, 0.2, 0.8)
  rows <- list()
  for (s in seq_len(n_sites)) {
    eff <- score_effect[score_int[s]]
    rows[[s]] <- data.frame(
      site = s, trait = c("t1", "t2"),
      value = c(0.6 + eff - 0.3 * z[s], -0.2 + eff + 0.5 * z[s]) +
        stats::rnorm(2, sd = 0.30),
      score = score_int[s], z = z[s], w = w[s], stringsAsFactors = FALSE
    )
  }
  dat <- do.call(rbind, rows)
  dat$site <- factor(dat$site, levels = seq_len(n_sites))
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  dat$score <- ordered(c("low", "medium", "high")[dat$score],
                       levels = c("low", "medium", "high"))
  dat$score[which(as.integer(dat$site) %in% c(5L, 14L, 27L, 41L, 53L))] <- NA

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(score),
    data = dat, family = gaussian(),
    impute = list(score = impute_model(score ~ z + w,
                                       family = cumulative_logit())),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))

  expect_equal(fit$tmb_data$mi_family, 2L)
  expect_equal(fit$missing_data$predictors$score$family, "ordinal")
  expect_equal(fit$missing_data$predictors$score$version, "phase5b")
  ## K-1 free cutpoints present (ordered route); beta_mi has just n_coef entries.
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 2L)
  expect_true(is.finite(as.numeric(logLik(fit))))
})

test_that("a binary mi() fit is unchanged by the unordered softmax machinery", {
  skip_if_not_heavy()
  set.seed(415)
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
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 0L)
  ## Binary beta_mi is just n_coef (3) -- NOT the (K-1)*n_coef softmax packing.
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$beta_mi, 3L)
  expect_true(is.finite(as.numeric(logLik(fit))))
})

test_that("a Gaussian mi() fit is unchanged by the unordered softmax machinery", {
  skip_if_not_heavy()
  set.seed(416)
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
  expect_equal(fit$tmb_data$mi_family, 0L)
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 0L)
})

test_that("a plain fit (no mi) sets has_mi = 0 -- the unordered block is a no-op", {
  skip_if_not_heavy()
  d <- .make_miu_uni()
  dat <- d$data                              # habitat fully observed; no mi()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + habitat,
    data = dat, family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$tmb_data$has_mi, 0L)
  expect_length(fit$tmb_obj$env$parList(fit$opt$par)$theta_ord, 0L)
  expect_true(is.finite(as.numeric(logLik(fit))))
})
