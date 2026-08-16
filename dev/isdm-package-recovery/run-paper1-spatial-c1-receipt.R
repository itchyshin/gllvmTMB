#!/usr/bin/env Rscript
## Materialise or validate a no-fit Paper 1 C1 gradient-topology receipt.

args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
ledger_path <- value("ledger")
out <- value("output")
if (!mode %in% c("validate", "receipt") || is.null(ledger_path) ||
    (identical(mode, "receipt") && is.null(out))) {
  stop("require --mode=validate|receipt, --ledger=PATH, and --output=PATH for receipt",
       call. = FALSE)
}
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                        mustWork = TRUE)
source(file.path(dirname(script), "paper1-spatial-c1-topology.R"), local = TRUE)
ledger_path <- normalizePath(ledger_path, mustWork = TRUE)
ledger <- readRDS(ledger_path)
sha_line <- system2("shasum", c("-a", "256", ledger_path), stdout = TRUE, stderr = TRUE)
ledger_sha256 <- sub("[[:space:]].*$", "", sha_line[[1L]])
receipt <- paper1_c1_receipt(ledger, source_ledger = list(path = ledger_path, sha256 = ledger_sha256))
paper1_c1_validate_receipt(receipt)
if (identical(mode, "receipt")) {
  if (!grepl("^/", out)) out <- file.path(getwd(), out)
  out <- normalizePath(out, mustWork = FALSE)
  parent <- normalizePath(file.path(getwd(), "dev", "isdm-package-recovery", "results"),
                          mustWork = FALSE)
  if (!startsWith(out, paste0(parent, "/"))) {
    stop("receipt output must stay under private results root", call. = FALSE)
  }
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  saveRDS(receipt, file.path(out, "paper1-c1-topology-receipt.rds"))
  utils::write.csv(data.frame(
    retained_attempt_id = receipt$retained_attempt_id,
    retained_commit = receipt$retained_commit,
    max_index = receipt$maximum$index,
    max_block = receipt$maximum$block,
    max_abs_gradient = receipt$maximum$absolute_gradient,
    case = receipt$classifier$case,
    reason = receipt$classifier$reason,
    candidate = receipt$decision$candidate
  ), file.path(out, "paper1-c1-topology-summary.csv"), row.names = FALSE)
}
cat("PAPER1_C1_TOPOLOGY_RECEIPT_PASS (no fit)\n")
