args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("usage: verify-forensics.R <integrity|table|boundary|receipt>", call. = FALSE)
kind <- args[[1L]]
root <- "dev/isdm-requalification/response-information-forensics/evidence"
need <- c("fit-diagnostics.csv", "pair-diagnostics.csv", "focal-diagnostics.csv", "receipt.csv")
if (any(!file.exists(file.path(root, need)))) stop("forensic evidence is incomplete", call. = FALSE)
fits <- read.csv(file.path(root, "fit-diagnostics.csv"), stringsAsFactors = FALSE)
pairs <- read.csv(file.path(root, "pair-diagnostics.csv"), stringsAsFactors = FALSE)
focal <- read.csv(file.path(root, "focal-diagnostics.csv"), stringsAsFactors = FALSE)
receipt <- read.csv(file.path(root, "receipt.csv"), header = FALSE, stringsAsFactors = FALSE)
if (kind == "integrity") {
  stopifnot(nrow(fits) == 800L, all(sort(focal$task_id) == c(624L, 632L)), all(focal$max_gradient > 0.01), identical(sort(focal$gradient_rank), c(49L, 50L)), identical(unique(focal$gradient_n), 50L))
  cat("G0 predecessor integrity PASS\n")
} else if (kind == "table") {
  stopifnot(nrow(pairs) == 400L, sum(pairs$baseline_valid & pairs$rep3_valid) == 398L, all(c("shared_error", "full_error", "psi1_error") %in% names(fits)))
  cat("G1 diagnostic table PASS\n")
} else if (kind == "boundary") {
  stopifnot(sum(fits$valid_fit) == 798L, sum(fits$task_id %in% c(624L, 632L) & !fits$valid_fit) == 2L)
  cat("G2 boundary PASS\n")
} else if (kind == "receipt") {
  value <- receipt$V2[receipt$V1 == "decision"]
  stopifnot(identical(value, "NO_FRESH_CAMPAIGN_YET"))
  cat("G3 decision receipt PASS\n")
} else stop("unknown verification kind", call. = FALSE)
