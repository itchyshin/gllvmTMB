## PVT-02 pure contract helpers.
##
## These helpers deliberately live outside the package namespace: they freeze
## the calibration packet's arithmetic and accounting without changing the
## public profile implementation or its currently over-broad status predicate.

pvt02_lower_triangular_loadings <- function(theta, n_traits, d) {
  n_traits <- as.integer(n_traits)
  d <- as.integer(d)
  n_expected <- sum(pmin(seq_len(n_traits), d))
  if (
    n_traits < 1L || d < 1L || length(theta) != n_expected ||
      any(!is.finite(theta))
  ) {
    stop("theta must contain the finite lower-triangular loading coordinates")
  }
  out <- matrix(0, nrow = n_traits, ncol = d)
  cursor <- 1L
  for (i in seq_len(n_traits)) {
    width <- min(i, d)
    out[i, seq_len(width)] <- theta[cursor:(cursor + width - 1L)]
    cursor <- cursor + width
  }
  out
}

pvt02_psi_sq <- function(theta_psi) {
  if (any(!is.finite(theta_psi))) {
    stop("theta_psi must be finite")
  }
  exp(2 * theta_psi)
}

pvt02_target_spec <- function(theta_lambda, theta_psi, n_traits, d, trait) {
  lambda <- pvt02_lower_triangular_loadings(theta_lambda, n_traits, d)
  psi_sq <- pvt02_psi_sq(theta_psi)
  trait <- as.integer(trait)
  if (length(theta_psi) != n_traits || trait < 1L || trait > n_traits) {
    stop("theta_psi and trait must match n_traits")
  }
  V <- sum(lambda[trait, ]^2) + psi_sq[trait]
  if (!is.finite(V) || V <= 0) {
    stop("PVT-02 target V_t must be positive and finite")
  }

  ## Coordinates follow pvt02_lower_triangular_loadings() row by row, then
  ## theta_psi. Only the selected row's loading coordinates contribute.
  gradient <- numeric(length(theta_lambda) + length(theta_psi))
  cursor <- 1L
  for (i in seq_len(n_traits)) {
    width <- min(i, d)
    if (i == trait) {
      gradient[cursor:(cursor + width - 1L)] <- 2 * lambda[i, seq_len(width)] / V
    }
    cursor <- cursor + width
  }
  gradient[length(theta_lambda) + trait] <- 2 * psi_sq[trait] / V

  list(
    lambda = lambda,
    psi_sq = psi_sq,
    V = V,
    log_V = log(V),
    gradient = gradient
  )
}

pvt02_fd_gradient <- function(fn, par, h = 1e-6) {
  if (length(par) < 1L || !is.finite(h) || h <= 0) {
    stop("par must be non-empty and h must be positive")
  }
  vapply(seq_along(par), function(i) {
    plus <- minus <- par
    plus[i] <- plus[i] + h
    minus[i] <- minus[i] - h
    (fn(plus) - fn(minus)) / (2 * h)
  }, numeric(1))
}

pvt02_profile_root <- function(score, lo, hi, tol = 1e-8, max_iter = 100L) {
  if (!is.function(score) || !is.finite(lo) || !is.finite(hi) || lo >= hi) {
    stop("score, lo, and hi must define an ordered finite bracket")
  }
  flo <- score(lo)
  fhi <- score(hi)
  if (!is.finite(flo) || !is.finite(fhi) || flo * fhi > 0) {
    stop("profile endpoint does not bracket a one-df LR root")
  }
  for (i in seq_len(as.integer(max_iter))) {
    mid <- (lo + hi) / 2
    fmid <- score(mid)
    if (!is.finite(fmid)) {
      stop("non-finite likelihood-ratio score inside profile bracket")
    }
    if (abs(fmid) <= tol || (hi - lo) / 2 <= tol) {
      return(list(root = mid, iterations = i, converged = TRUE))
    }
    if (flo * fmid <= 0) {
      hi <- mid
      fhi <- fmid
    } else {
      lo <- mid
      flo <- fmid
    }
  }
  list(root = (lo + hi) / 2, iterations = as.integer(max_iter), converged = FALSE)
}

pvt02_seed_window <- function(start, n) {
  start <- as.integer(start)
  n <- as.integer(n)
  if (is.na(start) || is.na(n) || start < 1L || n < 1L) {
    stop("seed-window start and n must be positive integers")
  }
  seq.int(start, length.out = n)
}

pvt02_m3_seed <- function(rep_index, d = 2L, seed_base = 1L, family_index = 1L) {
  as.integer(seed_base + 1000L * as.integer(d) +
    100000L * as.integer(family_index) + as.integer(rep_index))
}

pvt02_windows_disjoint <- function(...) {
  windows <- list(...)
  all_indices <- unlist(windows, use.names = FALSE)
  length(all_indices) == length(unique(all_indices))
}

pvt02_interval_is_valid <- function(estimate, lower, upper) {
  is.finite(estimate) && is.finite(lower) && is.finite(upper) &&
    lower < estimate && estimate < upper
}

pvt02_attempt_row <- function(rep, seed, truth, estimate, lower = NA_real_, upper = NA_real_,
                              fit_converged = TRUE, endpoint_reason = "profile_failed") {
  fit_converged <- isTRUE(fit_converged)
  valid_interval <- fit_converged && pvt02_interval_is_valid(estimate, lower, upper)
  ci_failed <- fit_converged && !valid_interval
  data.frame(
    rep = as.integer(rep),
    seed = as.integer(seed),
    truth = as.numeric(truth),
    estimate = as.numeric(estimate),
    lower = as.numeric(lower),
    upper = as.numeric(upper),
    fit_converged = fit_converged,
    ci_failed = ci_failed,
    eligible = fit_converged,
    covered = if (!fit_converged) NA else if (valid_interval) {
      truth >= lower && truth <= upper
    } else {
      FALSE
    },
    endpoint_reason = if (!fit_converged) "fit_failed" else if (valid_interval) {
      "ok"
    } else {
      endpoint_reason
    },
    stringsAsFactors = FALSE
  )
}

pvt02_validate_attempt_rows <- function(rows, expected_reps) {
  required <- c("rep", "seed", "fit_converged", "ci_failed", "eligible", "covered", "endpoint_reason")
  if (!is.data.frame(rows) || !all(required %in% names(rows))) {
    stop("PVT-02 results must retain the complete attempt-row schema")
  }
  expected_reps <- as.integer(expected_reps)
  if (nrow(rows) != length(expected_reps) || anyDuplicated(rows$rep) ||
      !setequal(rows$rep, expected_reps)) {
    stop("PVT-02 must retain exactly one row for every requested replicate")
  }
  ordered <- rows[match(expected_reps, rows$rep), , drop = FALSE]
  expected_seeds <- pvt02_m3_seed(expected_reps, d = 2L)
  if (anyDuplicated(rows$seed) || !identical(as.integer(ordered$seed), expected_seeds)) {
    stop("PVT-02 retained seeds must be unique and match the frozen d = 2 mapping")
  }
  if (any(rows$eligible & is.na(rows$covered)) ||
      any(!rows$eligible & rows$endpoint_reason != "fit_failed")) {
    stop("PVT-02 endpoint policy is not fully classified")
  }
  invisible(TRUE)
}

pvt02_summarise <- function(rows, expected_reps = sort(unique(rows$rep))) {
  pvt02_validate_attempt_rows(rows, expected_reps)
  eligible <- rows$eligible
  cluster_means <- tapply(as.numeric(rows$covered[eligible]), rows$rep[eligible], mean)
  n_clusters <- length(cluster_means)
  coverage <- if (n_clusters > 0L) mean(cluster_means) else NA_real_
  mcse <- if (n_clusters > 1L) stats::sd(cluster_means) / sqrt(n_clusters) else NA_real_
  list(
    n_attempted = nrow(rows),
    n_converged = sum(eligible),
    n_fit_failed = sum(!rows$fit_converged),
    n_ci_failed = sum(rows$ci_failed),
    all_attempt_failure_fraction = mean(!rows$fit_converged | rows$ci_failed),
    coverage = coverage,
    mcse = mcse,
    lower_band = coverage - 2 * mcse
  )
}

pvt02_exact_cell <- function(cell) {
  identical(cell$family, "gaussian") &&
    identical(cell$tier, "unit") &&
    identical(cell$mode, "latent") &&
    identical(cell$unique, TRUE) &&
    identical(as.integer(cell$d), 2L) &&
    identical(as.integer(cell$n_units), 400L) &&
    identical(cell$target_scale, "log_V") &&
    identical(as.numeric(cell$level), 0.95)
}

pvt02_promotion_verdict <- function(cell, summary, seed_disjoint) {
  reasons <- character()
  if (!pvt02_exact_cell(cell)) reasons <- c(reasons, "not_exact_pvt02_cell")
  if (!isTRUE(seed_disjoint)) reasons <- c(reasons, "seed_window_not_disjoint")
  if (!identical(as.integer(summary$n_attempted), 5000L)) reasons <- c(reasons, "not_5000_attempts")
  if (!is.finite(summary$coverage) || summary$coverage < 0.94) reasons <- c(reasons, "coverage_below_0.94")
  if (!is.finite(summary$lower_band) || summary$lower_band < 0.94) reasons <- c(reasons, "lower_band_below_0.94")
  list(promote = length(reasons) == 0L, reasons = reasons)
}
