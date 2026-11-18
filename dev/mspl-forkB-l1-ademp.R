## Design 125 / ADEMP L1 local smoke harness (fork B)
##
## Internal measurement only.  Does not open public se / vcov / confint,
## does not undraft #1077, and does not flip MSPL-04.  Totoro / T* are
## hard OUT — this file is the local L1 runner only.
##
## L1 gate (SIGNED ADEMP P5, G4d):
##   On >= 1 anchor cell, n_rep in 50-100:
##     cov_eff Wilson interval is not entirely below 0.80
##     availability >= 0.90
##     refusal <= 0.15
##
## Fork B = tape = "Q_0": unpenalized Laplace at fixed MSPL nuisance.
## If that argument is not on the loaded probe, the harness returns
## blocked-on-L0 rather than silently walking fork A.

mspl_forkB_l0_ready <- function() {
  if (!exists(".gllvmTMB_mspl_profile_feasibility",
              where = asNamespace("gllvmTMB"), inherits = FALSE)) {
    return(FALSE)
  }
  fn <- get(".gllvmTMB_mspl_profile_feasibility",
            envir = asNamespace("gllvmTMB"))
  "tape" %in% names(formals(fn))
}

mspl_forkB_wilson <- function(success, total, level = 0.95) {
  success <- as.integer(success)
  total <- as.integer(total)
  if (length(success) != 1L || length(total) != 1L ||
      is.na(success) || is.na(total) || total < 0L ||
      success < 0L || success > total) {
    stop("Wilson inputs must be one non-negative pair with success <= total.")
  }
  if (total == 0L) {
    return(c(lower = NA_real_, upper = NA_real_, centre = NA_real_))
  }
  z <- stats::qnorm(1 - (1 - level) / 2)
  p <- success / total
  den <- 1 + z^2 / total
  centre <- (p + z^2 / (2 * total)) / den
  margin <- z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2)) / den
  c(
    lower = max(0, centre - margin),
    upper = min(1, centre + margin),
    centre = centre
  )
}

## ADEMP local-smoke DGP (G4d): Bernoulli logit, ordinary latent(d=1),
## unique = FALSE.  Anchor = interior pi ~ 0.5 at the named (n, T).
mspl_forkB_l1_dgp <- function(n_site = 80L, n_trait = 8L, seed = 1L,
                              prevalence = "anchor") {
  set.seed(as.integer(seed))
  n_site <- as.integer(n_site)
  n_trait <- as.integer(n_trait)
  site <- factor(rep(sprintf("s%03d", seq_len(n_site)), each = n_trait))
  trait <- factor(
    rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  Lambda <- rep_len(c(0.9, -0.6, 0.45, 0.7), n_trait)
  beta <- switch(
    match.arg(prevalence, c("anchor", "near_tail")),
    anchor = rep_len(c(0.0, 0.25, -0.25, 0.1), n_trait),
    near_tail = rep_len(c(-1.6, -1.4, -1.8, -1.5), n_trait)
  )
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * Lambda[as.integer(trait)]
  y <- stats::rbinom(length(eta), 1L, stats::plogis(eta))
  data <- data.frame(site = site, trait = trait, y = y)
  list(
    data = data,
    beta = beta,
    Lambda = Lambda,
    n_site = n_site,
    n_trait = n_trait,
    prevalence = prevalence,
    seed = as.integer(seed),
    pi_mean = mean(y)
  )
}

mspl_forkB_l1_cells <- function() {
  data.frame(
    cell_id = c("L1-anchor-n80-T8", "L1-anchor-n40-T4", "L1-neartail-n40-T4"),
    n_site = c(80L, 40L, 40L),
    n_trait = c(8L, 4L, 4L),
    prevalence = c("anchor", "anchor", "near_tail"),
    role = c("L1-primary", "L1-timing", "L2-hold"),
    stringsAsFactors = FALSE
  )
}

mspl_forkB_trait_saturated <- function(data, trait_level) {
  y <- data$y[as.character(data$trait) == as.character(trait_level)]
  length(y) > 0L && (all(y == 0L) || all(y == 1L))
}

## Classify one replicate.  E1 only: first b_fix / first trait intercept.
## E2 (loadings) stays out until the probe accepts a non-b_fix coordinate.
mspl_forkB_classify <- function(fit, probe, fixture, which = 1L) {
  trait_level <- levels(fixture$data$trait)[[1L]]
  if (mspl_forkB_trait_saturated(fixture$data, trait_level)) {
    return(list(
      status = "refused", reason = "R-SAT", available = FALSE,
      returned = FALSE, covered = FALSE,
      lo = NA_real_, hi = NA_real_, truth = fixture$beta[[1L]]
    ))
  }
  if (inherits(fit, "try-error") || is.null(fit)) {
    return(list(
      status = "refused", reason = "R-FIT", available = FALSE,
      returned = FALSE, covered = FALSE,
      lo = NA_real_, hi = NA_real_, truth = fixture$beta[[1L]]
    ))
  }
  if (inherits(probe, "try-error") || is.null(probe)) {
    return(list(
      status = "refused", reason = "R-NAVL", available = FALSE,
      returned = FALSE, covered = FALSE,
      lo = NA_real_, hi = NA_real_, truth = fixture$beta[[1L]]
    ))
  }
  two_sided <- isTRUE(probe$finite_stable) &&
    identical(probe$lower_status, "crossed") &&
    identical(probe$upper_status, "crossed") &&
    is.finite(probe$lower_endpoint) &&
    is.finite(probe$upper_endpoint)
  if (!two_sided) {
    return(list(
      status = "refused", reason = "R-NAVL", available = FALSE,
      returned = FALSE, covered = FALSE,
      lo = NA_real_, hi = NA_real_, truth = fixture$beta[[1L]]
    ))
  }
  truth <- fixture$beta[[1L]]
  lo <- min(probe$lower_endpoint, probe$upper_endpoint)
  hi <- max(probe$lower_endpoint, probe$upper_endpoint)
  list(
    status = "returned", reason = NA_character_, available = TRUE,
    returned = TRUE, covered = isTRUE(truth >= lo && truth <= hi),
    lo = lo, hi = hi, truth = truth
  )
}

mspl_forkB_l1_metrics <- function(rows, level = 0.95) {
  n <- nrow(rows)
  n_sat <- sum(rows$reason == "R-SAT", na.rm = TRUE)
  n_non_sat <- n - n_sat
  n_avail <- sum(rows$available %in% TRUE)
  n_refused <- sum(rows$status == "refused")
  n_ret <- sum(rows$returned %in% TRUE)
  n_cover <- sum(rows$covered %in% TRUE)
  availability <- if (n_non_sat > 0L) n_avail / n_non_sat else NA_real_
  refusal <- if (n > 0L) n_refused / n else NA_real_
  cov_ret <- if (n_ret > 0L) n_cover / n_ret else NA_real_
  cov_eff <- if (n > 0L) n_cover / n else NA_real_
  w_ret <- if (n_ret > 0L) {
    mspl_forkB_wilson(n_cover, n_ret, level)
  } else {
    c(lower = NA_real_, upper = NA_real_, centre = NA_real_)
  }
  w_eff <- if (n > 0L) {
    mspl_forkB_wilson(n_cover, n, level)
  } else {
    c(lower = NA_real_, upper = NA_real_, centre = NA_real_)
  }
  ## "Wilson not entirely below 0.80" = the interval is not wholly < 0.80.
  wilson_eff_not_below_080 <- is.finite(w_eff[["upper"]]) &&
    w_eff[["upper"]] >= 0.80
  list(
    n_rep = n,
    n_returned = n_ret,
    n_refused = n_refused,
    n_available = n_avail,
    n_cover = n_cover,
    availability = availability,
    refusal = refusal,
    cov_ret = cov_ret,
    cov_eff = cov_eff,
    wilson_ret_lower = unname(w_ret[["lower"]]),
    wilson_ret_upper = unname(w_ret[["upper"]]),
    wilson_eff_lower = unname(w_eff[["lower"]]),
    wilson_eff_upper = unname(w_eff[["upper"]]),
    l1_wilson_eff_not_below_080 = wilson_eff_not_below_080,
    l1_availability_ge_090 = is.finite(availability) && availability >= 0.90,
    l1_refusal_le_015 = is.finite(refusal) && refusal <= 0.15
  )
}

mspl_forkB_l1_gate <- function(metrics) {
  pass <- isTRUE(metrics$l1_wilson_eff_not_below_080) &&
    isTRUE(metrics$l1_availability_ge_090) &&
    isTRUE(metrics$l1_refusal_le_015)
  list(
    pass = pass,
    rule = paste(
      "L1: cov_eff Wilson not entirely below 0.80;",
      "availability >= 0.90; refusal <= 0.15"
    )
  )
}

mspl_forkB_l1_fit <- function(data) {
  suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = data,
    family = stats::binomial(link = "logit"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  ))
}

mspl_forkB_l1_profile <- function(fit, which = 1L) {
  gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
    fit, which = as.integer(which), tape = "Q_0"
  )
}

## One L1 cell.  Returns a list with status blocked-on-L0 if the probe
## has no tape= argument (fork B not measurable on this install).
mspl_forkB_l1_run_cell <- function(cell_id = "L1-anchor-n80-T8",
                                   n_rep = 50L,
                                   seed_base = 20260818L,
                                   which = 1L) {
  cells <- mspl_forkB_l1_cells()
  cell <- cells[cells$cell_id == cell_id, , drop = FALSE]
  if (nrow(cell) != 1L) {
    stop("Unknown L1 cell_id: ", cell_id)
  }
  if (!mspl_forkB_l0_ready()) {
    return(list(
      status = "blocked-on-L0",
      cell_id = cell_id,
      n_rep = as.integer(n_rep),
      reason = paste(
        "L0 plumbing is not on the loaded gllvmTMB:",
        ".gllvmTMB_mspl_profile_feasibility() has no tape= argument,",
        "so fork B (tape = \"Q_0\") is not measurable."
      ),
      public_confint = "refused",
      calibrated = FALSE,
      coverage_claim = "none"
    ))
  }
  rows <- vector("list", as.integer(n_rep))
  for (i in seq_len(as.integer(n_rep))) {
    fixture <- mspl_forkB_l1_dgp(
      n_site = cell$n_site[[1L]],
      n_trait = cell$n_trait[[1L]],
      seed = as.integer(seed_base) + i,
      prevalence = cell$prevalence[[1L]]
    )
    fit <- try(mspl_forkB_l1_fit(fixture$data), silent = TRUE)
    probe <- if (inherits(fit, "try-error")) {
      fit
    } else {
      try(mspl_forkB_l1_profile(fit, which = which), silent = TRUE)
    }
    klass <- mspl_forkB_classify(fit, probe, fixture, which = which)
    tape <- if (is.list(probe) && !inherits(probe, "try-error")) {
      probe$tape
    } else {
      NA_character_
    }
    fork <- if (is.list(probe) && !inherits(probe, "try-error")) {
      probe$design_125_fork
    } else {
      NA_character_
    }
    rows[[i]] <- data.frame(
      cell_id = cell_id,
      rep = i,
      seed = fixture$seed,
      pi_mean = fixture$pi_mean,
      status = klass$status,
      reason = if (is.na(klass$reason)) NA_character_ else klass$reason,
      available = klass$available,
      returned = klass$returned,
      covered = klass$covered,
      lo = klass$lo,
      hi = klass$hi,
      truth = klass$truth,
      tape = if (is.na(tape)) NA_character_ else tape,
      design_125_fork = if (is.na(fork)) NA_character_ else fork,
      stringsAsFactors = FALSE
    )
  }
  tab <- do.call(rbind, rows)
  metrics <- mspl_forkB_l1_metrics(tab)
  gate <- mspl_forkB_l1_gate(metrics)
  list(
    status = if (gate$pass) "L1-PASS" else "L1-FAIL",
    cell_id = cell_id,
    n_rep = as.integer(n_rep),
    seed_base = as.integer(seed_base),
    estimand = "E1",
    tape = "Q_0",
    design_125_fork = "B",
    rows = tab,
    metrics = metrics,
    gate = gate,
    public_confint = "refused",
    calibrated = FALSE,
    coverage_claim = "none"
  )
}
