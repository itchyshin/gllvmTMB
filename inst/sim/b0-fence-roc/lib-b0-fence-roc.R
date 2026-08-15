## Design 118 -- B0 fence-ROC harness, pure functions.
## docs/design/118-mspl-interval-calibration-protocol.md s1.2, s1.6, s5.3, s5.4.
##
## Sourced by run-b0-shard.R (fitting) and tests/testthat/test-b0-fence-roc.R
## (pure-function checks); no side effects at source time.

`%||%` <- function(x, y) if (is.null(x)) y else x

## ---- DGP: the 12 published archive cells, re-simulated on FRESH seeds ----
##
## Same generative mechanism as the 2026-08-14 archive's
## inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R (branch
## codex/lane-b-mspl-interval-feasibility: manifest_table()/case_truth()/
## simulate_outer_data()) -- n_site = 24, n_trait = 3, formula
## `y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)`,
## beta = c(-0.5, 0.1, 0.55) + beta_shift, lambda = lambda_scale * c(0.8, -0.55, 0.35).
## Case order (regime x link, by = NULL cross join) reproduces the archive's
## C001..C012 labelling exactly (verified against A1b's per-case link/regime
## table): C011 = cloglog x high_prevalence, the fenced pocket; C001/C004/
## C005/C008 = the well-identified logit/probit anchors.
##
## B0 uses its OWN seed_base range, disjoint from the archive's. The archive
## (2026-08-14 campaign) used seed_base = 1,900,000,000 + case_number *
## 10,000,000 (range ~1.91e9-2.02e9); that campaign's own README forbids
## reusing its seeds to tune or validate a method. B0 uses
## 118,000,000 + case_number * 1,000,000 (range ~1.19e8-1.30e8) -- disjoint,
## and the leading "118" tags it to this design.
b0_seed_base <- function(case_number) 118000000L + as.integer(case_number) * 1000000L

b0_manifest <- function() {
  regimes <- data.frame(
    regime = c("baseline", "low_prevalence", "high_prevalence", "strong_signal"),
    beta_shift = c(0, -1.5, 1.5, 0), lambda_scale = c(1, 1, 1, 1.75),
    stringsAsFactors = FALSE
  )
  out <- merge(
    regimes,
    data.frame(link = c("logit", "probit", "cloglog"), stringsAsFactors = FALSE),
    by = NULL, sort = FALSE
  )
  out$case_number <- seq_len(nrow(out))
  out$case_id <- sprintf("C%03d", out$case_number)
  out$seed_base <- b0_seed_base(out$case_number)
  out[, c(
    "case_id", "case_number", "regime", "link", "beta_shift", "lambda_scale", "seed_base"
  )]
}

b0_case_row <- function(case_id) {
  m <- b0_manifest()
  row <- m[m$case_id == case_id, , drop = FALSE]
  if (nrow(row) != 1L) stop("Unknown B0 case_id: ", case_id, call. = FALSE)
  row
}

b0_case_truth <- function(beta_shift) c(-0.5, 0.1, 0.55) + beta_shift

b0_outer_seed <- function(case_row, outer_id) {
  as.integer(case_row$seed_base[[1L]]) + as.integer(outer_id)
}

b0_simulate_outer_data <- function(case_row, outer_id, n_site = 24L, n_trait = 3L) {
  set.seed(b0_outer_seed(case_row, outer_id))
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  beta <- b0_case_truth(case_row$beta_shift[[1L]])
  lambda <- case_row$lambda_scale[[1L]] * c(0.8, -0.55, 0.35)
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * lambda[as.integer(trait)]
  mu <- switch(case_row$link[[1L]],
    logit = stats::plogis(eta),
    probit = stats::pnorm(eta),
    cloglog = -expm1(-exp(eta)),
    stop("Unknown link: ", case_row$link[[1L]], call. = FALSE)
  )
  data.frame(site = site, trait = trait, y = stats::rbinom(length(mu), 1L, mu))
}

b0_formula <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

b0_trait_counts <- function(data) {
  k <- tapply(data$y, data$trait, sum)
  n <- tapply(data$y, data$trait, length)
  data.frame(target = seq_along(k), target_name = names(k),
    k = as.integer(k), n_obs = as.integer(n), stringsAsFactors = FALSE
  )
}

## ---- Fit wrapper (Route A: the mspl_c_n_multiplier probe hook) ----------
## Design 118 s7.1. `control$mspl_c_n_multiplier` is a private, unexported
## probe hook (R/mspl.R, R/fit-multi.R) -- not a gllvmTMBcontrol() formal.
b0_control <- function(mult = 1) {
  ctrl <- gllvmTMB::gllvmTMBcontrol(
    n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
  )
  ctrl$mspl_c_n_multiplier <- mult
  ctrl
}

b0_fit_mspl <- function(data, link, mult = 1) {
  gllvmTMB::gllvmTMB(
    b0_formula, data = data, family = stats::binomial(link = link),
    estimator = "mspl", control = b0_control(mult), silent = TRUE
  )
}

## ---- Analytic count-attractor root (A1b Task 1.2 / Design 118 s1.6 L2) --
##
## The MSPL objective for a saturated (or near-saturated) trait column
## separates, at loading zero, into a deterministic univariate function of
## the observed success count k:
##   Q(b) = k * log p1(b) + (n-k) * log p0(b) + (c_n/2) * log w(b)
## p1/p0/w are the link's Bernoulli probabilities and Jeffreys expected-
## information weight (src/gllvmTMB.cpp gll_mspl_log_weight() /
## gll_mspl_bernoulli_loglik(), link_id 0 = logit, 1 = probit, 2 = cloglog).
## b0_attractor_score() is dQ/db, in closed form per link, written in a
## form that stays finite for |b| up to ~15 (the cloglog terms are the
## overflow risk: a*exp(a)/expm1(a) is rewritten as a/(1 - exp(-a)) so
## exp(a) itself, which overflows for a > ~700, is never formed).
## Validated against A1b's independently-derived roots to 8 decimal places
## (cloglog k=24: 1.59640004; logit k=24: 4.43246352; probit k=24:
## 2.36293512; and the c_n/2, 2c_n movements 1.715161 / 1.466704 -- Design
## 118 P5) -- see the harness README.
b0_attractor_score <- function(b, k, n, c_n, link) {
  if (identical(link, "logit")) {
    p <- stats::plogis(b)
    return(k * (1 - p) - (n - k) * p + (c_n / 2) * (1 - 2 * p))
  }
  if (identical(link, "probit")) {
    ph <- stats::dnorm(b)
    P1 <- stats::pnorm(b)
    P0 <- stats::pnorm(-b)
    return(k * ph / P1 - (n - k) * ph / P0 + (c_n / 2) * (-2 * b - ph / P1 + ph / P0))
  }
  if (identical(link, "cloglog")) {
    a <- exp(b)
    ema <- exp(-a)
    denom <- -expm1(-a)
    term1 <- ifelse(denom > 0, a * ema / denom, 1) ## a/expm1(a),      limit 1 as a->0
    term2 <- ifelse(denom > 0, a / denom, 1) ## a*exp(a)/expm1(a), limit 1 as a->0
    return(k * term1 - (n - k) * a + (c_n / 2) * (2 - term2))
  }
  stop("Unknown link: ", link, call. = FALSE)
}

b0_attractor_root <- function(k, n, c_n, link, bracket = c(-15, 15), tol = 1e-10) {
  f <- function(b) b0_attractor_score(b, k = k, n = n, c_n = c_n, link = link)
  flo <- f(bracket[[1L]])
  fhi <- f(bracket[[2L]])
  if (!is.finite(flo) || !is.finite(fhi) || flo * fhi > 0) return(NA_real_)
  stats::uniroot(f, bracket, tol = tol)$root
}

## c_n as computed in src/gllvmTMB.cpp:3166 (the Bernoulli/binomial route).
## Provided for cross-checks; the harness reads the fitted value off each
## fit's own TMB report rather than assuming this formula holds for every
## cell (Design 118 s5.3 item 4: "read exact p_free/N_eff counts off real
## fits").
b0_c_n_formula <- function(p_free, N_eff, mult = 1) 2 * sqrt(p_free / N_eff) * mult

## ---- Labels (Design 118 s1.6) --------------------------------------------
b0_label_l1 <- function(k, n) k == 0L | k == n

b0_label_l2 <- function(estimate, root, tol = 1e-4) {
  is.finite(estimate) & is.finite(root) & abs(estimate - root) < tol
}

## ---- Probe statistic (Design 118 s1.2, Route A) --------------------------
b0_s_j <- function(estimate_half, estimate_double, se_penalised) {
  d_per_efold <- (estimate_double - estimate_half) / log(4)
  list(d_per_efold = d_per_efold, s_j = abs(d_per_efold) / se_penalised)
}

b0_probe_class <- function(s_j) {
  out <- rep(NA_character_, length(s_j))
  ok <- is.finite(s_j)
  out[ok & s_j >= 1.0] <- "penalty_determined"
  out[ok & s_j >= 0.25 & s_j < 1.0] <- "penalty_influenced"
  out[ok & s_j < 0.25] <- "data_determined"
  out
}

## ---- Penalised Hessian / se_penalised (Route A denominator) --------------
##
## Design 118 s1.2 needs (H^-1)_jj, the diagonal of the inverse Hessian of
## the ACTIVE PENALISED objective at the MSPL estimate. The matching private
## helper, `.gllvmTMB_mspl_penalized_hessian_diagnostic()`, exists on branch
## codex/lane-b-mspl-interval-feasibility (R/mspl.R) but is NOT one of this
## worktree's two committed prerequisites (a16e1f26 the c_n multiplier hook,
## 0d6de305 the profile bracket-search fix) -- see the harness README's
## "spec vs structure" note. Rather than porting a third package-internal
## function, this computes the identical quantity directly off `fit$tmb_obj`
## (the fitted object's own active penalised tape), which is exactly what
## the ported profile-feasibility probe already does for its own Hessian-
## free bracket search.
b0_penalised_se <- function(fit) {
  obj <- fit$tmb_obj
  par <- as.numeric(fit$opt$par)
  n_par <- length(par)
  hess <- tryCatch(stats::optimHess(par, obj$fn, obj$gr), error = identity)
  if (inherits(hess, "error")) {
    return(list(
      status = "hessian_error", se = rep(NA_real_, n_par),
      covariance = NULL, message = conditionMessage(hess)
    ))
  }
  hess <- as.matrix(hess)
  if (!identical(dim(hess), rep.int(n_par, 2L)) || any(!is.finite(hess))) {
    return(list(
      status = "hessian_nonfinite", se = rep(NA_real_, n_par),
      covariance = NULL, message = NA_character_
    ))
  }
  hess <- (hess + t(hess)) / 2
  chol_h <- tryCatch(chol(hess), error = identity)
  if (inherits(chol_h, "error")) {
    return(list(
      status = "hessian_non_pd", se = rep(NA_real_, n_par),
      covariance = NULL, message = conditionMessage(chol_h)
    ))
  }
  covariance <- chol2inv(chol_h)
  variance <- diag(covariance)
  if (any(!is.finite(variance)) || any(variance <= 0)) {
    return(list(
      status = "hessian_variance_invalid", se = rep(NA_real_, n_par),
      covariance = covariance, message = NA_character_
    ))
  }
  list(status = "ok", se = sqrt(variance), covariance = covariance, message = NA_character_)
}

## ---- Route B surrogate (diagnostic; Design 118 s1.2 switch rule) ---------
##
## S_hat^surr = -H^-1 grad(likelihood)(theta_hat). Design 118 s1.2:
## "S = d(theta_hat)/d(log c) = -H^-1 grad(l_LA)(theta_hat)". H is the
## Hessian of Q_LA (max convention) = -(Hessian of the penalised NLL);
## grad(l_LA) = -grad(unpenalised NLL). Substituting:
##   S = -(-H_nll)^-1 (-grad_u) = -H_nll^-1 grad_u
## where H_nll is the SAME penalised-NLL Hessian used for se_penalised
## above (covariance = H_nll^-1), and grad_u is the gradient of the
## penalty-off ("unpenalized_tmb_obj") NLL at the MSPL estimate.
b0_route_b_surrogate <- function(fit, covariance) {
  n_par <- length(fit$opt$par)
  if (is.null(covariance)) {
    return(list(status = "route_b_no_covariance", s_surr = rep(NA_real_, n_par)))
  }
  obj_u <- fit$mspl$unpenalized_tmb_obj
  if (is.null(obj_u)) {
    return(list(status = "route_b_no_unpenalized_obj", s_surr = rep(NA_real_, n_par)))
  }
  par <- as.numeric(fit$opt$par)
  gr_u <- tryCatch(obj_u$gr(par), error = identity)
  if (inherits(gr_u, "error") || length(gr_u) != n_par || any(!is.finite(gr_u))) {
    return(list(status = "route_b_gradient_error", s_surr = rep(NA_real_, n_par)))
  }
  s_surr <- as.numeric(-(covariance %*% as.numeric(gr_u)))
  list(status = "ok", s_surr = s_surr)
}

## ---- Separation screen (Design 118 s1.1 / fence line 1) ------------------
## Design 88's shipped screen_control(separation = "fixed"); returns one row
## per trait aligned to b0_trait_counts()'s `target_name`.
b0_screen_traits <- function(data, link) {
  scr <- suppressWarnings(gllvmTMB::screen_gllvmTMB(
    y ~ 0 + trait, data = data, unit = "site", trait = "trait",
    family = stats::binomial(link = link),
    control = gllvmTMB::screen_control(separation = "fixed")
  ))
  sep <- gllvmTMB::screen_table(scr, "separation")
  sep[, c("traits", "status", "severity", "separated", "complete")]
}

## ---- Output schema ---------------------------------------------------
## One row per (outer dataset x target). Column order is the CSV contract;
## keep test-b0-fence-roc.R's schema test in sync with any change here.
b0_output_columns <- c(
  "case_id", "case_number", "regime", "link", "beta_shift", "lambda_scale",
  "shard_id", "outer_id", "seed",
  "n_site", "n_trait", "p_free", "N_eff", "c_n",
  "target", "target_name", "truth", "k", "n_obs",
  "estimate", "converged",
  "estimate_half_cn", "half_converged",
  "estimate_double_cn", "double_converged",
  "se_penalised", "hessian_status",
  "d_per_efold", "s_j", "probe_class",
  "route_b_s_surr", "route_b_status",
  "attractor_root", "label_l1", "label_l2",
  "screen_status", "screen_severity",
  "fit_elapsed_seconds", "probe_elapsed_seconds", "hessian_elapsed_seconds",
  "screen_elapsed_seconds",
  "status", "message"
)

b0_na_row <- function(n = 1L) {
  out <- as.data.frame(matrix(NA, nrow = n, ncol = length(b0_output_columns)))
  names(out) <- b0_output_columns
  out
}

## ---- One outer dataset: simulate, fit, probe, label, screen -------------
## Returns a 3-row data.frame (one row per b_fix target) with the full
## b0_output_columns schema. Every stage is wrapped so a failure anywhere
## downgrades that row's `status`/`message` instead of aborting the shard.
b0_run_outer <- function(case_row, outer_id, shard_id) {
  n_site <- 24L
  n_trait <- 3L
  link <- case_row$link[[1L]]
  truth <- b0_case_truth(case_row$beta_shift[[1L]])
  seed <- b0_outer_seed(case_row, outer_id)
  data <- b0_simulate_outer_data(case_row, outer_id, n_site = n_site, n_trait = n_trait)
  counts <- b0_trait_counts(data)

  base_row <- function(status, message = "") {
    out <- b0_na_row(n_trait)
    out$case_id <- case_row$case_id[[1L]]
    out$case_number <- case_row$case_number[[1L]]
    out$regime <- case_row$regime[[1L]]
    out$link <- link
    out$beta_shift <- case_row$beta_shift[[1L]]
    out$lambda_scale <- case_row$lambda_scale[[1L]]
    out$shard_id <- as.integer(shard_id)
    out$outer_id <- as.integer(outer_id)
    out$seed <- seed
    out$n_site <- n_site
    out$n_trait <- n_trait
    out$target <- counts$target
    out$target_name <- counts$target_name
    out$truth <- truth
    out$k <- counts$k
    out$n_obs <- counts$n_obs
    out$status <- status
    out$message <- message
    out
  }

  started <- proc.time()[["elapsed"]]
  fit <- tryCatch(b0_fit_mspl(data, link, mult = 1), error = identity)
  fit_elapsed <- proc.time()[["elapsed"]] - started
  if (inherits(fit, "error")) {
    out <- base_row("outer_fit_error", conditionMessage(fit))
    out$fit_elapsed_seconds <- fit_elapsed
    return(out)
  }

  idx <- which(names(fit$opt$par) == "b_fix")
  if (length(idx) != n_trait) {
    out <- base_row("outer_target_alignment_failed", "")
    out$fit_elapsed_seconds <- fit_elapsed
    return(out)
  }

  out <- base_row("ok")
  out$fit_elapsed_seconds <- fit_elapsed
  out$converged <- identical(as.integer(fit$opt$convergence), 0L)
  out$p_free <- fit$tmb_obj$env$data$p_free
  out$N_eff <- fit$tmb_obj$env$data$N_eff
  invisible(fit$tmb_obj$fn(as.numeric(fit$opt$par))) ## sync internal state before report()
  rep <- fit$tmb_obj$report()
  out$c_n <- rep$mspl_c_n %||% NA_real_
  out$estimate <- as.numeric(fit$opt$par[idx])

  ## Analytic count-attractor labels (Design 118 s1.6).
  out$attractor_root <- vapply(seq_len(n_trait), function(j) {
    b0_attractor_root(k = counts$k[[j]], n = counts$n_obs[[j]], c_n = out$c_n[[1L]], link = link)
  }, numeric(1L))
  out$label_l1 <- b0_label_l1(counts$k, counts$n_obs)
  out$label_l2 <- b0_label_l2(out$estimate, out$attractor_root)

  ## Route A: two extra outer refits at c_n/2 and 2c_n (the shipped probe).
  probe_started <- proc.time()[["elapsed"]]
  fit_half <- tryCatch(b0_fit_mspl(data, link, mult = 0.5), error = identity)
  fit_double <- tryCatch(b0_fit_mspl(data, link, mult = 2), error = identity)
  out$probe_elapsed_seconds <- proc.time()[["elapsed"]] - probe_started

  half_ok <- !inherits(fit_half, "error") &&
    length(which(names(fit_half$opt$par) == "b_fix")) == n_trait
  double_ok <- !inherits(fit_double, "error") &&
    length(which(names(fit_double$opt$par) == "b_fix")) == n_trait
  out$half_converged <- if (half_ok) identical(as.integer(fit_half$opt$convergence), 0L) else FALSE
  out$double_converged <- if (double_ok) identical(as.integer(fit_double$opt$convergence), 0L) else FALSE
  if (half_ok) {
    idx_h <- which(names(fit_half$opt$par) == "b_fix")
    out$estimate_half_cn <- as.numeric(fit_half$opt$par[idx_h])
  }
  if (double_ok) {
    idx_d <- which(names(fit_double$opt$par) == "b_fix")
    out$estimate_double_cn <- as.numeric(fit_double$opt$par[idx_d])
  }

  ## se_penalised: numerical outer Hessian of the ACTIVE penalised tape.
  hessian_started <- proc.time()[["elapsed"]]
  hess <- b0_penalised_se(fit)
  out$hessian_elapsed_seconds <- proc.time()[["elapsed"]] - hessian_started
  out$hessian_status <- hess$status
  out$se_penalised <- hess$se[idx]

  if (half_ok && double_ok && identical(hess$status, "ok")) {
    sj <- b0_s_j(out$estimate_half_cn, out$estimate_double_cn, out$se_penalised)
    out$d_per_efold <- sj$d_per_efold
    out$s_j <- sj$s_j
    out$probe_class <- b0_probe_class(sj$s_j)
  }

  ## Route B (diagnostic surrogate).
  rb <- b0_route_b_surrogate(fit, hess$covariance)
  out$route_b_status <- rb$status
  out$route_b_s_surr <- rb$s_surr[idx]

  ## Fence line 1: the shipped separation screen.
  screen_started <- proc.time()[["elapsed"]]
  sep <- tryCatch(b0_screen_traits(data, link), error = identity)
  out$screen_elapsed_seconds <- proc.time()[["elapsed"]] - screen_started
  if (!inherits(sep, "error")) {
    m <- match(out$target_name, sep$traits)
    out$screen_status <- sep$status[m]
    out$screen_severity <- sep$severity[m]
  }

  out
}
