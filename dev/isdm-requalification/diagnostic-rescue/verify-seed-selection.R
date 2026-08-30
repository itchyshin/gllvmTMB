## Verify the locally retained, checksum-bound output of the frozen selector.

.seed_file <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  script <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  candidates <- c(current,
    if (length(script) == 1L) sub("^--file=", "", script) else character(),
    file.path("dev", "isdm-requalification", "diagnostic-rescue",
              "verify-seed-selection.R"),
    file.path("..", "..", "dev", "isdm-requalification",
              "diagnostic-rescue", "verify-seed-selection.R"))
  current <- candidates[!is.na(candidates) & nzchar(candidates) &
                          file.exists(candidates)][[1L]]
  normalizePath(current, mustWork = TRUE)
})
.seed_dir <- dirname(.seed_file)
source(file.path(.seed_dir, "verify-contract.R"), local = TRUE)
source(file.path(.seed_dir, "verify-remote-receipt.R"), local = TRUE)

isdm_diag_verify_seed_selection <- function(root = .receipt_evidence_root()) {
  bundle <- file.path(root, "seed-selection")
  isdm_diag_verify_bundle_manifest(bundle)
  path <- file.path(bundle, "seed-manifest.rds")
  result <- isdm_diag_verify_seed_manifest(path)
  manifest <- readRDS(path)
  ## These are the frozen results of applying the preregistered minimum rules
  ## to the pinned, raw-manifest-verified production universe. Re-running the
  ## selectors on the retained selection must be idempotent and preserve them.
  expected_nonspatial <- c(1L, 401L, 801L, 1201L, 201L, 601L, 1001L, 1401L)
  expected_spatial <- c(1802L, 1809L, 1801L, 2203L, 2202L, 2201L,
                        2001L, 2002L, 2003L, 2401L, 2402L, 2404L)
  reproduced_nonspatial <- isdm_diag_select_nonspatial(manifest$nonspatial)
  reproduced_spatial <- isdm_diag_select_spatial(manifest$spatial)
  if (!identical(as.integer(manifest$nonspatial$task_id), expected_nonspatial) ||
      !identical(as.integer(manifest$spatial$task_id), expected_spatial) ||
      !identical(reproduced_nonspatial, manifest$nonspatial) ||
      !identical(reproduced_spatial, manifest$spatial) ||
      !identical(result$planned_n, 52L) || !identical(result$smoke_n, 4L)) {
    .receipt_abort("seed selection does not reproduce the frozen selected identities")
  }
  cat("DIAGNOSTIC_SEED_SELECTION_VERIFIED\n")
  invisible(result)
}

if (sys.nframe() == 0L) isdm_diag_verify_seed_selection()
