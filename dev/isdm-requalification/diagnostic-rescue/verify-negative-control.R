## Corrupt one disposable copied byte and prove the production verifier rejects.

.negative_file <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  script <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  candidates <- c(current,
    if (length(script) == 1L) sub("^--file=", "", script) else character(),
    file.path("dev", "isdm-requalification", "diagnostic-rescue",
              "verify-negative-control.R"),
    file.path("..", "..", "dev", "isdm-requalification",
              "diagnostic-rescue", "verify-negative-control.R"))
  current <- candidates[!is.na(candidates) & nzchar(candidates) &
                          file.exists(candidates)][[1L]]
  normalizePath(current, mustWork = TRUE)
})
.negative_dir <- dirname(.negative_file)
source(file.path(.negative_dir, "verify-remote-receipt.R"), local = TRUE)

isdm_diag_verify_negative_control <- function(root = .receipt_evidence_root()) {
  source_bundle <- file.path(root, "experiment")
  isdm_diag_verify_bundle_manifest(source_bundle)
  scratch <- tempfile("isdm-diagnostic-negative-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
  copied <- file.path(scratch, "experiment")
  if (!file.copy(source_bundle, scratch, recursive = TRUE, copy.mode = TRUE))
    .receipt_abort("could not create disposable negative-control copy")
  manifest <- file.path(copied, "MANIFEST.sha256")
  rows <- readLines(manifest, warn = FALSE)
  target <- sub("^[0-9A-Fa-f]{64}  ", "", rows[[1L]])
  target_path <- file.path(copied, target)
  connection <- file(target_path, open = "ab")
  on.exit(try(close(connection), silent = TRUE), add = TRUE)
  writeBin(as.raw(0x00), connection)
  close(connection)
  rejected <- tryCatch({
    isdm_diag_verify_bundle_manifest(copied)
    FALSE
  }, isdm_diag_receipt_hash_mismatch = function(e) TRUE,
     isdm_diag_receipt_invalid = function(e) TRUE)
  if (!isTRUE(rejected))
    .receipt_abort("corrupted disposable bundle was not rejected")
  ## Prove the immutable source bundle still verifies after the control.
  isdm_diag_verify_bundle_manifest(source_bundle)
  cat("DIAGNOSTIC_NEGATIVE_CONTROL_VERIFIED\n")
  invisible(TRUE)
}

if (sys.nframe() == 0L) isdm_diag_verify_negative_control()
