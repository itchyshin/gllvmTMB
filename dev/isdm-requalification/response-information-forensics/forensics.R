ISDM_FORENSICS_SCHEMA <- "isdm-response-information-forensics-v1"
ISDM_FORENSICS_FOCAL_IDS <- c(624L, 632L)

isdm_forensics_fit_health <- function(diagnostics, gradient_max = 0.01) {
  is.list(diagnostics) &&
    identical(as.integer(diagnostics$convergence), 0L) &&
    isTRUE(diagnostics$pd_hessian) &&
    isTRUE(diagnostics$finite) &&
    is.finite(diagnostics$max_gradient) &&
    diagnostics$max_gradient <= gradient_max
}

isdm_forensics_read_manifest <- function(path) {
  lines <- readLines(path, warn = FALSE)
  pieces <- regexec("^([[:xdigit:]]{64})[[:space:]]+(.+)$", lines)
  parsed <- regmatches(lines, pieces)
  parsed <- Filter(length, parsed)
  if (!length(parsed)) stop("checksum manifest has no entries", call. = FALSE)
  out <- data.frame(hash = vapply(parsed, `[[`, character(1L), 2L), path = vapply(parsed, `[[`, character(1L), 3L), stringsAsFactors = FALSE)
  if (anyDuplicated(out$path)) stop("checksum manifest has duplicate paths", call. = FALSE)
  out
}

isdm_forensics_sha256 <- function(path) {
  exe <- Sys.which("sha256sum")
  args <- path
  if (!nzchar(exe)) {
    exe <- Sys.which("shasum")
    args <- c("-a", "256", path)
  }
  if (!nzchar(exe)) stop("neither sha256sum nor shasum is available", call. = FALSE)
  output <- system2(exe, args, stdout = TRUE, stderr = TRUE)
  if (!length(output) || !grepl("^[[:xdigit:]]{64}[[:space:]]", output[[1L]])) stop("SHA-256 command failed", call. = FALSE)
  sub("[[:space:]].*$", "", output[[1L]])
}

isdm_forensics_metric <- function(record) {
  raw <- record$raw
  list(
    shared_error = isdm_respinfo_raw_surface_error(raw$surfaces$shared, raw$truth_surfaces$shared, raw$trait),
    full_error = isdm_respinfo_raw_surface_error(raw$surfaces$full, raw$truth_surfaces$full, raw$trait),
    psi1_error = abs(raw$Psi[1L, 1L] - raw$truth_Psi[1L, 1L]) / raw$truth_Psi[1L, 1L],
    psi2_error = abs(raw$Psi[2L, 2L] - raw$truth_Psi[2L, 2L]) / raw$truth_Psi[2L, 2L],
    psi3_error = abs(raw$Psi[3L, 3L] - raw$truth_Psi[3L, 3L]) / raw$truth_Psi[3L, 3L],
    sigma_error = isdm_respinfo_relative_frobenius_raw(raw$Sigma, raw$truth_Sigma),
    source_coefficient_rmse = {
      source_terms <- grep("^isdm_source:", intersect(names(raw$fixed), names(raw$fixed_truth)), value = TRUE)
      sqrt(mean((raw$fixed[source_terms] - raw$fixed_truth[source_terms])^2))
    }
  )
}

isdm_forensics_fit_row <- function(record, gradient_max = 0.01) {
  task <- record$task; d <- record$diagnostics; metric <- isdm_forensics_metric(record)
  data.frame(
    task_id = as.integer(record$task_id), dataset_id = as.integer(task$dataset_id), cell_index = as.integer(task$cell_index),
    seed_index = as.integer(task$seed_index), n_sources = as.integer(task$n_sources), n_cells = as.integer(task$n_cells), overlap = as.character(task$overlap),
    variant = as.character(task$variant), convergence = as.integer(d$convergence), pd_hessian = isTRUE(d$pd_hessian), finite = isTRUE(d$finite),
    max_gradient = as.numeric(d$max_gradient), objective = as.numeric(d$objective), runtime_s = as.numeric(record$runtime_s),
    peak_rss_bytes = as.numeric(d$peak_rss_bytes), valid_fit = isdm_forensics_fit_health(d, gradient_max),
    shared_error = metric$shared_error, full_error = metric$full_error, psi1_error = metric$psi1_error, psi2_error = metric$psi2_error,
    psi3_error = metric$psi3_error, sigma_error = metric$sigma_error, source_coefficient_rmse = metric$source_coefficient_rmse,
    stringsAsFactors = FALSE
  )
}

isdm_forensics_pair_table <- function(fits) {
  baseline <- fits[fits$variant == "baseline", , drop = FALSE]
  rep3 <- fits[fits$variant == "rep3", , drop = FALSE]
  if (!identical(baseline$dataset_id, rep3$dataset_id)) stop("baseline and rep3 rows do not align", call. = FALSE)
  data.frame(
    dataset_id = baseline$dataset_id, cell_index = baseline$cell_index, baseline_task_id = baseline$task_id, rep3_task_id = rep3$task_id,
    baseline_gradient = baseline$max_gradient, rep3_gradient = rep3$max_gradient,
    baseline_valid = baseline$valid_fit, rep3_valid = rep3$valid_fit,
    baseline_shared_error = baseline$shared_error, rep3_shared_error = rep3$shared_error,
    baseline_full_error = baseline$full_error, rep3_full_error = rep3$full_error,
    baseline_psi1_error = baseline$psi1_error, rep3_psi1_error = rep3$psi1_error,
    baseline_psi2_error = baseline$psi2_error, rep3_psi2_error = rep3$psi2_error,
    baseline_psi3_error = baseline$psi3_error, rep3_psi3_error = rep3$psi3_error,
    stringsAsFactors = FALSE
  )
}

isdm_forensics_focal_table <- function(fits, pairs, focal_ids = ISDM_FORENSICS_FOCAL_IDS) {
  focal <- fits[fits$task_id %in% focal_ids, , drop = FALSE]
  if (!identical(sort(focal$task_id), sort(as.integer(focal_ids)))) stop("focal IDs are absent", call. = FALSE)
  out <- lapply(seq_len(nrow(focal)), function(i) {
    x <- focal[i, , drop = FALSE]
    pool <- fits[fits$cell_index == x$cell_index & fits$variant == x$variant, , drop = FALSE]
    pair <- pairs[pairs$rep3_task_id == x$task_id, , drop = FALSE]
    data.frame(
      task_id = x$task_id, dataset_id = x$dataset_id, cell_index = x$cell_index, max_gradient = x$max_gradient,
      gradient_rank = sum(pool$max_gradient <= x$max_gradient), gradient_n = nrow(pool),
      gradient_excess = x$max_gradient - 0.01, baseline_task_id = pair$baseline_task_id,
      baseline_gradient = pair$baseline_gradient, baseline_valid = pair$baseline_valid,
      rep3_shared_error = x$shared_error, baseline_shared_error = pair$baseline_shared_error,
      rep3_full_error = x$full_error, baseline_full_error = pair$baseline_full_error,
      rep3_psi1_error = x$psi1_error, baseline_psi1_error = pair$baseline_psi1_error,
      rep3_psi2_error = x$psi2_error, baseline_psi2_error = pair$baseline_psi2_error,
      rep3_psi3_error = x$psi3_error, baseline_psi3_error = pair$baseline_psi3_error,
      runtime_s = x$runtime_s, peak_rss_bytes = x$peak_rss_bytes, stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

isdm_forensics_mechanism <- function(fits, focal) {
  ## The comparison is intentionally restricted to the focal cell.  A near
  ## threshold gradient in an unrelated cell cannot explain this cell's tail.
  focal_cells <- unique(as.integer(focal$cell_index))
  if (length(focal_cells) != 1L) stop("focal records must belong to one cell", call. = FALSE)
  baseline <- fits[fits$variant == "baseline" & fits$cell_index == focal_cells, , drop = FALSE]
  ## The focal records must occupy the two largest positions, not both tie for
  ## the one largest position.  A strict maximum and second maximum are the
  ## expected empirical pattern.
  focal_are_upper_tail <- length(focal$gradient_rank) == 2L &&
    identical(sort(as.integer(focal$gradient_rank)), c(as.integer(focal$gradient_n[[1L]] - 1L), as.integer(focal$gradient_n[[1L]]))) &&
    length(unique(focal$gradient_n)) == 1L
  near_threshold_baseline <- max(baseline$max_gradient) <= 0.01 && max(baseline$max_gradient) >= 0.0095
  if (focal_are_upper_tail && near_threshold_baseline) {
    list(label = "SUPPORTED_NARROW_GRADIENT_TAIL", decision = "NO_FRESH_CAMPAIGN_YET", reason = "The focal rep3 fits are the cell's two largest rep3 gradients, while baseline gradients also approach the frozen threshold. The retained receipt lacks component-level gradients and optimizer trace, so the tail is supported but its numerical cause is unresolved.")
  } else {
    list(label = "UNRESOLVED", decision = "NO_FRESH_CAMPAIGN_YET", reason = "The retained scalar diagnostics do not support a mechanism. A fresh campaign cannot be justified from this audit.")
  }
}
