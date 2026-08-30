args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L || !args[[3L]] %in% c("smoke", "experiment")) {
  stop("usage: launch-preflight.R PLAN_RDS QUALIFICATION_RDS smoke|experiment OUTPUT_RDS")
}
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE),
                                     value = TRUE)[[1L]])
root <- dirname(normalizePath(script))
source(file.path(root, "record.R"), local = TRUE)
source(file.path(root, "contract.R"), local = TRUE)
plan_path <- normalizePath(args[[1L]], mustWork = TRUE)
qualification_path <- normalizePath(args[[2L]], mustWork = TRUE)
run_kind <- args[[3L]]
output <- args[[4L]]
plan <- readRDS(plan_path)
qualification <- readRDS(qualification_path)
if (identical(run_kind, "experiment")) isdm_diag_validate_plan(plan) else
  isdm_diag_validate_smoke_plan(plan)
if (!identical(unname(diagnostic_sha256(plan_path)),
               qualification$plan_sha256[[run_kind]])) {
  stop("launch plan hash differs from qualification")
}
if (!identical(unname(diagnostic_sha256(qualification$harness_manifest_path)),
               qualification$harness_manifest_sha256)) {
  stop("launch harness manifest differs from qualification")
}
old_wd <- setwd(qualification$harness_root)
on.exit(setwd(old_wd), add = TRUE)
checked <- system2("sha256sum", c("-c", qualification$harness_manifest_path),
                   stdout = TRUE, stderr = TRUE)
if (!identical(as.integer(attr(checked, "status") %||% 0L), 0L)) {
  stop("launch harness bytes differ from qualification")
}
package_path <- normalizePath(qualification$package_path, mustWork = TRUE)
installed_files <- sort(list.files(package_path, recursive = TRUE,
                                   full.names = TRUE, all.files = TRUE,
                                   no.. = TRUE))
installed_files <- installed_files[!file.info(installed_files)$isdir]
installed_manifest <- data.frame(
  path = substring(installed_files, nchar(package_path) + 2L),
  sha256 = unname(diagnostic_sha256(installed_files)),
  stringsAsFactors = FALSE
)
if (!identical(diagnostic_object_hash(installed_manifest),
               qualification$installed_manifest_sha256)) {
  stop("installed package bytes differ from qualification")
}
command_n <- if (identical(run_kind, "smoke")) 2L else 28L
receipt <- list(
  schema = "isdm-diagnostic-launch-start-v1",
  created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  run_kind = run_kind, planned = nrow(plan), commands = command_n,
  plan_sha256 = unname(diagnostic_sha256(plan_path)),
  qualification_sha256 = unname(diagnostic_sha256(qualification_path)),
  seed_manifest_sha256 = qualification$seed_manifest_sha256,
  harness_manifest_sha256 = qualification$harness_manifest_sha256,
  installed_manifest_sha256 = qualification$installed_manifest_sha256
)
if (!identical(output, "-")) diagnostic_atomic_save(receipt, output)
cat("DIAGNOSTIC_LAUNCH_PREFLIGHT_VERIFIED\n")
