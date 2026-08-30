args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 9L) {
  stop(paste("usage: qualify.R SOURCE_CHECKOUT R_LIBRARY HARNESS_ROOT",
             "HARNESS_MANIFEST INSTALL_RECEIPT SEED_MANIFEST",
             "EXPERIMENT_PLAN SMOKE_PLAN OUTPUT_RDS"))
}
source_checkout <- normalizePath(args[[1L]], mustWork = TRUE)
r_library <- normalizePath(args[[2L]], mustWork = TRUE)
harness_root <- normalizePath(args[[3L]], mustWork = TRUE)
harness_manifest <- normalizePath(args[[4L]], mustWork = TRUE)
install_receipt_path <- normalizePath(args[[5L]], mustWork = TRUE)
seed_manifest_path <- normalizePath(args[[6L]], mustWork = TRUE)
experiment_plan_path <- normalizePath(args[[7L]], mustWork = TRUE)
smoke_plan_path <- normalizePath(args[[8L]], mustWork = TRUE)
output <- args[[9L]]
if (file.exists(output)) stop("qualification output already exists")

diagnostic_root <- file.path(harness_root, "dev", "isdm-requalification",
                             "diagnostic-rescue")
source(file.path(diagnostic_root, "record.R"), local = TRUE)
source(file.path(diagnostic_root, "contract.R"), local = TRUE)
pin <- "09eca7b1eb9018958bad367be824871161a60af1"
tree <- "fb979daa5d9a93d0804a053ff1bb00eced47ad09"
git <- function(x) system2("git", c("-C", source_checkout, x),
                           stdout = TRUE, stderr = TRUE)
if (!identical(git(c("rev-parse", "HEAD"))[[1L]], pin) ||
    !identical(git(c("rev-parse", "HEAD^{tree}"))[[1L]], tree) ||
    length(git(c("status", "--porcelain=v1")))) {
  stop("source checkout is not clean exact diagnostic compute pin")
}

old_wd <- setwd(harness_root)
manifest_check <- system2("sha256sum", c("-c", harness_manifest),
                          stdout = TRUE, stderr = TRUE)
setwd(old_wd)
if (!identical(as.integer(attr(manifest_check, "status") %||% 0L), 0L)) {
  stop("precomputed diagnostic harness manifest verification failed")
}
experiment_plan <- readRDS(experiment_plan_path)
smoke_plan <- readRDS(smoke_plan_path)
seed_manifest <- readRDS(seed_manifest_path)
isdm_diag_validate_plan(experiment_plan)
isdm_diag_validate_smoke_plan(smoke_plan)
if (!identical(experiment_plan, diagnostic_plan(seed_manifest)) ||
    !identical(smoke_plan, diagnostic_smoke_plan(seed_manifest))) {
  stop("qualified plans differ from the checksum-bound seed manifest")
}

.libPaths(c(r_library, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
package_path <- normalizePath(find.package("gllvmTMB"), mustWork = TRUE)
if (!identical(package_path, normalizePath(file.path(r_library, "gllvmTMB"),
                                            mustWork = TRUE))) {
  stop("gllvmTMB loaded outside isolated diagnostic library")
}
dlls <- getLoadedDLLs()
if (!"gllvmTMB" %in% names(dlls)) stop("gllvmTMB DLL is not loaded")
dll_path <- normalizePath(dlls[["gllvmTMB"]][["path"]], mustWork = TRUE)

installed_files <- sort(list.files(package_path, recursive = TRUE,
                                   full.names = TRUE, all.files = TRUE,
                                   no.. = TRUE))
installed_files <- installed_files[!file.info(installed_files)$isdir]
installed_hashes <- diagnostic_sha256(installed_files)
installed_manifest <- data.frame(
  path = substring(names(installed_hashes), nchar(package_path) + 2L),
  sha256 = unname(installed_hashes), stringsAsFactors = FALSE
)
install_receipt <- readRDS(install_receipt_path)
if (!is.list(install_receipt) ||
    !identical(install_receipt$schema, "isdm-diagnostic-install-receipt-v1") ||
    !identical(as.integer(install_receipt$command_status), 0L) ||
    !identical(install_receipt$post_install_status, "verified") ||
    !identical(install_receipt$source_sha, pin) ||
    !identical(install_receipt$source_tree, tree) ||
    !identical(install_receipt$package_path, package_path) ||
    !identical(install_receipt$installed_manifest_sha256,
               diagnostic_object_hash(installed_manifest)) ||
    !identical(install_receipt$installed_manifest, installed_manifest) ||
    !identical(unname(diagnostic_sha256(install_receipt$install_log_path)),
               install_receipt$install_log_sha256) ||
    !identical(install_receipt$dll_sha256,
               unname(diagnostic_sha256(dll_path)))) {
  stop("install receipt does not bind the exact source to installed bytes")
}

qualification <- list(
  schema = "isdm-diagnostic-qualification-v1",
  qualified_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  source_sha = pin, source_tree = tree,
  source_checkout = source_checkout,
  source_status = character(),
  ci_run_id = 33272534580,
  ci_url = "https://github.com/itchyshin/gllvmTMB/actions/runs/33272534580",
  ci_platforms = c(ubuntu = "success"),
  package_version = as.character(utils::packageVersion("gllvmTMB")),
  package_path = package_path,
  installed_manifest = installed_manifest,
  installed_manifest_sha256 = diagnostic_object_hash(installed_manifest),
  install_receipt_path = install_receipt_path,
  install_receipt_sha256 = unname(diagnostic_sha256(install_receipt_path)),
  dll_path = dll_path,
  dll_sha256 = unname(diagnostic_sha256(dll_path)),
  library_paths = .libPaths(),
  harness_root = harness_root,
  harness_manifest_path = harness_manifest,
  harness_manifest_sha256 = unname(diagnostic_sha256(harness_manifest)),
  harness_manifest_verified_n = length(manifest_check),
  seed_manifest_path = seed_manifest_path,
  seed_manifest_sha256 = unname(diagnostic_sha256(seed_manifest_path)),
  plan_sha256 = c(
    experiment = unname(diagnostic_sha256(experiment_plan_path)),
    smoke = unname(diagnostic_sha256(smoke_plan_path))
  ),
  session_info = capture.output(utils::sessionInfo())
)
diagnostic_atomic_save(qualification, output)
cat("DIAGNOSTIC_REMOTE_QUALIFICATION_WRITTEN\n")
