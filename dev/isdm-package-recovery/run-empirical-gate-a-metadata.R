#!/usr/bin/env Rscript
## Validate or materialise the metadata-only BBS/GBIF Gate-A receipt; no download.

args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
out <- value("output")
if (!mode %in% c("validate", "receipt") || (identical(mode, "receipt") && is.null(out))) {
  stop("require --mode=validate|receipt and --output=PATH for receipt", call. = FALSE)
}
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), mustWork = TRUE)
base <- dirname(script)
source(file.path(base, "empirical-gate-a-metadata-contract.R"), local = TRUE)
dossier <- file.path(base, "2026-08-13-bbs-gbif-empirical-screening-dossier.md")
if (!file.exists(dossier)) stop("missing BBS/GBIF screening dossier")
template <- empirical_gate_a_template()
decision <- empirical_gate_a_assess(template)
empirical_gate_a_validate(decision)
if (identical(mode, "receipt")) {
  if (!grepl("^/", out)) out <- file.path(getwd(), out)
  out <- normalizePath(out, mustWork = FALSE)
  parent <- normalizePath(file.path(getwd(), "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
  if (!startsWith(out, paste0(parent, "/"))) stop("receipt output must stay under private results root")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(template, file.path(out, "empirical-gate-a-metadata-table.csv"), row.names = FALSE)
  saveRDS(decision, file.path(out, "empirical-gate-a-metadata-receipt.rds"))
}
cat("EMPIRICAL_GATE_A_METADATA_PASS (no download, no fit)\n")
