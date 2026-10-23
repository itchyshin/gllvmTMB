## CI-10/XFI-01 pure outer-replicate campaign ledger.
## No fitter, simulator, or launcher belongs in this file.

.ci10_campaign_id <- "CI-10/XFI-01"
.ci10_seed_base <- 20260718L
.ci10_n_sim <- 5000L
.ci10_n_boot <- 499L
.ci10_gate <- 0.94
.ci10_historical_seed_exception <- list(
  cell_id = 18L,
  rep = 4381L,
  seed = 18065153L,
  note = "reviewed historical exception; retain separately and never pool"
)
`%||%` <- function(x, y) if (is.null(x)) y else x

ci10_campaign_spec <- function() {
  cells <- expand.grid(
    partner = c("gaussian", "binomial"),
    N = c(50L, 150L, 500L),
    target_multiple_r = c(0.2, 0.5, 0.8),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  cells <- cells[
    order(cells$partner, cells$N, cells$target_multiple_r),
    ,
    drop = FALSE
  ]
  cells$cell_id <- seq_len(nrow(cells))
  rownames(cells) <- NULL
  list(
    campaign_id = .ci10_campaign_id,
    schema_version = "ci10-outer-v1",
    seed_base = .ci10_seed_base,
    n_sim = .ci10_n_sim,
    n_boot = .ci10_n_boot,
    gate = .ci10_gate,
    cells = cells,
    targets = list(
      list(
        target_id = "multiple_r",
        estimand = "multiple_r",
        method = "bootstrap"
      ),
      list(
        target_id = "contrast_r:cat:2",
        estimand = "contrast_r",
        method = "profile"
      ),
      list(
        target_id = "contrast_r:cat:3",
        estimand = "contrast_r",
        method = "profile"
      )
    )
  )
}

ci10_validate_method_estimand <- function(estimand, method) {
  expected <- switch(
    estimand,
    multiple_r = "bootstrap",
    contrast_r = "profile",
    stop("unknown CI-10 estimand: ", estimand, call. = FALSE)
  )
  if (!identical(method, expected)) {
    stop(
      sprintf("CI-10 %s must use %s, not %s.", estimand, expected, method),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

## Exact arithmetic contract of .xfc_rep_seed(20260718, cell_id, rep).
ci10_rep_seed <- function(seed_base, cell_id, rep) {
  as.integer((seed_base %% 100000L) + 1000003L * (cell_id %% 997L) + rep)
}

.ci10_outer_key <- function(cell_id, rep) paste(cell_id, rep, sep = "::")

.ci10_target <- function(spec, target_id) {
  hit <- which(vapply(
    spec$targets,
    function(x) identical(x$target_id, target_id),
    logical(1)
  ))
  if (length(hit) != 1L) {
    stop("unknown CI-10 target: ", target_id, call. = FALSE)
  }
  spec$targets[[hit]]
}

.ci10_manifest_fingerprint <- function(manifest) {
  cells <- apply(
    manifest$spec$cells[, c("cell_id", "partner", "N", "target_multiple_r")],
    1L,
    paste,
    collapse = ":"
  )
  targets <- vapply(
    manifest$spec$targets,
    function(x) paste(unlist(x), collapse = ":"),
    character(1)
  )
  expected <- vapply(
    manifest$expected,
    function(x) paste(x$cell_id, x$rep, x$seed, sep = ":"),
    character(1)
  )
  exception <- unlist(manifest$historical_seed_exception, use.names = FALSE)
  paste(
    manifest$campaign_id,
    manifest$schema_version,
    manifest$source_sha,
    manifest$seed_base,
    manifest$n_sim,
    manifest$n_boot,
    manifest$gate,
    paste(cells, collapse = "|"),
    paste(targets, collapse = "|"),
    paste(expected, collapse = "|"),
    paste(exception, collapse = "|"),
    sep = "||"
  )
}

ci10_validate_manifest <- function(manifest) {
  needed <- c(
    "campaign_id",
    "schema_version",
    "source_sha",
    "seed_base",
    "n_sim",
    "n_boot",
    "gate",
    "spec",
    "expected",
    "historical_seed_exception",
    "fingerprint"
  )
  if (!all(needed %in% names(manifest))) {
    stop("invalid CI-10 outer manifest", call. = FALSE)
  }
  frozen <- identical(manifest$campaign_id, .ci10_campaign_id) &&
    identical(manifest$schema_version, "ci10-outer-v1") &&
    is.character(manifest$source_sha) &&
    length(manifest$source_sha) == 1L &&
    nzchar(manifest$source_sha) &&
    identical(manifest$seed_base, .ci10_seed_base) &&
    identical(manifest$n_sim, .ci10_n_sim) &&
    identical(manifest$n_boot, .ci10_n_boot) &&
    identical(manifest$gate, .ci10_gate)
  if (!frozen) {
    stop(
      "CI-10 manifest does not match the frozen campaign contract",
      call. = FALSE
    )
  }
  if (
    !identical(
      manifest$historical_seed_exception,
      .ci10_historical_seed_exception
    )
  ) {
    stop(
      "CI-10 manifest lost the reviewed historical seed exception",
      call. = FALSE
    )
  }
  if (!identical(manifest$fingerprint, .ci10_manifest_fingerprint(manifest))) {
    stop("CI-10 outer manifest was modified after freezing", call. = FALSE)
  }
  invisible(TRUE)
}

## expected contains one identity per cell x outer replicate: 18 x 5000 = 90000.
ci10_attempt_manifest <- function(
  spec = ci10_campaign_spec(),
  cell_ids = NULL,
  rep_ids = NULL,
  source_sha = NULL
) {
  if (
    !identical(spec$campaign_id, .ci10_campaign_id) ||
      nrow(spec$cells) != 18L ||
      !identical(spec$n_sim, .ci10_n_sim) ||
      !identical(spec$n_boot, .ci10_n_boot)
  ) {
    stop(
      "CI-10 requires the frozen 18-cell, 5000-by-499 campaign specification",
      call. = FALSE
    )
  }
  for (target in spec$targets) {
    ci10_validate_method_estimand(target$estimand, target$method)
  }
  if (
    !is.character(source_sha) || length(source_sha) != 1L || !nzchar(source_sha)
  ) {
    stop(
      "CI-10 source_sha is required to freeze an outer manifest",
      call. = FALSE
    )
  }
  cell_ids <- sort(unique(as.integer(cell_ids %||% spec$cells$cell_id)))
  rep_ids <- sort(unique(as.integer(rep_ids %||% seq_len(spec$n_sim))))
  if (
    !all(cell_ids %in% spec$cells$cell_id) ||
      any(rep_ids < 1L | rep_ids > spec$n_sim)
  ) {
    stop(
      "CI-10 manifest selection is outside the frozen campaign",
      call. = FALSE
    )
  }
  expected <- unlist(
    lapply(cell_ids, function(cell_id) {
      lapply(rep_ids, function(rep) {
        list(
          cell_id = cell_id,
          rep = rep,
          seed = ci10_rep_seed(spec$seed_base, cell_id, rep)
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
    n_boot = spec$n_boot,
    gate = spec$gate,
    spec = spec,
    selected_cell_ids = cell_ids,
    historical_seed_exception = .ci10_historical_seed_exception,
    selected_rep_ids = rep_ids,
    expected = expected
  )
  manifest$fingerprint <- .ci10_manifest_fingerprint(manifest)
  class(manifest) <- "ci10_outer_manifest"
  manifest
}

ci10_target_results <- function(manifest, outcomes) {
  ci10_validate_manifest(manifest)
  target_ids <- vapply(manifest$spec$targets, `[[`, character(1), "target_id")
  if (
    is.null(names(outcomes)) ||
      !setequal(names(outcomes), target_ids) ||
      length(outcomes) != length(target_ids)
  ) {
    stop(
      "CI-10 eligible outer attempts require a complete target payload",
      call. = FALSE
    )
  }
  outcomes <- outcomes[target_ids]
  if (!all(outcomes %in% c("covered", "miss", "ci_failed"))) {
    stop(
      "CI-10 target outcomes must be covered, miss, or ci_failed",
      call. = FALSE
    )
  }
  lapply(seq_along(target_ids), function(i) {
    target <- manifest$spec$targets[[i]]
    list(
      target_id = target$target_id,
      estimand = target$estimand,
      method = target$method,
      outcome = unname(outcomes[i])
    )
  })
}

.ci10_validate_target_results <- function(manifest, target_results) {
  if (
    !is.list(target_results) ||
      length(target_results) != length(manifest$spec$targets)
  ) {
    stop(
      "CI-10 eligible outer attempts require a complete target payload",
      call. = FALSE
    )
  }
  target_ids <- vapply(manifest$spec$targets, `[[`, character(1), "target_id")
  ids <- vapply(
    target_results,
    function(x) x$target_id %||% NA_character_,
    character(1)
  )
  if (anyDuplicated(ids) || !setequal(ids, target_ids)) {
    stop(
      "CI-10 eligible outer attempts require each frozen target exactly once",
      call. = FALSE
    )
  }
  for (result in target_results) {
    target <- .ci10_target(manifest$spec, result$target_id)
    if (
      !identical(result$estimand, target$estimand) ||
        !identical(result$method, target$method)
    ) {
      stop(
        "CI-10 target payload conflicts with immutable method-estimand contract",
        call. = FALSE
      )
    }
    ci10_validate_method_estimand(result$estimand, result$method)
    if (!result$outcome %in% c("covered", "miss", "ci_failed")) {
      stop(
        "CI-10 target outcomes must be covered, miss, or ci_failed",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

ci10_outer_attempt <- function(
  manifest,
  cell_id,
  rep,
  outcome,
  target_results = NULL,
  attempt_version = 1L
) {
  ci10_validate_manifest(manifest)
  cell_id <- as.integer(cell_id)
  rep <- as.integer(rep)
  attempt_version <- as.integer(attempt_version)
  key <- .ci10_outer_key(cell_id, rep)
  known <- vapply(
    manifest$expected,
    function(x) .ci10_outer_key(x$cell_id, x$rep),
    character(1)
  )
  if (!key %in% known) {
    stop("outer attempt is outside the immutable CI-10 manifest", call. = FALSE)
  }
  allowed <- c(
    "eligible",
    "base_fit_failed",
    "infrastructure_failure",
    "scientific_base_failure"
  )
  if (!outcome %in% allowed) {
    stop("unknown CI-10 outer outcome: ", outcome, call. = FALSE)
  }
  if (identical(outcome, "eligible")) {
    .ci10_validate_target_results(manifest, target_results)
  } else if (!is.null(target_results)) {
    stop(
      "non-eligible CI-10 outer attempts cannot carry target results",
      call. = FALSE
    )
  }
  list(
    campaign_id = manifest$campaign_id,
    schema_version = manifest$schema_version,
    source_sha = manifest$source_sha,
    cell_id = cell_id,
    rep = rep,
    seed = ci10_rep_seed(manifest$seed_base, cell_id, rep),
    attempt_version = attempt_version,
    outcome = outcome,
    target_results = target_results
  )
}

.ci10_outer_df <- function(attempts) {
  if (!length(attempts)) {
    return(data.frame())
  }
  data.frame(
    campaign_id = vapply(attempts, `[[`, character(1), "campaign_id"),
    schema_version = vapply(attempts, `[[`, character(1), "schema_version"),
    source_sha = vapply(attempts, `[[`, character(1), "source_sha"),
    cell_id = vapply(attempts, `[[`, integer(1), "cell_id"),
    rep = vapply(attempts, `[[`, integer(1), "rep"),
    seed = vapply(attempts, `[[`, integer(1), "seed"),
    attempt_version = vapply(attempts, `[[`, integer(1), "attempt_version"),
    outcome = vapply(attempts, `[[`, character(1), "outcome"),
    stringsAsFactors = FALSE
  )
}

ci10_validate_retry_history <- function(attempts) {
  tab <- .ci10_outer_df(attempts)
  if (!nrow(tab)) {
    return(invisible(TRUE))
  }
  tab$key <- .ci10_outer_key(tab$cell_id, tab$rep)
  for (rows in split(tab, tab$key)) {
    rows <- rows[order(rows$attempt_version), , drop = FALSE]
    if (!identical(rows$attempt_version, seq_len(nrow(rows)))) {
      stop(
        "CI-10 retry history must be versioned consecutively from 1",
        call. = FALSE
      )
    }
    if (nrow(rows) > 1L) {
      for (i in 2:nrow(rows)) {
        previous <- rows$outcome[i - 1L]
        if (identical(previous, "scientific_base_failure")) {
          stop(
            "CI-10 scientific failure is terminal and cannot be retried",
            call. = FALSE
          )
        }
        if (!identical(previous, "infrastructure_failure")) {
          stop(
            "CI-10 retries are permitted only after infrastructure failure",
            call. = FALSE
          )
        }
      }
    }
  }
  invisible(TRUE)
}

.ci10_validate_outer_attempt <- function(manifest, attempt) {
  required <- c(
    "campaign_id",
    "schema_version",
    "source_sha",
    "cell_id",
    "rep",
    "seed",
    "attempt_version",
    "outcome",
    "target_results"
  )
  if (!is.list(attempt) || !all(required %in% names(attempt))) {
    stop("invalid CI-10 outer attempt", call. = FALSE)
  }
  if (
    !identical(attempt$campaign_id, manifest$campaign_id) ||
      !identical(attempt$schema_version, manifest$schema_version) ||
      !identical(attempt$source_sha, manifest$source_sha)
  ) {
    stop(
      "outer attempt campaign identity does not match the manifest",
      call. = FALSE
    )
  }
  expected_seed <- ci10_rep_seed(
    manifest$seed_base,
    attempt$cell_id,
    attempt$rep
  )
  if (!identical(attempt$seed, expected_seed)) {
    stop("outer attempt seed conflicts with manifest", call. = FALSE)
  }
  if (
    !attempt$outcome %in%
      c(
        "eligible",
        "base_fit_failed",
        "infrastructure_failure",
        "scientific_base_failure"
      )
  ) {
    stop("invalid CI-10 outer outcome", call. = FALSE)
  }
  if (identical(attempt$outcome, "eligible")) {
    .ci10_validate_target_results(manifest, attempt$target_results)
  }
  if (
    !identical(attempt$outcome, "eligible") && !is.null(attempt$target_results)
  ) {
    stop(
      "non-eligible CI-10 outer attempts cannot carry target results",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

ci10_merge_attempts <- function(manifest, attempts) {
  ci10_validate_manifest(manifest)
  if (!is.list(attempts) || !length(attempts)) {
    stop("missing canonical CI-10 outer attempts", call. = FALSE)
  }
  for (attempt in attempts) {
    .ci10_validate_outer_attempt(manifest, attempt)
  }
  tab <- .ci10_outer_df(attempts)
  tab$key <- .ci10_outer_key(tab$cell_id, tab$rep)
  tab$version_key <- paste(tab$key, tab$attempt_version, sep = "::v")
  for (idx in split(seq_len(nrow(tab)), tab$version_key)) {
    if (length(idx) > 1L) {
      if (
        any(
          !vapply(
            idx,
            function(i) identical(attempts[[i]], attempts[[idx[1L]]]),
            logical(1)
          )
        )
      ) {
        stop("conflicting canonical CI-10 outer attempts", call. = FALSE)
      }
      stop("duplicate canonical CI-10 outer attempts", call. = FALSE)
    }
  }
  expected_keys <- vapply(
    manifest$expected,
    function(x) .ci10_outer_key(x$cell_id, x$rep),
    character(1)
  )
  canonical <- tab[tab$attempt_version == 1L, , drop = FALSE]
  if (any(!expected_keys %in% canonical$key)) {
    stop("missing canonical CI-10 outer attempts", call. = FALSE)
  }
  if (any(!canonical$key %in% expected_keys)) {
    stop("unexpected canonical CI-10 outer attempt", call. = FALSE)
  }
  ci10_validate_retry_history(attempts)
  final_idx <- vapply(
    split(seq_len(nrow(tab)), tab$key),
    function(idx) idx[which.max(tab$attempt_version[idx])],
    integer(1)
  )
  list(
    manifest = manifest,
    attempts = attempts,
    attempt_table = tab,
    final = attempts[final_idx]
  )
}

.ci10_clustered_mcse <- function(eligible_attempts, target_id) {
  if (!length(eligible_attempts)) {
    return(NA_real_)
  }
  covered <- vapply(
    eligible_attempts,
    function(attempt) {
      result <- Filter(
        function(x) identical(x$target_id, target_id),
        attempt$target_results
      )[[1L]]
      identical(result$outcome, "covered")
    },
    logical(1)
  )
  reps <- vapply(eligible_attempts, `[[`, integer(1), "rep")
  means <- vapply(split(covered, reps), mean, numeric(1))
  if (length(means) == 1L) {
    return(0)
  }
  sqrt(stats::var(means) / length(means))
}

ci10_summarise <- function(merged) {
  manifest <- merged$manifest
  final <- merged$final
  rows <- list()
  for (cell_id in manifest$selected_cell_ids) {
    outers <- Filter(function(x) identical(x$cell_id, cell_id), final)
    eligible <- Filter(function(x) identical(x$outcome, "eligible"), outers)
    for (target in manifest$spec$targets) {
      outcomes <- if (length(eligible)) {
        vapply(
          eligible,
          function(attempt) {
            Filter(
              function(x) identical(x$target_id, target$target_id),
              attempt$target_results
            )[[1L]]$outcome
          },
          character(1)
        )
      } else {
        character(0)
      }
      n_eligible <- length(eligible)
      n_covered <- sum(outcomes == "covered")
      coverage <- if (n_eligible) n_covered / n_eligible else NA_real_
      mcse <- .ci10_clustered_mcse(eligible, target$target_id)
      rows[[length(rows) + 1L]] <- data.frame(
        cell_id = cell_id,
        target_id = target$target_id,
        estimand = target$estimand,
        method = target$method,
        n_outer = length(outers),
        n_eligible = n_eligible,
        n_covered = n_covered,
        n_ci_failed = sum(outcomes == "ci_failed"),
        base_fit_failed = sum(vapply(
          outers,
          function(x) identical(x$outcome, "base_fit_failed"),
          logical(1)
        )),
        scientific_failures = sum(vapply(
          outers,
          function(x) identical(x$outcome, "scientific_base_failure"),
          logical(1)
        )),
        infrastructure_failures = sum(vapply(
          outers,
          function(x) identical(x$outcome, "infrastructure_failure"),
          logical(1)
        )),
        availability_rate = if (length(outers)) {
          n_eligible / length(outers)
        } else {
          NA_real_
        },
        coverage = coverage,
        mcse = mcse,
        lower_2mcse = coverage - 2 * mcse,
        stringsAsFactors = FALSE
      )
    }
  }
  targets <- do.call(rbind, rows)
  rownames(targets) <- NULL
  list(
    targets = targets,
    base_fit_health = targets[, c(
      "cell_id",
      "target_id",
      "n_outer",
      "n_eligible",
      "base_fit_failed",
      "availability_rate"
    )]
  )
}

ci10_manifest_is_complete_campaign <- function(manifest) {
  ci10_validate_manifest(manifest)
  identical(as.integer(manifest$selected_cell_ids), seq_len(18L)) &&
    identical(as.integer(manifest$selected_rep_ids), seq_len(.ci10_n_sim)) &&
    identical(length(manifest$expected), 18L * .ci10_n_sim) &&
    !anyDuplicated(vapply(
      manifest$expected,
      function(x) {
        .ci10_outer_key(x$cell_id, x$rep)
      },
      character(1)
    ))
}

ci10_promote <- function(manifest, attempts) {
  merged <- ci10_merge_attempts(manifest, attempts)
  summary <- ci10_summarise(merged)
  targets <- summary$targets
  coverage_ok <- !is.na(targets$coverage) &
    !is.na(targets$mcse) &
    targets$coverage >= manifest$gate &
    targets$lower_2mcse >= manifest$gate
  complete_campaign <- ci10_manifest_is_complete_campaign(manifest) &&
    identical(length(merged$final), 18L * .ci10_n_sim) &&
    identical(nrow(targets), 18L * length(manifest$spec$targets)) &&
    all(targets$n_outer == .ci10_n_sim)
  target_gates_pass <- isTRUE(all(coverage_ok))
  promote <- isTRUE(complete_campaign) && target_gates_pass
  promotion_reasons <- c(
    if (!complete_campaign) {
      "incomplete campaign: exact 18-cell by 5000-replicate ledger required"
    },
    if (!target_gates_pass) "coverage gate failed"
  )
  list(
    merged = merged,
    targets = targets,
    base_fit_health = summary$base_fit_health,
    promotion = list(
      complete_campaign = complete_campaign,
      target_gates_pass = target_gates_pass,
      promote = promote,
      gate = manifest$gate,
      reason = if (length(promotion_reasons)) {
        paste(promotion_reasons, collapse = "; ")
      } else {
        "all promotional targets passed"
      },
      availability_note = "Availability and retained failure counts are reported only and are not promotion criteria."
    )
  )
}
