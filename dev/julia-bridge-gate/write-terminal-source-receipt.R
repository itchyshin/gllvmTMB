#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("usage: write-terminal-source-receipt.R ARTIFACT_ROOT RUN_ROOT GLLVM_JL_PATH", call. = FALSE)
}
artifact_root <- normalizePath(args[[1L]], mustWork = TRUE)
run_root <- normalizePath(args[[2L]], mustWork = TRUE)
gllvmjl_path <- normalizePath(args[[3L]], mustWork = TRUE)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
source(file.path(dirname(script_path), "two-cell-gate-lib.R"), local = TRUE)

sha256 <- function(path) {
  line <- system2("sha256sum", shQuote(path), stdout = TRUE)
  if (length(line) != 1L || !grepl("^[0-9a-f]{64}", line)) stop("failed to hash ", path, call. = FALSE)
  substr(line, 1L, 64L)
}
spec <- bridge_gate_spec()
paths <- list(
  gllvmtmb_archive = file.path(run_root, "incoming", "gllvmTMB-86e95fff.tar.gz"),
  gllvmjl_archive = file.path(run_root, "incoming", "GLLVMjl-00a2d7b7.tar.gz"),
  project = file.path(gllvmjl_path, "Project.toml"),
  manifest = file.path(gllvmjl_path, "Manifest.toml"),
  manifest_1_12 = file.path(run_root, "sources", "GLLVM.jl", "Manifest.toml")
)
dll <- list.files(system.file("libs", package = "gllvmTMB"), pattern = "gllvmTMB.*\\.(so|dll|dylib)$", full.names = TRUE)
if (!all(file.exists(unlist(paths))) || length(dll) != 1L) stop("terminal identity inputs are incomplete", call. = FALSE)
reason <- paste(
  "Totoro direct GLLVM.jl loading admitted Gaussian and Poisson, but the",
  "JuliaCall embedding required by gllvmTMB(engine='julia') terminated with",
  "exit 139 under both Julia 1.12.6 and Julia 1.10.10 before any fit started."
)
contract <- list(
  status = "terminal",
  terminal_code = "NO_RUN_SOURCE_CONTRACT",
  fit_started = FALSE,
  reason = reason,
  gllvmtmb_sha = spec$gllvmtmb_sha,
  gllvmtmb_tree = spec$gllvmtmb_tree,
  gllvmjl_sha = spec$gllvmjl_sha,
  gllvmjl_tree = spec$gllvmjl_tree,
  gllvmtmb_archive_sha256 = sha256(paths$gllvmtmb_archive),
  gllvmjl_archive_sha256 = sha256(paths$gllvmjl_archive),
  project_sha256 = sha256(paths$project),
  manifest_status = "absent_in_source_generated_at_runtime",
  resolved_manifest_sha256 = sha256(paths$manifest),
  runtime_manifest_sha256 = c(
    `1.12.6` = sha256(paths$manifest_1_12),
    `1.10.10` = sha256(paths$manifest)
  ),
  runtime_manifest_files = c(
    `1.12.6` = "GLLVM-Manifest-julia-1.12.6.toml",
    `1.10.10` = "GLLVM-Manifest-julia-1.10.10.toml"
  ),
  installed_dll_sha256 = sha256(dll),
  capability_status = "eligible_static_runtime_embedding_failed",
  gllvmtmb_version = as.character(utils::packageVersion("gllvmTMB")),
  juliacall_version = as.character(utils::packageVersion("JuliaCall")),
  r_version = R.version.string,
  julia_direct_versions = c("1.12.6", "1.10.10"),
  julia_embedding_exit = c(`1.12.6` = 139L, `1.10.10` = 139L),
  qualification_receipts = c(
    `1.12.6` = "process/julia-1_12_6.receipt",
    `1.10.10` = "process/julia-1_10_10.receipt"
  ),
  qualification_receipt_sha256 = c(
    `1.12.6` = sha256(file.path(artifact_root, "process/julia-1_12_6.receipt")),
    `1.10.10` = sha256(file.path(artifact_root, "process/julia-1_10_10.receipt"))
  ),
  installed_package_path = find.package("gllvmTMB"),
  installed_dll_path = dll,
  qualified_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
bridge_gate_validate_source_contract(contract)
bridge_gate_validate_process_receipts(artifact_root, contract)
saveRDS(contract, file.path(artifact_root, "source-contract.rds"))
dput(contract, file = file.path(artifact_root, "source-contract.txt"))
writeLines(capture.output(sessionInfo()), file.path(artifact_root, "R-sessionInfo.txt"))
file.copy(paths$manifest, file.path(artifact_root, "GLLVM-Manifest.toml"), overwrite = FALSE)
file.copy(
  paths$manifest_1_12,
  file.path(artifact_root, "GLLVM-Manifest-julia-1.12.6.toml"),
  overwrite = TRUE
)
file.copy(
  paths$manifest,
  file.path(artifact_root, "GLLVM-Manifest-julia-1.10.10.toml"),
  overwrite = TRUE
)
writeLines(c(
  "JULIA_1_12_DIRECT_GLLVM=ELIGIBLE",
  "JULIA_1_12_JULIACALL_EXIT=139",
  "JULIA_1_10_10_DIRECT_GLLVM=ELIGIBLE",
  "JULIA_1_10_10_JULIACALL_EXIT=139",
  "FIT_ATTEMPTS_STARTED=0"
), file.path(artifact_root, "runtime-failures.txt"))
if (file.exists(file.path(run_root, "qualify-1.10.log"))) {
  file.copy(file.path(run_root, "qualify-1.10.log"), file.path(artifact_root, "qualify-1.10.log"), overwrite = FALSE)
}

records <- bridge_gate_terminal_records("NO_RUN_SOURCE_CONTRACT", reason)
dir.create(file.path(artifact_root, "attempts"), showWarnings = FALSE)
for (i in seq_len(nrow(records))) {
  saveRDS(list(record = records[i, , drop = FALSE], result = NULL),
          file.path(artifact_root, "attempts", paste0(records$attempt_id[i], ".rds")))
}
utils::write.csv(records, file.path(artifact_root, "records.csv"), row.names = FALSE)
verdict <- list(
  outcome = "NO_RUN_SOURCE_CONTRACT",
  fit_started = FALSE,
  thresholds_frozen = TRUE,
  replacement_attempts = 0L,
  reason = reason
)
saveRDS(verdict, file.path(artifact_root, "verdict.rds"))
dput(verdict, file = file.path(artifact_root, "verdict.txt"))
members <- setdiff(list.files(artifact_root, recursive = TRUE), "SHA256SUMS")
bridge_gate_write_manifest(artifact_root, members)
cat("TERMINAL_SOURCE_RECEIPT_WRITTEN\n")
