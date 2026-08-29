args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5L) {
  stop("usage: qualify.R SOURCE_CHECKOUT R_LIBRARY HARNESS_ROOT HARNESS_MANIFEST OUTPUT_RDS")
}
source_checkout <- normalizePath(args[[1L]], mustWork = TRUE)
r_library <- normalizePath(args[[2L]], mustWork = TRUE)
harness_root <- normalizePath(args[[3L]], mustWork = TRUE)
harness_manifest <- normalizePath(args[[4L]], mustWork = TRUE)
output <- args[[5L]]
if (file.exists(output)) stop("qualification output already exists")

source(file.path(harness_root, "record.R"), local = TRUE)
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

qualification <- list(
  schema = "isdm-diagnostic-qualification-v1",
  qualified_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  source_sha = pin, source_tree = tree,
  source_checkout = source_checkout,
  source_status = character(),
  ci_run_id = 33272534580,
  ci_url = "https://github.com/itchyshin/gllvmTMB/actions/runs/33272534580",
  ci_platforms = c(linux = "success", macos = "success", windows = "success"),
  package_version = as.character(utils::packageVersion("gllvmTMB")),
  package_path = package_path,
  installed_manifest = installed_manifest,
  installed_manifest_sha256 = diagnostic_object_hash(installed_manifest),
  dll_path = dll_path,
  dll_sha256 = unname(diagnostic_sha256(dll_path)),
  library_paths = .libPaths(),
  harness_root = harness_root,
  harness_manifest_path = harness_manifest,
  harness_manifest_sha256 = unname(diagnostic_sha256(harness_manifest)),
  harness_manifest_verified_n = length(manifest_check),
  session_info = capture.output(utils::sessionInfo())
)
diagnostic_atomic_save(qualification, output)
cat("DIAGNOSTIC_REMOTE_QUALIFICATION_WRITTEN\n")
