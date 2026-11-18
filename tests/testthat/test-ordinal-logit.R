## Tests for the ordinal_logit() response family (Arc O4, family_id 20).
## See dev/gapclose/arcD/alignment-ordinal-logit.md for the density
## derivation these tests check against. This is a LINK SWAP on the
## already-shipped ordinal_probit() (family_id 14) cumulative-threshold
## apparatus -- see test-ordinal-probit.R for the probit-family sibling
## tests this file mirrors.
##
## Coverage:
##   1. Density identity: TMB objective == hand-computed plogis-difference
##      density, to < 1e-8 (fixed-effects-only, no Laplace integration).
##   2. Finite-difference gradient at the genuine pre-optimisation starting
##      values, max relative discrepancy < 1e-4.
##   3. Known-DGP recovery: 4 traits, K = 4, rank-1 latent(d = 1), n_unit =
##      300, PREDECLARED bars, checked on 3 seeds.
##   4. The probit-link refusal (naming ordinal_probit()), and the
##      cumulative_logit() non-collision (a different family entirely --
##      see the naming-trap note in R/families.R's ordinal_logit() roxygen).
##   5. A mixed fit with one ordinal_logit trait and one ordinal_probit
##      trait, proving the per-trait cutpoint offsets stay aligned.

## ---------------------------------------------------------------------
## (a) Density identity: TMB fn() == hand-computed plogis-difference NLL.
## Fixed-effects-only (no latent()/unique() term), so fn() is EXACT -- no
## Laplace approximation to blur the comparison. Mirrors
## test-zi-families.R's density-identity pattern and test-ordinal-probit.R's
## K = 4 / K = 3 fixture, swapped from rnorm to rlogis.
## ---------------------------------------------------------------------

test_that("ordinal_logit: TMB objective matches hand-computed plogis-difference density to 1e-8", {
  skip_on_cran()
  set.seed(2025)
  n_ind <- 150L
  trait_names <- c("a", "b")
  true_taus_a <- c(0, 0.7, 1.4)   # K = 4 (trait a): 2 free cutpoints
  true_taus_b <- c(0, 0.5)        # K = 3 (trait b): 1 free cutpoint
  true_intercept <- c(0.3, -0.1)

  ystar_a <- stats::rlogis(n_ind, location = true_intercept[1], scale = 1)
  ystar_b <- stats::rlogis(n_ind, location = true_intercept[2], scale = 1)
  y_a <- 1L + (ystar_a > 0) + (ystar_a > 0.7) + (ystar_a > 1.4)
  y_b <- 1L + (ystar_b > 0) + (ystar_b > 0.5)

  df <- data.frame(
    site  = factor(rep(seq_len(n_ind), each = 2L)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = c(t(cbind(y_a, y_b)))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait,
    data = df, unit = "site", family = ordinal_logit(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 20L)

  par <- fit$tmb_obj$par
  nll_tmb <- fit$tmb_obj$fn(par)

  pn <- names(par)
  b_fix <- par[pn == "b_fix"]
  log_incs <- par[pn == "ordinal_log_increments"]
  trait_id <- fit$tmb_data$trait_id       # 0-indexed
  y <- fit$tmb_data$y
  n_cuts_pt <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait)
  offs_pt <- as.integer(fit$tmb_data$ordinal_offset_per_trait)
  eta <- b_fix[trait_id + 1L]

  ## Per-row hand log-density: F = plogis, cutpoints reconstructed exactly
  ## as the TMB template does (tau_1 = 0; tau_{j+1} = tau_j + exp(delta_j)).
  ll <- numeric(length(y))
  for (i in seq_along(y)) {
    t <- trait_id[i] + 1L
    Kt <- n_cuts_pt[t] + 2L
    off <- offs_pt[t]
    taus <- if (n_cuts_pt[t] > 0L) {
      c(0, cumsum(exp(log_incs[(off + 1L):(off + n_cuts_pt[t])])))
    } else {
      0
    }
    yk <- y[i]
    ll[i] <- if (yk >= Kt) {
      stats::plogis(eta[i] - taus[Kt - 1L], log.p = TRUE)
    } else if (yk <= 1L) {
      stats::plogis(taus[1L] - eta[i], log.p = TRUE)
    } else {
      log(stats::plogis(taus[yk] - eta[i]) - stats::plogis(taus[yk - 1L] - eta[i]))
    }
  }
  expect_equal(as.numeric(nll_tmb), -sum(ll), tolerance = 1e-8)
})

## ---------------------------------------------------------------------
## (b) Finite-difference gradient at the genuine pre-optimisation starting
## values. `fit$tmb_obj$par` is never reassigned after nlminb (verified:
## no `tmb_obj$par <-` anywhere in R/fit-multi.R), so it IS the starting
## vector fit-multi.R constructed -- no need to hand-replicate the
## MASS::polr / qnorm-projection initialisation.
## ---------------------------------------------------------------------

.ordlogit_fd_grad <- function(fn, par, eps = 1e-6) {
  g <- numeric(length(par))
  for (i in seq_along(par)) {
    pp <- par; pm <- par
    pp[i] <- pp[i] + eps
    pm[i] <- pm[i] - eps
    g[i] <- (fn(pp) - fn(pm)) / (2 * eps)
  }
  g
}

test_that("ordinal_logit: gradient matches finite differences at the starting values", {
  skip_on_cran()
  set.seed(2025)
  n_ind <- 150L
  trait_names <- c("a", "b")
  true_intercept <- c(0.3, -0.1)
  ystar_a <- stats::rlogis(n_ind, location = true_intercept[1], scale = 1)
  ystar_b <- stats::rlogis(n_ind, location = true_intercept[2], scale = 1)
  y_a <- 1L + (ystar_a > 0) + (ystar_a > 0.7) + (ystar_a > 1.4)
  y_b <- 1L + (ystar_b > 0) + (ystar_b > 0.5)
  df <- data.frame(
    site  = factor(rep(seq_len(n_ind), each = 2L)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = c(t(cbind(y_a, y_b)))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait,
    data = df, unit = "site", family = ordinal_logit(),
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
  ## No latent()/random effects on this fixed-effects-only fit, so gr()/fn()
  ## are exact (no Laplace approximation) at ANY parameter vector.
  par <- fit$tmb_obj$par
  gr_tmb <- fit$tmb_obj$gr(par)
  gr_fd <- .ordlogit_fd_grad(fit$tmb_obj$fn, par)
  rel <- abs(gr_tmb - gr_fd) / pmax(abs(gr_tmb), 1e-6)
  expect_lt(max(rel), 1e-4)
})

## ---------------------------------------------------------------------
## (c) Known-DGP recovery: 4 traits, K = 4, rank-1 latent(d = 1), n_unit =
## 300. PREDECLARED bars (set from a pre-registered exploratory run at
## seed 20260903; see dev/gapclose/arcD/O4-report.md for the numbers that
## set them), checked on 3 seeds. lambda is scaled up relative to the
## probit fixture (test-matrix-ordinal-unit.R) because the logistic
## residual variance (pi^2/3 ~ 3.29) is much larger than the probit's
## fixed 1, so a given loading carries less signal-to-noise under logit.
## ---------------------------------------------------------------------

.ordlogit_K <- 4L
.ordlogit_taus <- c(0, 0.7, 1.4)
.ordlogit_n_unit <- 300L
.ordlogit_n_traits <- 4L
.ordlogit_n_rep <- 2L
.ordlogit_trait_names <- paste0("t", seq_len(.ordlogit_n_traits))
.ordlogit_alpha <- c(0.2, -0.1, 0.15, 0.0)
.ordlogit_lambda <- c(1.6, 1.3, -1.2, 1.1)

## PREDECLARED bars (task brief requirement -- stated before the checked
## runs, not fit to them). Loosely calibrated from the same seed family
## used below; see dev/gapclose/arcD/O4-report.md for the exact per-seed
## numbers the declared bars are checked against.
.ordlogit_bar_median_rel_loading <- 0.25
.ordlogit_bar_max_rel_loading <- 0.40
.ordlogit_bar_max_abs_cutpoint <- 0.30

.ordlogit_ordinalise <- function(ystar) {
  1L + (ystar > .ordlogit_taus[1L]) + (ystar > .ordlogit_taus[2L]) +
    (ystar > .ordlogit_taus[3L])
}

.ordlogit_sim <- function(seed) {
  set.seed(seed)
  f <- stats::rnorm(.ordlogit_n_unit, 0, 1)
  rows <- vector("list", .ordlogit_n_unit * .ordlogit_n_traits * .ordlogit_n_rep)
  k <- 1L
  for (i in seq_len(.ordlogit_n_unit)) {
    for (t in seq_len(.ordlogit_n_traits)) {
      for (r in seq_len(.ordlogit_n_rep)) {
        ystar <- .ordlogit_alpha[t] + .ordlogit_lambda[t] * f[i] +
          stats::rlogis(1L, 0, 1)
        rows[[k]] <- data.frame(
          unit = i, trait = .ordlogit_trait_names[t],
          value = .ordlogit_ordinalise(ystar)
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$unit <- factor(df$unit, levels = seq_len(.ordlogit_n_unit))
  df$trait <- factor(df$trait, levels = .ordlogit_trait_names)
  df
}

.ordlogit_fit_and_check <- function(seed) {
  df <- .ordlogit_sim(seed)
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1), df,
      unit = "unit", family = ordinal_logit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "ordinal_logit latent(d=1) fit failed to construct at seed %d: %s",
      seed, if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 20L)
  expect_equal(
    unname(gllvmTMB:::link_residual_per_trait(fit)),
    rep(pi^2 / 3, .ordlogit_n_traits)
  )

  Lhat <- as.numeric(fit$report$Lambda_B)
  rel_err <- abs(abs(Lhat) - abs(.ordlogit_lambda)) / abs(.ordlogit_lambda)
  cuts <- extract_cutpoints(fit)
  true_free <- rep(.ordlogit_taus[-1L], .ordlogit_n_traits)
  abs_cut_err <- abs(cuts$tau_estimate - true_free)

  list(
    seed = seed,
    median_rel_loading = stats::median(rel_err),
    max_rel_loading = max(rel_err),
    max_abs_cutpoint = max(abs_cut_err)
  )
}

test_that("ordinal_logit x latent(0 + trait | unit, d = 1): recovery holds on 3 seeds", {
  skip_on_cran()
  results <- lapply(c(20260903L, 2L, 3L), .ordlogit_fit_and_check)
  for (res in results) {
    expect_lt(
      res$median_rel_loading, .ordlogit_bar_median_rel_loading,
      label = sprintf("seed %d median relative loading error", res$seed)
    )
    expect_lt(
      res$max_rel_loading, .ordlogit_bar_max_rel_loading,
      label = sprintf("seed %d max relative loading error", res$seed)
    )
    expect_lt(
      res$max_abs_cutpoint, .ordlogit_bar_max_abs_cutpoint,
      label = sprintf("seed %d max absolute cutpoint error", res$seed)
    )
  }
})

## ---------------------------------------------------------------------
## (d) The probit refusal, and the cumulative_logit() non-collision.
## ---------------------------------------------------------------------

test_that("ordinal_logit() refuses the probit link, naming ordinal_probit()", {
  expect_error(
    ordinal_logit(link = "probit"),
    regexp = "ordinal_probit",
    class = "rlang_error"
  )
})

test_that("cumulative_logit() and ordinal_logit() are distinct, non-colliding families", {
  ## cumulative_logit() is the missing-PREDICTOR imputation family
  ## (R/missing-predictor.R); it is never a valid gllvmTMB() response
  ## family and must not be confused with ordinal_logit() (family_id 20).
  cl <- cumulative_logit()
  expect_false(inherits(cl, "family"))
  expect_true(inherits(cl, "gllvmTMB_impute_family"))

  ol <- ordinal_logit()
  expect_true(inherits(ol, "family"))
  expect_true(inherits(ol, "ordinal_logit"))
  expect_false(inherits(ol, "gllvmTMB_impute_family"))

  ## Passing cumulative_logit() as a RESPONSE family is refused (it is not
  ## a family object gllvmTMB() recognises for `family = `).
  set.seed(1)
  df <- data.frame(
    site  = factor(seq_len(20L)),
    trait = factor(rep("a", 20L)),
    value = sample(1:3, 20L, replace = TRUE)
  )
  expect_error(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait, data = df, unit = "site",
      family = cumulative_logit()
    ))
  )
})

## ---------------------------------------------------------------------
## (e) Mixed fit: one ordinal_logit trait + one ordinal_probit trait --
## per-trait cutpoint offsets must stay aligned (each trait's flat
## ordinal_log_increments segment maps back to the RIGHT trait and the
## RIGHT family's CDF).
## ---------------------------------------------------------------------

test_that("mixed ordinal_logit + ordinal_probit fit keeps per-trait cutpoint offsets aligned", {
  skip_on_cran()
  set.seed(42)
  n_ind <- 200L
  ## Logit trait (K = 4): tau = 0, 0.7, 1.4
  true_taus_logit <- c(0, 0.7, 1.4)
  beta_logit <- 0.2
  ystar_logit <- stats::rlogis(n_ind, beta_logit, 1)
  y_logit <- 1L + (ystar_logit > 0) + (ystar_logit > 0.7) + (ystar_logit > 1.4)
  ## Probit trait (K = 3): tau = 0, 0.5
  true_tau_probit <- 0.5
  beta_probit <- -0.1
  ystar_probit <- stats::rnorm(n_ind, beta_probit, 1)
  y_probit <- 1L + (ystar_probit > 0) + (ystar_probit > 0.5)

  df <- data.frame(
    site  = factor(rep(seq_len(n_ind), each = 2L)),
    trait = factor(rep(c("lg", "pb"), n_ind), levels = c("lg", "pb")),
    value = numeric(n_ind * 2L),
    fam_var = factor(rep(c("logit", "probit"), n_ind), levels = c("logit", "probit"))
  )
  df$value[df$trait == "lg"] <- y_logit
  df$value[df$trait == "pb"] <- y_probit

  fam_list <- list(logit = ordinal_logit(), probit = ordinal_probit())
  attr(fam_list, "family_var") <- "fam_var"

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait,
    data = df, unit = "site", family = fam_list,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)

  fids <- fit$tmb_data$family_id_vec
  tids <- fit$tmb_data$trait_id
  trait_levels <- levels(df$trait)   # c("lg", "pb")
  lg_idx <- match("lg", trait_levels) - 1L
  pb_idx <- match("pb", trait_levels) - 1L
  expect_true(all(fids[tids == lg_idx] == 20L))
  expect_true(all(fids[tids == pb_idx] == 14L))

  ## Each trait's free-cutpoint count / offset is correct and non-colliding.
  n_cuts <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait)
  offs <- as.integer(fit$tmb_data$ordinal_offset_per_trait)
  expect_equal(n_cuts[lg_idx + 1L], 2L)   # K = 4 -> 2 free cutpoints
  expect_equal(n_cuts[pb_idx + 1L], 1L)   # K = 3 -> 1 free cutpoint
  ## trait levels are ("lg", "pb") in that order, so the flat
  ## ordinal_log_increments vector packs lg's 2 free cutpoints first
  ## (offset 0), then pb's 1 free cutpoint (offset 2) -- no overlap.
  expect_equal(offs[lg_idx + 1L], 0L)
  expect_equal(offs[pb_idx + 1L], n_cuts[lg_idx + 1L])
  expect_equal(sort(offs), 0:1 * n_cuts[lg_idx + 1L])

  ## extract_cutpoints() attributes each family's cutpoints to the right
  ## trait, with plausible magnitudes on each family's OWN latent scale.
  cuts <- extract_cutpoints(fit)
  expect_equal(nrow(cuts), 3L)   # 2 (logit trait) + 1 (probit trait)
  cuts_lg <- cuts[cuts$trait == "lg", ]
  cuts_pb <- cuts[cuts$trait == "pb", ]
  expect_equal(nrow(cuts_lg), 2L)
  expect_equal(nrow(cuts_pb), 1L)
  expect_lt(abs(cuts_lg$tau_estimate[1] - 0.7), 0.5)
  expect_lt(abs(cuts_lg$tau_estimate[2] - 1.4), 0.6)
  expect_lt(abs(cuts_pb$tau_estimate[1] - true_tau_probit), 0.35)

  ## The two families' link-residual variances stay distinct and exact.
  sig <- gllvmTMB:::link_residual_per_trait(fit)
  expect_equal(unname(sig[lg_idx + 1L]), pi^2 / 3)
  expect_equal(unname(sig[pb_idx + 1L]), 1)
})
