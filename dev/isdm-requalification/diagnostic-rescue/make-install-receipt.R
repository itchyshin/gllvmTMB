args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("usage: make-install-receipt.R SOURCE_CHECKOUT R_LIBRARY INSTALL_LOG OUTPUT_RDS")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                     value = TRUE)[[1L]])
source(file.path(dirname(normalizePath(script)), "record.R"), local = TRUE)
source_checkout <- normalizePath(args[[1L]], mustWork = TRUE)
r_library <- path.expand(args[[2L]])
install_log <- path.expand(args[[3L]])
output <- args[[4L]]
pin <- "09eca7b1eb9018958bad367be824871161a60af1"
tree <- "fb979daa5d9a93d0804a053ff1bb00eced47ad09"
git <- function(x) system2("git", c("-C", source_checkout, x),
                           stdout = TRUE, stderr = TRUE)
if (!identical(git(c("rev-parse", "HEAD"))[[1L]], pin) ||
    !identical(git(c("rev-parse", "HEAD^{tree}"))[[1L]], tree) ||
    length(git(c("status", "--porcelain=v1")))) {
  stop("install source is not the clean exact compute pin")
}
if (dir.exists(r_library) && length(list.files(r_library, all.files = TRUE,
                                               no.. = TRUE))) {
  stop("isolated install library is not empty")
}
dir.create(r_library, recursive = TRUE, showWarnings = FALSE)
r_library <- normalizePath(r_library, mustWork = TRUE)
dir.create(dirname(install_log), recursive = TRUE, showWarnings = FALSE)
install_args <- c("CMD", "INSTALL", paste0("--library=", r_library),
                  "--no-multiarch", "--preclean", source_checkout)
command_status <- system2(file.path(R.home("bin"), "R"), install_args,
                          stdout = install_log, stderr = install_log)
command_status <- as.integer(command_status %||% 0L)
if (!file.exists(install_log)) stop("R CMD INSTALL did not retain its log")
if (command_status != 0L) {
  failure <- list(
    schema = "isdm-diagnostic-install-receipt-v1",
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    command = paste(shQuote(file.path(R.home("bin"), "R")),
                    paste(shQuote(install_args), collapse = " ")),
    command_status = command_status,
    install_log_path = normalizePath(install_log, mustWork = TRUE),
    install_log_sha256 = unname(diagnostic_sha256(install_log)),
    source_sha = pin, source_tree = tree, source_status = character()
  )
  diagnostic_atomic_save(failure, output)
  stop("R CMD INSTALL failed; retained failure receipt")
}
install_log <- normalizePath(install_log, mustWork = TRUE)
.libPaths(c(r_library, .libPaths()))
post_install <- tryCatch({
  suppressPackageStartupMessages(library(gllvmTMB))
  package_path <- normalizePath(find.package("gllvmTMB"), mustWork = TRUE)
  if (!identical(package_path,
                 normalizePath(file.path(r_library, "gllvmTMB"),
                               mustWork = TRUE))) {
    stop("installed package is outside the isolated library")
  }
  dll_path <- normalizePath(getLoadedDLLs()[["gllvmTMB"]][["path"]],
                            mustWork = TRUE)
  installed_files <- sort(list.files(package_path, recursive = TRUE,
                                     full.names = TRUE, all.files = TRUE,
                                     no.. = TRUE))
  installed_files <- installed_files[!file.info(installed_files)$isdir]
  installed_manifest <- data.frame(
    path = substring(installed_files, nchar(package_path) + 2L),
    sha256 = unname(diagnostic_sha256(installed_files)),
    stringsAsFactors = FALSE
  )
  list(package_path = package_path, dll_path = dll_path,
       installed_manifest = installed_manifest)
}, error = function(e) e)
if (inherits(post_install, "condition")) {
  failure <- list(
    schema = "isdm-diagnostic-install-receipt-v1",
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    command = paste(shQuote(file.path(R.home("bin"), "R")),
                    paste(shQuote(install_args), collapse = " ")),
    command_status = command_status, post_install_status = "error",
    post_install_error_class = class(post_install),
    post_install_error_message = conditionMessage(post_install),
    install_log_path = install_log,
    install_log_sha256 = unname(diagnostic_sha256(install_log)),
    source_sha = pin, source_tree = tree, source_status = character()
  )
  diagnostic_atomic_save(failure, output)
  stop("post-install load/hash failed; retained failure receipt")
}
package_path <- post_install$package_path
dll_path <- post_install$dll_path
installed_manifest <- post_install$installed_manifest
receipt <- list(
  schema = "isdm-diagnostic-install-receipt-v1",
  created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  command = paste(shQuote(file.path(R.home("bin"), "R")),
                  paste(shQuote(install_args), collapse = " ")),
  command_status = command_status,
  post_install_status = "verified",
  install_log_path = install_log,
  install_log_sha256 = unname(diagnostic_sha256(install_log)),
  source_sha = pin, source_tree = tree, source_status = character(),
  package_path = package_path,
  installed_manifest = installed_manifest,
  installed_manifest_sha256 = diagnostic_manifest_hash(installed_manifest),
  dll_path = dll_path,
  dll_sha256 = unname(diagnostic_sha256(dll_path)),
  session_info = capture.output(utils::sessionInfo())
)
diagnostic_atomic_save(receipt, output)
cat("DIAGNOSTIC_INSTALL_RECEIPT_WRITTEN\n")
