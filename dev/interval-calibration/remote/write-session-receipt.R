#!/usr/bin/env Rscript
## Capture the Linux/R/compiler/BLAS/source environment before a wave.

source("dev/interval-calibration/remote/shard-io.R")

interval_command_output <- function(command, args = character()) {
  out <- tryCatch(
    system2(command, args, stdout = TRUE, stderr = TRUE),
    error = function(e) interval_stop(
      "session receipt command failed: ",
      conditionMessage(e)
    )
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    interval_stop(
      "session receipt command exited nonzero: ",
      command,
      " ",
      paste(args, collapse = " "),
      "\n",
      paste(out, collapse = "\n")
    )
  }
  out
}

interval_session_receipt <- function(packet, task_tsv, source_root, output_root) {
  interval_assert_clean_checkout(source_root)
  approved_source_sha <- interval_approved_source(packet)
  installed_package <- interval_assert_installed_package(approved_source_sha)
  runtime_dependencies <- interval_assert_runtime_dependencies()
  list(
    schema = "INTERVAL_CALIBRATION_SESSION_RECEIPT_V1",
    packet = packet,
    approved_source_sha = approved_source_sha,
    host = Sys.info(),
    session_info = utils::sessionInfo(),
    R = R.version,
    libraries = .libPaths(),
    ext_soft_version = extSoftVersion(),
    compiler = list(
      cc = interval_command_output(file.path(R.home("bin"), "R"), c("CMD", "config", "CC")),
      cxx = interval_command_output(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX"))
    ),
    package_versions = vapply(
      c("gllvmTMB", "TMB", "Matrix", "RcppEigen"),
      function(x) {
        if (requireNamespace(x, quietly = TRUE)) as.character(utils::packageVersion(x)) else NA_character_
      },
      character(1)
    ),
    checkout_sha = trimws(interval_git_output(c("rev-parse", "HEAD"), source_root)[[1L]]),
    checkout_status = "clean",
    installed_package = installed_package,
    runtime_dependencies = runtime_dependencies,
    installed_tree_sha256 = interval_directory_sha256(
      installed_package$package_path
    ),
    thread_environment = Sys.getenv(c(
      "OPENBLAS_NUM_THREADS",
      "OMP_NUM_THREADS",
      "MKL_NUM_THREADS"
    )),
    task_manifest = normalizePath(task_tsv, mustWork = TRUE),
    task_manifest_sha256 = interval_sha256_file(task_tsv),
    runner_sha256 = interval_sha256_file(
      file.path(source_root, "dev/interval-calibration/remote/run-shard.R")
    ),
    aggregator_sha256 = interval_sha256_file(
      file.path(source_root, "dev/interval-calibration/remote/aggregate-campaign.R")
    ),
    totoro_driver_sha256 = interval_sha256_file(
      file.path(source_root, "dev/interval-calibration/remote/run-totoro-wave.sh")
    ),
    slurm_driver_sha256 = interval_sha256_file(
      file.path(source_root, "dev/interval-calibration/remote/ci10-cost-array.sbatch")
    ),
    filesystem_root = normalizePath(source_root, mustWork = TRUE),
    output_root = normalizePath(output_root, mustWork = TRUE),
    captured_at = Sys.time()
  )
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 5L) {
    interval_stop(
      "usage: write-session-receipt.R PACKET TASK_TSV SOURCE_ROOT OUTPUT_ROOT OUTPUT_RDS"
    )
  }
  receipt <- interval_session_receipt(
    args[[1L]],
    args[[2L]],
    args[[3L]],
    args[[4L]]
  )
  interval_atomic_save_rds(receipt, args[[5L]])
  cat("INTERVAL_SESSION_RECEIPT_WROTE ", args[[5L]], "\n", sep = "")
}
