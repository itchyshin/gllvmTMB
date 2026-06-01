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
  link_intended = c("identity", "log", "probit", "probit"),
  link_harness = c("identity", "log", "logit", "probit"),
  stringsAsFactors = FALSE
)

## Signal axis (Design 66 locked decision): signal = between-unit
## variance share of total latent variance. 0.0 (null, for Type-I /
## coverage-under-null) / 0.2 (moderate) / 0.5 (strong).
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
## plus preliminary coverage / power numbers available so far.
##
## Returns (invisibly) a list with `$counts`, `$cells` (the per-cell
## index joined to the grid), and `$coverage` / `$power` summaries. Also
## prints a compact ASCII report. "Coverage" cells are signal > 0 (the
## primary Sigma_unit_diag coverage claim); "power/Type-I" reporting uses
## the signal = 0 null cells (coverage-under-null is the Type-I proxy --
## a full reject-rate power rule is a Phase-2 addition, Design 66 sec. 9).
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
    grid[, c("cell_id", "family_label", "d", "n_units", "signal")],
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
  ## Null cells (signal == 0): coverage-under-null = Type-I proxy.
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
      "preliminary null/Type-I proxy (signal=0, %d cells): mean coverage-under-null=%.3f\n",
      nrow(null_cells),
      mean(null_cells$coverage_primary)
    ))
  } else {
    cat("preliminary null/Type-I proxy (signal=0): <no done cells yet>\n")
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
