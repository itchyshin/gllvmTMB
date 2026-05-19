## dev/precompute-m3-grid.R
## ========================
## M3.2 driver: runs the DGP grid pipeline from `dev/m3-grid.R` and
## persists the long-format coverage data + per-cell summary to
## `dev/precomputed/`.
##
## Usage (from repo root):
##   Rscript dev/precompute-m3-grid.R              # smoke (10 reps/cell, Gaussian only)
##   Rscript dev/precompute-m3-grid.R --all-fams   # smoke across all 5 families
##   Rscript dev/precompute-m3-grid.R --full       # full grid (200 reps; ~hours)
##   Rscript dev/precompute-m3-grid.R --full --family=nbinom2 --d=2 \
##     --n-reps=200 --init-strategy=single_trait_warmup
##
## Output:
##   dev/precomputed/m3-coverage-grid.rds (long-format)
##   dev/precomputed/m3-coverage-summary.rds (per-cell aggregate)
##
## Scope (M3.2/M3.3 — Curie + Grace lead; Fisher review):
##   * Pipeline machinery + a working smoke artefact.
##   * Profile CIs on per-trait psi for the production grid.
##   * Full 5-family x 3-d grid execution is dispatched by the
##     M3 production-grid GitHub Actions workflow.

suppressPackageStartupMessages({
  library(gllvmTMB)
})

source("dev/m3-grid.R")

## ---- Argument parsing -------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
mode <- if ("--full" %in% args) {
  "full"
} else if ("--all-fams" %in% args) {
  "all-fams"
} else {
  "smoke"
}

arg_value <- function(name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

split_arg <- function(x) {
  if (is.null(x) || !nzchar(x)) {
    return(NULL)
  }
  strsplit(x, ",", fixed = TRUE)[[1L]]
}

config <- switch(
  mode,
  smoke = list(
    cells = data.frame(
      family = "gaussian",
      d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 10L,
    label = "smoke-gaussian"
  ),
  `all-fams` = list(
    ## All 5 families × 3 dims = 15 cells.
    ## Mixed-family integration uses the M1 fixture pattern: per-row
    ## `family_id` column + `attr(family_list, 'family_var')` lookup.
    cells = expand.grid(
      family = M3_FAMILIES,
      d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 10L,
    label = "smoke-all-fams"
  ),
  full = list(
    cells = expand.grid(
      family = M3_FAMILIES,
      d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 200L,
    label = "full-grid"
  )
)

family_filter <- split_arg(arg_value("--family"))
d_filter <- split_arg(arg_value("--d"))
if (!is.null(family_filter)) {
  unknown <- setdiff(family_filter, M3_FAMILIES)
  if (length(unknown)) {
    stop("Unknown --family value(s): ", paste(unknown, collapse = ", "))
  }
  config$cells <- config$cells[
    config$cells$family %in% family_filter,
    ,
    drop = FALSE
  ]
}
if (!is.null(d_filter)) {
  d_filter <- as.integer(d_filter)
  if (anyNA(d_filter) || any(!d_filter %in% c(1L, 2L, 3L))) {
    stop("--d must contain one or more of 1, 2, 3")
  }
  config$cells <- config$cells[config$cells$d %in% d_filter, , drop = FALSE]
}
if (!nrow(config$cells)) {
  stop("No M3 cells selected")
}

n_reps_override <- arg_value("--n-reps")
if (!is.null(n_reps_override)) {
  config$n_reps <- as.integer(n_reps_override)
  if (is.na(config$n_reps) || config$n_reps < 1L) {
    stop("--n-reps must be a positive integer")
  }
}

init_strategy <- match.arg(
  arg_value("--init-strategy", "default"),
  c("default", "single_trait_warmup")
)

OUT_DIR <- arg_value("--out-dir", file.path("dev", "precomputed"))
out_prefix <- arg_value("--out-prefix", "m3-coverage")
GRID_RDS <- file.path(OUT_DIR, paste0(out_prefix, "-grid.rds"))
SUMM_RDS <- file.path(OUT_DIR, paste0(out_prefix, "-summary.rds"))

if (!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}

## ---- Run --------------------------------------------------------------

cat(sprintf(
  "[m3] mode = %s (%d cells x %d reps; init_strategy = %s)\n",
  mode,
  nrow(config$cells),
  config$n_reps,
  init_strategy
))

t_start <- Sys.time()
grid_df <- m3_run_grid(
  cells = config$cells,
  n_reps = config$n_reps,
  seed_base = 20260517L,
  n_units = M3_DEFAULT_N_UNITS,
  n_traits = M3_DEFAULT_N_TRAITS,
  init_strategy = init_strategy,
  parallel = FALSE # workflow matrix parallelises cells
)
t_elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

summary_df <- m3_summarise(grid_df)

cat(sprintf(
  "[m3] total time: %.1fs (%d cells, %d reps each)\n",
  t_elapsed,
  nrow(config$cells),
  config$n_reps
))
cat("[m3] per-cell summary:\n")
print(summary_df, row.names = FALSE)

## ---- Persist artefacts -----------------------------------------------

artefact <- list(
  meta = list(
    label = config$label,
    mode = mode,
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    gllvmTMB_ver = as.character(utils::packageVersion("gllvmTMB")),
    R_version = R.version.string,
    elapsed_s = t_elapsed,
    seed_base = 20260517L,
    n_reps = config$n_reps,
    n_cells = nrow(config$cells),
    init_strategy = init_strategy
  ),
  grid = grid_df,
  summary = summary_df
)

saveRDS(artefact, GRID_RDS)
saveRDS(summary_df, SUMM_RDS)

cat(sprintf("[m3] saved -> %s (long-format)\n", GRID_RDS))
cat(sprintf("[m3] saved -> %s (per-cell summary)\n", SUMM_RDS))
