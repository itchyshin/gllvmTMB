## Pure PVT-02 helpers.  This dev-only contract deliberately has no package API.
pvt02_lower_triangular_loadings <- function(theta, n_traits, d) {
  n_traits <- as.integer(n_traits)
  d <- as.integer(d)
  n <- sum(pmin(seq_len(n_traits), d))
  if (n_traits < 1L || d < 1L || length(theta) != n || any(!is.finite(theta))) {
    stop("theta must contain the finite lower-triangular loading coordinates")
  }
  out <- matrix(0, n_traits, d)
  at <- 1L
  diag_n <- min(n_traits, d)
  for (j in seq_len(diag_n)) {
    out[j, j] <- theta[at]
    at <- at + 1L
  }
  for (j in seq_len(d)) {
    if (j < n_traits) {
      for (i in (j + 1L):n_traits) {
        out[i, j] <- theta[at]
        at <- at + 1L
      }
    }
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
  gradient <- numeric(length(theta_lambda) + length(theta_psi))
  at <- 1L
  diag_n <- min(n_traits, d)
  for (j in seq_len(diag_n)) {
    if (trait == j) {
      gradient[at] <- 2 * lambda[j, j] / V
    }
    at <- at + 1L
  }
  for (j in seq_len(d)) {
    if (j < n_traits) {
      for (i in (j + 1L):n_traits) {
        if (trait == i) {
          gradient[at] <- 2 * lambda[i, j] / V
        }
        at <- at + 1L
      }
    }
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
  if (!length(par) || !is.finite(h) || h <= 0) {
    stop("par must be non-empty and h must be positive")
  }
  vapply(
    seq_along(par),
    function(i) {
      a <- b <- par
      a[i] <- a[i] + h
      b[i] <- b[i] - h
      (fn(a) - fn(b)) / (2 * h)
    },
    numeric(1)
  )
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
    fm <- score(mid)
    if (!is.finite(fm)) {
      stop("non-finite likelihood-ratio score inside profile bracket")
    }
    if (abs(fm) <= tol || (hi - lo) / 2 <= tol) {
      return(list(root = mid, iterations = i, converged = TRUE))
    }
    if (flo * fm <= 0) {
      hi <- mid
    } else {
      lo <- mid
      flo <- fm
    }
  }
  list(
    root = (lo + hi) / 2,
    iterations = as.integer(max_iter),
    converged = FALSE
  )
}
pvt02_seed_window <- function(start, n) {
  start <- as.integer(start)
  n <- as.integer(n)
  if (is.na(start) || is.na(n) || start < 1L || n < 1L) {
    stop("seed-window start and n must be positive integers")
  }
  seq.int(start, length.out = n)
}
pvt02_m3_seed <- function(
  rep_index,
  d = 2L,
  seed_base = 1L,
  family_index = 1L
) {
  as.integer(
    seed_base +
      1000L * as.integer(d) +
      100000L * as.integer(family_index) +
      as.integer(rep_index)
  )
}
pvt02_campaign_seed <- function(rep_index) {
  rep_index <- as.integer(rep_index)
  if (
    !length(rep_index) ||
      anyNA(rep_index) ||
      any(rep_index < 1L) ||
      any(rep_index > 1347483647L)
  ) {
    stop("PVT-02 replicate indices cannot be mapped to the reserved seed range")
  }
  as.integer(800000000L + rep_index)
}
pvt02_windows_disjoint <- function(...) {
  x <- unlist(list(...), use.names = FALSE)
  length(x) == length(unique(x))
}
pvt02_interval_is_valid <- function(estimate, lower, upper) {
  is.finite(estimate) &&
    is.finite(lower) &&
    is.finite(upper) &&
    lower < estimate &&
    estimate < upper
}
pvt02_attempt_row <- function(
  rep,
  seed,
  truth,
  estimate,
  lower = NA_real_,
  upper = NA_real_,
  fit_converged = TRUE,
  endpoint_reason = "profile_failed"
) {
  fit_converged <- isTRUE(fit_converged)
  valid <- fit_converged && pvt02_interval_is_valid(estimate, lower, upper)
  data.frame(
    rep = as.integer(rep),
    seed = as.integer(seed),
    truth = as.numeric(truth),
    estimate = as.numeric(estimate),
    lower = as.numeric(lower),
    upper = as.numeric(upper),
    fit_converged = fit_converged,
    ci_failed = fit_converged && !valid,
    eligible = fit_converged,
    covered = if (!fit_converged) {
      NA
    } else if (valid) {
      truth >= lower && truth <= upper
    } else {
      FALSE
    },
    endpoint_reason = if (!fit_converged) {
      "fit_failed"
    } else if (valid) {
      "ok"
    } else {
      endpoint_reason
    },
    stringsAsFactors = FALSE
  )
}
pvt02_validate_attempt_rows <- function(rows, expected_reps) {
  req <- c(
    "rep",
    "seed",
    "fit_converged",
    "ci_failed",
    "eligible",
    "covered",
    "endpoint_reason"
  )
  expected_reps <- as.integer(expected_reps)
  if (!is.data.frame(rows) || !all(req %in% names(rows))) {
    stop("PVT-02 results must retain the complete attempt-row schema")
  }
  if (
    nrow(rows) != length(expected_reps) ||
      anyDuplicated(rows$rep) ||
      !setequal(rows$rep, expected_reps)
  ) {
    stop("PVT-02 must retain exactly one row for every requested replicate")
  }
  ordered <- rows[match(expected_reps, rows$rep), ]
  if (
    anyDuplicated(rows$seed) ||
      !identical(as.integer(ordered$seed), pvt02_m3_seed(expected_reps, d = 2L))
  ) {
    stop(
      "PVT-02 retained seeds must be unique and match the frozen d = 2 mapping"
    )
  }
  if (
    any(rows$eligible & is.na(rows$covered)) ||
      any(!rows$eligible & rows$endpoint_reason != "fit_failed")
  ) {
    stop("PVT-02 endpoint policy is not fully classified")
  }
  invisible(TRUE)
}
pvt02_summarise <- function(rows, expected_reps = sort(unique(rows$rep))) {
  pvt02_validate_attempt_rows(rows, expected_reps)
  ok <- rows$eligible
  z <- tapply(as.numeric(rows$covered[ok]), rows$rep[ok], mean)
  coverage <- if (length(z)) mean(z) else NA_real_
  mcse <- if (length(z) > 1L) stats::sd(z) / sqrt(length(z)) else NA_real_
  list(
    n_attempted = nrow(rows),
    n_converged = sum(ok),
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
  if (!pvt02_exact_cell(cell)) {
    reasons <- c(reasons, "not_exact_pvt02_cell")
  }
  if (!isTRUE(seed_disjoint)) {
    reasons <- c(reasons, "seed_window_not_disjoint")
  }
  if (!identical(as.integer(summary$n_attempted), 5000L)) {
    reasons <- c(reasons, "not_5000_attempts")
  }
  if (!is.finite(summary$coverage) || summary$coverage < .94) {
    reasons <- c(reasons, "coverage_below_0.94")
  }
  if (!is.finite(summary$lower_band) || summary$lower_band < .94) {
    reasons <- c(reasons, "lower_band_below_0.94")
  }
  list(promote = !length(reasons), reasons = reasons)
}

pvt02_manifest_fingerprint <- function(manifest) {
  cols <- c(
    "campaign_id",
    "source_sha",
    "rep",
    "seed",
    "attempt",
    "attempt_id",
    "target_traits",
    "family",
    "tier",
    "mode",
    "unique",
    "d",
    "n_units",
    "n_traits",
    "target_scale",
    "level"
  )
  if (!is.data.frame(manifest) || !all(cols %in% names(manifest))) {
    stop("PVT-02 manifest lacks provenance fields")
  }
  paste(
    vapply(
      cols,
      function(x) paste(manifest[[x]], collapse = ","),
      character(1)
    ),
    collapse = "|"
  )
}
pvt02_campaign_manifest <- function(cell, source_sha, reps = 50001:55000) {
  if (!pvt02_exact_cell(cell) || !identical(as.integer(cell$n_traits), 3L)) {
    stop("PVT-02 manifest requires the frozen n_traits = 3 exact cell")
  }
  if (
    !is.character(source_sha) || length(source_sha) != 1L || !nzchar(source_sha)
  ) {
    stop("PVT-02 manifest requires a nonempty source_sha")
  }
  reps <- as.integer(reps)
  if (!length(reps) || anyNA(reps) || any(reps < 1L) || anyDuplicated(reps)) {
    stop("PVT-02 replicate indices must be unique positive integers")
  }
  out <- data.frame(
    campaign_id = "PVT-02",
    source_sha = source_sha,
    rep = reps,
    seed = pvt02_campaign_seed(reps),
    attempt = 1L,
    attempt_id = sprintf("pvt02-r%d-a1", reps),
    target_traits = "1,2",
    family = cell$family,
    tier = cell$tier,
    mode = cell$mode,
    unique = cell$unique,
    d = as.integer(cell$d),
    n_units = as.integer(cell$n_units),
    n_traits = as.integer(cell$n_traits),
    target_scale = cell$target_scale,
    level = as.numeric(cell$level),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}
pvt02_target_payload <- function(
  trait,
  truth,
  estimate,
  lower = NA_real_,
  upper = NA_real_,
  endpoint_reason = "profile_failed",
  interval_status = "route-only"
) {
  trait <- as.integer(trait)
  if (length(trait) != 1L || is.na(trait) || !(trait %in% 1:2)) {
    stop("PVT-02 target payload requires trait 1 or 2")
  }
  valid <- pvt02_interval_is_valid(estimate, lower, upper)
  data.frame(
    trait = trait,
    truth = as.numeric(truth),
    estimate = as.numeric(estimate),
    lower = as.numeric(lower),
    upper = as.numeric(upper),
    ci_failed = !valid,
    covered = if (valid) truth >= lower && truth <= upper else FALSE,
    endpoint_reason = if (valid) "ok" else as.character(endpoint_reason),
    interval_status = as.character(interval_status),
    stringsAsFactors = FALSE
  )
}

pvt02_fit_is_healthy <- function(fit) {
  inherits(fit, "gllvmTMB_multi") &&
    identical(as.integer(fit$opt$convergence), 0L) &&
    isTRUE(fit$fit_health$converged) &&
    !is.null(fit$sd_report) &&
    isTRUE(fit$sd_report$pdHess)
}
pvt02_outer_attempt_row <- function(
  manifest_row,
  fit_converged,
  targets = NULL,
  endpoint_reason = "fit_failed"
) {
  req <- c("campaign_id", "source_sha", "rep", "seed", "attempt", "attempt_id")
  if (
    !is.data.frame(manifest_row) ||
      nrow(manifest_row) != 1L ||
      !all(req %in% names(manifest_row))
  ) {
    stop("PVT-02 outer attempt requires one manifest row with provenance")
  }
  if (is.null(targets)) {
    targets <- data.frame(
      trait = integer(),
      truth = numeric(),
      estimate = numeric(),
      lower = numeric(),
      upper = numeric(),
      ci_failed = logical(),
      covered = logical(),
      endpoint_reason = character(),
      interval_status = character()
    )
  }
  ok <- isTRUE(fit_converged)
  data.frame(
    campaign_id = manifest_row$campaign_id,
    source_sha = manifest_row$source_sha,
    rep = manifest_row$rep,
    seed = manifest_row$seed,
    attempt = manifest_row$attempt,
    attempt_id = manifest_row$attempt_id,
    fit_converged = ok,
    eligible = ok,
    endpoint_reason = if (ok) "ok" else endpoint_reason,
    targets = I(list(targets)),
    stringsAsFactors = FALSE
  )
}
pvt02_validate_outer_payload <- function(outer) {
  req <- c("fit_converged", "eligible", "endpoint_reason", "targets")
  if (
    !is.data.frame(outer) || nrow(outer) != 1L || !all(req %in% names(outer))
  ) {
    stop("PVT-02 outer row has the wrong schema")
  }
  ok <- isTRUE(outer$fit_converged[[1L]])
  if (!identical(isTRUE(outer$eligible[[1L]]), ok)) {
    stop("PVT-02 outer eligibility conflicts with fit state")
  }
  z <- outer$targets[[1L]]
  if (!is.data.frame(z)) {
    stop("PVT-02 targets must be a nested data frame")
  }
  if (!ok) {
    if (nrow(z)) {
      stop("PVT-02 fit failure cannot contain target payloads")
    }
    return(invisible(TRUE))
  }
  req2 <- c(
    "trait",
    "truth",
    "estimate",
    "lower",
    "upper",
    "ci_failed",
    "covered",
    "endpoint_reason",
    "interval_status"
  )
  if (
    !all(req2 %in% names(z)) ||
      nrow(z) != 2L ||
      anyDuplicated(z$trait) ||
      !setequal(as.integer(z$trait), 1:2)
  ) {
    stop("PVT-02 eligible outer row has an incomplete target payload")
  }
  if (any(z$interval_status != "route-only")) {
    stop("PVT-02 n_units=400 targets must retain route-only public status")
  }
  z <- z[match(1:2, z$trait), ]
  valid <- mapply(pvt02_interval_is_valid, z$estimate, z$lower, z$upper)
  cover <- ifelse(valid, z$truth >= z$lower & z$truth <= z$upper, FALSE)
  if (
    !identical(as.logical(z$ci_failed), as.logical(!valid)) ||
      !identical(as.logical(z$covered), as.logical(cover))
  ) {
    stop("PVT-02 target payload conflicts with endpoints")
  }
  invisible(TRUE)
}
pvt02_retry_class <- function(message, stage) {
  x <- tolower(paste(as.character(message), collapse = " "))
  stage <- tolower(as.character(stage)[[1L]])
  if (!stage %in% c("simulate", "fit", "profile", "write", "merge")) {
    stop("PVT-02 retry stage is not recognised")
  }
  if (
    grepl(
      "slurm|node failure|network|connection|filesystem|file system|i/o|disk|quota|timeout|preempt",
      x,
      perl = TRUE
    )
  ) {
    return("infrastructure")
  }
  if (
    grepl(
      "non[- ]?converg|hessian|optimizer|profile|endpoint|likelihood|gradient|non[- ]?finite",
      x,
      perl = TRUE
    )
  ) {
    return("scientific")
  }
  stop("PVT-02 retry cause is unclassified; do not retry by default")
}
pvt02_operational_retry_row <- function(manifest_row, attempt, message, stage) {
  if (
    !is.data.frame(manifest_row) ||
      nrow(manifest_row) != 1L ||
      !all(c("rep", "seed", "source_sha") %in% names(manifest_row))
  ) {
    stop("PVT-02 retry history requires exactly one outer manifest row")
  }
  attempt <- as.integer(attempt)
  if (is.na(attempt) || attempt < 2L) {
    stop("operational retries start at attempt 2")
  }
  if (!identical(pvt02_retry_class(message, stage), "infrastructure")) {
    stop("scientific failures are terminal canonical outer outcomes")
  }
  data.frame(
    source_sha = manifest_row$source_sha,
    rep = manifest_row$rep,
    seed = manifest_row$seed,
    attempt = attempt,
    attempt_id = sprintf("pvt02-r%d-a%d", manifest_row$rep, attempt),
    retry_class = "infrastructure",
    stage = stage,
    message = message,
    stringsAsFactors = FALSE
  )
}
pvt02_batch_receipt <- function(
  manifest,
  canonical,
  operational_history = NULL
) {
  if (is.null(operational_history)) {
    operational_history <- data.frame(
      source_sha = character(),
      rep = integer(),
      seed = integer(),
      attempt = integer(),
      attempt_id = character(),
      retry_class = character(),
      stage = character(),
      message = character()
    )
  }
  list(
    schema = "pvt02-outer-batch-v1",
    manifest = manifest,
    manifest_fingerprint = pvt02_manifest_fingerprint(manifest),
    canonical = canonical,
    operational_history = operational_history
  )
}
pvt02_manifest_key <- function(rows) paste(rows$rep, rows$seed, sep = ":")
pvt02_validate_batch_receipt <- function(receipt, manifest) {
  req <- c(
    "schema",
    "manifest",
    "manifest_fingerprint",
    "canonical",
    "operational_history"
  )
  if (
    !is.list(receipt) ||
      !identical(names(receipt), req) ||
      !identical(receipt$schema, "pvt02-outer-batch-v1")
  ) {
    stop("PVT-02 batch receipt does not use immutable outer schema")
  }
  batch <- receipt$manifest
  if (
    !identical(receipt$manifest_fingerprint, pvt02_manifest_fingerprint(batch))
  ) {
    stop("PVT-02 receipt fingerprint was tampered")
  }
  bk <- pvt02_manifest_key(batch)
  gk <- pvt02_manifest_key(manifest)
  if (
    anyDuplicated(bk) ||
      anyNA(match(bk, gk)) ||
      !identical(as.integer(batch$seed), pvt02_campaign_seed(batch$rep))
  ) {
    stop("PVT-02 batch receipt manifest conflicts with frozen seed mapping")
  }
  expected <- manifest[match(bk, gk), names(batch), drop = FALSE]
  attr(expected, "row.names") <- attr(batch, "row.names")
  if (!identical(batch, expected)) {
    stop("PVT-02 batch receipt manifest is not immutable")
  }
  can <- receipt$canonical
  reqc <- c(
    "campaign_id",
    "source_sha",
    "rep",
    "seed",
    "attempt",
    "attempt_id",
    "fit_converged",
    "eligible",
    "endpoint_reason",
    "targets"
  )
  if (!is.data.frame(can) || !all(reqc %in% names(can))) {
    stop("PVT-02 canonical outer rows have wrong schema")
  }
  if (anyDuplicated(can$rep)) {
    stop("PVT-02 receipt has duplicate canonical outer rows")
  }
  if (!setequal(can$rep, batch$rep)) {
    stop("PVT-02 receipt has missing canonical outer rows")
  }
  m <- batch[match(can$rep, batch$rep), ]
  if (
    !identical(as.integer(can$seed), as.integer(m$seed)) ||
      !identical(as.character(can$source_sha), as.character(m$source_sha)) ||
      !identical(as.character(can$attempt_id), as.character(m$attempt_id))
  ) {
    stop("PVT-02 canonical outer row conflicts with manifest")
  }
  for (i in seq_len(nrow(can))) {
    pvt02_validate_outer_payload(can[i, , drop = FALSE])
  }
  h <- receipt$operational_history
  if (
    !is.data.frame(h) ||
      !all(
        c(
          "source_sha",
          "rep",
          "seed",
          "attempt",
          "attempt_id",
          "retry_class",
          "stage",
          "message"
        ) %in%
          names(h)
      )
  ) {
    stop("PVT-02 operational history has wrong schema")
  }
  if (
    nrow(h) &&
      (any(h$source_sha != batch$source_sha[[1L]]) ||
        any(h$attempt < 2L) ||
        any(h$retry_class != "infrastructure") ||
        anyDuplicated(h$attempt_id))
  ) {
    stop("PVT-02 operational retry history conflicts with manifest")
  }
  if (nrow(h)) {
    retry_manifest <- batch[match(h$rep, batch$rep), , drop = FALSE]
    expected_ids <- sprintf("pvt02-r%d-a%d", h$rep, h$attempt)
    if (
      any(is.na(retry_manifest$rep)) ||
        !identical(as.integer(h$seed), as.integer(retry_manifest$seed)) ||
        !identical(as.character(h$attempt_id), expected_ids)
    ) {
      stop("PVT-02 operational retry identity conflicts with manifest")
    }
    attempts_by_rep <- split(h$attempt, h$rep)
    if (
      any(vapply(
        attempts_by_rep,
        function(x) !identical(sort(as.integer(x)), seq.int(2L, max(x))),
        logical(1)
      ))
    ) {
      stop("PVT-02 operational retry versions must be consecutive from two")
    }
  }
  invisible(TRUE)
}
pvt02_merge_batch_receipts <- function(manifest, receipts) {
  if (!is.data.frame(manifest) || !length(receipts)) {
    stop("PVT-02 requires batch receipts")
  }
  lapply(receipts, pvt02_validate_batch_receipt, manifest = manifest)
  can <- do.call(rbind, lapply(receipts, `[[`, "canonical"))
  hist <- do.call(rbind, lapply(receipts, `[[`, "operational_history"))
  if (anyDuplicated(can$rep)) {
    stop("PVT-02 merger rejects duplicate/conflicting canonical outer rows")
  }
  if (!setequal(can$rep, manifest$rep)) {
    stop("PVT-02 merger rejects missing canonical outer rows")
  }
  can <- can[match(manifest$rep, can$rep), ]
  list(
    canonical = can,
    operational_history = hist,
    manifest_fingerprint = pvt02_manifest_fingerprint(manifest)
  )
}
pvt02_summarise_campaign <- function(merged, manifest) {
  if (
    !identical(
      merged$manifest_fingerprint,
      pvt02_manifest_fingerprint(manifest)
    )
  ) {
    stop("PVT-02 merged ledger fingerprint was tampered")
  }
  pvt02_validate_batch_receipt(
    pvt02_batch_receipt(manifest, merged$canonical, merged$operational_history),
    manifest
  )
  outer <- merged$canonical
  ok <- outer$eligible
  rows <- lapply(1:2, function(trait) {
    z <- lapply(which(ok), function(i) {
      x <- outer$targets[[i]]
      x[x$trait == trait, , drop = FALSE]
    })
    if (length(z)) {
      do.call(rbind, z)
    } else {
      data.frame(covered = logical(), ci_failed = logical())
    }
  })
  cov <- mcse <- band <- nrep <- nci <- numeric(2)
  names(cov) <- names(mcse) <- names(band) <- names(nrep) <- names(nci) <- c(
    "1",
    "2"
  )
  for (k in c("1", "2")) {
    z <- rows[[as.integer(k)]]
    nrep[[k]] <- nrow(z)
    nci[[k]] <- sum(z$ci_failed)
    cov[[k]] <- if (nrow(z)) mean(z$covered) else NA_real_
    mcse[[k]] <- if (nrow(z) > 1) {
      stats::sd(as.numeric(z$covered)) / sqrt(nrow(z))
    } else {
      NA_real_
    }
    band[[k]] <- cov[[k]] - 2 * mcse[[k]]
  }
  list(
    n_outer = nrow(outer),
    n_converged_outer = sum(ok),
    n_fit_failed_outer = sum(!ok),
    all_attempt_outer_failure_fraction = mean(!ok),
    n_operational_retries = nrow(merged$operational_history),
    coverage = cov,
    mcse = mcse,
    lower_band = band,
    n_replicates = structure(as.integer(nrep), names = names(nrep)),
    n_ci_failed = structure(as.integer(nci), names = names(nci)),
    manifest_fingerprint = pvt02_manifest_fingerprint(manifest)
  )
}
pvt02_availability_report <- function(summary) {
  data.frame(
    n_outer = as.integer(summary$n_outer),
    n_converged_outer = as.integer(summary$n_converged_outer),
    n_fit_failed_outer = as.integer(summary$n_fit_failed_outer),
    all_attempt_outer_failure_fraction = as.numeric(
      summary$all_attempt_outer_failure_fraction
    ),
    n_operational_retries = as.integer(summary$n_operational_retries)
  )
}
pvt02_campaign_promotion_verdict <- function(
  cell,
  manifest,
  merged,
  seed_disjoint,
  n_sim = 5000L
) {
  reasons <- character()
  if (!pvt02_exact_cell(cell) || !identical(as.integer(cell$n_traits), 3L)) {
    reasons <- c(reasons, "not_exact_pvt02_cell")
  }
  if (!isTRUE(seed_disjoint)) {
    reasons <- c(reasons, "seed_window_not_disjoint")
  }
  full <- pvt02_campaign_manifest(cell, manifest$source_sha[[1L]])
  if (!identical(manifest, full) || !identical(as.integer(n_sim), 5000L)) {
    reasons <- c(reasons, "not_exact_5000_outer_manifest")
  }
  summary <- tryCatch(
    pvt02_summarise_campaign(merged, manifest),
    error = function(e) NULL
  )
  if (is.null(summary) || summary$n_outer != 5000L) {
    reasons <- c(reasons, "invalid_outer_ledger")
  }
  if (!is.null(summary)) {
    for (k in c("1", "2")) {
      if (!is.finite(summary$coverage[[k]]) || summary$coverage[[k]] < .94) {
        reasons <- c(reasons, paste0("trait_", k, "_coverage_below_0.94"))
      }
      if (
        !is.finite(summary$lower_band[[k]]) || summary$lower_band[[k]] < .94
      ) {
        reasons <- c(reasons, paste0("trait_", k, "_lower_band_below_0.94"))
      }
    }
  }
  list(
    promote = !length(reasons),
    reasons = reasons,
    availability = if (is.null(summary)) {
      NULL
    } else {
      pvt02_availability_report(summary)
    }
  )
}
