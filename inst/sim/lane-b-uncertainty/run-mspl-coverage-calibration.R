#!/usr/bin/env Rscript

## Private Gate 0 LA-MSPL repeated-sampling coverage runner.  This script is
## deliberately outside public inference dispatch.  Its outputs are evidence
## receipts, not user-facing confidence intervals.

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x

arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}

atomic_write_rds <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".mspl-coverage-", dirname(path), fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, compress = "gzip", version = 3L)
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path)
  invisible(path)
}

atomic_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".mspl-coverage-", dirname(path), fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.csv(x, tmp, row.names = FALSE, na = "")
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path)
  invisible(path)
}

atomic_write_tsv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(".mspl-coverage-", dirname(path), fileext = ".tsv")
  on.exit(unlink(tmp), add = TRUE)
  utils::write.table(x, tmp, sep = "\t", row.names = FALSE, quote = FALSE, na = "")
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path)
  invisible(path)
}

atomic_write_lines <- function(x, path, immutable = FALSE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (immutable && file.exists(path)) {
    if (identical(readLines(path, warn = FALSE), x)) return(invisible(path))
    stop("An immutable Gate4 pre-run receipt already exists with different contents.", call. = FALSE)
  }
  tmp <- tempfile(".mspl-coverage-", dirname(path), fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(x, tmp, useBytes = TRUE)
  if (!file.rename(tmp, path)) stop("Could not atomically publish ", path)
  invisible(path)
}

validate_safe_label <- function(x, field) {
  ok <- length(x) == 1L && !is.na(x) && nzchar(x) &&
    grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", x)
  if (!ok) {
    stop(field, " must be one safe label using only ASCII letters, digits, dot, underscore, or hyphen.",
      call. = FALSE
    )
  }
  as.character(x)
}

manifest_table <- function(
  n_outer = 1000L,
  bootstrap_reps = 500L,
  outer_per_shard = 10L,
  campaign_id,
  source_sha,
  clusters = c(rep("nibi", 6L), rep("narval", 4L), rep("rorqual", 2L)),
  availability_min = 0.95,
  coverage_wilson_level = 0.90,
  coverage_equivalence_lower = 0.92,
  coverage_equivalence_upper = 0.98,
  wald_min_available = 500L
) {
  campaign_id <- validate_safe_label(campaign_id, "campaign_id")
  source_sha <- validate_safe_label(source_sha, "source_sha")
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
  if (length(clusters) != nrow(out)) {
    stop("The frozen cluster assignment requires exactly 12 entries.", call. = FALSE)
  }
  if (n_outer < 1L || bootstrap_reps < 1L || bootstrap_reps > 500L || outer_per_shard < 1L ||
      n_outer %% outer_per_shard != 0L) {
    stop("Outer count must be a positive multiple of outer-per-shard; bootstrap must be in 1..500.", call. = FALSE)
  }
  if (!is.finite(availability_min) || availability_min <= 0 || availability_min > 1 ||
      !is.finite(coverage_wilson_level) || coverage_wilson_level <= 0 || coverage_wilson_level >= 1 ||
      !is.finite(coverage_equivalence_lower) || !is.finite(coverage_equivalence_upper) ||
      coverage_equivalence_lower <= 0 || coverage_equivalence_upper >= 1 ||
      coverage_equivalence_lower >= coverage_equivalence_upper || wald_min_available < 1L) {
    stop("Frozen availability, Wilson, and equivalence bounds are invalid.", call. = FALSE)
  }
  out$case_number <- seq_len(nrow(out))
  out$case_id <- sprintf("C%03d", out$case_number)
  out$seed_base <- 1900000000L + out$case_number * 10000000L
  out$n_outer <- as.integer(n_outer)
  out$bootstrap_reps <- as.integer(bootstrap_reps)
  out$minimum_usable_bootstrap <- as.integer(ceiling(0.95 * bootstrap_reps))
  out$outer_per_shard <- as.integer(outer_per_shard)
  out$n_shards <- as.integer(n_outer / outer_per_shard)
  out$assigned_cluster <- as.character(clusters)
  out$availability_min <- availability_min
  out$coverage_wilson_level <- coverage_wilson_level
  out$coverage_equivalence_lower <- coverage_equivalence_lower
  out$coverage_equivalence_upper <- coverage_equivalence_upper
  out$wald_min_available <- as.integer(wald_min_available)
  out$manifest_version <- "lane-b-mspl-coverage-gate0-v1-2026-08-14"
  out$campaign_id <- campaign_id
  out$source_sha <- source_sha
  out[, c(
    "case_id", "case_number", "regime", "link", "beta_shift", "lambda_scale",
    "seed_base", "n_outer", "bootstrap_reps", "minimum_usable_bootstrap",
    "outer_per_shard", "n_shards", "assigned_cluster", "availability_min",
    "coverage_wilson_level", "coverage_equivalence_lower", "coverage_equivalence_upper",
    "wald_min_available", "manifest_version", "campaign_id", "source_sha"
  )]
}

campaign_array_maps <- function(manifest) {
  full_keys <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    data.frame(
      case_id = manifest$case_id[[i]],
      shard_id = seq_len(manifest$n_shards[[i]]),
      stringsAsFactors = FALSE
    )
  }))
  index_map <- function(keys) data.frame(
    array_index = seq_len(nrow(keys)), keys,
    row.names = NULL, check.names = FALSE
  )
  maps <- list(
    full = index_map(full_keys),
    prerun = index_map(full_keys[full_keys$shard_id == 1L, , drop = FALSE]),
    remaining = index_map(full_keys[full_keys$shard_id != 1L, , drop = FALSE])
  )
  validate_campaign_array_maps(manifest, maps$full, maps$prerun, maps$remaining)
  maps
}

validate_campaign_array_maps <- function(manifest, full, prerun, remaining) {
  required <- c("array_index", "case_id", "shard_id")
  if (!identical(names(full), required) || !identical(names(prerun), required) ||
      !identical(names(remaining), required)) {
    stop("Campaign array-map schemas are frozen.", call. = FALSE)
  }
  map_key <- function(x) key(x$case_id, x$shard_id)
  if (anyDuplicated(map_key(full)) || anyDuplicated(map_key(prerun)) ||
      anyDuplicated(map_key(remaining)) ||
      length(intersect(map_key(prerun), map_key(remaining)))) {
    stop("Pre-run and remaining-production shard keys must be unique and disjoint.", call. = FALSE)
  }
  expected_keys <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    data.frame(
      case_id = manifest$case_id[[i]],
      shard_id = seq_len(manifest$n_shards[[i]]),
      stringsAsFactors = FALSE
    )
  }))
  expected_full <- data.frame(
    array_index = seq_len(nrow(expected_keys)), expected_keys,
    row.names = NULL, check.names = FALSE
  )
  expected_prerun_keys <- expected_keys[expected_keys$shard_id == 1L, , drop = FALSE]
  expected_prerun <- data.frame(
    array_index = seq_len(nrow(expected_prerun_keys)), expected_prerun_keys,
    row.names = NULL, check.names = FALSE
  )
  expected_remaining_keys <- expected_keys[expected_keys$shard_id != 1L, , drop = FALSE]
  expected_remaining <- data.frame(
    array_index = seq_len(nrow(expected_remaining_keys)), expected_remaining_keys,
    row.names = NULL, check.names = FALSE
  )
  if (!identical(full, expected_full) || !identical(prerun, expected_prerun) ||
      !identical(remaining, expected_remaining) ||
      !setequal(c(map_key(prerun), map_key(remaining)), map_key(full))) {
    stop("Campaign array maps do not have the exact frozen keys, order, and cardinality.", call. = FALSE)
  }
  invisible(TRUE)
}

validate_manifest_contract <- function(manifest) {
  production_version <- "lane-b-mspl-coverage-gate0-v1-2026-08-14"
  if (!all(manifest$manifest_version == production_version)) return(invisible(TRUE))
  identity_ok <- nrow(manifest) > 0L &&
    length(unique(as.character(manifest$campaign_id))) == 1L &&
    length(unique(as.character(manifest$source_sha))) == 1L &&
    !is.na(manifest$campaign_id[[1L]]) && nzchar(manifest$campaign_id[[1L]]) &&
    !is.na(manifest$source_sha[[1L]]) && nzchar(manifest$source_sha[[1L]])
  expected <- manifest_table(
    campaign_id = manifest$campaign_id[[1L]],
    source_sha = manifest$source_sha[[1L]]
  )
  fixed <- setdiff(names(expected), c("campaign_id", "source_sha"))
  if (!identity_ok || nrow(manifest) != nrow(expected) ||
      !identical(names(manifest), names(expected)) ||
      any(manifest$campaign_id != manifest$campaign_id[[1L]]) ||
      any(manifest$source_sha != manifest$source_sha[[1L]]) ||
      !identical(manifest[fixed], expected[fixed])) {
    stop(
      "Production manifest cardinalities, gates, case order, and cluster assignment are frozen.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

write_manifest <- function(root, manifest) {
  validate_manifest_contract(manifest)
  dir.create(file.path(root, "shards"), recursive = TRUE, showWarnings = FALSE)
  atomic_write_csv(manifest, file.path(root, "manifest.csv"))
  maps <- campaign_array_maps(manifest)
  atomic_write_tsv(maps$full, file.path(root, "array-map.tsv"))
  atomic_write_tsv(maps$prerun, file.path(root, "pre-run-array-map.tsv"))
  atomic_write_tsv(maps$remaining, file.path(root, "remaining-production-array-map.tsv"))
  writeLines(c(
    "Private LA-MSPL Gate 0 repeated-sampling coverage-calibration campaign.",
    "Each completed outer dataset retains every requested unconditional bootstrap attempt.",
    "Penalised profile/bootstrap and penalty-off Wald curvature have distinct objective roles.",
    "Public MSPL inference remains fail-closed pending the availability and coverage gates."
  ), file.path(root, "README.txt"))
  invisible(manifest)
}

smoke_manifest_table <- function(campaign_id, source_sha, cluster) {
  full <- manifest_table(
    n_outer = 1L, bootstrap_reps = 2L, outer_per_shard = 1L,
    campaign_id = campaign_id, source_sha = source_sha, clusters = rep(cluster, 12L)
  )
  out <- full[full$regime == "baseline", , drop = FALSE]
  if (nrow(out) != 3L || !setequal(out$link, c("logit", "probit", "cloglog"))) {
    stop("The smoke manifest could not select one fixed baseline case per link.", call. = FALSE)
  }
  out$manifest_version <- "lane-b-mspl-coverage-gate0-smoke-v1-2026-08-14"
  rownames(out) <- NULL
  out
}

test_manifest_table <- function(n_outer, bootstrap_reps, outer_per_shard,
                                campaign_id, source_sha, clusters) {
  out <- manifest_table(
    n_outer = n_outer, bootstrap_reps = bootstrap_reps,
    outer_per_shard = outer_per_shard, campaign_id = campaign_id,
    source_sha = source_sha, clusters = clusters
  )
  out$manifest_version <- "lane-b-mspl-coverage-gate0-test-v1-2026-08-14"
  out
}

manifest_versions <- c(
  production = "lane-b-mspl-coverage-gate0-v1-2026-08-14",
  prerun = "lane-b-mspl-coverage-gate0-v1-2026-08-14",
  smoke = "lane-b-mspl-coverage-gate0-smoke-v1-2026-08-14",
  test = "lane-b-mspl-coverage-gate0-test-v1-2026-08-14",
  mini = "lane-b-mspl-coverage-gate0-mini-v1-2026-08-14"
)

validate_manifest_mode <- function(manifest, mode) {
  if (!mode %in% names(manifest_versions) || !"manifest_version" %in% names(manifest) ||
      !identical(unique(as.character(manifest$manifest_version)), manifest_versions[[mode]])) {
    stop("Manifest version is unknown, mixed, or not valid for this aggregation mode.", call. = FALSE)
  }
  if (mode %in% c("production", "prerun")) {
    clusters <- c(rep("nibi", 6L), rep("narval", 4L), rep("rorqual", 2L))
    production_ok <- nrow(manifest) == 12L &&
      identical(as.character(manifest$case_id), sprintf("C%03d", seq_len(12L))) &&
      all(manifest$n_outer == 1000L & manifest$bootstrap_reps == 500L &
        manifest$minimum_usable_bootstrap == 475L & manifest$outer_per_shard == 10L &
        manifest$n_shards == 100L & manifest$availability_min == .95 &
        manifest$coverage_wilson_level == .90 & manifest$coverage_equivalence_lower == .92 &
        manifest$coverage_equivalence_upper == .98 & manifest$wald_min_available == 500L) &&
      identical(as.character(manifest$assigned_cluster), clusters)
    if (!production_ok) stop("Production manifest semantics are not the frozen Gate 0 contract.", call. = FALSE)
  } else if (identical(mode, "smoke")) {
    smoke_ok <- nrow(manifest) == 3L && all(manifest$regime == "baseline") &&
      setequal(manifest$link, c("logit", "probit", "cloglog")) &&
      all(manifest$n_outer == 1L & manifest$bootstrap_reps == 2L &
        manifest$minimum_usable_bootstrap == 2L & manifest$outer_per_shard == 1L &
        manifest$n_shards == 1L) && length(unique(manifest$assigned_cluster)) == 1L
    if (!smoke_ok) stop("Smoke manifest semantics are not the frozen three-link contract.", call. = FALSE)
  } else if (identical(mode, "test")) {
    if (nrow(manifest) != 12L || !identical(as.character(manifest$case_id), sprintf("C%03d", seq_len(12L)))) {
      stop("Test manifest semantics are invalid.", call. = FALSE)
    }
  } else if (identical(mode, "mini")) {
    if (nrow(manifest) != 12L || !all(manifest$n_outer == 1L & manifest$outer_per_shard == 1L &
        manifest$bootstrap_reps >= 1L & manifest$bootstrap_reps <= 500L) ||
        !all(manifest$assigned_cluster == "local")) {
      stop("Mini manifest semantics are invalid.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

gate4_receipt_manifest <- function(manifest) {
  validate_manifest_contract(manifest)
  validate_manifest_mode(manifest, "prerun")
  out <- manifest
  out$n_outer <- 10L
  out$n_shards <- 1L
  out
}

validate_gate4_receipt_manifest <- function(manifest) {
  expected <- manifest_table(
    n_outer = 10L, bootstrap_reps = 500L, outer_per_shard = 10L,
    campaign_id = manifest$campaign_id[[1L]],
    source_sha = manifest$source_sha[[1L]]
  )
  if (!identical(manifest, expected)) {
    stop("Gate4 receipt cardinalities, settings, identity, and case order are frozen.", call. = FALSE)
  }
  invisible(TRUE)
}

validate_gate4_shard_files <- function(root, manifest) {
  expected <- sprintf("%s-shard-001.rds", manifest$case_id)
  observed <- list.files(file.path(root, "shards"), pattern = "\\.rds$")
  if (!identical(sort(observed), sort(expected))) {
    stop("Compressed shard set does not exactly match the 12-file Gate4 pre-run contract.", call. = FALSE)
  }
  invisible(TRUE)
}

case_truth <- function(case) {
  c(-0.5, 0.1, 0.55) + case$beta_shift[[1L]]
}

simulate_outer_data <- function(case, outer_id) {
  set.seed(outer_seed(case, outer_id))
  n_site <- 24L
  n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(sprintf("t%d", seq_len(n_trait)), n_site),
    levels = sprintf("t%d", seq_len(n_trait))
  )
  z <- stats::rnorm(n_site)
  beta <- case_truth(case)
  lambda <- case$lambda_scale[[1L]] * c(0.8, -0.55, 0.35)
  eta <- beta[as.integer(trait)] + z[as.integer(site)] * lambda[as.integer(trait)]
  mu <- switch(case$link[[1L]],
    logit = stats::plogis(eta),
    probit = stats::pnorm(eta),
    cloglog = -expm1(-exp(eta))
  )
  data.frame(site = site, trait = trait, y = stats::rbinom(length(mu), 1L, mu))
}

outer_seed <- function(case, outer_id) {
  as.integer(case$seed_base[[1L]]) + as.integer(outer_id)
}

bootstrap_seed <- function(case, outer_id, attempt_id) {
  as.integer(case$seed_base[[1L]]) + 1000000L +
    (as.integer(outer_id) - 1L) * 500L + as.integer(attempt_id)
}

fit_mspl <- function(data, link) {
  gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = data, family = stats::binomial(link = link), estimator = "mspl",
    control = gllvmTMB::gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    ),
    silent = TRUE
  )
}

runtime_fingerprint <- function() {
  paste(
    R.version$version.string,
    paste0("TMB=", as.character(utils::packageVersion("TMB"))),
    paste0("gllvmTMB=", as.character(utils::packageVersion("gllvmTMB"))),
    R.version$platform,
    sep = " | "
  )
}

provenance_columns <- function(case, cluster, outer_id, shard_id, fingerprint) {
  data.frame(
    manifest_version = case$manifest_version[[1L]], campaign_id = case$campaign_id[[1L]],
    source_sha = case$source_sha[[1L]], cluster = cluster,
    case_id = case$case_id[[1L]], case_number = case$case_number[[1L]],
    regime = case$regime[[1L]], link = case$link[[1L]], outer_id = as.integer(outer_id),
    shard_id = as.integer(shard_id), runtime_fingerprint = fingerprint,
    stringsAsFactors = FALSE
  )
}

bootstrap_attempt_rows <- function(case, cluster, outer_id, shard_id, fingerprint,
                                   status, message, n = NULL) {
  n <- n %||% case$bootstrap_reps[[1L]]
  base <- provenance_columns(case, cluster, outer_id, shard_id, fingerprint)
  out <- base[rep(1L, n), , drop = FALSE]
  out$attempt_id <- seq_len(n)
  out$seed <- vapply(out$attempt_id, function(attempt_id) {
    bootstrap_seed(case, outer_id, attempt_id)
  }, integer(1L))
  out$status <- status
  out$convergence <- NA_integer_
  out$objective <- NA_real_
  out$estimator_id <- NA_integer_
  out$unconditional_redraw <- FALSE
  out$b_fix_1 <- NA_real_
  out$b_fix_2 <- NA_real_
  out$b_fix_3 <- NA_real_
  out$elapsed_seconds <- NA_real_
  out$message <- message
  out$objective_role <- "penalised_bootstrap_refit_estimator_id_1"
  out
}

bootstrap_failure_row <- function(case, cluster, outer_id, shard_id, fingerprint,
                                  attempt_id, seed, status, message,
                                  redraw = FALSE, elapsed_seconds = NA_real_) {
  out <- bootstrap_attempt_rows(case, cluster, outer_id, shard_id, fingerprint,
    status, message, n = 1L
  )
  out$attempt_id <- as.integer(attempt_id)
  out$seed <- as.integer(seed)
  out$unconditional_redraw <- redraw
  out$elapsed_seconds <- elapsed_seconds
  out
}

outer_fit_row <- function(case, cluster, outer_id, shard_id, fingerprint,
                          status, message, convergence = NA_integer_,
                          objective = NA_real_, estimator_id = NA_integer_,
                          estimates = rep(NA_real_, 3L), elapsed_seconds = NA_real_) {
  out <- provenance_columns(case, cluster, outer_id, shard_id, fingerprint)
  out$seed <- outer_seed(case, outer_id)
  out$status <- status
  out$convergence <- convergence
  out$objective <- objective
  out$estimator_id <- estimator_id
  out$b_fix_1 <- estimates[[1L]]
  out$b_fix_2 <- estimates[[2L]]
  out$b_fix_3 <- estimates[[3L]]
  out$elapsed_seconds <- elapsed_seconds
  out$message <- message
  out$objective_role <- "penalised_outer_mspl_estimator_id_1"
  out
}

bootstrap_attempt <- function(fit, case, cluster, outer_id, shard_id, fingerprint) {
  redraw <- gllvmTMB:::.check_simulate_unconditional(fit)
  if (!isTRUE(redraw$can_redraw) || length(redraw$unhandled)) {
    return(do.call(rbind, lapply(seq_len(case$bootstrap_reps[[1L]]), function(attempt_id) {
      bootstrap_failure_row(
        case, cluster, outer_id, shard_id, fingerprint, attempt_id,
        bootstrap_seed(case, outer_id, attempt_id), "unconditional_redraw_unavailable",
        paste(redraw$unhandled, collapse = ",")
      )
    })))
  }
  do.call(rbind, lapply(seq_len(case$bootstrap_reps[[1L]]), function(attempt_id) {
    seed <- bootstrap_seed(case, outer_id, attempt_id)
    simulated <- tryCatch(
      stats::simulate(fit, nsim = 1L, seed = seed, condition_on_RE = FALSE),
      error = identity
    )
    if (inherits(simulated, "error")) {
      return(bootstrap_failure_row(
        case, cluster, outer_id, shard_id, fingerprint, attempt_id, seed,
        "simulate_error", conditionMessage(simulated), redraw = TRUE
      ))
    }
    y <- as.numeric(simulated[, 1L])
    if (length(y) != nrow(fit$data) || any(!is.finite(y))) {
      return(bootstrap_failure_row(
        case, cluster, outer_id, shard_id, fingerprint, attempt_id, seed,
        "simulate_nonfinite", "Invalid simulated response.", redraw = TRUE
      ))
    }
    data <- fit$data
    data$y <- y
    started <- proc.time()[[3L]]
    refit <- tryCatch(fit_mspl(data, case$link[[1L]]), error = identity)
    elapsed <- proc.time()[[3L]] - started
    if (inherits(refit, "error")) {
      return(bootstrap_failure_row(
        case, cluster, outer_id, shard_id, fingerprint, attempt_id, seed,
        "refit_error", conditionMessage(refit), redraw = TRUE, elapsed_seconds = elapsed
      ))
    }
    idx <- which(names(refit$opt$par) == "b_fix")
    estimate <- as.numeric(refit$opt$par[idx])
    active <- !is.null(refit$tmb_obj) &&
      !identical(refit$tmb_obj, refit$mspl$unpenalized_tmb_obj) &&
      identical(as.integer(refit$tmb_obj$env$data$estimator_id), 1L)
    status <- if (!identical(refit$opt$convergence, 0L)) {
      "refit_optimizer_failed"
    } else if (!active) {
      "penalised_objective_mismatch"
    } else if (length(idx) != 3L || any(!is.finite(estimate))) {
      "target_alignment_failed"
    } else {
      "ok"
    }
    out <- bootstrap_failure_row(
      case, cluster, outer_id, shard_id, fingerprint, attempt_id, seed, status,
      refit$opt$message %||% "", redraw = TRUE, elapsed_seconds = elapsed
    )
    out$convergence <- as.integer(refit$opt$convergence)
    out$objective <- as.numeric(refit$opt$objective)
    out$estimator_id <- if (active) 1L else NA_integer_
    if (identical(status, "ok")) out[1L, c("b_fix_1", "b_fix_2", "b_fix_3")] <- estimate
    out
  }))
}

endpoint_row <- function(case, cluster, outer_id, shard_id, fingerprint, method,
                         target, truth, estimate = NA_real_, lower = NA_real_,
                         upper = NA_real_, status = "not_run", message = "",
                         objective_role, elapsed_seconds = NA_real_) {
  out <- provenance_columns(case, cluster, outer_id, shard_id, fingerprint)
  out$method <- method
  out$target <- as.integer(target)
  out$target_name <- sprintf("b_fix[%d]", target)
  out$truth <- truth
  out$estimate <- estimate
  out$lower <- lower
  out$upper <- upper
  out$status <- status
  out$available <- identical(status, "ok") && all(is.finite(c(lower, upper))) && lower < upper
  out$covers <- isTRUE(out$available) && truth >= lower && truth <= upper
  out$objective_role <- objective_role
  out$elapsed_seconds <- elapsed_seconds
  out$message <- message
  out
}

profile_and_wald <- function(fit, case, cluster, outer_id, shard_id, fingerprint, truth) {
  endpoints <- list()
  traces <- list()
  idx <- which(names(fit$opt$par) == "b_fix")
  for (target in seq_len(3L)) {
    started <- proc.time()[[3L]]
    probe <- tryCatch(
      gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
        fit, idx[[target]], step = 0.5, max_steps = 12L,
        control = list(eval.max = 100L, iter.max = 100L), refinement_steps = 12L,
        bracket_tolerance = 1.25e-4
      ), error = identity
    )
    profile_elapsed <- proc.time()[[3L]] - started
    if (inherits(probe, "error")) {
      endpoints[[length(endpoints) + 1L]] <- endpoint_row(
        case, cluster, outer_id, shard_id, fingerprint, "profile", target, truth[[target]],
        status = "profile_error", message = conditionMessage(probe),
        objective_role = "penalised_profile_nuisance_reoptimised", elapsed_seconds = profile_elapsed
      )
    } else {
      diagnostic <- gllvmTMB:::.gllvmTMB_mspl_profile_threshold_diagnostic(probe)
      profile_ok <- identical(diagnostic$centre_status, "matched") &&
        identical(diagnostic$lower_status, "crossed") &&
        identical(diagnostic$upper_status, "crossed")
      terminal <- paste(
        paste0("centre=", diagnostic$centre_status),
        paste0("lower=", diagnostic$lower_status),
        paste0("upper=", diagnostic$upper_status), sep = "; "
      )
      endpoints[[length(endpoints) + 1L]] <- endpoint_row(
        case, cluster, outer_id, shard_id, fingerprint, "profile", target, truth[[target]],
        estimate = diagnostic$estimate, lower = diagnostic$diagnostic_lower,
        upper = diagnostic$diagnostic_upper,
        status = if (profile_ok) "ok" else paste0(
          "profile_", diagnostic$centre_status, "_", diagnostic$lower_status,
          "_", diagnostic$upper_status
        ), message = terminal,
        objective_role = "penalised_profile_nuisance_reoptimised", elapsed_seconds = profile_elapsed
      )
      trace <- probe$trace
      names(trace)[names(trace) == "target"] <- "target_value"
      trace <- cbind(provenance_columns(case, cluster, outer_id, shard_id, fingerprint)[rep(1L, nrow(trace)), , drop = FALSE],
        method = "profile", target = target, target_name = sprintf("b_fix[%d]", target),
        objective_role = "penalised_profile_nuisance_reoptimised",
        threshold = probe$threshold,
        lower_bracket_1 = probe$lower_bracket[[1L]], lower_bracket_2 = probe$lower_bracket[[2L]],
        upper_bracket_1 = probe$upper_bracket[[1L]], upper_bracket_2 = probe$upper_bracket[[2L]],
        bracket_tolerance = probe$bracket_tolerance, trace
      )
      traces[[length(traces) + 1L]] <- trace
    }
    started <- proc.time()[[3L]]
    wald <- tryCatch(
      gllvmTMB:::.gllvmTMB_mspl_likelihood_hessian_diagnostic(fit, idx[[target]]),
      error = identity
    )
    wald_elapsed <- proc.time()[[3L]] - started
    if (inherits(wald, "error")) {
      endpoints[[length(endpoints) + 1L]] <- endpoint_row(
        case, cluster, outer_id, shard_id, fingerprint, "wald", target, truth[[target]],
        status = "likelihood_hessian_error", message = conditionMessage(wald),
        objective_role = "penalty_off_likelihood_curvature_at_penalised_mspl_estimate",
        elapsed_seconds = wald_elapsed
      )
    } else {
      endpoints[[length(endpoints) + 1L]] <- endpoint_row(
        case, cluster, outer_id, shard_id, fingerprint, "wald", target, truth[[target]],
        estimate = wald$estimate, lower = wald$diagnostic_lower, upper = wald$diagnostic_upper,
        status = wald$status, message = wald$message %||% "",
        objective_role = "penalty_off_likelihood_curvature_at_penalised_mspl_estimate",
        elapsed_seconds = wald_elapsed
      )
    }
  }
  list(endpoints = do.call(rbind, endpoints),
       profile_traces = if (length(traces)) do.call(rbind, traces) else data.frame())
}

bootstrap_endpoints <- function(attempts, case, cluster, outer_id, shard_id, fingerprint,
                                truth, outer_estimates) {
  usable <- attempts$status == "ok" & attempts$convergence == 0L &
    attempts$estimator_id == 1L & attempts$unconditional_redraw
  do.call(rbind, lapply(seq_len(3L), function(target) {
    values <- attempts[[paste0("b_fix_", target)]][usable]
    endpoints <- if (length(values)) stats::quantile(values, c(.025, .975), type = 7L, names = FALSE) else c(NA_real_, NA_real_)
    status <- if (sum(usable) < case$minimum_usable_bootstrap[[1L]]) {
      "insufficient_usable_bootstrap"
    } else if (any(!is.finite(endpoints)) || endpoints[[1L]] >= endpoints[[2L]]) {
      "bootstrap_endpoints_invalid"
    } else {
      "ok"
    }
    endpoint_row(
      case, cluster, outer_id, shard_id, fingerprint, "bootstrap", target, truth[[target]],
      estimate = outer_estimates[[target]], lower = endpoints[[1L]],
      upper = endpoints[[2L]], status = status,
      message = paste0("usable=", sum(usable), "/", nrow(attempts)),
      objective_role = "unconditional_parametric_percentile_refit_estimator_id_1",
      elapsed_seconds = sum(attempts$elapsed_seconds, na.rm = TRUE)
    )
  }))
}

run_outer <- function(case, cluster, outer_id, shard_id, fingerprint) {
  truth <- case_truth(case)
  data <- simulate_outer_data(case, outer_id)
  started <- proc.time()[[3L]]
  fit <- tryCatch(fit_mspl(data, case$link[[1L]]), error = identity)
  fit_elapsed <- proc.time()[[3L]] - started
  if (inherits(fit, "error")) {
    outer_fit <- outer_fit_row(
      case, cluster, outer_id, shard_id, fingerprint, "outer_fit_error",
      conditionMessage(fit), elapsed_seconds = fit_elapsed
    )
    attempts <- bootstrap_attempt_rows(case, cluster, outer_id, shard_id, fingerprint,
      "outer_fit_error", conditionMessage(fit)
    )
    endpoints <- do.call(rbind, lapply(c("profile", "wald", "bootstrap"), function(method) {
      role <- switch(method,
        profile = "penalised_profile_nuisance_reoptimised",
        wald = "penalty_off_likelihood_curvature_at_penalised_mspl_estimate",
        bootstrap = "unconditional_parametric_percentile_refit_estimator_id_1"
      )
      do.call(rbind, lapply(seq_len(3L), function(target) endpoint_row(
        case, cluster, outer_id, shard_id, fingerprint, method, target, truth[[target]],
        status = "outer_fit_error", message = conditionMessage(fit), objective_role = role,
        elapsed_seconds = fit_elapsed
      )))
    }))
    return(list(outer_fits = outer_fit, bootstrap_attempts = attempts,
      endpoints = endpoints, profile_traces = data.frame()))
  }
  idx <- which(names(fit$opt$par) == "b_fix")
  estimates <- as.numeric(fit$opt$par[idx])
  active <- !is.null(fit$tmb_obj) && !identical(fit$tmb_obj, fit$mspl$unpenalized_tmb_obj) &&
    identical(as.integer(fit$tmb_obj$env$data$estimator_id), 1L)
  outer_status <- if (!identical(fit$opt$convergence, 0L)) {
    "outer_optimizer_failed"
  } else if (!active) {
    "outer_penalised_objective_mismatch"
  } else if (length(idx) != 3L || any(!is.finite(estimates))) {
    "outer_target_alignment_failed"
  } else {
    "ok"
  }
  outer_fit <- outer_fit_row(
    case, cluster, outer_id, shard_id, fingerprint, outer_status,
    fit$opt$message %||% "", convergence = as.integer(fit$opt$convergence),
    objective = as.numeric(fit$opt$objective), estimator_id = if (active) 1L else NA_integer_,
    estimates = if (length(estimates) == 3L) estimates else rep(NA_real_, 3L),
    elapsed_seconds = fit_elapsed
  )
  if (!identical(outer_status, "ok")) {
    attempts <- bootstrap_attempt_rows(case, cluster, outer_id, shard_id, fingerprint,
      outer_status, outer_fit$message[[1L]]
    )
    endpoints <- do.call(rbind, lapply(c("profile", "wald", "bootstrap"), function(method) {
      role <- switch(method,
        profile = "penalised_profile_nuisance_reoptimised",
        wald = "penalty_off_likelihood_curvature_at_penalised_mspl_estimate",
        bootstrap = "unconditional_parametric_percentile_refit_estimator_id_1"
      )
      do.call(rbind, lapply(seq_len(3L), function(target) endpoint_row(
        case, cluster, outer_id, shard_id, fingerprint, method, target, truth[[target]],
        status = outer_status, message = outer_fit$message[[1L]], objective_role = role,
        elapsed_seconds = fit_elapsed
      )))
    }))
    return(list(outer_fits = outer_fit, bootstrap_attempts = attempts,
      endpoints = endpoints, profile_traces = data.frame()))
  }
  pw <- profile_and_wald(fit, case, cluster, outer_id, shard_id, fingerprint, truth)
  attempts <- bootstrap_attempt(fit, case, cluster, outer_id, shard_id, fingerprint)
  list(
    outer_fits = outer_fit,
    bootstrap_attempts = attempts,
    endpoints = rbind(pw$endpoints, bootstrap_endpoints(
      attempts, case, cluster, outer_id, shard_id, fingerprint, truth, estimates
    )),
    profile_traces = pw$profile_traces
  )
}

run_shard <- function(case, shard_id, cluster) {
  if (!identical(cluster, case$assigned_cluster[[1L]])) {
    stop("Requested cluster does not match the frozen manifest assignment.", call. = FALSE)
  }
  first <- (shard_id - 1L) * case$outer_per_shard[[1L]] + 1L
  last <- shard_id * case$outer_per_shard[[1L]]
  fingerprint <- runtime_fingerprint()
  outer <- lapply(first:last, function(outer_id) {
    run_outer(case, cluster, outer_id, shard_id, fingerprint)
  })
  list(
    schema_version = "gate0-shard-v1",
    outer_fits = do.call(rbind, lapply(outer, `[[`, "outer_fits")),
    bootstrap_attempts = do.call(rbind, lapply(outer, `[[`, "bootstrap_attempts")),
    endpoints = do.call(rbind, lapply(outer, `[[`, "endpoints")),
    profile_traces = rbind_nonempty(lapply(outer, `[[`, "profile_traces"))
  )
}

key <- function(...) do.call(paste, c(list(...), sep = "\r"))

rbind_nonempty <- function(rows) {
  rows <- Filter(function(x) is.data.frame(x) && nrow(x) > 0L, rows)
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

read_shards <- function(root) {
  files <- list.files(file.path(root, "shards"), pattern = "\\.rds$", full.names = TRUE)
  if (!length(files)) stop("No compressed shards found.", call. = FALSE)
  shards <- lapply(files, readRDS)
  required <- c("schema_version", "outer_fits", "bootstrap_attempts", "endpoints", "profile_traces")
  if (any(!vapply(shards, function(x) {
    is.list(x) && all(required %in% names(x)) && identical(x$schema_version, "gate0-shard-v1")
  }, logical(1L)))) {
    stop("A compressed shard has the wrong schema.", call. = FALSE)
  }
  list(
    outer_fits = do.call(rbind, lapply(shards, `[[`, "outer_fits")),
    bootstrap_attempts = do.call(rbind, lapply(shards, `[[`, "bootstrap_attempts")),
    endpoints = do.call(rbind, lapply(shards, `[[`, "endpoints")),
    profile_traces = rbind_nonempty(lapply(shards, `[[`, "profile_traces"))
  )
}

validate_receipts <- function(receipts, manifest, receipt_mode = "campaign") {
  if (identical(receipt_mode, "gate4-prerun")) {
    validate_gate4_receipt_manifest(manifest)
  } else if (identical(receipt_mode, "campaign")) {
    validate_manifest_contract(manifest)
  } else {
    stop("Receipt validation mode is unknown.", call. = FALSE)
  }
  outer <- receipts$outer_fits
  boot <- receipts$bootstrap_attempts
  endpoints <- receipts$endpoints
  traces <- receipts$profile_traces
  required_outer <- c(
    "manifest_version", "campaign_id", "source_sha", "cluster", "case_id",
    "outer_id", "shard_id", "seed", "status", "convergence", "objective",
    "estimator_id", "b_fix_1", "b_fix_2", "b_fix_3", "elapsed_seconds",
    "message", "objective_role"
  )
  required_boot <- c(
    "manifest_version", "campaign_id", "source_sha", "cluster", "case_id",
    "outer_id", "shard_id", "attempt_id", "seed", "status", "convergence",
    "estimator_id", "unconditional_redraw", "b_fix_1", "b_fix_2", "b_fix_3",
    "objective_role"
  )
  required_end <- c(
    "manifest_version", "campaign_id", "source_sha", "cluster", "case_id",
    "outer_id", "shard_id", "method", "target", "truth", "estimate", "lower",
    "upper", "status", "available", "covers", "message", "objective_role"
  )
  if (!all(required_outer %in% names(outer)) || !all(required_boot %in% names(boot)) ||
      !all(required_end %in% names(endpoints))) {
    stop("Receipt identity fields are missing.", call. = FALSE)
  }
  expected_shards <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    data.frame(case_id = manifest$case_id[[i]], shard_id = seq_len(manifest$n_shards[[i]]))
  }))
  observed_shards <- unique(boot[c("case_id", "shard_id")])
  shard_key <- function(x) key(x$case_id, x$shard_id)
  if (anyDuplicated(shard_key(observed_shards)) || !setequal(shard_key(observed_shards), shard_key(expected_shards))) {
    stop("Compressed shard set is duplicated or does not exactly match the frozen manifest.", call. = FALSE)
  }
  m_outer <- match(outer$case_id, manifest$case_id)
  m_boot <- match(boot$case_id, manifest$case_id)
  m_end <- match(endpoints$case_id, manifest$case_id)
  fields <- c("manifest_version", "campaign_id", "source_sha", "assigned_cluster")
  observed <- c("manifest_version", "campaign_id", "source_sha", "cluster")
  mismatch <- function(data, index) {
    anyNA(index) || any(vapply(seq_along(fields), function(i) {
      any(as.character(data[[observed[[i]]]]) !=
        as.character(manifest[[fields[[i]]]][index]))
    }, logical(1L)))
  }
  if (mismatch(outer, m_outer) || mismatch(boot, m_boot) || mismatch(endpoints, m_end)) {
    stop("Receipt provenance (manifest/campaign/source SHA/cluster) does not match the frozen manifest.", call. = FALSE)
  }
  expected_role <- c(
    profile = "penalised_profile_nuisance_reoptimised",
    wald = "penalty_off_likelihood_curvature_at_penalised_mspl_estimate",
    bootstrap = "unconditional_parametric_percentile_refit_estimator_id_1"
  )
  endpoint_roles <- unname(expected_role[as.character(endpoints$method)])
  if (any(as.character(outer$objective_role) != "penalised_outer_mspl_estimator_id_1") ||
      any(as.character(boot$objective_role) != "penalised_bootstrap_refit_estimator_id_1") ||
      anyNA(endpoint_roles) || any(as.character(endpoints$objective_role) != endpoint_roles)) {
    stop("Receipt objective-role provenance is not the frozen method map.", call. = FALSE)
  }
  if (nrow(traces)) {
    trace_required <- c(
      "manifest_version", "campaign_id", "source_sha", "cluster", "case_id",
      "outer_id", "shard_id", "method", "target", "target_value", "threshold",
      "lower_bracket_1", "lower_bracket_2", "upper_bracket_1", "upper_bracket_2",
      "bracket_tolerance", "finite", "convergence", "nuisance_reoptimized",
      "objective_delta", "side", "stage", "objective_role"
    )
    if (!all(trace_required %in% names(traces))) {
      stop("Profile trace provenance fields are missing.", call. = FALSE)
    }
    trace_match <- match(traces$case_id, manifest$case_id)
    if (mismatch(traces, trace_match) || any(traces$objective_role != expected_role[["profile"]]) ||
        any(traces$method != "profile") || any(!traces$target %in% seq_len(3L)) ||
        !all(as.integer(traces$shard_id) == ceiling(as.integer(traces$outer_id) /
          as.integer(manifest$outer_per_shard[trace_match])))) {
      stop("Profile trace provenance does not match the frozen method map.", call. = FALSE)
    }
    profile_threshold <- stats::qchisq(0.95, df = 1L) / 2
    if (any(!is.finite(traces$threshold)) || any(abs(traces$threshold - profile_threshold) > 1e-12)) {
      stop("Profile trace threshold is not the frozen chi-square 95% criterion.", call. = FALSE)
    }
  }
  expected_boot <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    expand.grid(case_id = manifest$case_id[[i]], outer_id = seq_len(manifest$n_outer[[i]]),
      attempt_id = seq_len(manifest$bootstrap_reps[[i]]), stringsAsFactors = FALSE)
  }))
  expected_outer <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    data.frame(case_id = manifest$case_id[[i]], outer_id = seq_len(manifest$n_outer[[i]]))
  }))
  expected_end <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
    expand.grid(case_id = manifest$case_id[[i]], outer_id = seq_len(manifest$n_outer[[i]]),
      method = c("profile", "wald", "bootstrap"), target = seq_len(3L), stringsAsFactors = FALSE)
  }))
  boot_key <- function(x) key(x$case_id, x$outer_id, x$attempt_id)
  outer_key <- function(x) key(x$case_id, x$outer_id)
  end_key <- function(x) key(x$case_id, x$outer_id, x$method, x$target)
  if (anyDuplicated(outer_key(outer)) || nrow(outer) != nrow(expected_outer) ||
      !setequal(outer_key(outer), outer_key(expected_outer))) {
    stop("Outer-fit keys are duplicated or do not exactly match the frozen manifest.", call. = FALSE)
  }
  if (anyDuplicated(boot_key(boot)) || nrow(boot) != nrow(expected_boot) || !setequal(boot_key(boot), boot_key(expected_boot))) {
    stop("Bootstrap attempt keys are duplicated or do not exactly match the frozen manifest.", call. = FALSE)
  }
  if (anyDuplicated(end_key(endpoints)) || nrow(endpoints) != nrow(expected_end) || !setequal(end_key(endpoints), end_key(expected_end))) {
    stop("Method-target endpoint keys are duplicated or do not exactly match the frozen manifest.", call. = FALSE)
  }
  shard_matches_outer <- function(data, index) {
    all(as.integer(data$shard_id) == ceiling(as.integer(data$outer_id) /
      as.integer(manifest$outer_per_shard[index])))
  }
  if (!shard_matches_outer(outer, m_outer) || !shard_matches_outer(boot, m_boot) ||
      !shard_matches_outer(endpoints, m_end)) {
    stop("Receipt shard IDs are inconsistent with frozen outer ranges.", call. = FALSE)
  }
  expected_outer_seed <- as.integer(manifest$seed_base[m_outer]) + as.integer(outer$outer_id)
  expected_boot_seed <- as.integer(manifest$seed_base[m_boot]) + 1000000L +
    (as.integer(boot$outer_id) - 1L) * 500L + as.integer(boot$attempt_id)
  if (any(as.integer(outer$seed) != expected_outer_seed) ||
      any(as.integer(boot$seed) != expected_boot_seed) ||
      anyDuplicated(c(as.integer(outer$seed), as.integer(boot$seed)))) {
    stop("Frozen outer/bootstrap seeds are incorrect or collide.", call. = FALSE)
  }
  expected_truth <- function(data, index) {
    c(-0.5, 0.1, 0.55)[as.integer(data$target)] + manifest$beta_shift[index]
  }
  expected_available <- endpoints$status == "ok" & is.finite(endpoints$lower) &
    is.finite(endpoints$upper) & endpoints$lower < endpoints$upper
  expected_covers <- expected_available & endpoints$truth >= endpoints$lower &
    endpoints$truth <= endpoints$upper
  if (any(!is.finite(endpoints$truth)) ||
      any(abs(endpoints$truth - expected_truth(endpoints, m_end)) > 1e-12) ||
      any(as.logical(endpoints$available) != expected_available) ||
      any(as.logical(endpoints$covers) != expected_covers)) {
    stop("Endpoint truth, availability, or coverage flags are inconsistent with the receipt.", call. = FALSE)
  }
  boot_ok <- boot$status == "ok"
  if (any(boot_ok & (!is.finite(boot$b_fix_1) | !is.finite(boot$b_fix_2) |
      !is.finite(boot$b_fix_3) | boot$convergence != 0L | boot$estimator_id != 1L |
      !as.logical(boot$unconditional_redraw)))) {
    stop("Successful bootstrap rows violate the frozen penalised-refit contract.", call. = FALSE)
  }
  outer_ok <- outer$status == "ok"
  if (any(outer_ok & (!is.finite(outer$b_fix_1) | !is.finite(outer$b_fix_2) |
      !is.finite(outer$b_fix_3) | outer$convergence != 0L | outer$estimator_id != 1L))) {
    stop("Successful outer-fit rows violate the frozen MSPL objective contract.", call. = FALSE)
  }
  outer_match <- match(outer_key(endpoints), outer_key(outer))
  if (anyNA(outer_match) || any(outer$status[outer_match] != "ok" & endpoints$status == "ok")) {
    stop("An unavailable outer fit supplied a falsely available endpoint.", call. = FALSE)
  }
  bootstrap_endpoints <- endpoints[endpoints$method == "bootstrap", , drop = FALSE]
  for (i in seq_len(nrow(bootstrap_endpoints))) {
    endpoint <- bootstrap_endpoints[i, , drop = FALSE]
    case_index <- match(endpoint$case_id, manifest$case_id)
    outer_index <- boot$case_id == endpoint$case_id & boot$outer_id == endpoint$outer_id
    attempts <- boot[outer_index, , drop = FALSE]
    usable <- attempts$status == "ok" & attempts$convergence == 0L &
      attempts$estimator_id == 1L & attempts$unconditional_redraw
    values <- attempts[[paste0("b_fix_", endpoint$target[[1L]])]][usable]
    expected_bounds <- if (length(values)) stats::quantile(
      values, c(0.025, 0.975), type = 7L, names = FALSE
    ) else c(NA_real_, NA_real_)
    endpoint_ok <- sum(usable) >= manifest$minimum_usable_bootstrap[[case_index]] &&
      all(is.finite(expected_bounds)) && expected_bounds[[1L]] < expected_bounds[[2L]]
    expected_point <- outer[[paste0("b_fix_", endpoint$target[[1L]])]][match(
      outer_key(endpoint), outer_key(outer)
    )]
    if (identical(endpoint$status[[1L]], "ok") != endpoint_ok ||
        any(abs(c(endpoint$lower[[1L]], endpoint$upper[[1L]]) - expected_bounds) > 1e-12, na.rm = TRUE) ||
        any(is.na(c(endpoint$lower[[1L]], endpoint$upper[[1L]])) != is.na(expected_bounds)) ||
        !isTRUE(all.equal(endpoint$estimate[[1L]], expected_point, tolerance = 0))) {
      stop("Bootstrap endpoint does not exactly match retained type-7 attempts and usable-count rule.", call. = FALSE)
    }
  }
  profile_endpoints <- endpoints[endpoints$method == "profile" & endpoints$status == "ok", , drop = FALSE]
  for (i in seq_len(nrow(profile_endpoints))) {
    endpoint <- profile_endpoints[i, , drop = FALSE]
    trace <- traces[traces$case_id == endpoint$case_id &
      traces$outer_id == endpoint$outer_id & traces$target == endpoint$target, , drop = FALSE]
    if (!nrow(trace)) {
      stop("Successful profile endpoint lacks matched/crossed finite converged trace evidence.", call. = FALSE)
    }
    row_ok <- trace$finite %in% TRUE & trace$convergence == 0L &
      trace$nuisance_reoptimized %in% TRUE & is.finite(trace$objective_delta)
    centre_ok <- any(trace$side == "centre" & trace$stage == "centre" & row_ok)
    bracket_ok <- function(side, first, second, endpoint_value) {
      side_trace <- trace[trace$side == side & row_ok, , drop = FALSE]
      values <- c(first, second)
      if (any(!is.finite(values)) || !is.finite(endpoint_value) ||
          abs(diff(values)) > trace$bracket_tolerance[[1L]] + 1e-12 ||
          endpoint_value < min(values) - 1e-12 || endpoint_value > max(values) + 1e-12 ||
          !any(side_trace$stage == "refinement")) return(FALSE)
      adjacent <- unique(side_trace$target_value[
        side_trace$target_value >= min(values) - 1e-12 &
          side_trace$target_value <= max(values) + 1e-12
      ])
      if (length(adjacent) != 2L || any(abs(sort(adjacent) - sort(values)) > 1e-12)) return(FALSE)
      delta_at <- function(value) {
        found <- side_trace$objective_delta[abs(side_trace$target_value - value) <= 1e-12]
        if (!length(found)) return(NA_real_)
        found[[1L]]
      }
      deltas <- vapply(values, delta_at, numeric(1L))
      all(is.finite(deltas)) && any(deltas < side_trace$threshold[[1L]]) &&
        any(deltas >= side_trace$threshold[[1L]])
    }
    lower_ok <- bracket_ok("lower", trace$lower_bracket_1[[1L]],
      trace$lower_bracket_2[[1L]], endpoint$lower[[1L]])
    upper_ok <- bracket_ok("upper", trace$upper_bracket_1[[1L]],
      trace$upper_bracket_2[[1L]], endpoint$upper[[1L]])
    terminal_ok <- identical(endpoint$message[[1L]], "centre=matched; lower=crossed; upper=crossed")
    if (!centre_ok || !lower_ok || !upper_ok || !terminal_ok) {
      stop("Successful profile endpoint lacks matched/crossed finite converged trace evidence.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

wilson_interval <- function(success, total, level = 0.90) {
  if (!is.finite(total) || total < 1L) return(c(lower = NA_real_, upper = NA_real_))
  z <- stats::qnorm((1 + level) / 2)
  p <- success / total
  den <- 1 + z^2 / total
  centre <- (p + z^2 / (2 * total)) / den
  half <- z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2)) / den
  c(lower = centre - half, upper = centre + half)
}

mean_mcse <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2L) return(NA_real_)
  stats::sd(x) / sqrt(length(x))
}

rmse_mcse <- function(errors) {
  errors <- errors[is.finite(errors)]
  if (length(errors) < 2L) return(NA_real_)
  rmse <- sqrt(mean(errors^2))
  if (!is.finite(rmse) || rmse == 0) return(0)
  stats::sd(errors^2) / sqrt(length(errors)) / (2 * rmse)
}

summarise_receipts <- function(receipts, manifest, receipt_mode = "campaign") {
  validate_receipts(receipts, manifest, receipt_mode = receipt_mode)
  outer <- receipts$outer_fits
  endpoints <- receipts$endpoints
  key_group <- interaction(endpoints$case_id, endpoints$method, endpoints$target, drop = TRUE)
  out <- do.call(rbind, lapply(split(endpoints, key_group), function(x) {
    case <- manifest[match(x$case_id[[1L]], manifest$case_id), , drop = FALSE]
    available <- x$available %in% TRUE
    covered <- x$covers %in% TRUE
    available_n <- sum(available)
    unconditional_covered <- sum(covered)
    unconditional_coverage <- unconditional_covered / nrow(x)
    conditional_covered <- sum(covered[available])
    conditional_coverage <- if (available_n) conditional_covered / available_n else NA_real_
    unconditional_interval <- wilson_interval(
      unconditional_covered, nrow(x), level = case$coverage_wilson_level[[1L]]
    )
    conditional_interval <- if (available_n) wilson_interval(
      conditional_covered, available_n, level = case$coverage_wilson_level[[1L]]
    ) else c(lower = NA_real_, upper = NA_real_)
    point <- outer[match(key(x$case_id, x$outer_id), key(outer$case_id, outer$outer_id)), , drop = FALSE]
    point_estimate <- point[[paste0("b_fix_", x$target[[1L]])]]
    point_ok <- point$status == "ok" & is.finite(point_estimate)
    errors <- point_estimate[point_ok] - x$truth[point_ok]
    widths <- x$upper[available] - x$lower[available]
    method <- x$method[[1L]]
    availability_gate <- if (identical(method, "wald")) {
      available_n >= case$wald_min_available[[1L]]
    } else {
      available_n / nrow(x) >= case$availability_min[[1L]]
    }
    coverage_gate <- if (identical(method, "wald")) {
      is.finite(conditional_coverage) &&
        conditional_interval[["lower"]] >= case$coverage_equivalence_lower[[1L]] &&
        conditional_interval[["upper"]] <= case$coverage_equivalence_upper[[1L]]
    } else {
      unconditional_interval[["lower"]] >= case$coverage_equivalence_lower[[1L]] &&
        unconditional_interval[["upper"]] <= case$coverage_equivalence_upper[[1L]]
    }
    data.frame(
      case_id = x$case_id[[1L]], regime = x$regime[[1L]], link = x$link[[1L]],
      method = x$method[[1L]], target = x$target[[1L]], target_name = x$target_name[[1L]],
      attempted_outer = nrow(x), available_outer = available_n,
      availability = available_n / nrow(x), availability_gate = availability_gate,
      availability_mcse = sqrt((available_n / nrow(x)) * (1 - available_n / nrow(x)) / nrow(x)),
      unconditional_covered_outer = unconditional_covered,
      unconditional_coverage = unconditional_coverage,
      unconditional_wilson_lower = unconditional_interval[["lower"]],
      unconditional_wilson_upper = unconditional_interval[["upper"]],
      conditional_covered_outer = conditional_covered,
      conditional_coverage = conditional_coverage,
      conditional_wilson_lower = conditional_interval[["lower"]],
      conditional_wilson_upper = conditional_interval[["upper"]],
      coverage_gate = coverage_gate,
      unconditional_coverage_mcse = sqrt(unconditional_coverage * (1 - unconditional_coverage) / nrow(x)),
      conditional_coverage_mcse = if (available_n) sqrt(conditional_coverage * (1 - conditional_coverage) / available_n) else NA_real_,
      point_estimate_outer = sum(point_ok),
      bias = if (length(errors)) mean(errors) else NA_real_,
      bias_mcse = mean_mcse(errors),
      rmse = if (length(errors)) sqrt(mean(errors^2)) else NA_real_,
      rmse_mcse = rmse_mcse(errors),
      mean_width = if (length(widths)) mean(widths) else NA_real_,
      mean_width_mcse = mean_mcse(widths),
      median_width = if (length(widths)) stats::median(widths) else NA_real_,
      mean_runtime_seconds = mean(x$elapsed_seconds, na.rm = TRUE),
      mean_runtime_mcse = mean_mcse(x$elapsed_seconds),
      total_runtime_seconds = sum(x$elapsed_seconds, na.rm = TRUE),
      gate_pass = availability_gate && coverage_gate,
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

aggregate_campaign <- function(root, mode) {
  manifest_path <- file.path(root, "manifest.csv")
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  validate_manifest_mode(manifest, mode)
  receipt_mode <- if (identical(mode, "prerun")) "gate4-prerun" else "campaign"
  receipt_manifest <- if (identical(mode, "prerun")) gate4_receipt_manifest(manifest) else manifest
  if (identical(mode, "prerun")) validate_gate4_shard_files(root, receipt_manifest)
  receipts <- read_shards(root)
  summary <- summarise_receipts(receipts, receipt_manifest, receipt_mode = receipt_mode)
  atomic_write_csv(summary, file.path(root, "summary.csv"))
  atomic_write_csv(receipts$outer_fits, file.path(root, "outer-fit-rows.csv"))
  atomic_write_csv(receipts$endpoints, file.path(root, "endpoint-rows.csv"))
  atomic_write_csv(receipts$bootstrap_attempts, file.path(root, "bootstrap-attempts-wide.csv"))
  atomic_write_csv(receipts$profile_traces, file.path(root, "profile-traces.csv"))
  receipt_header <- paste("manifest_mode:", mode)
  if (identical(mode, "prerun")) receipt_header <- c(
    receipt_header,
    "receipt_type: gate4-production-prerun-v1",
    "gate4_contract: exact",
    paste("campaign_id:", manifest$campaign_id[[1L]]),
    paste("source_sha:", manifest$source_sha[[1L]]),
    paste("manifest_version:", manifest$manifest_version[[1L]]),
    paste("manifest_md5:", unname(tools::md5sum(manifest_path))),
    "launcher_unlock_eligible: FALSE",
    paste("case_count:", nrow(receipt_manifest)),
    paste("shard_count:", length(list.files(file.path(root, "shards"), pattern = "\\.rds$"))),
    paste("outer_per_case:", unique(receipt_manifest$n_outer)),
    paste("bootstrap_reps:", unique(receipt_manifest$bootstrap_reps))
  )
  receipt <- c(
    receipt_header,
    paste("calibration_gate_eligible:", identical(mode, "production")),
    paste("outer_fit_rows:", nrow(receipts$outer_fits)),
    paste("bootstrap_attempt_rows:", nrow(receipts$bootstrap_attempts)),
    paste("endpoint_rows:", nrow(receipts$endpoints)),
    paste("profile_trace_rows:", nrow(receipts$profile_traces)),
    paste("availability_gates_pass:", sum(summary$availability_gate)),
    paste("coverage_gates_pass:", sum(summary$coverage_gate)),
    "public_fence: unchanged"
  )
  receipt_path <- file.path(root, if (identical(mode, "prerun")) {
    "gate4-prerun-receipt.txt"
  } else {
    "receipt.txt"
  })
  atomic_write_lines(receipt, receipt_path, immutable = identical(mode, "prerun"))
}

run_cli <- function() {
  command <- if (length(args)) args[[1L]] else ""
  root <- arg_value("--root")
  if (!nzchar(root %||% "")) stop("Use --root <outside-repository-campaign-root>.", call. = FALSE)
  if (identical(command, "manifest")) {
    campaign_id <- arg_value("--campaign-id")
    source_sha <- arg_value("--source-sha")
    if (!nzchar(campaign_id %||% "") || !nzchar(source_sha %||% "")) {
      stop("manifest requires --campaign-id and --source-sha.", call. = FALSE)
    }
    frozen_arguments <- c(
      "--n-outer", "--bootstrap-reps", "--outer-per-shard", "--clusters",
      "--availability-min", "--coverage-wilson-level",
      "--coverage-equivalence-lower", "--coverage-equivalence-upper",
      "--wald-min-available"
    )
    if (any(frozen_arguments %in% args)) {
      stop("Production manifest settings and cluster assignment are frozen; use smoke-manifest or test-manifest.", call. = FALSE)
    }
    write_manifest(root, manifest_table(campaign_id = campaign_id, source_sha = source_sha))
  } else if (identical(command, "test-manifest")) {
    campaign_id <- arg_value("--campaign-id")
    source_sha <- arg_value("--source-sha")
    if (!nzchar(campaign_id %||% "") || !nzchar(source_sha %||% "")) {
      stop("test-manifest requires --campaign-id and --source-sha.", call. = FALSE)
    }
    clusters <- strsplit(arg_value("--clusters", paste(rep("local", 12L), collapse = ",")), ",", fixed = TRUE)[[1L]]
    write_manifest(root, test_manifest_table(
      n_outer = as.integer(arg_value("--n-outer", "1")),
      bootstrap_reps = as.integer(arg_value("--bootstrap-reps", "2")),
      outer_per_shard = as.integer(arg_value("--outer-per-shard", "1")),
      campaign_id = campaign_id, source_sha = source_sha, clusters = clusters
    ))
  } else if (identical(command, "smoke-manifest")) {
    campaign_id <- arg_value("--campaign-id")
    source_sha <- arg_value("--source-sha")
    cluster <- arg_value("--cluster", "local")
    if (!nzchar(campaign_id %||% "") || !nzchar(source_sha %||% "")) {
      stop("smoke-manifest requires --campaign-id and --source-sha.", call. = FALSE)
    }
    write_manifest(root, smoke_manifest_table(campaign_id, source_sha, cluster))
  } else if (identical(command, "run-shard")) {
    if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) devtools::load_all(quiet = TRUE) else library(gllvmTMB)
    manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
    case <- manifest[manifest$case_id == arg_value("--case-id"), , drop = FALSE]
    shard_id <- as.integer(arg_value("--shard-id"))
    cluster <- arg_value("--cluster", Sys.getenv("SLURM_CLUSTER_NAME", "local"))
    if (nrow(case) != 1L || is.na(shard_id) || shard_id < 1L || shard_id > case$n_shards[[1L]]) stop("Unknown case or shard.", call. = FALSE)
    path <- file.path(root, "shards", sprintf("%s-shard-%03d.rds", case$case_id[[1L]], shard_id))
    if (!file.exists(path)) atomic_write_rds(run_shard(case, shard_id, cluster), path)
  } else if (identical(command, "mini")) {
    source_sha <- arg_value("--source-sha", "local-miniature")
    campaign_id <- arg_value("--campaign-id", "local-miniature")
    manifest <- manifest_table(n_outer = 1L, bootstrap_reps = as.integer(arg_value("--bootstrap-reps", "2")),
      outer_per_shard = 1L, campaign_id = campaign_id, source_sha = source_sha,
      clusters = rep("local", 12L)
    )
    manifest$manifest_version <- "lane-b-mspl-coverage-gate0-mini-v1-2026-08-14"
    write_manifest(root, manifest)
    if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) devtools::load_all(quiet = TRUE) else library(gllvmTMB)
    for (i in seq_len(nrow(manifest))) atomic_write_rds(run_shard(manifest[i, , drop = FALSE], 1L, "local"),
      file.path(root, "shards", sprintf("%s-shard-001.rds", manifest$case_id[[i]])))
  } else if (identical(command, "aggregate")) {
    aggregate_campaign(root, "production")
  } else if (identical(command, "aggregate-prerun")) {
    aggregate_campaign(root, "prerun")
  } else if (identical(command, "aggregate-smoke")) {
    aggregate_campaign(root, "smoke")
  } else if (identical(command, "aggregate-test")) {
    aggregate_campaign(root, "test")
  } else if (identical(command, "aggregate-mini")) {
    aggregate_campaign(root, "mini")
  } else {
    stop("Use manifest, test-manifest, smoke-manifest, mini, run-shard, aggregate, aggregate-prerun, aggregate-smoke, aggregate-test, or aggregate-mini.", call. = FALSE)
  }
}

if (!identical(Sys.getenv("MSPL_COVERAGE_SOURCE_ONLY"), "true")) run_cli()
