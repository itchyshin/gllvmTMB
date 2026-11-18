## CI-09 pure campaign-preparation ledger.
##
## This file deliberately contains neither a fitter nor a simulator.  It freezes
## the ordinary Gaussian, two-trait Fisher-z campaign and validates the retained
## records that a separately approved campaign would produce.

.ci09_campaign_id <- "CI-09"
.ci09_schema_version <- "ci09-attempt-v1"
.ci09_seed_base <- 90000000L
.ci09_n_sim <- 5000L
.ci09_gate <- 0.94

ci09_campaign_spec <- function() {
  cells <- expand.grid(
    n_units = c(150L, 400L),
    rho = c(-0.5, 0, 0.5),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  cells <- cells[order(cells$n_units, cells$rho), , drop = FALSE]
  cells$cell_id <- seq_len(nrow(cells))
  rownames(cells) <- NULL
  list(
    campaign_id = .ci09_campaign_id,
    schema_version = .ci09_schema_version,
    seed_base = .ci09_seed_base,
    n_sim = .ci09_n_sim,
    gate = .ci09_gate,
    family = "gaussian",
    tier = "ordinary-unit",
    traits = 2L,
    interval_method = "fisher-z",
    targets = list(list(
      target_id = "rho_1_2",
      estimand = "Sigma[1,2]/sqrt(Sigma[1,1]*Sigma[2,2])"
    )),
    cells = cells
  )
}

ci09_rep_seed <- function(cell_id, local_rep) {
  cell_id <- as.integer(cell_id)
  local_rep <- as.integer(local_rep)
  if (
    length(cell_id) != 1L ||
      is.na(cell_id) ||
      cell_id < 1L ||
      cell_id > 6L ||
      length(local_rep) != 1L ||
      is.na(local_rep) ||
      local_rep < 1L ||
      local_rep > .ci09_n_sim
  ) {
    stop(
      "CI-09 seed identity is outside the frozen six-cell, 5000-replicate campaign",
      call. = FALSE
    )
  }
  as.integer(.ci09_seed_base + cell_id * 10000L + local_rep)
}

ci09_seed_sets_intersect <- function(cell_a, reps_a, cell_b, reps_b) {
  length(intersect(
    vapply(reps_a, function(rep) ci09_rep_seed(cell_a, rep), integer(1)),
    vapply(reps_b, function(rep) ci09_rep_seed(cell_b, rep), integer(1))
  )) >
    0L
}

ci09_fisher_interval <- function(rho, n_eff, level = 0.95) {
  n_eff <- suppressWarnings(as.integer(n_eff))
  unavailable <- length(rho) != 1L ||
    !is.finite(rho) ||
    abs(rho) >= 1 ||
    length(n_eff) != 1L ||
    is.na(n_eff) ||
    n_eff < 4L
  if (unavailable) {
    return(list(
      lower = NA_real_,
      upper = NA_real_,
      n_eff = n_eff,
      available = FALSE
    ))
  }
  z_crit <- stats::qnorm(1 - (1 - level) / 2)
  se_z <- 1 / sqrt(n_eff - 3L)
  z <- atanh(rho)
  list(
    lower = tanh(z - z_crit * se_z),
    upper = tanh(z + z_crit * se_z),
    n_eff = n_eff,
    available = TRUE
  )
}

.ci09_identity_key <- function(cell_id, rep, target_id) {
  paste(as.integer(cell_id), as.integer(rep), target_id, sep = "::")
}

.ci09_manifest_fingerprint <- function(manifest) {
  expected <- vapply(
    manifest$expected,
    function(x) {
      paste(x$cell_id, x$rep, x$target_id, x$seed, sep = ":")
    },
    character(1)
  )
  paste(
    manifest$campaign_id,
    manifest$schema_version,
    manifest$source_sha,
    manifest$seed_base,
    manifest$n_sim,
    manifest$n_outer,
    manifest$gate,
    paste(expected, collapse = "|"),
    sep = "||"
  )
}

ci09_attempt_manifest <- function(
  spec = ci09_campaign_spec(),
  cell_ids = NULL,
  rep_ids = NULL,
  source_sha = NULL
) {
  if (
    !identical(spec$campaign_id, .ci09_campaign_id) ||
      !identical(spec$schema_version, .ci09_schema_version) ||
      !identical(spec$n_sim, .ci09_n_sim) ||
      nrow(spec$cells) != 6L ||
      !identical(spec$interval_method, "fisher-z")
  ) {
    stop(
      "CI-09 requires the frozen six-cell, 5000-replicate Fisher-z specification",
      call. = FALSE
    )
  }
  if (
    !is.character(source_sha) || length(source_sha) != 1L || !nzchar(source_sha)
  ) {
    stop("CI-09 manifest requires a non-empty source SHA", call. = FALSE)
  }
  cell_ids <- sort(unique(as.integer(cell_ids %||% spec$cells$cell_id)))
  rep_ids <- sort(unique(as.integer(rep_ids %||% seq_len(spec$n_sim))))
  if (
    !all(cell_ids %in% spec$cells$cell_id) ||
      anyNA(rep_ids) ||
      any(rep_ids < 1L | rep_ids > spec$n_sim)
  ) {
    stop(
      "CI-09 manifest selection is outside the frozen campaign",
      call. = FALSE
    )
  }
  expected <- unlist(
    lapply(cell_ids, function(cell_id) {
      lapply(rep_ids, function(rep) {
        list(
          cell_id = cell_id,
          rep = rep,
          target_id = "rho_1_2",
          seed = ci09_rep_seed(cell_id, rep)
        )
      })
    }),
    recursive = FALSE
  )
  manifest <- list(
    campaign_id = spec$campaign_id,
    schema_version = spec$schema_version,
    source_sha = source_sha,
    seed_base = spec$seed_base,
    n_sim = spec$n_sim,
    n_outer = length(cell_ids) * length(rep_ids),
    gate = spec$gate,
    spec = spec,
    selected_cell_ids = cell_ids,
    selected_rep_ids = rep_ids,
    expected = expected
  )
  manifest$fingerprint <- .ci09_manifest_fingerprint(manifest)
  class(manifest) <- "ci09_attempt_manifest"
  manifest
}

`%||%` <- function(x, y) if (is.null(x)) y else x

ci09_validate_manifest <- function(manifest) {
  needed <- c(
    "campaign_id",
    "schema_version",
    "source_sha",
    "seed_base",
    "n_sim",
    "n_outer",
    "gate",
    "spec",
    "expected",
    "fingerprint"
  )
  if (!is.list(manifest) || !all(needed %in% names(manifest))) {
    stop("invalid CI-09 attempt manifest", call. = FALSE)
  }
  if (
    !identical(manifest$campaign_id, .ci09_campaign_id) ||
      !identical(manifest$schema_version, .ci09_schema_version) ||
      !identical(manifest$seed_base, .ci09_seed_base) ||
      !identical(manifest$n_sim, .ci09_n_sim) ||
      !identical(manifest$gate, .ci09_gate) ||
      !is.character(manifest$source_sha) ||
      length(manifest$source_sha) != 1L ||
      !nzchar(manifest$source_sha)
  ) {
    stop(
      "CI-09 manifest does not match the frozen campaign contract",
      call. = FALSE
    )
  }
  if (
    length(manifest$expected) !=
      length(unique(vapply(
        manifest$expected,
        function(x) {
          .ci09_identity_key(x$cell_id, x$rep, x$target_id)
        },
        character(1)
      )))
  ) {
    stop("CI-09 manifest has duplicate outer identities", call. = FALSE)
  }
  if (!identical(manifest$n_outer, length(manifest$expected))) {
    stop("CI-09 manifest outer-identity count is incomplete", call. = FALSE)
  }
  if (!identical(manifest$fingerprint, .ci09_manifest_fingerprint(manifest))) {
    stop("CI-09 attempt manifest was modified after freezing", call. = FALSE)
  }
  invisible(TRUE)
}

ci09_attempt <- function(
  manifest,
  cell_id,
  rep,
  target_id,
  outcome,
  n_eff,
  attempt_version = 1L,
  base_fit = NULL
) {
  ci09_validate_manifest(manifest)
  cell_id <- as.integer(cell_id)
  rep <- as.integer(rep)
  attempt_version <- as.integer(attempt_version)
  key <- .ci09_identity_key(cell_id, rep, target_id)
  expected_keys <- vapply(
    manifest$expected,
    function(x) {
      .ci09_identity_key(x$cell_id, x$rep, x$target_id)
    },
    character(1)
  )
  if (!key %in% expected_keys) {
    stop("attempt is outside the immutable CI-09 manifest", call. = FALSE)
  }
  allowed <- c(
    "covered",
    "miss",
    "ci_failed",
    "interval_unavailable",
    "base_fit_failed",
    "scientific_failure",
    "infrastructure_failure"
  )
  if (!outcome %in% allowed) {
    stop("unknown CI-09 outcome", call. = FALSE)
  }
  if (is.null(base_fit)) {
    base_fit <- if (outcome %in% c("base_fit_failed", "scientific_failure")) {
      "failed"
    } else if (identical(outcome, "infrastructure_failure")) {
      "unknown"
    } else {
      "eligible"
    }
  }
  if (!base_fit %in% c("eligible", "failed", "unknown")) {
    stop("invalid CI-09 base-fit state", call. = FALSE)
  }
  expected_base_fit <- if (
    outcome %in%
      c("covered", "miss", "ci_failed", "interval_unavailable")
  ) {
    "eligible"
  } else if (outcome %in% c("base_fit_failed", "scientific_failure")) {
    "failed"
  } else {
    "unknown"
  }
  if (!identical(base_fit, expected_base_fit)) {
    stop("CI-09 outcome conflicts with its base-fit state", call. = FALSE)
  }
  interval <- ci09_fisher_interval(rho = 0, n_eff = n_eff)
  if (
    outcome %in%
      c("covered", "miss", "ci_failed") &&
      !isTRUE(interval$available)
  ) {
    stop(
      "covered, miss, and CI failure outcomes require realised n_eff >= 4",
      call. = FALSE
    )
  }
  if (
    identical(outcome, "interval_unavailable") && isTRUE(interval$available)
  ) {
    stop(
      "interval_unavailable requires missing, non-finite, or small realised n_eff",
      call. = FALSE
    )
  }
  if (
    outcome %in%
      c("base_fit_failed", "scientific_failure", "infrastructure_failure") &&
      !is.na(interval$n_eff)
  ) {
    stop("non-eligible CI-09 outcomes require missing n_eff", call. = FALSE)
  }
  list(
    campaign_id = manifest$campaign_id,
    schema_version = manifest$schema_version,
    source_sha = manifest$source_sha,
    cell_id = cell_id,
    rep = rep,
    target_id = target_id,
    seed = ci09_rep_seed(cell_id, rep),
    attempt_version = attempt_version,
    base_fit = base_fit,
    outcome = outcome,
    n_eff = interval$n_eff
  )
}

.ci09_attempt_df <- function(attempts) {
  if (!length(attempts)) {
    return(data.frame())
  }
  data.frame(
    campaign_id = vapply(attempts, `[[`, character(1), "campaign_id"),
    schema_version = vapply(attempts, `[[`, character(1), "schema_version"),
    source_sha = vapply(attempts, `[[`, character(1), "source_sha"),
    cell_id = vapply(attempts, `[[`, integer(1), "cell_id"),
    rep = vapply(attempts, `[[`, integer(1), "rep"),
    target_id = vapply(attempts, `[[`, character(1), "target_id"),
    seed = vapply(attempts, `[[`, integer(1), "seed"),
    attempt_version = vapply(attempts, `[[`, integer(1), "attempt_version"),
    base_fit = vapply(attempts, `[[`, character(1), "base_fit"),
    outcome = vapply(attempts, `[[`, character(1), "outcome"),
    n_eff = vapply(attempts, `[[`, integer(1), "n_eff"),
    stringsAsFactors = FALSE
  )
}

ci09_merge_attempts <- function(manifest, attempts) {
  ci09_validate_manifest(manifest)
  if (!is.list(attempts) || !length(attempts)) {
    stop("missing canonical CI-09 attempts", call. = FALSE)
  }
  operational <- .ci09_attempt_df(attempts)
  allowed_outcomes <- c(
    "covered",
    "miss",
    "ci_failed",
    "interval_unavailable",
    "base_fit_failed",
    "scientific_failure",
    "infrastructure_failure"
  )
  if (any(!operational$outcome %in% allowed_outcomes)) {
    stop(
      "CI-09 deserialised outcome is outside the frozen contract",
      call. = FALSE
    )
  }
  expected_base_fit <- ifelse(
    operational$outcome %in%
      c("covered", "miss", "ci_failed", "interval_unavailable"),
    "eligible",
    ifelse(
      operational$outcome %in% c("base_fit_failed", "scientific_failure"),
      "failed",
      "unknown"
    )
  )
  if (any(operational$base_fit != expected_base_fit)) {
    stop(
      "CI-09 deserialised outcome conflicts with its base-fit state",
      call. = FALSE
    )
  }
  interval_available <- !is.na(operational$n_eff) & operational$n_eff >= 4L
  if (
    any(
      operational$outcome %in%
        c("covered", "miss", "ci_failed") &
        !interval_available
    ) ||
      any(operational$outcome == "interval_unavailable" & interval_available) ||
      any(
        operational$outcome %in%
          c("base_fit_failed", "scientific_failure", "infrastructure_failure") &
          !is.na(operational$n_eff)
      )
  ) {
    stop("CI-09 deserialised n_eff conflicts with its outcome", call. = FALSE)
  }
  if (
    any(is.na(operational$attempt_version) | operational$attempt_version < 1L)
  ) {
    stop("CI-09 deserialised attempt version is invalid", call. = FALSE)
  }
  if (
    any(operational$campaign_id != manifest$campaign_id) ||
      any(operational$schema_version != manifest$schema_version) ||
      any(operational$source_sha != manifest$source_sha)
  ) {
    stop("attempt campaign identity does not match manifest", call. = FALSE)
  }
  expected <- vapply(
    manifest$expected,
    function(x) {
      .ci09_identity_key(x$cell_id, x$rep, x$target_id)
    },
    character(1)
  )
  operational$key <- .ci09_identity_key(
    operational$cell_id,
    operational$rep,
    operational$target_id
  )
  if (any(!operational$key %in% expected)) {
    stop("attempt is outside immutable CI-09 manifest", call. = FALSE)
  }
  version_key <- paste(
    operational$key,
    operational$attempt_version,
    sep = "::v"
  )
  if (anyDuplicated(version_key)) {
    stop("duplicate canonical CI-09 attempts", call. = FALSE)
  }
  if (
    any(
      operational$seed !=
        mapply(ci09_rep_seed, operational$cell_id, operational$rep)
    )
  ) {
    stop("CI-09 seed collision or mismatch", call. = FALSE)
  }
  rows_by_key <- split(operational, operational$key, drop = TRUE)
  if (!all(expected %in% names(rows_by_key))) {
    stop("missing canonical CI-09 attempts", call. = FALSE)
  }
  canonical <- lapply(expected, function(key) {
    rows <- rows_by_key[[key]]
    rows <- rows[order(rows$attempt_version), , drop = FALSE]
    if (!identical(rows$attempt_version, seq_len(nrow(rows)))) {
      stop(
        "CI-09 retry history must be versioned consecutively from 1",
        call. = FALSE
      )
    }
    if (nrow(rows) > 1L) {
      for (i in 2:nrow(rows)) {
        previous <- rows$outcome[i - 1L]
        if (identical(previous, "scientific_failure")) {
          stop(
            "CI-09 scientific failure is terminal and cannot be retried",
            call. = FALSE
          )
        }
        if (!identical(previous, "infrastructure_failure")) {
          stop(
            "CI-09 retries are permitted only after infrastructure failure",
            call. = FALSE
          )
        }
      }
    }
    rows[nrow(rows), , drop = FALSE]
  })
  canonical <- do.call(rbind, canonical)
  rownames(canonical) <- NULL
  list(operational = operational, canonical = canonical, manifest = manifest)
}

## Fast, deterministic construction for the packet verifier only. This does
## not fit or simulate a model and exists so the complete 30,000-row ledger can
## be checked without repeatedly hashing the same frozen manifest.
ci09_synthetic_all_covered <- function(manifest, n_eff = 150L) {
  ci09_validate_manifest(manifest)
  if (is.na(as.integer(n_eff)) || as.integer(n_eff) < 4L) {
    stop(
      "synthetic covered attempts require realised n_eff >= 4",
      call. = FALSE
    )
  }
  lapply(manifest$expected, function(x) {
    list(
      campaign_id = manifest$campaign_id,
      schema_version = manifest$schema_version,
      source_sha = manifest$source_sha,
      cell_id = x$cell_id,
      rep = x$rep,
      target_id = x$target_id,
      seed = x$seed,
      attempt_version = 1L,
      base_fit = "eligible",
      outcome = "covered",
      n_eff = as.integer(n_eff)
    )
  })
}

.ci09_clustered_mcse <- function(covered) {
  covered <- as.numeric(covered)
  if (length(covered) <= 1L) {
    return(0)
  }
  stats::sd(covered) / sqrt(length(covered))
}

ci09_summarise <- function(merged) {
  canonical <- merged$canonical
  target_keys <- unique(paste(
    canonical$cell_id,
    canonical$target_id,
    sep = "::"
  ))
  rows <- lapply(target_keys, function(key) {
    tab <- canonical[
      paste(canonical$cell_id, canonical$target_id, sep = "::") == key,
      ,
      drop = FALSE
    ]
    coverage_eligible <- tab$outcome %in%
      c("covered", "miss", "ci_failed", "interval_unavailable")
    covered <- tab$outcome == "covered"
    interval_available <- tab$outcome %in% c("covered", "miss")
    n_eligible <- sum(coverage_eligible)
    coverage <- if (n_eligible) {
      sum(covered[coverage_eligible]) / n_eligible
    } else {
      NA_real_
    }
    data.frame(
      cell_id = tab$cell_id[1L],
      target_id = tab$target_id[1L],
      n_outer = nrow(tab),
      n_eligible = n_eligible,
      n_covered = sum(covered),
      n_ci_failed = sum(tab$outcome == "ci_failed"),
      n_interval_unavailable = sum(tab$outcome == "interval_unavailable"),
      base_fit_failed = sum(tab$outcome == "base_fit_failed"),
      scientific_failure = sum(tab$outcome == "scientific_failure"),
      infrastructure_failure = sum(tab$outcome == "infrastructure_failure"),
      availability_rate = sum(tab$base_fit == "eligible") / nrow(tab),
      interval_available_rate = sum(interval_available) / nrow(tab),
      coverage = coverage,
      mcse = if (n_eligible) {
        .ci09_clustered_mcse(covered[coverage_eligible])
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  })
  targets <- do.call(rbind, rows)
  targets$lower <- targets$coverage - 2 * targets$mcse
  list(
    targets = targets,
    canonical = canonical,
    operational = merged$operational,
    manifest = merged$manifest
  )
}

ci09_promote <- function(summary) {
  targets <- summary$targets
  manifest <- summary$manifest
  full_cells <- identical(sort(as.integer(manifest$selected_cell_ids)), 1:6)
  full_reps <- identical(
    sort(as.integer(manifest$selected_rep_ids)),
    seq_len(.ci09_n_sim)
  )
  full_outer <- identical(as.integer(manifest$n_outer), 30000L) &&
    identical(nrow(summary$canonical), 30000L) &&
    nrow(targets) == 6L &&
    all(targets$n_outer == .ci09_n_sim)
  if (!isTRUE(full_cells && full_reps && full_outer)) {
    return(list(
      targets = targets,
      promotion = list(
        promote = FALSE,
        reason = "full six-cell, 5000-replicate CI-09 campaign is required for certification"
      )
    ))
  }
  passing <- !is.na(targets$coverage) &
    targets$coverage >= .ci09_gate &
    !is.na(targets$lower) &
    targets$lower >= .ci09_gate
  list(
    targets = targets,
    promotion = list(
      promote = isTRUE(all(passing)),
      reason = if (isTRUE(all(passing))) {
        "all targets satisfy coverage and lower-band gates"
      } else {
        "coverage gate failed for one or more targets"
      }
    )
  )
}
