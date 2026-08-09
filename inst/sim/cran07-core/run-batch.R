#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if ("--expected-sha" %in% args) {
  stop("--expected-sha is forbidden; the frozen hash is compiled from --campaign.",
       call. = FALSE)
}
value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit)) default else args[[hit + 1L]]
}
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
if ("--load-all" %in% args) devtools::load_all(repo, quiet = TRUE) else
  suppressPackageStartupMessages(library(gllvmTMB))
source(file.path(script_dir, "schema.R"), local = .GlobalEnv)
source(file.path(script_dir, "campaign.R"), local = .GlobalEnv)
source(file.path(script_dir, "attempt-runner.R"), local = .GlobalEnv)
source(file.path(script_dir, "batch.R"), local = .GlobalEnv)
campaign_id <- value("--campaign", "cran07-core-recovery-v2")
registry_path <- value("--registry")
output <- value("--output")
if (is.null(output)) stop("--output is required and should point outside the repository.", call. = FALSE)
output_abs <- normalizePath(output, mustWork = FALSE)
if (startsWith(output_abs, paste0(repo, .Platform$file.sep))) {
  stop("Raw attempt output must be outside the repository (for example, under /tmp).",
       call. = FALSE)
}
registry <- cran07_read_campaign_registry(campaign_id, repo, registry_path)
cells <- value("--cells")
if (!is.null(cells)) cells <- strsplit(cells, ",", fixed = TRUE)[[1L]]
reps <- value("--reps")
manifest_in <- value("--manifest-in")
manifest <- if (!is.null(manifest_in)) utils::read.csv(manifest_in, stringsAsFactors = FALSE) else
  cran07_manifest(registry, value("--stage", "smoke"),
    if (is.null(reps)) NULL else as.integer(reps), cells, campaign_id, attr(registry, "sha256"))
required_manifest <- c("campaign_id", "registry_sha256", "cell_number", "cell_id", "replicate", "seed")
if (!all(required_manifest %in% names(manifest)) ||
    any(manifest$campaign_id != campaign_id) ||
    any(manifest$registry_sha256 != attr(registry, "sha256")) ||
    any(!manifest$cell_id %in% registry$cell_id) ||
    anyNA(manifest$replicate) || any(manifest$replicate < 1L) ||
    anyDuplicated(paste(manifest$campaign_id, manifest$cell_id, manifest$replicate))) {
  stop("Manifest does not match the selected frozen registry.", call. = FALSE)
}
manifest_path <- value("--manifest")
if (!is.null(manifest_path)) utils::write.csv(manifest, manifest_path, row.names = FALSE)
cran07_run_manifest(registry, manifest, output)
summary <- cran07_summarize(output, manifest)
print(table(summary$attempts$cell_id, summary$attempts$status))
if (length(summary$missing_attempt_keys)) stop("Manifest remains incomplete.", call. = FALSE)
