#!/usr/bin/env Rscript
## Validate or materialise the Paper 2 C2 no-fit all-attempt receipt.
args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
out <- value("output")
if (!mode %in% c("validate", "retained-receipt") ||
    (identical(mode, "retained-receipt") && is.null(out))) {
  stop("require --mode=validate|retained-receipt and --output=PATH for retained-receipt", call. = FALSE)
}
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), mustWork = TRUE)
base <- dirname(script)
source(file.path(base, "paper2-c2-all-attempt-contract.R"), local = TRUE)
spec <- file.path(base, "2026-08-12-paper2-case-c-psi-information-specification.md")
adjudication <- file.path(base, "2026-08-12-paper2-s6-local-prerun-adjudication.md")
for (path in c(spec, adjudication)) if (!file.exists(path)) stop("missing C2 source: ", path)
cells <- paper2_c2_cells()
stopifnot(identical(cells$S, c(6L, 20L, 60L)), all(cells$R == 20L))
retained <- paper2_c2_retained_s6()
paper2_c2_validate_retained_s6(retained)
receipt <- list(
  schema = "PAPER2_C2_NO_FIT_RECEIPT_V1",
  frozen_cells = cells,
  retained_s6 = retained,
  retained_s6_summary = paper2_c2_summarise(list(retained), expected_R = 1L),
  historical_provenance = list(seed = 86122L, S = 6L, C = 360L, r = 3L, b = 1L, d = 1L,
    retained_commit = "57613984ddf844194326c3829ae97aab28ba3a35",
    historical_fixture_sha256 = "701ba79e88a354c7285ac4786d9464b3b8b31edf8789e5fb71ed1f887bee9969"),
  current_contract_md5 = unname(tools::md5sum(c(spec, adjudication,
    file.path(base, "paper2-c2-all-attempt-contract.R")))),
  scope = "private_no_fit_contract_only"
)
paper2_c2_validate_receipt(receipt)
if (identical(mode, "retained-receipt")) {
  if (!grepl("^/", out)) out <- file.path(getwd(), out)
  out <- normalizePath(out, mustWork = FALSE)
  parent <- normalizePath(file.path(getwd(), "dev", "isdm-package-recovery", "results"), mustWork = FALSE)
  if (!startsWith(out, paste0(parent, "/"))) stop("receipt output must stay under private results root")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  saveRDS(receipt, file.path(out, "paper2-c2-frozen-record-receipt.rds"))
}
cat("PAPER2_C2_NO_FIT_CONTRACT_PASS\n")
