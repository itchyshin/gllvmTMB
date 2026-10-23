# Deterministic reconciliation for the retained two-cell recovery campaign.

if (!exists("CROSS_FAMILY_LV_SCHEMA", inherits = TRUE)) {
  caller_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(caller_file)) caller_file <- ""
  candidates <- c(
    file.path("dev", "cross-family-lv-predictor", "recovery-campaign.R"),
    file.path(dirname(caller_file), "recovery-campaign.R")
  )
  campaign_file <- candidates[file.exists(candidates)][1L]
  if (is.na(campaign_file)) stop("Cannot locate recovery-campaign.R")
  source(campaign_file, local = TRUE)
}

cross_family_lv_summarise_target <- function(values, prefix) {
  if (!length(values)) return(data.frame())
  width <- max(lengths(values))
  rows <- lapply(seq_len(width), function(j) {
    x <- vapply(values, function(v) if (length(v) >= j) v[[j]] else NA_real_, numeric(1L))
    x <- x[is.finite(x)]
    data.frame(
      target = sprintf("%s[%d]", prefix, j), n = length(x),
      bias = if (length(x)) mean(x) else NA_real_,
      bias_mcse = if (length(x) > 1L) stats::sd(x) / sqrt(length(x)) else NA_real_,
      rmse = if (length(x)) sqrt(mean(x^2)) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

cross_family_lv_summarise <- function(output_dir, n_reps = CROSS_FAMILY_LV_EXPECTED_REPS) {
  plan <- cross_family_lv_plan(n_reps)
  attempt_files <- list.files(file.path(output_dir, "attempts"), pattern = "\\.rds$",
    full.names = TRUE)
  started_files <- list.files(file.path(output_dir, "started"), pattern = "\\.rds$",
    full.names = TRUE)
  attempts <- lapply(attempt_files, readRDS)
  started <- lapply(started_files, readRDS)
  ids <- vapply(attempts, function(x) as.integer(x$task_id), integer(1L))
  if (anyDuplicated(ids)) stop("duplicate retained final task")
  started_ids <- vapply(started, function(x) as.integer(x$task_id), integer(1L))
  by_id <- setNames(attempts, as.character(ids))

  ledger <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    x <- by_id[[as.character(plan$task_id[[i]])]]
    data.frame(
      task_id = plan$task_id[[i]], cell_id = plan$cell_id[[i]], rep = plan$rep[[i]],
      seed = plan$seed[[i]],
      status = if (!is.null(x)) x$status else if (plan$task_id[[i]] %in% started_ids) {
        "interrupted_missing_final"
      } else "planned_not_started",
      attempted = !is.null(x) || plan$task_id[[i]] %in% started_ids,
      converged = !is.null(x) && identical(x$convergence, 0L),
      point_eligible = !is.null(x) && isTRUE(x$point_eligible),
      max_gradient = if (!is.null(x)) x$max_gradient %||% NA_real_ else NA_real_,
      score_identity_error = if (!is.null(x)) x$score_identity_error %||% NA_real_ else NA_real_,
      runtime_s = if (!is.null(x)) x$runtime_s %||% NA_real_ else NA_real_,
      error_message = if (!is.null(x)) x$error_message %||% NA_character_ else NA_character_,
      stringsAsFactors = FALSE
    )
  }))

  cell_rows <- lapply(split(ledger, ledger$cell_id), function(x) {
    data.frame(
      cell_id = x$cell_id[[1L]], planned = nrow(x), attempted = sum(x$attempted),
      converged = sum(x$converged), point_eligible = sum(x$point_eligible),
      convergence_rate = mean(x$converged), point_availability = mean(x$point_eligible),
      max_score_identity_error = if (any(is.finite(x$score_identity_error))) {
        max(x$score_identity_error, na.rm = TRUE)
      } else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  cell_summary <- do.call(rbind, cell_rows)

  target_blocks <- lapply(unique(plan$cell_id), function(cell_id) {
    records <- attempts[vapply(attempts, function(x) {
      identical(x$cell_id, cell_id) && isTRUE(x$point_eligible)
    }, logical(1L))]
    if (!length(records)) return(data.frame())
    out <- rbind(
      cross_family_lv_summarise_target(lapply(records, `[[`, "B_lv_error"), "B_lv"),
      cross_family_lv_summarise_target(lapply(records, `[[`, "Sigma_error"), "Sigma_shared"),
      cross_family_lv_summarise_target(lapply(records, `[[`, "R_error"), "R_shared"),
      cross_family_lv_summarise_target(lapply(records, `[[`, "log_sigma_error"), "log_sigma")
    )
    out$cell_id <- cell_id
    out
  })
  target_blocks <- Filter(function(x) nrow(x) > 0L, target_blocks)
  target_summary <- if (length(target_blocks)) {
    do.call(rbind, target_blocks)
  } else {
    data.frame(
      target = character(), n = integer(), bias = numeric(),
      bias_mcse = numeric(), rmse = numeric(), cell_id = character(),
      stringsAsFactors = FALSE
    )
  }

  gates <- do.call(rbind, lapply(seq_len(nrow(cell_summary)), function(i) {
    cell <- cell_summary$cell_id[[i]]
    s <- cell_summary[i, ]
    t <- target_summary[target_summary$cell_id == cell, , drop = FALSE]
    B <- t[startsWith(t$target, "B_lv["), , drop = FALSE]
    S <- t[startsWith(t$target, "Sigma_shared["), , drop = FALSE]
    R <- t[startsWith(t$target, "R_shared["), , drop = FALSE]
    scale <- t[startsWith(t$target, "log_sigma["), , drop = FALSE]
    scale_required <- identical(cell, "continuous-unequal-scale-d2")
    data.frame(
      cell_id = cell,
      denominator_pass = s$planned == n_reps && s$attempted == n_reps,
      convergence_pass = s$convergence_rate >= 0.95,
      point_pass = s$point_availability >= 0.90,
      B_pass = nrow(B) > 0L && all(abs(B$bias) <= 0.10 & B$rmse <= 0.20),
      Sigma_pass = nrow(S) > 0L && all(abs(S$bias) <= 0.15),
      R_pass = nrow(R) > 0L && all(abs(R$bias) <= 0.10),
      scale_pass = if (scale_required) {
        nrow(scale) == 2L && all(abs(scale$bias) <= 0.10 & scale$rmse <= 0.20)
      } else TRUE,
      identity_pass = is.finite(s$max_score_identity_error) &&
        s$max_score_identity_error <= 1e-8,
      stringsAsFactors = FALSE
    )
  }))
  gates$verdict <- apply(gates[-1L], 1L, function(x) all(x %in% TRUE))
  list(ledger = ledger, cell_summary = cell_summary,
    target_summary = target_summary, gates = gates)
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 2L && identical(args[[1L]], "--summarise")) {
  result <- cross_family_lv_summarise(args[[2L]])
  print(result$cell_summary)
  print(result$gates)
}
