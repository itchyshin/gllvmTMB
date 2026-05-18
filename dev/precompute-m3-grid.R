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
##
## Output:
##   dev/precomputed/m3-coverage-grid.rds (long-format)
##   dev/precomputed/m3-coverage-summary.rds (per-cell aggregate)
##
## Scope (M3.2 — Curie + Grace lead; Fisher review):
##   * Pipeline machinery + a working smoke artefact.
##   * Wald CIs only on Sigma_unit diagonals (the rotation-invariant
##     target). Profile CIs are deferred to M3.3 production run.
##   * Full 5-family x 3-d grid execution is M3.3's responsibility.

suppressPackageStartupMessages({
  library(gllvmTMB)
})

source("dev/m3-grid.R")

## ---- Argument parsing -------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
mode <- if ("--full" %in% args) "full" else
        if ("--all-fams" %in% args) "all-fams" else "smoke"

config <- switch(
  mode,
  smoke = list(
    cells = data.frame(family = "gaussian", d = c(1L, 2L, 3L),
                       stringsAsFactors = FALSE),
    n_reps = 10L,
    label  = "smoke-gaussian"
  ),
  `all-fams` = list(
    cells = expand.grid(
      family = M3_FAMILIES, d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 10L,
    label  = "smoke-all-fams"
  ),
  full = list(
    cells = expand.grid(
      family = M3_FAMILIES, d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 200L,
    label  = "full-grid"
  )
)

OUT_DIR  <- file.path("dev", "precomputed")
GRID_RDS <- file.path(OUT_DIR, "m3-coverage-grid.rds")
SUMM_RDS <- file.path(OUT_DIR, "m3-coverage-summary.rds")

if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

## ---- Run --------------------------------------------------------------

cat(sprintf("[m3] mode = %s (%d cells x %d reps)\n",
            mode, nrow(config$cells), config$n_reps))

t_start <- Sys.time()
grid_df <- m3_run_grid(
  cells      = config$cells,
  n_reps     = config$n_reps,
  seed_base  = 20260517L,
  n_units    = M3_DEFAULT_N_UNITS,
  n_traits   = M3_DEFAULT_N_TRAITS,
  parallel   = FALSE  # smoke runs serial; M3.3 enables parallel
)
t_elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

summary_df <- m3_summarise(grid_df)

cat(sprintf("[m3] total time: %.1fs (%d cells, %d reps each)\n",
            t_elapsed, nrow(config$cells), config$n_reps))
cat("[m3] per-cell summary:\n")
print(summary_df, row.names = FALSE)

## ---- Persist artefacts -----------------------------------------------

artefact <- list(
  meta = list(
    label       = config$label,
    mode        = mode,
    created_at  = format(Sys.time(), tz = "UTC", usetz = TRUE),
    gllvmTMB_ver = as.character(utils::packageVersion("gllvmTMB")),
    R_version   = R.version.string,
    elapsed_s   = t_elapsed,
    seed_base   = 20260517L,
    n_reps      = config$n_reps,
    n_cells     = nrow(config$cells)
  ),
  grid    = grid_df,
  summary = summary_df
)

saveRDS(artefact, GRID_RDS)
saveRDS(summary_df, SUMM_RDS)

cat(sprintf("[m3] saved -> %s (long-format)\n", GRID_RDS))
cat(sprintf("[m3] saved -> %s (per-cell summary)\n", SUMM_RDS))
