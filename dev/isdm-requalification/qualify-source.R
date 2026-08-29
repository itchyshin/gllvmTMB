## Qualification consumes retained CI and install receipts; it never infers
## either result and performs no network calls.

suppressPackageStartupMessages(library(gllvmTMB))
.ISDM_QUALIFICATION_DIR <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(current) && nzchar(current)) {
    dirname(normalizePath(current, mustWork = TRUE))
  } else if (file.exists("campaign.R")) {
    normalizePath(".", mustWork = TRUE)
  } else {
    normalizePath(file.path("dev", "isdm-requalification"), mustWork = TRUE)
  }
})
source(file.path(.ISDM_QUALIFICATION_DIR, "campaign.R"), local = TRUE)

isdm_installed_package_hashes <- function(package_path) {
  package_path <- normalizePath(package_path, mustWork = TRUE)
  files <- sort(list.files(package_path, recursive = TRUE, full.names = TRUE,
                           all.files = TRUE, no.. = TRUE))
  files <- files[!file.info(files)$isdir]
  if (!length(files)) stop("installed package contains no hashable files")
  hashes <- unname(isdm_sha256(files))
  names(hashes) <- substring(files, nchar(package_path) + 2L)
  hashes
}

isdm_read_qualification_receipt <- function(path, label) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path) || !file.exists(path)) {
    stop(label, " receipt must name an existing RDS file")
  }
  receipt <- tryCatch(readRDS(path), error = function(e) e)
  if (inherits(receipt, "condition") || !is.list(receipt)) {
    stop(label, " receipt is unreadable or is not a list")
  }
  receipt
}

isdm_validate_ci_receipt <- function(receipt, source_sha) {
  run_url <- receipt$run_url
  required_platforms <- c(linux = "success", macos = "success",
                          windows = "success")
  github_run <- is.character(run_url) && length(run_url) == 1L &&
    !is.na(run_url) &&
    grepl(paste0("^https?://github\\.com/[^/[:space:]]+/",
                 "[^/[:space:]]+/actions/runs/[0-9]+(/[^[:space:]]*)?$"),
          run_url)
  valid <- identical(receipt$schema, "isdm-ci-receipt-v1") &&
    identical(receipt$verified, TRUE) &&
    identical(receipt$conclusion, "success") &&
    identical(receipt$head_sha, source_sha) && github_run
  valid <- valid && identical(receipt$platform_conclusions,
                              required_platforms)
  if (!valid) {
    stop(paste(
      "CI receipt must be independently verified, successful, bound to the",
      "exact source SHA, name a GitHub Actions run URL, and record successful",
      "Linux, macOS, and Windows jobs"
    ))
  }
  invisible(TRUE)
}

isdm_validate_install_receipt <- function(receipt, identity,
                                          package_hash_fn =
                                            isdm_installed_package_hashes) {
  required <- c("schema", "source_sha", "source_tree", "package_path",
                "package_version", "package_hashes", "dll_path",
                "dll_sha256")
  if (!is.list(receipt) || !all(required %in% names(receipt)) ||
      !identical(receipt$schema, "isdm-install-receipt-v1")) {
    stop("install receipt does not satisfy isdm-install-receipt-v1")
  }
  observed_hashes <- package_hash_fn(identity$package_path)
  fields <- c("source_sha", "source_tree", "package_path", "package_version",
              "dll_path", "dll_sha256")
  fields_match <- all(vapply(fields, function(field) {
    identical(receipt[[field]], identity[[field]])
  }, logical(1L)))
  hashes_match <- is.character(receipt$package_hashes) &&
    length(receipt$package_hashes) > 0L &&
    !is.null(names(receipt$package_hashes)) &&
    identical(receipt$package_hashes, observed_hashes)
  if (!fields_match || !hashes_match) {
    stop(paste(
      "install receipt is not bound to the exact source/tree and observed",
      "installed package/DLL hashes"
    ))
  }
  invisible(observed_hashes)
}

isdm_qualify_source <- function(output_path, ci_receipt_path,
                                install_receipt_path,
                                identity_fn = isdm_source_identity,
                                origin_main_fn = function() {
                                  system2("git", c("rev-parse", "origin/main"),
                                          stdout = TRUE)[[1L]]
                                },
                                package_hash_fn =
                                  isdm_installed_package_hashes) {
  identity <- identity_fn()
  origin_main <- origin_main_fn()
  if (!identical(identity$source_sha, origin_main)) {
    stop("qualification checkout is not exact origin/main")
  }
  if (length(identity$worktree_status)) {
    stop("qualification worktree is not clean")
  }
  if (is.na(identity$package_path) || is.na(identity$dll_path) ||
      is.na(identity$dll_sha256)) {
    stop("installed package and loaded gllvmTMB DLL must be available")
  }

  ci <- isdm_read_qualification_receipt(ci_receipt_path, "CI")
  install <- isdm_read_qualification_receipt(install_receipt_path, "install")
  isdm_validate_ci_receipt(ci, identity$source_sha)
  package_hashes <- isdm_validate_install_receipt(
    install, identity, package_hash_fn = package_hash_fn
  )
  contract <- identity
  contract$schema <- "isdm-source-contract-v2"
  contract$qualified_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  contract$ci_receipt <- ci
  contract$install_receipt <- install
  contract$package_hashes <- package_hashes
  contract$ci_url <- ci$run_url
  contract$ci_conclusion <- ci$conclusion
  isdm_atomic_save(contract, output_path)
  invisible(contract)
}

isdm_qualify_source_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 3L) {
    stop(paste("usage: qualify-source.R OUTPUT_CONTRACT.rds",
               "VERIFIED_CI_RECEIPT.rds INSTALL_RECEIPT.rds"))
  }
  if (!identical(Sys.getenv("ISDM_QUALIFY", ""), "YES")) {
    stop("ISDM_QUALIFY=YES is required for source qualification")
  }
  isdm_qualify_source(args[[1L]], args[[2L]], args[[3L]])
  cat("ISDM_SOURCE_QUALIFIED\n")
}

if (sys.nframe() == 0L) isdm_qualify_source_main()
