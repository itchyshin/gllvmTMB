#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
value <- function(flag, default = NULL) {
  hit <- match(flag, args)
  if (is.na(hit)) default else {
    if (hit == length(args)) stop(flag, " requires a value.", call. = FALSE)
    args[[hit + 1L]]
  }
}
if ("--expected-sha" %in% args || "--reps" %in% args) {
  stop("--expected-sha and --reps are forbidden; v3 identity and stage sizes are frozen.",
       call. = FALSE)
}
script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
script_dir <- dirname(normalizePath(script_arg, mustWork = TRUE))
core_dir <- normalizePath(file.path(script_dir, "../cran07-core"), mustWork = TRUE)
repo <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
if ("--load-all" %in% args) devtools::load_all(repo, quiet = TRUE) else
  suppressPackageStartupMessages(library(gllvmTMB))
source(file.path(core_dir, "schema.R"), local = .GlobalEnv)
source(file.path(core_dir, "campaign.R"), local = .GlobalEnv)
source(file.path(core_dir, "attempt-runner.R"), local = .GlobalEnv)
source(file.path(core_dir, "batch.R"), local = .GlobalEnv)
source(file.path(script_dir, "campaign-v3.R"), local = .GlobalEnv)
source(file.path(script_dir, "gates-v3.R"), local = .GlobalEnv)

campaign_id <- value("--campaign")
stage <- value("--stage")
output <- value("--output")
manifest_path <- value("--manifest")
if (is.null(campaign_id) || is.null(stage) || is.null(output) ||
    is.null(manifest_path)) {
  stop("Required: --campaign V3_ID --stage pilot|production --output DIR --manifest CSV",
       call. = FALSE)
}
stage <- match.arg(stage, c("pilot", "production"))
output_abs <- normalizePath(output, mustWork = FALSE)
manifest_abs <- normalizePath(manifest_path, mustWork = FALSE)
if (startsWith(output_abs, paste0(repo, .Platform$file.sep))) {
  stop("Raw attempt output must be outside the repository.", call. = FALSE)
}
registry <- cran07_v3_read_campaign_registry(campaign_id, repo, value("--registry"))
cells_arg <- value("--cells")
cells <- if (is.null(cells_arg)) NULL else strsplit(cells_arg, ",", fixed = TRUE)[[1L]]
if (stage == "pilot" && !is.null(cells)) {
  stop("V3 pilot must include every canonical registry cell.", call. = FALSE)
}
if (stage == "production" && is.null(cells)) {
  stop("V3 production requires the explicitly admitted --cells list.", call. = FALSE)
}
selected <- if (stage == "pilot") registry$cell_id else cells
reps <- if (stage == "pilot") CRAN07_V3_PILOT_REPS else CRAN07_V3_PRODUCTION_REPS
manifest <- cran07_manifest(registry, stage = "production", reps = reps,
  cells = selected, campaign_id = campaign_id,
  registry_sha256 = attr(registry, "sha256"))
cran07_v3_validate_manifest(manifest, registry, campaign_id, stage, selected)
dir.create(dirname(manifest_abs), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(manifest, manifest_abs, row.names = FALSE)
cran07_run_manifest(registry, manifest, output_abs)
summary <- cran07_v3_summary(output_abs, manifest, registry, campaign_id, stage,
                             if (stage == "production") selected else NULL)
print(summary$v3_gate)
if (!isTRUE(summary$v3_identity$complete)) stop("V3 output remains incomplete.", call. = FALSE)

