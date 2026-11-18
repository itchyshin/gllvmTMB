suppressPackageStartupMessages(library(gllvmTMB))
.ISDM_VERIFY_DIR <- local({
  current <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(current) && nzchar(current)) {
    dirname(normalizePath(current, mustWork = TRUE))
  } else if (file.exists("campaign.R")) {
    normalizePath(".", mustWork = TRUE)
  } else {
    normalizePath(file.path("dev", "isdm-requalification"), mustWork = TRUE)
  }
})
source(file.path(.ISDM_VERIFY_DIR, "campaign.R"), local = TRUE)
source(file.path(.ISDM_VERIFY_DIR, "qualify-source.R"), local = TRUE)

isdm_verify_source_contract <- function(path,
                                        identity_fn = isdm_source_identity,
                                        origin_main_fn = function() {
                                          system2("git", c("rev-parse",
                                                           "origin/main"),
                                                  stdout = TRUE)[[1L]]
                                        },
                                        package_hash_fn =
                                          isdm_installed_package_hashes) {
  expected <- isdm_read_qualification_receipt(path, "source contract")
  observed <- identity_fn()
  if (!identical(expected$schema, "isdm-source-contract-v2")) {
    stop("source contract does not satisfy isdm-source-contract-v2")
  }
  isdm_validate_ci_receipt(expected$ci_receipt, expected$source_sha)
  isdm_validate_install_receipt(expected$install_receipt, observed,
                                package_hash_fn = package_hash_fn)
  if (!identical(expected$package_hashes,
                 package_hash_fn(observed$package_path))) {
    stop("installed package hashes differ from the qualified contract")
  }
  if (!isdm_identity_matches(observed, expected)) {
    stop("current source/package/DLL identity differs from the qualified contract")
  }
  origin_main <- origin_main_fn()
  if (!identical(observed$source_sha, origin_main) ||
      length(observed$worktree_status)) {
    stop("verified source must remain clean exact origin/main")
  }
  invisible(expected)
}

isdm_verify_source_contract_main <- function() {
  path <- Sys.getenv("ISDM_SOURCE_CONTRACT_RDS", "")
  if (!nzchar(path) || !file.exists(path)) {
    stop("ISDM_SOURCE_CONTRACT_RDS must name the retained source contract")
  }
  isdm_verify_source_contract(path)
  cat("ISDM_SOURCE_CONTRACT_VERIFIED\n")
}

if (sys.nframe() == 0L) isdm_verify_source_contract_main()
