## Freeze the runtime identity only after all four host qualifications agree.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("usage: Rscript freeze-runtime.R <qualification-plan.rds> <totoro-output> <drac-output>", call. = FALSE)
source("dev/isdm-requalification/response-information/contract.R", local = TRUE)
plan <- readRDS(args[[1L]]); isdm_respinfo_validate_qualification_plan(plan)
output_for <- function(host) if (identical(host, "totoro")) args[[2L]] else args[[3L]]
objects <- lapply(seq_len(nrow(plan)), function(i) readRDS(file.path(output_for(plan$host[[i]]), sprintf("qualification-%06d.rds", plan$qualification_id[[i]]))))
required <- c("schema", "source_sha", "source_tree", "package_path", "dll_path", "dll_sha256", "harness_manifest_path", "harness_manifest_sha256", "harness_root")
if (any(!vapply(objects, function(x) is.list(x) && identical(x$schema, "isdm-response-information-qualification-v2") && all(required %in% names(x)), logical(1L)))) stop("qualification identity is malformed", call. = FALSE)
if (length(unique(vapply(objects, `[[`, character(1L), "source_sha"))) != 1L || length(unique(vapply(objects, `[[`, character(1L), "harness_manifest_sha256"))) != 1L) stop("host qualifications do not bind one source and harness", call. = FALSE)
by_host <- split(objects, plan$host)
if (any(vapply(by_host, function(x) length(unique(vapply(x, `[[`, character(1L), "dll_sha256"))) != 1L, logical(1L)))) stop("each host must bind one DLL", call. = FALSE)
runtime <- by_host$drac[[1L]]
runtime$schema <- "isdm-response-information-runtime-identity-v1"
runtime$qualified_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
saveRDS(runtime, file.path(args[[3L]], "runtime-identity.rds"), version = 3)
cat("response information runtime identity frozen\n")
