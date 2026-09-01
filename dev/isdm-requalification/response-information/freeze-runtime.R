## Freeze the runtime identity only after all four host qualifications agree.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: Rscript freeze-runtime.R <qualification-plan.rds> <qualification-output>", call. = FALSE)
source("dev/isdm-requalification/response-information/contract.R", local = TRUE)
plan <- readRDS(args[[1L]]); isdm_respinfo_validate_qualification_plan(plan)
objects <- lapply(plan$qualification_id, function(id) readRDS(file.path(args[[2L]], sprintf("qualification-%06d.rds", id))))
required <- c("schema", "source_sha", "source_tree", "package_path", "dll_path", "dll_sha256", "harness_manifest_path", "harness_manifest_sha256", "harness_root")
if (any(!vapply(objects, function(x) is.list(x) && identical(x$schema, "isdm-response-information-qualification-v2") && all(required %in% names(x)), logical(1L)))) stop("qualification identity is malformed", call. = FALSE)
bound <- c("source_sha", "dll_sha256", "harness_manifest_sha256")
if (any(vapply(bound, function(name) length(unique(vapply(objects, `[[`, character(1L), name))) != 1L, logical(1L)))) stop("host qualifications do not bind the same source, DLL, and harness", call. = FALSE)
runtime <- objects[[1L]]
runtime$schema <- "isdm-response-information-runtime-identity-v1"
runtime$qualified_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
saveRDS(runtime, file.path(args[[2L]], "runtime-identity.rds"), version = 3)
cat("response information runtime identity frozen\n")
