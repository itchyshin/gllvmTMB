## dev/m3-pilot-launch.R
## =====================
## Design 66 capstone power study -- Phase-1 PILOT launch driver.
## Implements docs/design/66-capstone-power-study.md (Phase 1, local pilot).
##
## This is a THIN, RESUMABLE driver layered on top of the validated M3
## harness in `dev/m3-grid.R`. It does NOT reimplement the DGP, the
## estimand machinery, or the coverage gate -- it reuses `m3_run_cell()`
## (the cell runner fixed for the `Sigma_unit_diag` primary target in
## PR #364) and `m3_summarise()` (the per-cell coverage aggregator).
##
## Phase split (Design 66 sec. 8, locked decisions):
##   * Phase 1 = THIS driver: local pilot at n_sim ~= 200, bounded
##     core-4 grid, free local compute while the maintainer is away.
##   * Phase 2 = core grid at n_sim = 2000 on HPC (later) -- NOT here.
##
## Public entry points:
##   pilot_grid()                      -> the enumerated core-4 pilot grid
##   run_next_pilot_batch(k, n_sim, ...) -> run the next k PENDING cells
##   pilot_status(results_dir)         -> done/pending/failed + prelim numbers
##
## Usage (from repo root, harness sourced first):
##   R -q -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-launch.R"); \
##            run_next_pilot_batch(k = 2, n_sim = 200)'
##   R -q -e 'source("dev/m3-grid.R"); source("dev/m3-pilot-launch.R"); \
##            print(pilot_status())'
##
## Resumability contract:
##   * Each completed cell writes `<results_dir>/<cell-id>.rds` (the long
##     per-replicate data.frame from `m3_run_cell()`).
##   * An index at `<results_dir>/pilot-index.rds` records, per cell:
##     status (done|failed), n_sim, wall_s, coverage_primary, and (for
##     failures) the error message. The index is the source of truth for
##     "what is already done"; if it is absent it is rebuilt from the
##     per-cell .rds files on disk.
##   * Re-running skips cells already marked done (idempotent).
##   * A cell that errors is caught, logged, marked `failed`, and skipped
##     -- it never crashes the batch (failure-tolerant). Failed cells are
##     NOT retried automatically (they stay failed in the index); delete
##     their index row / file to retry.
##
## This file is in `.Rbuildignore` (dev/) -- NOT shipped with the package.

## ---- Guard: the harness must be sourced first -------------------------

if (!exists("m3_run_cell", mode = "function")) {
  stop(
    "dev/m3-pilot-launch.R requires the M3 harness. ",
    "source(\"dev/m3-grid.R\") before this file."
  )
}

## ---- Pilot constants --------------------------------------------------

## Default local-pilot replicate count (Design 66 Phase 1: n_sim ~= 200).
PILOT_N_SIM_DEFAULT <- 200L

## Bootstrap reps per replicate for the primary Sigma_unit_diag CI.
## Kept modest for the LOCAL pilot (cost ~ n_sim * (1 + n_boot)); the
## Phase-2 HPC run raises this (Design 66 sec. 8). M3 production default
## is 25-30; the pilot uses 25.
PILOT_N_BOOT_DEFAULT <- 25L

## Nominal CI level. Design 66 locked decision: CIs at 95% nominal;
## report BOTH the 94% audit gate and the stricter 95% gate (the
## gate thresholds are applied in pilot_status(), not here).
PILOT_CI_LEVEL <- 0.95

## Default results directory (relative to repo root).
PILOT_RESULTS_DIR_DEFAULT <- "dev/m3-pilot-results"

## Index file name inside the results directory.
PILOT_INDEX_FILE <- "pilot-index.rds"

## Per-cell fixed backbone (held constant across the pilot grid so the
## varied axes are interpretable). n_traits is fixed; n_units is a grid
## axis. These mirror the M3 defaults closely.
PILOT_N_TRAITS <- 5L

## Family map: Design 66 locked "core 4" confirmatory families ->
## the family strings the M3 harness (`m3_run_cell`) actually accepts.
## NOTE (documented deviation): the harness's "binomial" path uses the
## LOGIT link in both the DGP (plogis) and the fit (stats::binomial()).
## There is no binomial(probit) path in `m3_run_cell` on origin/main.
## The locked decision names binomial(probit); for the LOCAL PILOT we
## validate the binomial coverage path via the existing logit harness
## and DEFER the one-line probit-link swap to the Phase-2 core grid
## (Design 66 sec. 4.2 already lists binomial-probit as a harness target
## to reach). This keeps the pilot a thin reuse of the validated harness
## rather than a DGP modification. The grid records the intended link in
## `link_intended` for traceability.
PILOT_CORE4 <- data.frame(
  family_label = c("gaussian", "nbinom2", "binomial_probit", "ordinal_probit"),
  harness_family = c("gaussian", "nbinom2", "binomial", "ordinal_probit"),
  evidence_family = c(
    "gaussian",
    "nbinom2",
    "binomial_logit_harness",
    "ordinal_probit"
  ),
  link_intended = c("identity", "log", "probit", "probit"),
  link_harness = c("identity", "log", "logit", "probit"),
  stringsAsFactors = FALSE
)

## Signal axis (Design 66 locked decision): signal = between-unit
## variance share of total latent variance. 0.0 is a signal-zero coverage
## diagnostic for the positive Sigma_unit_diag target, not a Type-I cell;
## 0.2 is moderate and 0.5 is strong.
PILOT_SIGNAL_LEVELS <- c(0.0, 0.2, 0.5)

## Latent rank and unit-count axes (small + large), Design 66 sec. 4.2.
PILOT_D_LEVELS <- c(1L, 2L)
PILOT_N_UNITS_LEVELS <- c(50L, 150L)

## ---- Signal -> lambda_scale mapping -----------------------------------

## The M3 DGP builds Sigma_unit = Lambda Lambda^T + diag(psi), with
## Lambda[t,k] ~ U(-1.5, 1.5) * lambda_scale and psi ~ Gamma(2, 2)
## (mean 1). The expected per-trait latent (between-unit) variance is
## E[diag(Lambda Lambda^T)] = d * lambda_scale^2 * Var(U(-1.5,1.5))
##                          = d * lambda_scale^2 * 0.75,
## and the expected unique variance is E[psi] = 1. So the between-unit
## variance SHARE is
##   share = d*0.75*lambda_scale^2 / (d*0.75*lambda_scale^2 + 1).
## Inverting for a target share s gives the lambda_scale that realizes
## the locked signal axis at each d (so the share is held constant
## across d). share = 0 -> a tiny floor (the harness rejects
## lambda_scale <= 0); at the floor Lambda Lambda^T ~= 0, so the
## between-unit latent signal is effectively absent -- the H4 null cell.
pilot_signal_to_lambda_scale <- function(signal_share, d) {
  stopifnot(length(signal_share) == 1L, length(d) == 1L, d >= 1L)
  if (!is.finite(signal_share) || signal_share < 0 || signal_share >= 1) {
    stop("signal_share must be in [0, 1).")
  }
  if (signal_share <= 0) {
    return(1e-6) # null cell: harness rejects <= 0, so use a tiny floor
  }
  sqrt((signal_share / (1 - signal_share)) / (d * 0.75))
}

## ---- The enumerated core-4 pilot grid ---------------------------------

## Build the bounded pilot grid: core-4 family x d{1,2} x n_units{50,150}
## x signal{0,0.2,0.5}. Full factorial = 4 x 2 x 2 x 3 = 48 cells. This
## is the PILOT (a few dozen cells), deliberately smaller than the full
## 192-cell core grid (Design 66 sec. 4.2). Each row is one cell with a
## stable cell_id used for the per-cell .rds filename and index key.
pilot_grid <- function() {
  g <- expand.grid(
    family_label = PILOT_CORE4$family_label,
    d = PILOT_D_LEVELS,
    n_units = PILOT_N_UNITS_LEVELS,
    signal = PILOT_SIGNAL_LEVELS,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  ## Join the harness-family / link metadata.
  g <- merge(g, PILOT_CORE4, by = "family_label", sort = FALSE)
  ## Per-cell lambda_scale realizing the target between-unit variance share.
  g$lambda_scale <- mapply(
    pilot_signal_to_lambda_scale,
    signal_share = g$signal,
    d = g$d
  )
  ## Stable, filesystem-safe cell id. ASCII only.
  g$cell_id <- sprintf(
    "%s-d%d-n%d-sig%s",
    g$family_label,
    g$d,
    g$n_units,
    sub("\\.", "p", formatC(g$signal, format = "f", digits = 1))
  )
  ## Deterministic per-cell seed base (distinct per cell to avoid seed
  ## collision across cells; the harness derives per-rep seeds from it).
  g$seed_base <- 660000L + seq_len(nrow(g))
  ## Order columns; sort by family then d then n then signal for readability.
  g <- g[
    order(g$family_label, g$d, g$n_units, g$signal),
    c(
      "cell_id",
      "family_label",
      "harness_family",
      "d",
      "n_units",
      "signal",
      "lambda_scale",
      "evidence_family",
      "link_intended",
      "link_harness",
      "seed_base"
    )
  ]
  rownames(g) <- NULL
  g
}

## ---- Index helpers ----------------------------------------------------

pilot_index_path <- function(results_dir) {
  file.path(results_dir, PILOT_INDEX_FILE)
}

## Empty index schema. One row per attempted cell.
pilot_empty_index <- function() {
  data.frame(
    cell_id = character(0),
    status = character(0), # "done" | "failed"
    n_sim = integer(0),
    n_boot = integer(0),
    wall_s = numeric(0),
    coverage_primary = numeric(0),
    primary_gate_status = character(0),
    error = character(0),
    timestamp = character(0),
    stringsAsFactors = FALSE
  )
}

## Load the index. If the index file is missing, rebuild a minimal index
## from any per-cell .rds files already on disk (so a deleted index does
## not lose resumability). Rebuilt rows are marked "done" (a written
## per-cell file means the cell completed).
pilot_load_index <- function(results_dir) {
  idx_path <- pilot_index_path(results_dir)
  if (file.exists(idx_path)) {
    idx <- readRDS(idx_path)
    ## Schema-tolerant: ensure all expected columns exist.
    empty <- pilot_empty_index()
    for (nm in names(empty)) {
      if (!nm %in% names(idx)) {
        idx[[nm]] <- empty[[nm]][rep(NA, nrow(idx))]
      }
    }
    return(idx[, names(empty), drop = FALSE])
  }
  ## Rebuild from disk.
  idx <- pilot_empty_index()
  if (!dir.exists(results_dir)) {
    return(idx)
  }
  cell_files <- list.files(
    results_dir,
    pattern = "\\.rds$",
    full.names = TRUE
  )
  cell_files <- cell_files[basename(cell_files) != PILOT_INDEX_FILE]
  for (f in cell_files) {
    cell_id <- sub("\\.rds$", "", basename(f))
    df <- tryCatch(readRDS(f), error = function(e) NULL)
    cov_p <- NA_real_
    gate <- NA_character_
    wall <- NA_real_
    nsim <- NA_integer_
    nboot <- NA_integer_
    if (!is.null(df) && is.data.frame(df) && nrow(df)) {
      s <- tryCatch(m3_summarise(df), error = function(e) NULL)
      if (!is.null(s)) {
        prim <- s[!is.na(s$coverage_primary), , drop = FALSE]
        if (nrow(prim)) {
          cov_p <- prim$coverage_primary[1]
          gate <- prim$primary_gate_status[1]
        }
        wall <- sum(s$mean_runtime_s * s$n_completed, na.rm = TRUE)
      }
      if ("rep" %in% names(df)) nsim <- length(unique(df$rep))
      if ("n_boot" %in% names(df)) {
        nb <- suppressWarnings(max(df$n_boot, na.rm = TRUE))
        if (is.finite(nb)) nboot <- as.integer(nb)
      }
    }
    idx <- rbind(idx, data.frame(
      cell_id = cell_id,
      status = "done",
      n_sim = nsim,
      n_boot = nboot,
      wall_s = wall,
      coverage_primary = cov_p,
      primary_gate_status = gate %||% NA_character_,
      error = NA_character_,
      timestamp = NA_character_,
      stringsAsFactors = FALSE
    ))
  }
  idx
}

pilot_save_index <- function(idx, results_dir) {
  if (!dir.exists(results_dir)) {
    dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  }
  saveRDS(idx, pilot_index_path(results_dir))
  invisible(idx)
}

## Upsert a single cell row into the index (replace any existing row for
## the same cell_id).
pilot_index_upsert <- function(idx, row) {
  idx <- idx[idx$cell_id != row$cell_id, , drop = FALSE]
  rbind(idx, row)
}

## ---- The resumable batch driver ---------------------------------------

## run_next_pilot_batch: run the next `k` PENDING cells of the pilot grid.
##
## A cell is PENDING if it is in `pilot_grid()` and is NOT marked "done"
## in the index. (Cells marked "failed" are treated as resolved -- they
## are skipped, not retried, so a deterministic failure does not block
## the queue forever. Delete the index row to retry.) Each cell is run via
## `m3_run_cell()` at `n_sim` reps; the long per-replicate result is
## written to `<results_dir>/<cell-id>.rds` and the index is updated and
## saved after EACH cell (so an interrupted batch still records finished
## cells). Errors in a single cell are caught and logged, never fatal.
##
## Prints a one-line ASCII progress summary on exit.
run_next_pilot_batch <- function(
  k = 2L,
  n_sim = PILOT_N_SIM_DEFAULT,
  results_dir = PILOT_RESULTS_DIR_DEFAULT,
  n_boot = PILOT_N_BOOT_DEFAULT,
  ci_level = PILOT_CI_LEVEL,
  verbose = FALSE
) {
  k <- as.integer(k)
  n_sim <- as.integer(n_sim)
  stopifnot(k >= 1L, n_sim >= 1L)

  if (!dir.exists(results_dir)) {
    dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  }

  grid <- pilot_grid()
  total <- nrow(grid)
  idx <- pilot_load_index(results_dir)

  done_ids <- idx$cell_id[idx$status == "done"]
  resolved_ids <- idx$cell_id[idx$status %in% c("done", "failed")]
  pending <- grid[!grid$cell_id %in% resolved_ids, , drop = FALSE]

  if (nrow(pending) == 0L) {
    n_done <- sum(grid$cell_id %in% done_ids)
    n_failed <- sum(grid$cell_id %in% idx$cell_id[idx$status == "failed"])
    cat(sprintf(
      "[pilot] done %d / %d; this batch: <none, all cells resolved>; failures: %d\n",
      n_done,
      total,
      n_failed
    ))
    return(invisible(idx))
  }

  batch <- utils::head(pending, k)
  batch_ids <- batch$cell_id
  batch_results <- character(0)

  for (i in seq_len(nrow(batch))) {
    cell <- batch[i, , drop = FALSE]
    cid <- cell$cell_id
    cat(sprintf(
      "[pilot] running cell %s (family=%s d=%d n=%d signal=%.1f lambda_scale=%.4f, n_sim=%d, n_boot=%d)\n",
      cid,
      cell$harness_family,
      cell$d,
      cell$n_units,
      cell$signal,
      cell$lambda_scale,
      n_sim,
      n_boot
    ))

    t0 <- Sys.time()
    res <- tryCatch(
      m3_run_cell(
        family = cell$harness_family,
        d = cell$d,
        n_reps = n_sim,
        seed_base = cell$seed_base,
        n_units = cell$n_units,
        n_traits = PILOT_N_TRAITS,
        lambda_scale = cell$lambda_scale,
        targets = "Sigma_unit_diag",
        n_boot = n_boot,
        ci_level = ci_level,
        verbose = verbose
      ),
      error = function(e) e
    )
    wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    if (inherits(res, "error")) {
      msg <- conditionMessage(res)
      ## ASCII-only sanitize of the error message for the log/index.
      msg <- iconv(msg, to = "ASCII", sub = "?")
      msg <- gsub("[\r\n]+", " ", msg)
      cat(sprintf("[pilot] FAILED cell %s after %.1fs: %s\n", cid, wall, msg))
      idx <- pilot_index_upsert(idx, data.frame(
        cell_id = cid,
        status = "failed",
        n_sim = n_sim,
        n_boot = as.integer(n_boot),
        wall_s = wall,
        coverage_primary = NA_real_,
        primary_gate_status = NA_character_,
        error = msg,
        timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
        stringsAsFactors = FALSE
      ))
      pilot_save_index(idx, results_dir)
      batch_results <- c(batch_results, paste0(cid, "[FAIL]"))
      next
    }

    ## Success: persist the long per-replicate result + summarise.
    saveRDS(res, file.path(results_dir, paste0(cid, ".rds")))
    cov_p <- NA_real_
    gate <- NA_character_
    s <- tryCatch(m3_summarise(res), error = function(e) NULL)
    if (!is.null(s)) {
      prim <- s[!is.na(s$coverage_primary), , drop = FALSE]
      if (nrow(prim)) {
        cov_p <- prim$coverage_primary[1]
        gate <- prim$primary_gate_status[1]
      }
    }
    idx <- pilot_index_upsert(idx, data.frame(
      cell_id = cid,
      status = "done",
      n_sim = n_sim,
      n_boot = as.integer(n_boot),
      wall_s = wall,
      coverage_primary = cov_p,
      primary_gate_status = gate %||% NA_character_,
      error = NA_character_,
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
      stringsAsFactors = FALSE
    ))
    pilot_save_index(idx, results_dir)
    cat(sprintf(
      "[pilot] OK cell %s in %.1fs (coverage_primary=%s)\n",
      cid,
      wall,
      ifelse(is.na(cov_p), "NA", formatC(cov_p, format = "f", digits = 3))
    ))
    batch_results <- c(batch_results, cid)
  }

  ## Final one-line progress summary (ASCII).
  n_done <- sum(grid$cell_id %in% idx$cell_id[idx$status == "done"])
  n_failed <- sum(grid$cell_id %in% idx$cell_id[idx$status == "failed"])
  failed_this <- grep("\\[FAIL\\]$", batch_results, value = TRUE)
  cat(sprintf(
    "[pilot] done %d / %d; this batch: %s; failures: %d%s\n",
    n_done,
    total,
    paste(batch_ids, collapse = ", "),
    n_failed,
    if (length(failed_this)) {
      paste0(" (", paste(failed_this, collapse = ", "), ")")
    } else {
      ""
    }
  ))

  invisible(idx)
}

## ---- Status helper ----------------------------------------------------

## pilot_status: summarize done / pending / failed across the pilot grid,
## plus preliminary coverage / zero-exclusion diagnostics available so far.
##
## Returns (invisibly) a list with `$counts`, `$cells` (the per-cell
## index joined to the grid), and `$coverage` / `$power` summaries. Also
## prints a compact ASCII report. "Coverage" cells are signal > 0 (the
## primary Sigma_unit_diag coverage claim). Signal == 0 cells are reported
## only as signal-zero coverage diagnostics because the Sigma_unit_diag target
## remains positive; they are not Type-I error or power cells.
pilot_status <- function(
  results_dir = PILOT_RESULTS_DIR_DEFAULT,
  gate_94 = 0.94,
  gate_95 = 0.95
) {
  grid <- pilot_grid()
  total <- nrow(grid)
  idx <- pilot_load_index(results_dir)

  done_ids <- idx$cell_id[idx$status == "done"]
  failed_ids <- idx$cell_id[idx$status == "failed"]
  n_done <- sum(grid$cell_id %in% done_ids)
  n_failed <- sum(grid$cell_id %in% failed_ids)
  n_pending <- total - sum(grid$cell_id %in% c(done_ids, failed_ids))

  ## Join grid <- index for the per-cell view.
  cells <- merge(
    grid[, c(
      "cell_id",
      "family_label",
      "evidence_family",
      "d",
      "n_units",
      "signal"
    )],
    idx[, c(
      "cell_id",
      "status",
      "n_sim",
      "wall_s",
      "coverage_primary",
      "primary_gate_status"
    )],
    by = "cell_id",
    all.x = TRUE
  )
  cells$status[is.na(cells$status)] <- "pending"
  ## Both-gate columns (Design 66 locked: report 94% AND 95%).
  cells$passes_94 <- ifelse(
    is.na(cells$coverage_primary),
    NA,
    cells$coverage_primary >= gate_94
  )
  cells$passes_95 <- ifelse(
    is.na(cells$coverage_primary),
    NA,
    cells$coverage_primary >= gate_95
  )
  cells <- cells[
    order(cells$family_label, cells$d, cells$n_units, cells$signal),
  ]
  rownames(cells) <- NULL

  ## Preliminary coverage (signal > 0 cells, done only).
  cov_cells <- cells[
    cells$status == "done" &
      cells$signal > 0 &
      !is.na(cells$coverage_primary),
    ,
    drop = FALSE
  ]
  ## Signal-zero cells: coverage on the positive Sigma_unit_diag target.
  null_cells <- cells[
    cells$status == "done" &
      cells$signal == 0 &
      !is.na(cells$coverage_primary),
    ,
    drop = FALSE
  ]

  ## ---- Print compact ASCII report ----
  cat("==== Design 66 Phase-1 pilot status ====\n")
  cat(sprintf("results_dir: %s\n", results_dir))
  cat(sprintf(
    "cells: done %d / %d  (pending %d, failed %d)\n",
    n_done,
    total,
    n_pending,
    n_failed
  ))
  if (n_failed > 0L) {
    fr <- idx[idx$status == "failed", c("cell_id", "error"), drop = FALSE]
    for (i in seq_len(nrow(fr))) {
      cat(sprintf(
        "  FAILED %s: %s\n",
        fr$cell_id[i],
        substr(fr$error[i] %||% "", 1L, 90L)
      ))
    }
  }
  if (nrow(cov_cells)) {
    cat(sprintf(
      "preliminary coverage (signal>0, %d cells): mean=%.3f  >=94%%: %d/%d  >=95%%: %d/%d\n",
      nrow(cov_cells),
      mean(cov_cells$coverage_primary),
      sum(cov_cells$passes_94, na.rm = TRUE),
      nrow(cov_cells),
      sum(cov_cells$passes_95, na.rm = TRUE),
      nrow(cov_cells)
    ))
  } else {
    cat("preliminary coverage (signal>0): <no done cells yet>\n")
  }
  if (nrow(null_cells)) {
    cat(sprintf(
      "preliminary signal-zero coverage diagnostic (signal=0, %d cells): mean coverage=%.3f\n",
      nrow(null_cells),
      mean(null_cells$coverage_primary)
    ))
  } else {
    cat("preliminary signal-zero coverage diagnostic (signal=0): <no done cells yet>\n")
  }

  invisible(list(
    counts = c(
      total = total,
      done = n_done,
      pending = n_pending,
      failed = n_failed
    ),
    cells = cells,
    coverage = cov_cells,
    null = null_cells
  ))
}

## ======================================================================
## ACCUMULATE MODE -- Design 66 campaign engine (cron-driven sweep)
## ======================================================================
##
## The batch driver above (run_next_pilot_batch) marks a cell DONE after
## ONE n_sim pass. The campaign engine below instead ACCUMULATES reps
## toward a target cap across MANY autonomous runs (a self-scheduling
## GitHub Actions cron, see .github/workflows/power-pilot-sweep.yaml):
## each invocation adds `n_sim_step` fresh reps to every cell that is
## still below `n_sim_cap`, COMBINES them with the cell's prior stored
## per-replicate grid, re-summarises coverage on the COMBINED grid, and
## writes back. A cell is "pending" until its accumulated reps reach the
## cap; at the cap it is skipped (idempotent resume).
##
## Determinism contract (no wall-clock / RNG seeds):
##   The per-batch seed is derived ONLY from the passed `seed_base` (in
##   GHA: the run number) and the cell's own stable `seed_base`. We NEVER
##   call Sys.time()/runif() to seed -- a given (cell, run-number) pair
##   always produces the same reps, so a re-run of the same run number is
##   reproducible. Distinct run numbers produce DISJOINT seed blocks (the
##   run number is multiplied by SEED_RUN_STRIDE, far larger than any
##   single-batch seed span), so accumulated reps never silently repeat a
##   draw.
##
## Why reps must be RE-INDEXED before rbind:
##   m3_summarise() groups replicates by the `rep` column (split on
##   sub$rep) to count completed/failed reps and per-rep runtime. Each
##   m3_run_cell() batch emits rep = 1..n_step, so two batches COLLIDE on
##   rep ids. Before combining we therefore renumber the new batch's
##   `rep` to continue above the prior maximum, making `rep` globally
##   unique within the cell's combined grid. The underlying coverage is
##   an average over trait rows (additive), and `rep_seed` already
##   disambiguates the actual RNG draw; renumbering `rep` only fixes the
##   grouping key so counts/coverage on the combined grid are correct.

## Per-batch seed stride: the run number is multiplied by this before
## being added to the cell seed_base, guaranteeing disjoint seed blocks
## across runs. m3_run_cell derives rep_seed = seed_base + 1000*d +
## 100000*family_index + r, so a single batch spans < ~1.3e6 of seed
## space (cell seed_base <= 6.6e5, plus 100000*family_index <= 5e5, plus
## 1000*d + r); a 5e6 stride leaves a wide margin so blocks never
## overlap. R seeds are 32-bit, so batch_seed_base MUST stay inside the
## signed-int range; with this stride the base stays in range for run
## numbers up to ~400 (~33 days at the 2h cadence -- well beyond the
## 1-week campaign). pilot_accum_batch_seed() folds defensively if a
## (very large) run number would ever exceed the range.
ACCUM_SEED_RUN_STRIDE <- 5000000

## Constant offset so block 0 (run number 0) starts clear of the cell
## seed_base band; keeps all seeds positive and well away from the
## non-accumulate driver's 66xxxx band.
ACCUM_SEED_BASE0 <- 700000

## Campaign defaults (Design 66 sec. 8: core grid target n_sim = 2000).
ACCUM_N_SIM_CAP_DEFAULT <- 2000L
ACCUM_N_SIM_STEP_DEFAULT <- 200L

## Overflow-safe per-batch seed base for a cell, derived ONLY from the
## passed run-level seed_base (the GHA run number) and the cell's stable
## seed_base. Computed in double precision, then coerced into the signed
## 32-bit integer range R uses for seeds. Distinct run numbers map to
## disjoint blocks (stride ACCUM_SEED_RUN_STRIDE); the cell seed_base
## separates cells within a block. Returns an integer.
pilot_accum_batch_seed <- function(run_seed_base, cell_seed_base) {
  raw <- ACCUM_SEED_BASE0 +
    as.double(run_seed_base) * ACCUM_SEED_RUN_STRIDE +
    as.double(cell_seed_base)
  imax <- .Machine$integer.max # 2147483647
  if (raw > imax || raw < -imax) {
    ## Defensive fold for pathologically large run numbers (should not
    ## happen within the campaign window). Preserves determinism.
    folded <- raw %% imax
    warning(sprintf(
      "accumulate seed base %.0f exceeds 32-bit range; folded to %.0f.",
      raw,
      folded
    ))
    raw <- folded
  }
  as.integer(raw)
}

## Count accumulated reps in a stored per-cell grid. Uses rep_seed (the
## true per-draw key) when present, else falls back to rep, else row
## count. Returns 0L for NULL / empty / malformed input.
pilot_accum_count <- function(df) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
    return(0L)
  }
  if ("rep_seed" %in% names(df)) {
    return(length(unique(df$rep_seed)))
  }
  if ("rep" %in% names(df)) {
    return(length(unique(df$rep)))
  }
  nrow(df)
}

## Re-index the `rep` column of a freshly-run batch so it continues above
## `offset` (the prior maximum rep id in the cell's stored grid). This
## keeps `rep` globally unique within the combined grid, which
## m3_summarise() relies on for its per-rep grouping.
pilot_reindex_reps <- function(df, offset) {
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0L) {
    return(df)
  }
  if (!"rep" %in% names(df) || !is.finite(offset) || offset <= 0L) {
    return(df)
  }
  ## Map the batch's own rep ids (1..n_step, possibly with gaps from
  ## failures) to a contiguous block starting at offset + 1, preserving
  ## the original ordering of distinct rep ids.
  uniq <- sort(unique(df$rep))
  remap <- stats::setNames(seq_along(uniq) + as.integer(offset), uniq)
  df$rep <- unname(remap[as.character(df$rep)])
  df
}

## Summarise a combined grid down to the single primary-target row,
## returning a small list of the fields the index stores. Fail-soft:
## any summarise error yields NA fields rather than throwing.
pilot_summarise_primary <- function(df) {
  out <- list(coverage_primary = NA_real_, primary_gate_status = NA_character_)
  s <- tryCatch(m3_summarise(df), error = function(e) NULL)
  if (is.null(s)) {
    return(out)
  }
  prim <- s[!is.na(s$coverage_primary), , drop = FALSE]
  if (nrow(prim)) {
    out$coverage_primary <- prim$coverage_primary[1]
    out$primary_gate_status <- prim$primary_gate_status[1]
  }
  out
}

## run_accumulate_pilot_batch: the campaign engine.
##
## For each TARGET cell (default: every cell in pilot_grid(); restrict via
## `cell_ids` for sharding), if its accumulated reps are below
## `n_sim_cap`, run `n_sim_step` FRESH reps (seeded from `seed_base`),
## renumber + rbind them onto the cell's prior stored grid, re-summarise
## the combined grid, and write both the grid and the index back. Cells
## already at the cap are skipped (idempotent resume). Each cell is
## wrapped in tryCatch so a single failure never aborts the sweep, and the
## index is saved after EACH cell so an interrupted run keeps its
## progress. Prior accumulated reps are preserved on a cell error.
##
## `seed_base` MUST be supplied (in GHA: the run number) -- it is the only
## source of per-batch seed variation; there is intentionally no
## wall-clock / RNG fallback.
##
## Returns (invisibly) a list with the updated `index`, a per-cell
## `report` data.frame (cell_id, action, n_before, n_after, coverage_primary,
## fail-soft error), and the run-level `fail_rate` (fraction of attempted
## cells that errored this run) for the workflow's failure-rate guard.
run_accumulate_pilot_batch <- function(
  cell_ids = NULL,
  n_sim_step = ACCUM_N_SIM_STEP_DEFAULT,
  n_sim_cap = ACCUM_N_SIM_CAP_DEFAULT,
  seed_base = NULL,
  results_dir = PILOT_RESULTS_DIR_DEFAULT,
  n_boot = PILOT_N_BOOT_DEFAULT,
  ci_level = PILOT_CI_LEVEL,
  seed_fn = pilot_accum_batch_seed,
  verbose = FALSE
) {
  ## `seed_fn(run_seed_base, cell_seed_base) -> integer` maps the run-level
  ## seed_base + the cell's stable seed_base to this batch's seed base.
  ## DEFAULT is the GHA scheme (pilot_accum_batch_seed): the GHA runner
  ## (dev/power-pilot-run.R) calls this function by name and never passes
  ## seed_fn, so the cron path is byte-identical to before this argument
  ## existed. A SECOND engine (the local continuous loop in
  ## dev/m3-pilot-local-loop.R) injects a DISJOINT seed_fn so its reps can
  ## never share an RNG draw with the GHA cron's reps -- see that file's
  ## local_accum_batch_seed() and the disjointness proof in its header.
  stopifnot(is.function(seed_fn))
  n_sim_step <- as.integer(n_sim_step)
  n_sim_cap <- as.integer(n_sim_cap)
  stopifnot(n_sim_step >= 1L, n_sim_cap >= 1L)
  if (is.null(seed_base)) {
    stop(
      "run_accumulate_pilot_batch requires `seed_base` (e.g. the GHA run ",
      "number). Seeding is deterministic -- there is no wall-clock fallback."
    )
  }
  seed_base <- as.integer(seed_base)
  if (is.na(seed_base) || seed_base < 0L) {
    stop("seed_base must be a non-negative integer.")
  }

  if (!dir.exists(results_dir)) {
    dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
  }

  grid <- pilot_grid()
  if (!is.null(cell_ids)) {
    unknown <- setdiff(cell_ids, grid$cell_id)
    if (length(unknown)) {
      stop(
        "unknown cell_ids requested: ",
        paste(utils::head(unknown, 5L), collapse = ", ")
      )
    }
    grid <- grid[grid$cell_id %in% cell_ids, , drop = FALSE]
  }
  idx <- pilot_load_index(results_dir)

  report <- data.frame(
    cell_id = character(0),
    action = character(0),
    n_before = integer(0),
    n_after = integer(0),
    coverage_primary = numeric(0),
    error = character(0),
    stringsAsFactors = FALSE
  )
  n_attempted <- 0L
  n_errored <- 0L

  for (i in seq_len(nrow(grid))) {
    cell <- grid[i, , drop = FALSE]
    cid <- cell$cell_id
    cell_path <- file.path(results_dir, paste0(cid, ".rds"))

    prior <- if (file.exists(cell_path)) {
      tryCatch(readRDS(cell_path), error = function(e) NULL)
    } else {
      NULL
    }
    n_before <- pilot_accum_count(prior)

    ## Resume / idempotent skip: at or above the cap -> leave untouched.
    if (n_before >= n_sim_cap) {
      cat(sprintf(
        "[accum] SKIP %s: at cap (n_sim=%d >= %d)\n",
        cid,
        n_before,
        n_sim_cap
      ))
      report <- rbind(report, data.frame(
        cell_id = cid,
        action = "skip_at_cap",
        n_before = n_before,
        n_after = n_before,
        coverage_primary = NA_real_,
        error = NA_character_,
        stringsAsFactors = FALSE
      ))
      next
    }

    ## Do not overshoot the cap: cap this batch's step at the remaining
    ## headroom (keeps the cap meaningful and avoids wasted compute).
    step <- min(n_sim_step, n_sim_cap - n_before)

    ## Deterministic per-batch seed block, disjoint across run numbers
    ## (overflow-safe; derived ONLY from the passed seed_base via seed_fn,
    ## which defaults to the GHA scheme pilot_accum_batch_seed).
    batch_seed_base <- seed_fn(seed_base, cell$seed_base)

    cat(sprintf(
      paste0(
        "[accum] RUN  %s: +%d reps (n_before=%d -> target %d; ",
        "family=%s d=%d n=%d signal=%.1f seed_base=%d)\n"
      ),
      cid,
      step,
      n_before,
      n_sim_cap,
      cell$harness_family,
      cell$d,
      cell$n_units,
      cell$signal,
      batch_seed_base
    ))

    n_attempted <- n_attempted + 1L
    t0 <- Sys.time()
    res <- tryCatch(
      m3_run_cell(
        family = cell$harness_family,
        d = cell$d,
        n_reps = step,
        seed_base = batch_seed_base,
        n_units = cell$n_units,
        n_traits = PILOT_N_TRAITS,
        lambda_scale = cell$lambda_scale,
        targets = "Sigma_unit_diag",
        n_boot = n_boot,
        ci_level = ci_level,
        verbose = verbose
      ),
      error = function(e) e
    )
    wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    if (inherits(res, "error")) {
      ## Fail-soft: log, record, preserve prior reps, continue.
      n_errored <- n_errored + 1L
      msg <- conditionMessage(res)
      msg <- iconv(msg, to = "ASCII", sub = "?")
      msg <- gsub("[\r\n]+", " ", msg)
      cat(sprintf("[accum] FAIL %s after %.1fs: %s\n", cid, wall, msg))
      ## Mark failed ONLY if the cell has no accumulated reps yet; a cell
      ## that already has reps stays "done"/"pending" on its prior count
      ## so a transient failure does not discard real progress.
      status <- if (n_before > 0L) {
        if (n_before >= n_sim_cap) "done" else "pending"
      } else {
        "failed"
      }
      prior_sum <- if (n_before > 0L) {
        pilot_summarise_primary(prior)
      } else {
        list(coverage_primary = NA_real_, primary_gate_status = NA_character_)
      }
      idx <- pilot_index_upsert(idx, data.frame(
        cell_id = cid,
        status = status,
        n_sim = n_before,
        n_boot = as.integer(n_boot),
        wall_s = wall,
        coverage_primary = prior_sum$coverage_primary,
        primary_gate_status = prior_sum$primary_gate_status %||% NA_character_,
        error = msg,
        timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
        stringsAsFactors = FALSE
      ))
      pilot_save_index(idx, results_dir)
      report <- rbind(report, data.frame(
        cell_id = cid,
        action = "error",
        n_before = n_before,
        n_after = n_before,
        coverage_primary = prior_sum$coverage_primary,
        error = msg,
        stringsAsFactors = FALSE
      ))
      next
    }

    ## Success: renumber the new batch's reps above the prior max, then
    ## combine with the prior stored grid.
    prior_max_rep <- if (
      !is.null(prior) && is.data.frame(prior) && "rep" %in% names(prior) &&
        nrow(prior)
    ) {
      suppressWarnings(max(prior$rep, na.rm = TRUE))
    } else {
      0L
    }
    if (!is.finite(prior_max_rep)) prior_max_rep <- 0L
    res <- pilot_reindex_reps(res, prior_max_rep)

    combined <- if (is.null(prior)) {
      res
    } else {
      ## Align columns defensively before rbind (schema drift across
      ## driver versions); intersect keeps only shared columns.
      common <- intersect(names(prior), names(res))
      rbind(prior[, common, drop = FALSE], res[, common, drop = FALSE])
    }

    saveRDS(combined, cell_path)
    n_after <- pilot_accum_count(combined)
    prim <- pilot_summarise_primary(combined)
    status <- if (n_after >= n_sim_cap) "done" else "pending"

    idx <- pilot_index_upsert(idx, data.frame(
      cell_id = cid,
      status = status,
      n_sim = n_after,
      n_boot = as.integer(n_boot),
      wall_s = wall,
      coverage_primary = prim$coverage_primary,
      primary_gate_status = prim$primary_gate_status %||% NA_character_,
      error = NA_character_,
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
      stringsAsFactors = FALSE
    ))
    pilot_save_index(idx, results_dir)
    cat(sprintf(
      "[accum] OK   %s in %.1fs: n_sim %d -> %d (%s); coverage_primary=%s\n",
      cid,
      wall,
      n_before,
      n_after,
      status,
      ifelse(
        is.na(prim$coverage_primary),
        "NA",
        formatC(prim$coverage_primary, format = "f", digits = 3)
      )
    ))
    report <- rbind(report, data.frame(
      cell_id = cid,
      action = if (status == "done") "advanced_to_cap" else "advanced",
      n_before = n_before,
      n_after = n_after,
      coverage_primary = prim$coverage_primary,
      error = NA_character_,
      stringsAsFactors = FALSE
    ))
  }

  fail_rate <- if (n_attempted > 0L) n_errored / n_attempted else 0
  rownames(report) <- NULL
  cat(sprintf(
    "[accum] run complete: %d cells attempted, %d errored (fail_rate=%.3f)\n",
    n_attempted,
    n_errored,
    fail_rate
  ))

  invisible(list(
    index = idx,
    report = report,
    n_attempted = n_attempted,
    n_errored = n_errored,
    fail_rate = fail_rate
  ))
}

## pilot_accum_status: campaign-level rollup for the accumulate mode.
## Like pilot_status() but the DONE / PENDING split is by the cap, not by
## a single pass: a cell is "complete" once its accumulated n_sim >= cap.
## Returns (invisibly) counts + the per-cell table; prints a compact
## ASCII report. Used by the workflow's auto-stop guard (all_complete)
## and the issue-#340 summary job.
pilot_accum_status <- function(
  results_dir = PILOT_RESULTS_DIR_DEFAULT,
  n_sim_cap = ACCUM_N_SIM_CAP_DEFAULT,
  gate_94 = 0.94,
  gate_95 = 0.95
) {
  grid <- pilot_grid()
  total <- nrow(grid)
  idx <- pilot_load_index(results_dir)

  cells <- merge(
    grid[, c(
      "cell_id",
      "family_label",
      "evidence_family",
      "d",
      "n_units",
      "signal"
    )],
    idx[, c(
      "cell_id",
      "status",
      "n_sim",
      "coverage_primary",
      "primary_gate_status"
    )],
    by = "cell_id",
    all.x = TRUE
  )
  cells$n_sim[is.na(cells$n_sim)] <- 0L
  cells$complete <- cells$n_sim >= n_sim_cap
  cells$passes_94 <- ifelse(
    is.na(cells$coverage_primary),
    NA,
    cells$coverage_primary >= gate_94
  )
  cells$passes_95 <- ifelse(
    is.na(cells$coverage_primary),
    NA,
    cells$coverage_primary >= gate_95
  )
  cells <- cells[
    order(cells$family_label, cells$d, cells$n_units, cells$signal),
  ]
  rownames(cells) <- NULL

  n_complete <- sum(cells$complete)
  n_started <- sum(cells$n_sim > 0L)
  reps_total <- sum(cells$n_sim)
  reps_target <- total * n_sim_cap
  all_complete <- n_complete == total

  cov_cells <- cells[
    cells$signal > 0 & !is.na(cells$coverage_primary),
    ,
    drop = FALSE
  ]
  null_cells <- cells[
    cells$signal == 0 & !is.na(cells$coverage_primary),
    ,
    drop = FALSE
  ]

  cat("==== Design 66 power-pilot ACCUMULATE status ====\n")
  cat(sprintf("results_dir: %s  (cap n_sim=%d/cell)\n", results_dir, n_sim_cap))
  cat(sprintf(
    "cells complete (>=cap): %d / %d   started: %d   ALL_COMPLETE=%s\n",
    n_complete,
    total,
    n_started,
    all_complete
  ))
  cat(sprintf(
    "reps accumulated: %d / %d  (%.1f%%)\n",
    reps_total,
    reps_target,
    100 * reps_total / max(reps_target, 1L)
  ))
  if (nrow(cov_cells)) {
    cat(sprintf(
      "coverage (signal>0, %d cells): mean=%.3f  >=94%%: %d/%d  >=95%%: %d/%d\n",
      nrow(cov_cells),
      mean(cov_cells$coverage_primary),
      sum(cov_cells$passes_94, na.rm = TRUE),
      nrow(cov_cells),
      sum(cov_cells$passes_95, na.rm = TRUE),
      nrow(cov_cells)
    ))
  } else {
    cat("coverage (signal>0): <no reps yet>\n")
  }
  if (nrow(null_cells)) {
    cat(sprintf(
      "signal-zero coverage diagnostic (signal=0, %d cells): mean coverage=%.3f\n",
      nrow(null_cells),
      mean(null_cells$coverage_primary)
    ))
  } else {
    cat("signal-zero coverage diagnostic (signal=0): <no reps yet>\n")
  }

  invisible(list(
    counts = c(
      total = total,
      complete = n_complete,
      started = n_started,
      reps_total = reps_total,
      reps_target = reps_target
    ),
    all_complete = all_complete,
    cells = cells,
    coverage = cov_cells,
    null = null_cells
  ))
}
