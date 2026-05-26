## dev/aggregate-m3-shards.R
## =========================
## Combine M3 shard artefacts from dev/precompute-m3-grid.R back into
## the existing single-cell grid + summary RDS format.
##
## Usage (from repo root):
##   Rscript dev/aggregate-m3-shards.R \
##     --input-dir=dev/precomputed \
##     --input-prefix=m3-coverage-binomial-d2 \
##     --out-prefix=m3-coverage-binomial-d2

suppressPackageStartupMessages({
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(".", quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
})

source("dev/m3-grid.R")

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

input_dir <- arg_value("--input-dir", file.path("dev", "precomputed"))
input_prefix <- arg_value("--input-prefix")
if (is.null(input_prefix) || !nzchar(input_prefix)) {
  stop("--input-prefix is required")
}
out_dir <- arg_value("--out-dir", input_dir)
out_prefix <- arg_value("--out-prefix", input_prefix)

if (!dir.exists(input_dir)) {
  stop("Input directory does not exist: ", input_dir)
}
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

grid_files <- list.files(
  input_dir,
  pattern = "-shard[0-9]+-grid[.]rds$",
  recursive = TRUE,
  full.names = TRUE
)
grid_files <- grid_files[startsWith(
  basename(grid_files),
  paste0(input_prefix, "-")
)]
grid_files <- sort(grid_files)
if (!length(grid_files)) {
  stop("No shard grid artefacts found for prefix: ", input_prefix)
}

artefacts <- lapply(grid_files, readRDS)
grid_list <- lapply(seq_along(artefacts), function(i) {
  artefact <- artefacts[[i]]
  if (is.data.frame(artefact)) {
    return(artefact)
  }
  if (!is.list(artefact) || !is.data.frame(artefact$grid)) {
    stop("Shard artefact lacks a data-frame `grid`: ", grid_files[[i]])
  }
  artefact$grid
})

grid_df <- do.call(rbind, grid_list)
rownames(grid_df) <- NULL

key_cols <- intersect(
  c(
    "cell",
    "family",
    "d",
    "rep",
    "trait_id",
    "target",
    "ci_method",
    "fit_phi_mode"
  ),
  names(grid_df)
)
if (length(key_cols) >= 4L) {
  duplicated_rows <- duplicated(grid_df[key_cols])
  if (any(duplicated_rows)) {
    dup <- grid_df[duplicated_rows, key_cols, drop = FALSE]
    stop(
      "Duplicate shard rows detected; first duplicate key: ",
      paste(dup[1, , drop = TRUE], collapse = " / ")
    )
  }
}

summary_df <- m3_summarise(grid_df)

meta_list <- lapply(artefacts, function(artefact) {
  if (is.list(artefact) && !is.null(artefact$meta)) {
    artefact$meta
  } else {
    NULL
  }
})
shards <- vapply(
  meta_list,
  function(meta) {
    if (is.null(meta$shard)) NA_integer_ else as.integer(meta$shard)
  },
  integer(1)
)
rep_indices <- sort(unique(grid_df$rep))

aggregate <- list(
  meta = list(
    label = "m3-shard-aggregate",
    mode = "aggregate",
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    input_dir = input_dir,
    input_prefix = input_prefix,
    input_files = basename(grid_files),
    n_shards = length(grid_files),
    shard_ids = shards,
    rep_index_start = min(rep_indices),
    rep_index_end = max(rep_indices),
    n_reps = length(rep_indices),
    source_meta = meta_list
  ),
  grid = grid_df,
  summary = summary_df
)

GRID_RDS <- file.path(out_dir, paste0(out_prefix, "-grid.rds"))
SUMM_RDS <- file.path(out_dir, paste0(out_prefix, "-summary.rds"))

saveRDS(aggregate, GRID_RDS)
saveRDS(summary_df, SUMM_RDS)

cat(sprintf(
  "[m3-aggregate] read %d shard grid artefacts\n",
  length(grid_files)
))
cat(sprintf(
  "[m3-aggregate] reps %d-%d (%d unique global reps)\n",
  min(rep_indices),
  max(rep_indices),
  length(rep_indices)
))
cat(sprintf("[m3-aggregate] saved -> %s (aggregate grid)\n", GRID_RDS))
cat(sprintf("[m3-aggregate] saved -> %s (aggregate summary)\n", SUMM_RDS))
