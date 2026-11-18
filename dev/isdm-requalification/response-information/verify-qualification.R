args <- commandArgs(trailingOnly = TRUE); if (length(args) != 3L) stop("usage: verify-qualification.R <qualification-plan.rds> <totoro-output> <drac-output>", call. = FALSE)
source("dev/isdm-requalification/response-information/contract.R", local = TRUE); source("dev/isdm-requalification/response-information/records.R", local = TRUE); source("dev/isdm-requalification/response-information/recompute.R", local = TRUE)
plan <- readRDS(args[[1L]]); isdm_respinfo_validate_qualification_plan(plan)
output_for <- function(host) if (identical(host, "totoro")) args[[2L]] else args[[3L]]
records <- lapply(seq_len(nrow(plan)), function(i) readRDS(file.path(output_for(plan$host[[i]]), "attempts", isdm_respinfo_leaf(plan$task_id[[i]]))))
valid <- vapply(seq_along(records), function(i) {
  x <- records[[i]]; task <- plan[i, , drop = FALSE]
  identical(as.integer(x$task_id), as.integer(task$task_id)) && identical(x$status, "fit_returned") &&
    identical(x$disposition_source, "worker") && isTRUE(x$optimizer_entered) && isTRUE(x$diagnostics$finite) &&
    is.finite(x$diagnostics$objective) && is.finite(x$diagnostics$max_gradient) && !is.null(x$raw) &&
    is.character(x$source_sha) && length(x$source_sha) == 1L && nzchar(x$source_sha) &&
    is.character(x$harness_manifest_sha256) && length(x$harness_manifest_sha256) == 1L && nzchar(x$harness_manifest_sha256) &&
    all(is.finite(unlist(isdm_respinfo_recompute_raw(x$raw), use.names = FALSE)))
}, logical(1L))
if (length(records) != 4L || !all(valid)) stop("engineering qualification did not yield four finite entered fits with identity receipts", call. = FALSE)
cat("response information qualification verification passed\n")
