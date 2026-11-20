#!/usr/bin/env Rscript
## Design 118 B0 -- fence-ROC harness shard runner.
## docs/design/118-mspl-interval-calibration-protocol.md s5.3.
##
## One shard = a contiguous block of outer datasets for ONE cell (case_id).
## Writes exactly one CSV per shard, with a header, to
## <out>/shards/<case_id>-shard-<NNN>.csv. Per D-50 this script never runs
## under GitHub Actions and the output root is always an explicit local path
## -- there is no in-repo default.
##
## Usage:
##   Rscript run-b0-shard.R --case-id C011 --shard-id 1 \
##     --outer-per-shard 10 --out /path/outside/repo/b0-fence-roc
##
## By default the runner attaches the currently-installed `gllvmTMB`. This
## harness needs the two Design 118 s7 prerequisites (the mspl_c_n_multiplier
## probe hook and the profile bracket-search fix), which as of this commit
## are NOT in the installed site library -- set
## GLLVM_TMB_PILOT_SOURCE=true (the existing repo convention, see
## inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R) to
## devtools::load_all() this checkout instead.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x
arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}

## ---- Locate this script and the package root ------------------------
full_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", full_args, value = TRUE)
script_path <- if (length(file_arg)) {
  normalizePath(sub("^--file=", "", file_arg[[1L]]))
} else {
  normalizePath("run-b0-shard.R")
}
script_dir <- dirname(script_path)
pkg_root <- normalizePath(file.path(script_dir, "..", "..", ".."))

source(file.path(script_dir, "lib-b0-fence-roc.R"))

if (identical(Sys.getenv("GLLVM_TMB_PILOT_SOURCE"), "true")) {
  suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))
} else {
  suppressMessages(library(gllvmTMB))
}

## ---- Parse CLI ---------------------------------------------------------
case_id <- arg_value("--case-id")
shard_id <- as.integer(arg_value("--shard-id"))
outer_per_shard <- as.integer(arg_value("--outer-per-shard", "10"))
out_root <- arg_value("--out")

if (is.null(case_id) || is.na(shard_id) || is.null(out_root)) {
  stop(
    "Usage: Rscript run-b0-shard.R --case-id C011 --shard-id 1 ",
    "[--outer-per-shard 10] --out /path/outside/repo/b0-fence-roc",
    call. = FALSE
  )
}

case_row <- b0_case_row(case_id)
first_outer <- (shard_id - 1L) * outer_per_shard + 1L
last_outer <- shard_id * outer_per_shard

message(sprintf(
  "B0 shard: case=%s (link=%s, regime=%s) shard_id=%d outer=%d..%d",
  case_id, case_row$link[[1L]], case_row$regime[[1L]], shard_id, first_outer, last_outer
))

rows <- lapply(first_outer:last_outer, function(outer_id) {
  b0_run_outer(case_row, outer_id, shard_id)
})
shard <- do.call(rbind, rows)

shard_dir <- file.path(out_root, "shards")
dir.create(shard_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(shard_dir, sprintf("%s-shard-%03d.csv", case_id, shard_id))
tmp <- tempfile(".b0-fence-roc-", shard_dir, fileext = ".csv")
utils::write.csv(shard, tmp, row.names = FALSE, na = "NA")
if (!file.rename(tmp, out_path)) stop("Could not atomically publish ", out_path, call. = FALSE)

message(sprintf(
  "Wrote %d rows (%d outer datasets) to %s", nrow(shard), outer_per_shard, out_path
))
