#!/usr/bin/env Rscript
## Design 118 B1 -- calibration-campaign harness shard runner.
## docs/design/118-mspl-interval-calibration-protocol.md s5; fence line 2 is
## F-AMD per docs/dev-log/2026-08-15-b1-launch-spec.md (DEV-3).
##
## One shard = a contiguous block of outer datasets for ONE cell. Writes
## exactly one CSV per shard, with a header, to
## <out>/shards/<cell_id>-shard-<NNN>.csv. Per D-50 this script never runs
## under GitHub Actions and the output root is always an explicit local
## path -- there is no in-repo default.
##
## Usage (two equivalent ways to identify a shard):
##   Rscript run-b1-shard.R --cell-id B001 --shard-id 1 \
##     --outer-per-shard 10 --out /path/outside/repo/b1-calibration
##   Rscript run-b1-shard.R --task-id 1 \
##     --outer-per-shard 10 --out /path/outside/repo/b1-calibration
##
## --print-map prints the full task-id -> (cell_id, shard_id) mapping as
## TSV to stdout and exits -- the orchestrator uses this to size
## `sbatch --array=1-N` (N = number of rows) before launching sbatch-b1.sh.
##
## By default the runner attaches the currently-installed `gllvmTMB`. This
## harness needs the Design 118 s7 prerequisites (mspl_c_n_multiplier probe
## hook, profile bracket-search fix), which as of this commit are NOT in the
## installed site library -- set GLLVM_TMB_PILOT_SOURCE=true (the existing
## repo convention) to devtools::load_all() this checkout instead.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")

args <- commandArgs(trailingOnly = FALSE)
cli_args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x
arg_value <- function(name, default = NULL) {
  hit <- match(name, cli_args)
  if (is.na(hit)) return(default)
  if (hit == length(cli_args)) stop("Missing value for ", name, call. = FALSE)
  cli_args[[hit + 1L]]
}
arg_flag <- function(name) name %in% cli_args

## ---- Locate this script and the package root ------------------------
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) {
  normalizePath(sub("^--file=", "", file_arg[[1L]]))
} else {
  normalizePath("run-b1-shard.R")
}
script_dir <- dirname(script_path)
pkg_root <- normalizePath(file.path(script_dir, "..", "..", ".."))

## Load order matters: B1's library reuses B0's functions directly.
source(file.path(script_dir, "..", "b0-fence-roc", "lib-b0-fence-roc.R"))
source(file.path(script_dir, "lib-b1-calibration.R"))

if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) {
  suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))
} else {
  suppressMessages(library(gllvmTMB))
}

## ---- --print-map: mapping table only, no fitting ------------------------
outer_per_shard <- as.integer(arg_value("--outer-per-shard", "10"))
reps <- as.integer(arg_value("--reps", "600"))

if (arg_flag("--print-map")) {
  m <- b1_task_map(outer_per_shard = outer_per_shard, reps = reps)
  utils::write.table(m, stdout(), sep = "\t", row.names = FALSE, quote = FALSE)
  quit(save = "no", status = 0L)
}

## ---- Parse CLI: --task-id, OR --cell-id/--cell-index + --shard-id -------
task_id <- arg_value("--task-id")
cell_id <- arg_value("--cell-id")
cell_index <- arg_value("--cell-index")
shard_id <- arg_value("--shard-id")
bootstrap_reps <- as.integer(arg_value("--bootstrap-reps", "500"))
out_root <- arg_value("--out")

if (is.null(out_root)) {
  stop(
    "Usage: Rscript run-b1-shard.R (--task-id N | --cell-id BNNN --shard-id N) ",
    "[--outer-per-shard 10] [--reps 600] [--bootstrap-reps 500] ",
    "--out /path/outside/repo/b1-calibration",
    call. = FALSE
  )
}

grid <- b1_grid()
if (!is.null(task_id)) {
  hit <- b1_task_lookup(as.integer(task_id), outer_per_shard = outer_per_shard, reps = reps, grid = grid)
  cell_id <- hit$cell_id[[1L]]
  shard_id <- hit$shard_id[[1L]]
} else if (!is.null(cell_id) || !is.null(cell_index)) {
  if (is.null(shard_id)) stop("--shard-id is required with --cell-id/--cell-index.", call. = FALSE)
  if (is.null(cell_id)) cell_id <- grid$cell_id[grid$cell_index == as.integer(cell_index)]
  shard_id <- as.integer(shard_id)
} else {
  stop("Provide either --task-id, or --cell-id/--cell-index with --shard-id.", call. = FALSE)
}

row <- b1_cell_row(cell_id, grid = grid)
first_outer <- (as.integer(shard_id) - 1L) * outer_per_shard + 1L
last_outer <- as.integer(shard_id) * outer_per_shard

message(sprintf(
  "B1 shard: cell=%s (block=%s, split=%s, link=%s, pi=%.2f, n_site=%d, n_trait=%d, q=%d) shard_id=%s outer=%d..%d",
  cell_id, row$block[[1L]], row$split[[1L]], row$link[[1L]], row$pi_target[[1L]],
  row$n_site[[1L]], row$n_trait[[1L]], row$q[[1L]], shard_id, first_outer, last_outer
))

rows <- lapply(first_outer:last_outer, function(outer_id) {
  b1_run_outer(row, outer_id, shard_id, bootstrap_reps = bootstrap_reps)
})
shard <- do.call(rbind, rows)

shard_dir <- file.path(out_root, "shards")
dir.create(shard_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(shard_dir, sprintf("%s-shard-%03d.csv", cell_id, as.integer(shard_id)))
tmp <- tempfile(".b1-calibration-", shard_dir, fileext = ".csv")
utils::write.csv(shard, tmp, row.names = FALSE, na = "NA")
if (!file.rename(tmp, out_path)) stop("Could not atomically publish ", out_path, call. = FALSE)

message(sprintf(
  "Wrote %d rows (%d outer datasets) to %s", nrow(shard), length(first_outer:last_outer), out_path
))
