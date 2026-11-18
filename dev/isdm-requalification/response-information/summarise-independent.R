## Independent reader: consumes frozen plan and terminal RDS receipts only.
source("dev/isdm-requalification/response-information/contract.R", local = TRUE)
source("dev/isdm-requalification/response-information/records.R", local = TRUE)
source("dev/isdm-requalification/response-information/classify.R", local = TRUE)
source("dev/isdm-requalification/response-information/recompute.R", local = TRUE)

isdm_respinfo_independent_summary <- function(plan_path, output_dir) {
  plan <- readRDS(plan_path); isdm_respinfo_validate_plan(plan)
  records <- isdm_respinfo_terminal_dispositions(plan, output_dir)
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    task <- plan[i, , drop = FALSE]; x <- records[[i]]; returned <- identical(x$status, "fit_returned")
    raw <- x$raw %||% list(); score <- if (returned) isdm_respinfo_recompute_raw(raw) else list()
    data.frame(task_id = task$task_id, dataset_id = task$dataset_id, cell_index = task$cell_index, seed_index = task$seed_index, variant = task$variant,
      status = x$status, optimizer_entered = isTRUE(x$optimizer_entered), runtime_s = if (is.finite(x$runtime_s)) x$runtime_s else NA_real_,
      peak_rss_bytes = if (returned) x$diagnostics$peak_rss_bytes %||% NA_real_ else NA_real_,
      shared_error = if (returned) score$shared_error else NA_real_, full_error = if (returned) score$full_error else NA_real_,
      psi1_error = if (returned) score$psi_error[[1L]] else NA_real_, psi2_error = if (returned) score$psi_error[[2L]] else NA_real_, psi3_error = if (returned) score$psi_error[[3L]] else NA_real_,
      sigma_error = if (returned) score$sigma_error else NA_real_, source_coefficient_rmse = if (returned) score$source_coefficient_rmse else NA_real_,
      valid_fit = returned && isTRUE(x$diagnostics$pd_hessian) && identical(as.integer(x$diagnostics$convergence), 0L) && isTRUE(x$diagnostics$finite) && is.finite(x$diagnostics$max_gradient) && x$diagnostics$max_gradient <= ISDM_RESPINFO_GRADIENT_MAX && !is.null(raw), stringsAsFactors = FALSE)
  })
  fits <- do.call(rbind, rows); pairs <- split(fits, fits$dataset_id)
  paired <- do.call(rbind, lapply(pairs, function(x) {
    b <- x[x$variant == "baseline", , drop = FALSE]; r <- x[x$variant == "rep3", , drop = FALSE]
    available <- nrow(b) == 1L && nrow(r) == 1L && isTRUE(b$valid_fit) && isTRUE(r$valid_fit)
    data.frame(dataset_id = b$dataset_id[[1L]], cell_index = b$cell_index[[1L]], seed_index = b$seed_index[[1L]], available = available,
      shared_D = if (available) log(r$shared_error + 1e-8) - log(b$shared_error + 1e-8) else NA_real_, full_D = if (available) log(r$full_error + 1e-8) - log(b$full_error + 1e-8) else NA_real_,
      psi1_D = if (available) log(r$psi1_error + 1e-8) - log(b$psi1_error + 1e-8) else NA_real_, psi2_D = if (available) log(r$psi2_error + 1e-8) - log(b$psi2_error + 1e-8) else NA_real_, psi3_D = if (available) log(r$psi3_error + 1e-8) - log(b$psi3_error + 1e-8) else NA_real_, stringsAsFactors = FALSE)
  }))
  classified <- isdm_respinfo_classify(paired[, c("cell_index", "shared_D", "full_D", "psi1_D", "psi2_D", "psi3_D")])
  list(schema = "isdm-response-information-independent-summary-v1", fits = fits, paired = paired,
       denominators = list(planned = nrow(plan), terminal = length(records), fit_returned = sum(fits$status == "fit_returned"), scoreable_pairs = sum(paired$available)), classification = classified)
}
