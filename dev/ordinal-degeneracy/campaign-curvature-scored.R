## SCORED grid runner for the frozen pre-registration:
## dev/ordinal-degeneracy/pass-criteria-curvature.md (STATUS: FROZEN
## 2026-08-17). Builds the exact 450-cell Grid table (Arm C baseline
## n_init=1, with the 140-cell Arm D subset run at n_init=5 instead) and
## writes ONE result row per cell.
##
## Reuses every functional definition (arm_c_stats(), arm_d_stats(),
## run_one_curvature(), the DGP wrappers) VERBATIM from
## campaign-curvature-pilot.R via the same parse-and-eval-named-defs
## technique that file already uses on campaign-ordinal-calibration.R and
## probe-mechanism.R -- never re-typing the frozen functional by hand, and
## never sourcing campaign-curvature-pilot.R's own --stage dispatch as a
## side effect (its `if (identical(STAGE, ...))` blocks are not `name <-`
## assignments, so the extraction technique cannot pick them up).
##
## OUTPUT PATH IS DELIBERATELY DISTINCT FROM THE QUARANTINED PILOT FILES:
##   pilot (never scored):  dev/ordinal-degeneracy/results/pilot-curvature-*.csv
##   scored (this script):  dev/ordinal-degeneracy/results/campaign-curvature-scored.csv
##
## This script does NOT compute sensitivity, false-positive rates, or any
## verdict -- per the coordinator's instruction, scoring is a separate
## reviewer's job against the frozen document.
##
## Usage (OPENBLAS_NUM_THREADS=1 is a hard constraint):
##   OPENBLAS_NUM_THREADS=1 Rscript dev/ordinal-degeneracy/campaign-curvature-scored.R --stage smoke
##   OPENBLAS_NUM_THREADS=1 Rscript dev/ordinal-degeneracy/campaign-curvature-scored.R --stage continue

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})

ARGS <- commandArgs(trailingOnly = TRUE)
stage_idx <- which(ARGS == "--stage")
STAGE <- if (length(stage_idx) == 1L && length(ARGS) > stage_idx) {
  ARGS[[stage_idx + 1L]]
} else {
  "smoke"
}
if (!STAGE %in% c("smoke", "continue")) stop("--stage must be one of: smoke, continue")

MC_CORES <- 10L  ## well inside this machine's 20 physical cores
OUTDIR <- file.path("dev", "ordinal-degeneracy", "results")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
SCORED_PATH <- file.path(OUTDIR, "campaign-curvature-scored.csv")
SMOKE_PATH  <- file.path(OUTDIR, "campaign-curvature-scored-smoke20.csv")

## ------------------------------------------------- reuse, never re-type ---
.load_named_defs <- function(path, wanted) {
  exprs <- parse(path)
  env <- new.env(parent = globalenv())
  found <- character(0)
  for (e in exprs) {
    if (
      is.call(e) && length(e) >= 2L &&
        identical(as.character(e[[1L]]), "<-") &&
        is.name(e[[2L]])
    ) {
      nm <- as.character(e[[2L]])
      if (nm %in% wanted) {
        eval(e, envir = env)
        found <- c(found, nm)
      }
    }
  }
  missing <- setdiff(wanted, found)
  if (length(missing) > 0L) {
    stop(
      path, " no longer defines: ", paste(missing, collapse = ", "),
      " -- update `wanted` or investigate before trusting this run."
    )
  }
  env
}

pilot <- .load_named_defs(
  file.path("dev", "ordinal-degeneracy", "campaign-curvature-pilot.R"),
  c(
    ".load_named_defs", "camp", "probe",
    ".fit_ordinal_ctrl", ".fit_ordinal_transport_ctrl", ".fit_ordinal_mixed_ctrl",
    "arm_c_stats", "arm_d_stats", "run_one_curvature"
  )
)
cat("Extracted", length(ls(pilot)), "definitions from campaign-curvature-pilot.R:",
    paste(ls(pilot), collapse = ", "), "\n")

## --- scoping fix, found and verified during the --stage smoke run ---
## sim_ordinal_transport()/sim_ordinal_mixed() (inside campaign-ordinal-
## calibration.R's text) reference a BARE `probe` binding that must resolve
## via R's lexical parent chain, which bottoms out at THIS session's true
## global environment -- not inside the `pilot` extraction environment
## where .load_named_defs() otherwise places it (a second layer of the same
## extraction technique that campaign-curvature-pilot.R itself uses once,
## safely, on a single layer). Without this, every `transport`/`mixed` cell
## fails with "object 'probe' not found" (confirmed: 8/8 such cells in the
## initial smoke run, 0/12 scale_* cells, which call `probe$...` directly
## from run_one_curvature's own closure and were never affected). Verified
## fix, standalone, before use here: re-binding `probe`/`camp` at true top
## level restores the SAME resolution chain campaign-curvature-pilot.R has
## when run directly via Rscript.
probe <- pilot$probe
camp  <- pilot$camp
stopifnot(exists("probe", envir = globalenv(), inherits = FALSE))
stopifnot(exists("camp", envir = globalenv(), inherits = FALSE))

## ------------------------------------------------ build the frozen grid ---
## pass-criteria-curvature.md Grid table (Arm C baseline n_init=1), with
## the Arm D subset's seed cutoffs applied as an n_init OVERRIDE on the
## SAME cells (never an additional row) -- exactly as the frozen document
## specifies: "a subset of the SAME cells, run at n_init=5 INSTEAD of
## n_init=1 -- not fit twice".
build_cells <- function() {
  mk <- function(subarm, sigma_vec, n_vec, seeds, n5_cutoff) {
    g <- expand.grid(
      subarm = subarm, sigma_lambda = sigma_vec, n = n_vec, seed = seeds,
      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    g$n_init <- ifelse(g$seed <= n5_cutoff, 5L, 1L)
    g
  }
  list(
    scale_healthy    = mk("scale_healthy",    c(0.3, 0.7),      c(100L, 400L), 1:35, 12L),
    scale_boundary   = mk("scale_boundary",   c(1.2, 2.0),      c(100L, 400L), 1:10, 0L),
    scale_degenerate = mk("scale_degenerate", c(3.0, 5.0, 8.0), c(100L, 400L), 1:20, 8L),
    transport        = mk("transport",        NA_real_,          c(100L, 400L), 1:40, 12L),
    mixed            = mk("mixed",            NA_real_,          c(100L, 400L), 1:35, 10L)
  )
}
cell_lists <- build_cells()
n_per_subarm <- vapply(cell_lists, nrow, integer(1))
cat("\nCells per sub-arm (baseline n_init=1 count):\n")
print(n_per_subarm)
stopifnot(identical(unname(n_per_subarm),
                     c(140L, 40L, 120L, 80L, 70L)))  ## matches the frozen Grid table
n_init5_per_subarm <- vapply(cell_lists, function(d) sum(d$n_init == 5L), integer(1))
cat("Cells overridden to n_init=5 per sub-arm:\n")
print(n_init5_per_subarm)
stopifnot(identical(unname(n_init5_per_subarm), c(48L, 0L, 48L, 24L, 20L)))

## Interleave (round-robin across the 5 sub-arm lists) so the "first ~20"
## cells span every sub-arm and both n_init regimes, rather than only the
## first sub-arm in a block order -- a disclosed, purpose-serving reading
## of "the first ~20 cells": the smoke check's job is to catch a sub-arm-
## specific harness bug, which a block-ordered first-20 (all one sub-arm)
## would not exercise.
interleave <- function(list_of_dfs) {
  n_lists <- length(list_of_dfs)
  max_len <- max(vapply(list_of_dfs, nrow, integer(1)))
  out <- vector("list", 0L)
  for (i in seq_len(max_len)) {
    for (j in seq_len(n_lists)) {
      d <- list_of_dfs[[j]]
      if (i <= nrow(d)) out[[length(out) + 1L]] <- d[i, , drop = FALSE]
    }
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}
all_cells <- interleave(cell_lists)
all_cells$cell_index <- seq_len(nrow(all_cells))
stopifnot(nrow(all_cells) == 450L)
cat("\nTotal cells (interleaved order):", nrow(all_cells), "\n")
cat("First 20 cells (subarm / sigma / n / seed / n_init):\n")
print(all_cells[1:20, c("cell_index", "subarm", "sigma_lambda", "n", "seed", "n_init")])

## ------------------------------------------------------------- run cells ---
run_cell_row <- function(row) {
  pilot$run_one_curvature(
    row$subarm, row$n, row$sigma_lambda, row$seed, n_init = row$n_init
  )
}

run_batch <- function(cells_df, mc.cores = MC_CORES) {
  rows <- parallel::mclapply(
    seq_len(nrow(cells_df)),
    function(i) tryCatch(
      run_cell_row(cells_df[i, , drop = FALSE]),
      error = function(e) data.frame(
        subarm = cells_df$subarm[i], n = cells_df$n[i],
        sigma_lambda = cells_df$sigma_lambda[i], seed = cells_df$seed[i],
        n_init = cells_df$n_init[i], n_obs = NA_integer_, init_jitter = NA_real_,
        seconds = NA_real_, status = "ERROR", note = paste("mclapply:", conditionMessage(e)),
        rel_frob = NA_real_, degenerate_label = NA,
        curvature_available = NA, idx_source = NA_character_, n_idx = NA_integer_,
        cond_LL = NA_real_, min_eig_raw = NA_real_, max_eig = NA_real_,
        min_eig_scaled_per_obs = NA_real_, max_loading_unit = NA_real_,
        disagreement_available = NA, n_success = NA_integer_,
        obj_spread_per_obs = NA_real_, n_modes_frac = NA_real_,
        stringsAsFactors = FALSE
      )
    ),
    mc.cores = mc.cores
  )
  out <- do.call(rbind, rows)
  out$cell_index <- cells_df$cell_index
  out
}

## ============================================================ smoke ===
if (identical(STAGE, "smoke")) {
  smoke_cells <- all_cells[1:20, , drop = FALSE]
  cat("\n=== SMOKE: first 20 (interleaved) cells, mc.cores =", MC_CORES, "===\n")
  t0 <- proc.time()[["elapsed"]]
  smoke_out <- run_batch(smoke_cells, mc.cores = MC_CORES)
  elapsed <- proc.time()[["elapsed"]] - t0
  smoke_out <- smoke_out[order(smoke_out$cell_index), ]
  write.csv(smoke_out, SMOKE_PATH, row.names = FALSE)

  cat(sprintf("\nSmoke wall-clock (mc.cores=%d): %.1fs (%.2f min)\n",
              MC_CORES, elapsed, elapsed / 60))
  cat("Rows written:", nrow(smoke_out), " -> ", SMOKE_PATH, "\n")
  print(smoke_out[, c("cell_index", "subarm", "n", "n_init", "seconds", "status")])

  cat("\n--- sanity (non-scoring) ---\n")
  cat("status counts:\n"); print(table(smoke_out$status))
  cat("subarm coverage:\n"); print(table(smoke_out$subarm))
  cat("n_init coverage:\n"); print(table(smoke_out$n_init))
  n_ok <- sum(smoke_out$status == "OK")
  finite_cols <- c("cond_LL", "min_eig_raw", "max_eig", "min_eig_scaled_per_obs")
  n_finite <- sapply(finite_cols, function(cl) sum(is.finite(smoke_out[[cl]][smoke_out$status == "OK"])))
  cat("finite counts among OK rows (out of", n_ok, "):\n"); print(n_finite)
  all_na <- all(is.na(unlist(smoke_out[smoke_out$status == "OK", finite_cols])))
  cat("ALL values NA (would indicate harness failure):", all_na, "\n")
  distinct_cond <- length(unique(round(smoke_out$cond_LL[is.finite(smoke_out$cond_LL)], 6)))
  cat("distinct finite cond_LL values (would flag all-identical harness failure):", distinct_cond, "\n")

  fit_equiv_smoke <- sum(ifelse(smoke_cells$n_init == 5L, 5L, 1L))
  cat(sprintf(
    "\nSmoke fit-equivalents: %d. Pilot-derived expectation at mc.cores=%d (linear): ~%.1fs\n",
    fit_equiv_smoke, MC_CORES,
    (sum(smoke_cells$n_init == 1L) * 1.69 + sum(smoke_cells$n_init == 5L) * 11.5) / MC_CORES
    ## using the pilot's OWN n=100 n_init=5 figure (11.5s), since this smoke batch is all n=100
  ))
  cat(sprintf("Actual smoke wall-clock: %.1fs\n", elapsed))
}

## ============================================================ continue ===
if (identical(STAGE, "continue")) {
  if (!file.exists(SMOKE_PATH)) {
    stop("No smoke file at ", SMOKE_PATH, " -- run --stage smoke first and inspect it.")
  }
  smoke_out <- read.csv(SMOKE_PATH, stringsAsFactors = FALSE)
  remaining_cells <- all_cells[!(all_cells$cell_index %in% smoke_out$cell_index), , drop = FALSE]
  cat("\n=== CONTINUE: remaining", nrow(remaining_cells), "cells, mc.cores =", MC_CORES, "===\n")
  t0 <- proc.time()[["elapsed"]]
  rest_out <- run_batch(remaining_cells, mc.cores = MC_CORES)
  elapsed <- proc.time()[["elapsed"]] - t0
  cat(sprintf("Remaining-cells wall-clock: %.1fs (%.2f min)\n", elapsed, elapsed / 60))

  full_out <- rbind(smoke_out, rest_out)
  full_out <- full_out[order(full_out$cell_index), ]
  write.csv(full_out, SCORED_PATH, row.names = FALSE)
  cat("Rows written:", nrow(full_out), " -> ", SCORED_PATH, "\n")
  cat("status counts (full grid):\n"); print(table(full_out$status))
  cat("subarm counts (full grid):\n"); print(table(full_out$subarm))
  cat("n_init counts (full grid):\n"); print(table(full_out$n_init))

  err_rows <- full_out[full_out$status != "OK", ]
  if (nrow(err_rows) > 0L) {
    cat("\n*** ERROR/non-OK rows: ***\n")
    print(err_rows[, c("cell_index", "subarm", "n", "sigma_lambda", "seed", "n_init", "status", "note")])
  } else {
    cat("\nNo ERROR rows.\n")
  }
}
