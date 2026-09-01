## One real fresh-worker engineering qualification task; not a retained identity.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("usage: Rscript qualify.R <qualification-plan.rds> <qualification-id> <output-dir>", call. = FALSE)
plan_path <- args[[1L]]; id <- as.integer(args[[2L]]); output <- args[[3L]]
file_arg <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())])
if (length(file_arg) != 1L || !nzchar(file_arg)) stop("cannot locate qualification script", call. = FALSE)
script_dir <- dirname(normalizePath(file_arg, mustWork = TRUE)); root <- normalizePath(file.path(script_dir, "..", "..", ".."), mustWork = TRUE)
source(file.path(script_dir, "contract.R"), local = TRUE); source(file.path(script_dir, "runner.R"), local = TRUE)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
plan <- readRDS(plan_path); isdm_respinfo_validate_qualification_plan(plan); task <- plan[plan$qualification_id == id, , drop = FALSE]
if (nrow(task) != 1L) stop("qualification identity not found", call. = FALSE)
suppressPackageStartupMessages(library(gllvmTMB))
dll <- getLoadedDLLs()[["gllvmTMB"]][["path"]]
manifest <- file.path(dirname(plan_path), "HARNESS_SHA256.txt")
qualification <- list(schema = "isdm-response-information-qualification-v2", source_sha = system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE), source_tree = system2("git", c("-C", root, "status", "--porcelain"), stdout = TRUE), package_path = normalizePath(find.package("gllvmTMB"), mustWork = TRUE), dll_path = normalizePath(dll, mustWork = TRUE), dll_sha256 = .isdm_respinfo_sha256(dll), harness_manifest_path = normalizePath(manifest, mustWork = TRUE), harness_manifest_sha256 = .isdm_respinfo_sha256(manifest), harness_root = root)
if (length(qualification$source_tree)) stop("qualification source tree is dirty", call. = FALSE)
saveRDS(qualification, file.path(output, sprintf("qualification-%06d.rds", id)), version = 3)
isdm_respinfo_run_one(task, output, qualification)
cat("response information qualification passed\n")
