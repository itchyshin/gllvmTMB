#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit)) default else {
    if (hit == length(args)) stop(flag, " requires a value.", call. = FALSE)
    args[[hit + 1L]]
  }
}
if (any(c("--expected-sha", "--source-archive", "--source-archive-sha",
          "--source-receipt", "--reps", "--cells", "--load-all",
          "--verify-authority-only") %in% args)) {
  stop("Caller-supplied hashes/receipts, size/cell overrides, and --load-all are forbidden in frozen v4.",
       call. = FALSE)
}

launcher_path_raw <- Sys.getenv("GLLVMTMB_V4_LAUNCHER_PATH")
launcher_parent_pid <- Sys.getenv("GLLVMTMB_V4_LAUNCH_PARENT_PID")
launcher_command_token <- Sys.getenv("GLLVMTMB_V4_LAUNCHER_COMMAND_TOKEN")
ps <- Sys.which("ps")
if (!nzchar(launcher_path_raw) || nzchar(Sys.readlink(launcher_path_raw)) ||
    !file_test("-f", launcher_path_raw) ||
    !grepl("^--file=", launcher_command_token) ||
    !grepl("^[1-9][0-9]*$", launcher_parent_pid) || !nzchar(ps)) {
  stop("V4 runner requires the live detached-launcher process boundary.",
       call. = FALSE)
}
launcher_path <- normalizePath(launcher_path_raw, mustWork = TRUE)
token_path <- sub("^--file=", "", launcher_command_token)
token_path <- gsub("~+~", " ", token_path, fixed = TRUE)
if (!identical(normalizePath(token_path, mustWork = TRUE), launcher_path)) {
  stop("V4 launcher command token does not resolve to the authenticated launcher.",
       call. = FALSE)
}
runner_file_token <- grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]
runner_script_arg <- sub("^--file=", "", runner_file_token)
runner_script_arg <- gsub("~+~", " ", runner_script_arg, fixed = TRUE)
runner_script_path <- normalizePath(runner_script_arg, mustWork = TRUE)
ps_field <- function(field, pid) {
  ans <- suppressWarnings(system2(ps,
    c("-o", field, "-p", as.character(pid)), stdout = TRUE, stderr = TRUE))
  if (!length(ans) || !is.null(attr(ans, "status"))) {
    stop("V4 runner could not inspect its detached-launcher process chain.",
         call. = FALSE)
  }
  trimws(paste(ans, collapse = " "))
}
actual_parent_pid <- ps_field("ppid=", Sys.getpid())
parent_command <- ps_field("command=", actual_parent_pid)
launcher_process_command <- parent_command
if (!identical(actual_parent_pid, launcher_parent_pid)) {
  wrapper_arguments <- strsplit(parent_command, "[[:space:]]+")[[1L]]
  wrapper_parent_pid <- ps_field("ppid=", actual_parent_pid)
  if (!identical(basename(wrapper_arguments[[1L]]), "sh") ||
      !grepl("Rscript", parent_command, fixed = TRUE) ||
      !grepl(runner_script_path, parent_command, fixed = TRUE) ||
      !identical(wrapper_parent_pid, launcher_parent_pid)) {
    stop("V4 runner found an unrecognized launcher-process intermediary.",
         call. = FALSE)
  }
  launcher_process_command <- ps_field("command=", wrapper_parent_pid)
}
launcher_arguments <- strsplit(launcher_process_command,
                               "[[:space:]]+")[[1L]]
launcher_executable <- launcher_arguments[[1L]]
launcher_file_arguments <- launcher_arguments[
  grepl("^--file=", launcher_arguments)]
launcher_uses_expression <- any(launcher_arguments %in%
  c("-e", "--expression")) ||
  any(grepl("^--expression=", launcher_arguments))
if (!identical(basename(launcher_executable), "R") ||
    launcher_uses_expression || length(launcher_file_arguments) != 1L ||
    !identical(launcher_file_arguments[[1L]], launcher_command_token)) {
  stop("V4 runner was not invoked by the authenticated detached launcher.",
       call. = FALSE)
}
script_dir <- dirname(runner_script_path)
core_dir <- normalizePath(file.path(script_dir, "../cran07-core"), mustWork = TRUE)
v3_dir <- normalizePath(file.path(script_dir, "../cran07-v3"), mustWork = TRUE)
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
suppressPackageStartupMessages(library(gllvmTMB))
for (f in c(file.path(core_dir, c("schema.R", "campaign.R", "attempt-runner.R", "batch.R")),
            file.path(v3_dir, c("campaign-v3.R", "gates-v3.R")),
            file.path(script_dir, c("campaign-v4.R", "schema-v4.R",
                                    "attempt-runner-v4.R", "gates-v4.R",
                                    "summary-v4.R")))) source(f, local = .GlobalEnv)
campaign_id <- value("--campaign")
stage <- match.arg(value("--stage"), names(CRAN07_V4_STAGE_REPS))
output <- value("--output")
manifest_path <- value("--manifest")
if (any(vapply(list(campaign_id, output, manifest_path), is.null,
                   logical(1L)))) {
  stop("Required: --campaign ID --stage smoke|pilot|production --output DIR --manifest CSV",
       call. = FALSE)
}
source_sha <- cran07_v4_verify_bound_source(repo)
authority <- cran07_v4_read_external_authority()
authority_sha <- attr(authority, "sha256")
bound_library <- normalizePath(Sys.getenv("GLLVMTMB_V4_BOUND_LIBRARY"),
                               mustWork = TRUE)
loaded_package <- normalizePath(system.file(package = "gllvmTMB"), mustWork = TRUE)
binding <- utils::read.csv(file.path(repo, CRAN07_V4_SOURCE_RECEIPT_RELPATH),
                           stringsAsFactors = FALSE)
if (!identical(Sys.getenv("GLLVMTMB_V4_BOUND_SOURCE_SHA"), source_sha) ||
    !identical(Sys.getenv("GLLVMTMB_V4_LAUNCHER_SHA"),
               binding$launcher_sha256[[1L]]) ||
    !identical(Sys.getenv("GLLVMTMB_V4_AUTHORITY_SHA"), authority_sha) ||
    !identical(cran07_sha256(launcher_path),
               binding$launcher_sha256[[1L]]) ||
    !startsWith(loaded_package, paste0(bound_library, .Platform$file.sep))) {
  stop("V4 runner was not loaded from the fresh bound-source installation.",
       call. = FALSE)
}
output_abs <- normalizePath(output, mustWork = FALSE)
if (startsWith(output_abs, paste0(repo, .Platform$file.sep))) {
  stop("Raw v4 attempts must be outside the repository.", call. = FALSE)
}
registry <- cran07_v4_read_campaign_registry(campaign_id, repo, value("--registry"))
selected <- if (stage == "production") cran07_v4_production_cells(campaign_id) else
  registry$cell_id
if (stage == "production") {
  pilot_path <- value("--pilot-gate")
  if (is.null(pilot_path)) stop("V4 production requires --pilot-gate.", call. = FALSE)
  pilot <- readRDS(pilot_path)
  if (!isTRUE(pilot$production_authorized) ||
      !identical(pilot$source_archive_sha256, source_sha)) {
    stop("Pilot did not authorize this exact source archive for production.",
         call. = FALSE)
  }
  selected <- pilot$admitted_cells$cell_id[
    pilot$admitted_cells$campaign_id == campaign_id]
  if (!length(selected) || any(selected %in% CRAN07_V4_HELD_CHALLENGE_CELLS)) {
    stop("Pilot receipt has no valid non-challenge production subset.", call. = FALSE)
  }
}
manifest <- cran07_v4_manifest(registry, campaign_id, stage, source_sha, selected)
cran07_v4_validate_manifest(manifest, registry, campaign_id, stage, source_sha,
                            selected)
dir.create(dirname(normalizePath(manifest_path, mustWork = FALSE)), recursive = TRUE,
           showWarnings = FALSE)
utils::write.csv(manifest, manifest_path, row.names = FALSE)
cran07_v4_run_manifest(registry, manifest, output_abs, stage,
  if (stage == "production") selected else NULL)
summary <- cran07_v4_summarize(output_abs, manifest, registry, campaign_id, stage,
  source_sha, if (stage == "production") pilot else NULL)
print(summary$v4_gate)
