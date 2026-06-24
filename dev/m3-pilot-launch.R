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
##     failures) the error message. The index is the local resume cache
##     for "what is already done"; if it is absent it is rebuilt from the
##     per-cell .rds files on disk. In the sharded workflow, per-cell
##     grids plus per-shard manifests are the audit trail and the index
##     is rebuilt as a derived cache by the single-writer persist job.
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

## Per-run manifest directory inside the results directory. Each shard writes
## one CSV here; the persist job merges + validates them before rebuilding the
## derived index.
PILOT_MANIFEST_DIR <- "_manifests"

## Planned immutable chunk output root. Current GitHub accumulation still writes
## per-cell stores, but DRAC preflight uses this path to prove that future array
## tasks can write one chunk per (campaign, cell, chunk) without shared files.
PILOT_CHUNK_DIR <- "_chunks"

## Derived per-cell aggregate output root for immutable chunk campaigns.
## Aggregates are rebuilt from validated chunks; they are never written by
## concurrent array tasks.
PILOT_CHUNK_AGGREGATE_DIR <- "_chunk-aggregate"

## Per-cell fixed backbone (held constant across the pilot grid so the
## varied axes are interpretable). n_traits is fixed; n_units is a grid
## axis. These mirror the M3 defaults closely.
PILOT_N_TRAITS <- 5L

## Family map: Design 66 locked "core 4" confirmatory families ->
## the family strings the M3 harness (`m3_run_cell`) actually accepts.
## `binomial_probit` is a harness family here: the DGP uses pnorm() and
## the fit uses stats::binomial(link = "probit"). The older local pilot
## used the logit harness behind the probit-labelled cell; result stores
## that pre-date this slice remain identifiable through their saved
## `evidence_family = "binomial_logit_harness"` metadata.
PILOT_CORE4 <- data.frame(
  family_label = c("gaussian", "nbinom2", "binomial_probit", "ordinal_probit"),
  harness_family = c("gaussian", "nbinom2", "binomial_probit", "ordinal_probit"),
  evidence_family = c(
    "gaussian",
    "nbinom2",
    "binomial_probit",
    "ordinal_probit"
  ),
  link_intended = c("identity", "log", "probit", "probit"),
  link_harness = c("identity", "log", "probit", "probit"),
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

## Audit-mini cells: one cheap representative moderate-signal cell per core
## family, used before any broader local or DRAC volume.
PILOT_AUDIT_MINI_FAMILIES <- c(
  "gaussian",
  "nbinom2",
  "binomial_probit",
  "ordinal_probit"
)
PILOT_AUDIT_MINI_D <- 1L
PILOT_AUDIT_MINI_N_UNITS <- 50L
PILOT_AUDIT_MINI_SIGNAL <- 0.2

## Effective per-cell seed blocks must be farther apart than any per-batch
## replicate block, otherwise cells can share rep_seed values.
PILOT_CELL_SEED_STRIDE <- 10000L

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
  ## Sort by family then d then n then signal for readability before assigning
  ## seed bases; this keeps the seed map stable under upstream expand.grid()
  ## ordering changes.
  g <- g[order(g$family_label, g$d, g$n_units, g$signal), ]
  ## Deterministic per-cell seed base. m3_run_cell() adds a family/d offset
  ## before adding the replicate index, so assign cell seed bases after
  ## subtracting that offset. The resulting effective rep_seed bases are
  ## exactly PILOT_CELL_SEED_STRIDE apart across the whole grid.
  seed_offset <- 100000L * m3_family_seed_index(g$harness_family) + 1000L * g$d
  g$seed_base <- 660000L +
    seq_len(nrow(g)) * PILOT_CELL_SEED_STRIDE -
    seed_offset
  ## Order columns.
  g <- g[
    seq_len(nrow(g)),
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

pilot_audit_mini_grid <- function() {
  g <- pilot_grid()
  keep <- g$family_label %in%
    PILOT_AUDIT_MINI_FAMILIES &
    g$d == PILOT_AUDIT_MINI_D &
    g$n_units == PILOT_AUDIT_MINI_N_UNITS &
    abs(g$signal - PILOT_AUDIT_MINI_SIGNAL) < sqrt(.Machine$double.eps)
  out <- g[keep, , drop = FALSE]
  missing <- setdiff(PILOT_AUDIT_MINI_FAMILIES, out$family_label)
  if (length(missing)) {
    stop(
      "pilot_audit_mini_grid() missing representative family row(s): ",
      paste(missing, collapse = ", ")
    )
  }
  out <- out[match(PILOT_AUDIT_MINI_FAMILIES, out$family_label), , drop = FALSE]
  rownames(out) <- NULL
  out
}

pilot_audit_mini_cell_ids <- function() {
  pilot_audit_mini_grid()$cell_id
}

pilot_build_audit_mini_manifest <- function(
  n_sim_step = 2L,
  n_sim_cap = 2L,
  seed_base,
  results_dir = PILOT_RESULTS_DIR_DEFAULT,
  n_boot = 0L,
  shard = 1L,
  n_shards = 1L,
  output_mode = c("chunk", "accumulate"),
  source_sha = Sys.getenv("GITHUB_SHA", unset = NA_character_),
  workflow_run_id = Sys.getenv("GITHUB_RUN_ID", unset = NA_character_),
  workflow_run_number = Sys.getenv("GITHUB_RUN_NUMBER", unset = NA_character_)
) {
  output_mode <- match.arg(output_mode)
  cell_ids <- pilot_audit_mini_cell_ids()
  manifest <- pilot_build_manifest(
    cell_ids = cell_ids,
    n_sim_step = n_sim_step,
    n_sim_cap = n_sim_cap,
    seed_base = seed_base,
    results_dir = results_dir,
    n_boot = n_boot,
    shard = shard,
    n_shards = n_shards,
    output_mode = output_mode,
    source_sha = source_sha,
    workflow_run_id = workflow_run_id,
    workflow_run_number = workflow_run_number
  )
  manifest <- manifest[match(cell_ids, manifest$cell_id), , drop = FALSE]
  rownames(manifest) <- NULL
  manifest
}

pilot_run_audit_mini_manifest <- function(
  n_sim_step = 2L,
  n_sim_cap = 2L,
  seed_base,
  results_dir = PILOT_RESULTS_DIR_DEFAULT,
  n_boot = 0L,
  shard = 1L,
  n_shards = 1L,
  runner = m3_run_cell,
  ci_level = PILOT_CI_LEVEL,
  verbose = FALSE,
  source_sha = Sys.getenv("GITHUB_SHA", unset = NA_character_),
  workflow_run_id = Sys.getenv("GITHUB_RUN_ID", unset = NA_character_),
  workflow_run_number = Sys.getenv("GITHUB_RUN_NUMBER", unset = NA_character_)
) {
  stopifnot(is.function(runner))
  manifest <- pilot_build_audit_mini_manifest(
    n_sim_step = n_sim_step,
    n_sim_cap = n_sim_cap,
    seed_base = seed_base,
    results_dir = results_dir,
    n_boot = n_boot,
    shard = shard,
    n_shards = n_shards,
    output_mode = "chunk",
    source_sha = source_sha,
    workflow_run_id = workflow_run_id,
    workflow_run_number = workflow_run_number
  )
  pilot_assert_manifest(manifest, require_unique_result_path = FALSE)
  manifest_path <- pilot_write_manifest(manifest, results_dir, shard)
  report <- pilot_run_chunk_manifest(
    manifest,
    runner = runner,
    ci_level = ci_level,
    verbose = verbose
  )
  audit <- pilot_assert_chunk_outputs(manifest)
  list(
    manifest = manifest,
    manifest_path = manifest_path,
    report = report,
    audit = audit
  )
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
      if ("rep" %in% names(df)) {
        nsim <- length(unique(df$rep))
      }
      if ("n_boot" %in% names(df)) {
        nb <- suppressWarnings(max(df$n_boot, na.rm = TRUE))
        if (is.finite(nb)) nboot <- as.integer(nb)
      }
    }
    idx <- rbind(
      idx,
      data.frame(
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
      )
    )
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

pilot_manifest_dir <- function(results_dir) {
  file.path(results_dir, PILOT_MANIFEST_DIR)
}

pilot_manifest_path <- function(results_dir, shard) {
  file.path(pilot_manifest_dir(results_dir), sprintf("shard-%s.csv", shard))
}

pilot_chunk_dir <- function(results_dir) {
  file.path(results_dir, PILOT_CHUNK_DIR)
}

pilot_chunk_path <- function(results_dir, campaign_id, cell_id, chunk_id) {
  file.path(
    pilot_chunk_dir(results_dir),
    campaign_id,
    cell_id,
    paste0(chunk_id, ".rds")
  )
}

pilot_chunk_aggregate_dir <- function(results_dir) {
  file.path(results_dir, PILOT_CHUNK_AGGREGATE_DIR)
}

pilot_manifest_seed_range <- function(batch_seed_base, family, d, n_reps) {
  if (!exists("m3_family_seed_index", mode = "function")) {
    stop("pilot manifest needs m3_family_seed_index(); source dev/m3-grid.R.")
  }
  n_reps <- as.integer(n_reps)
  if (is.na(n_reps) || n_reps < 1L) {
    return(c(min = NA_integer_, max = NA_integer_))
  }
  offset <- 1000L * as.integer(d) + 100000L * m3_family_seed_index(family)
  c(
    min = as.integer(batch_seed_base + offset + 1L),
    max = as.integer(batch_seed_base + offset + n_reps)
  )
}

## Build the deterministic audit manifest for one shard/run before fitting.
## This is intentionally side-effect free: it reads prior per-cell stores only
## to record n_before and the planned step size.
pilot_build_manifest <- function(
  cell_ids = NULL,
  n_sim_step = ACCUM_N_SIM_STEP_DEFAULT,
  n_sim_cap = ACCUM_N_SIM_CAP_DEFAULT,
  seed_base = NULL,
  results_dir = PILOT_RESULTS_DIR_DEFAULT,
  n_boot = PILOT_N_BOOT_DEFAULT,
  seed_fn = pilot_accum_batch_seed,
  shard = NA_integer_,
  n_shards = NA_integer_,
  output_mode = c("accumulate", "chunk"),
  source_sha = Sys.getenv("GITHUB_SHA", unset = NA_character_),
  workflow_run_id = Sys.getenv("GITHUB_RUN_ID", unset = NA_character_),
  workflow_run_number = Sys.getenv("GITHUB_RUN_NUMBER", unset = NA_character_)
) {
  stopifnot(is.function(seed_fn))
  output_mode <- match.arg(output_mode)
  if (is.null(seed_base)) {
    stop("pilot_build_manifest requires seed_base.")
  }
  n_sim_step <- as.integer(n_sim_step)
  n_sim_cap <- as.integer(n_sim_cap)
  seed_base <- as.integer(seed_base)
  n_boot <- as.integer(n_boot)
  if (is.na(seed_base) || seed_base < 0L) {
    stop("seed_base must be a non-negative integer.")
  }
  if (is.na(n_sim_step) || n_sim_step < 1L) {
    stop("n_sim_step must be a positive integer.")
  }
  if (is.na(n_sim_cap) || n_sim_cap < 1L) {
    stop("n_sim_cap must be a positive integer.")
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

  campaign_id <- sprintf("power-pilot-seed-%s", seed_base)
  rows <- vector("list", nrow(grid))
  for (i in seq_len(nrow(grid))) {
    cell <- grid[i, , drop = FALSE]
    cid <- cell$cell_id
    store_file <- paste0(cid, ".rds")
    store_path <- file.path(results_dir, store_file)
    prior <- if (file.exists(store_path)) {
      tryCatch(readRDS(store_path), error = function(e) NULL)
    } else {
      NULL
    }
    n_before <- pilot_accum_count(prior)
    n_reps_planned <- if (n_before >= n_sim_cap) {
      0L
    } else {
      min(n_sim_step, n_sim_cap - n_before)
    }
    batch_seed_base <- seed_fn(seed_base, cell$seed_base)
    seed_range <- pilot_manifest_seed_range(
      batch_seed_base,
      cell$harness_family,
      cell$d,
      n_reps_planned
    )
    rep_start <- if (n_reps_planned > 0L) n_before + 1L else NA_integer_
    rep_end <- if (n_reps_planned > 0L) {
      n_before + n_reps_planned
    } else {
      NA_integer_
    }
    chunk_id <- sprintf(
      "seed%s-shard%s-%s-rep%s-%s",
      seed_base,
      shard,
      cid,
      ifelse(is.na(rep_start), "none", rep_start),
      ifelse(is.na(rep_end), "none", rep_end)
    )
    chunk_file <- file.path(
      PILOT_CHUNK_DIR,
      campaign_id,
      cid,
      paste0(chunk_id, ".rds")
    )
    chunk_path <- pilot_chunk_path(results_dir, campaign_id, cid, chunk_id)
    result_file <- if (identical(output_mode, "chunk")) {
      chunk_file
    } else {
      store_file
    }
    result_path <- if (identical(output_mode, "chunk")) {
      chunk_path
    } else {
      store_path
    }
    rows[[i]] <- data.frame(
      campaign_id = campaign_id,
      source_sha = as.character(source_sha),
      workflow_run_id = as.character(workflow_run_id),
      workflow_run_number = as.character(workflow_run_number),
      shard = as.integer(shard),
      n_shards = as.integer(n_shards),
      chunk_id = chunk_id,
      cell_id = cid,
      family_label = cell$family_label,
      harness_family = cell$harness_family,
      evidence_family = cell$evidence_family,
      d = as.integer(cell$d),
      n_units = as.integer(cell$n_units),
      signal = as.numeric(cell$signal),
      lambda_scale = as.numeric(cell$lambda_scale),
      output_mode = output_mode,
      result_file = result_file,
      result_path = result_path,
      store_file = store_file,
      store_path = store_path,
      chunk_file = chunk_file,
      chunk_path = chunk_path,
      n_before = as.integer(n_before),
      n_reps_planned = as.integer(n_reps_planned),
      rep_start = as.integer(rep_start),
      rep_end = as.integer(rep_end),
      n_sim_cap = as.integer(n_sim_cap),
      n_boot = as.integer(n_boot),
      run_seed_base = as.integer(seed_base),
      cell_seed_base = as.integer(cell$seed_base),
      batch_seed_base = as.integer(batch_seed_base),
      rep_seed_min = as.integer(seed_range[["min"]]),
      rep_seed_max = as.integer(seed_range[["max"]]),
      action = if (n_reps_planned > 0L) "advance" else "skip_at_cap",
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

pilot_write_manifest <- function(manifest, results_dir, shard) {
  manifest_dir <- pilot_manifest_dir(results_dir)
  if (!dir.exists(manifest_dir)) {
    dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  }
  path <- pilot_manifest_path(results_dir, shard)
  utils::write.csv(manifest, path, row.names = FALSE, na = "")
  invisible(path)
}

pilot_read_manifests <- function(results_dirs = PILOT_RESULTS_DIR_DEFAULT) {
  results_dirs <- results_dirs[dir.exists(results_dirs)]
  if (!length(results_dirs)) {
    return(data.frame())
  }
  files <- unlist(
    lapply(results_dirs, function(dir) {
      list.files(
        pilot_manifest_dir(dir),
        pattern = "[.]csv$",
        full.names = TRUE
      )
    }),
    use.names = FALSE
  )
  if (!length(files)) {
    return(data.frame())
  }
  rows <- lapply(files, function(path) {
    out <- utils::read.csv(path, stringsAsFactors = FALSE)
    out$manifest_file <- basename(path)
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

pilot_assert_manifest <- function(manifest, require_unique_result_path = TRUE) {
  if (is.null(manifest) || !is.data.frame(manifest) || nrow(manifest) == 0L) {
    return(invisible(TRUE))
  }
  required <- c(
    "chunk_id",
    "cell_id",
    "result_path",
    "n_reps_planned",
    "rep_seed_min",
    "rep_seed_max"
  )
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop(
      "Pilot manifest missing required columns: ",
      paste(missing, collapse = ", ")
    )
  }
  active <- manifest[manifest$n_reps_planned > 0L, , drop = FALSE]
  if (!nrow(active)) {
    return(invisible(TRUE))
  }
  dup_chunk <- active$chunk_id[duplicated(active$chunk_id)]
  if (length(dup_chunk)) {
    stop("Duplicate pilot manifest chunk_id: ", dup_chunk[[1]])
  }
  if (isTRUE(require_unique_result_path)) {
    dup_path <- active$result_path[duplicated(active$result_path)]
    if (length(dup_path)) {
      stop("Duplicate pilot output paths in manifest: ", dup_path[[1]])
    }
  }
  if ("chunk_path" %in% names(active)) {
    bad_chunk_path <- is.na(active$chunk_path) | !nzchar(active$chunk_path)
    if (any(bad_chunk_path)) {
      stop(
        "Missing pilot chunk path for chunk_id: ",
        active$chunk_id[which(bad_chunk_path)[1]]
      )
    }
    dup_chunk_path <- active$chunk_path[duplicated(active$chunk_path)]
    if (length(dup_chunk_path)) {
      stop("Duplicate pilot chunk paths in manifest: ", dup_chunk_path[[1]])
    }
  }
  if (all(c("rep_start", "rep_end") %in% names(active))) {
    bad_rep <- is.na(active$rep_start) |
      is.na(active$rep_end) |
      active$rep_start > active$rep_end
    if (any(bad_rep)) {
      stop(
        "Invalid pilot replicate window for chunk_id: ",
        active$chunk_id[which(bad_rep)[1]]
      )
    }
    for (cid in unique(active$cell_id)) {
      cell_rows <- active[active$cell_id == cid, , drop = FALSE]
      if (nrow(cell_rows) < 2L) {
        next
      }
      cell_rows <- cell_rows[
        order(cell_rows$rep_start, cell_rows$rep_end),
        ,
        drop = FALSE
      ]
      prev_end <- cell_rows$rep_end[-nrow(cell_rows)]
      next_start <- cell_rows$rep_start[-1L]
      hit <- which(next_start <= prev_end)
      if (length(hit)) {
        stop(
          "Overlapping pilot replicate windows for cell_id ",
          cid,
          ": ",
          cell_rows$chunk_id[hit[[1]]],
          " and ",
          cell_rows$chunk_id[hit[[1]] + 1L]
        )
      }
    }
  }
  active <- active[
    order(active$rep_seed_min, active$rep_seed_max),
    ,
    drop = FALSE
  ]
  bad_seed <- is.na(active$rep_seed_min) |
    is.na(active$rep_seed_max) |
    active$rep_seed_min > active$rep_seed_max
  if (any(bad_seed)) {
    stop(
      "Invalid pilot seed range for chunk_id: ",
      active$chunk_id[which(bad_seed)[1]]
    )
  }
  if (nrow(active) >= 2L) {
    prev_max <- active$rep_seed_max[-nrow(active)]
    next_min <- active$rep_seed_min[-1L]
    hit <- which(next_min <= prev_max)
    if (length(hit)) {
      stop(
        "Overlapping pilot seed ranges: ",
        active$chunk_id[hit[[1]]],
        " and ",
        active$chunk_id[hit[[1]] + 1L]
      )
    }
  }
  invisible(TRUE)
}

pilot_assert_chunk_outputs <- function(manifest, require_all = TRUE) {
  if (is.null(manifest) || !is.data.frame(manifest) || nrow(manifest) == 0L) {
    return(data.frame())
  }
  required <- c("chunk_id", "cell_id", "chunk_path", "n_reps_planned")
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop(
      "Pilot chunk audit missing required columns: ",
      paste(missing, collapse = ", ")
    )
  }
  pilot_assert_manifest(manifest, require_unique_result_path = FALSE)
  active <- manifest[manifest$n_reps_planned > 0L, , drop = FALSE]
  if (!nrow(active)) {
    return(data.frame())
  }
  exists <- file.exists(active$chunk_path)
  size_bytes <- rep(NA_real_, nrow(active))
  if (any(exists)) {
    size_bytes[exists] <- file.info(active$chunk_path[exists])$size
  }
  audit <- data.frame(
    chunk_id = active$chunk_id,
    cell_id = active$cell_id,
    chunk_path = active$chunk_path,
    n_reps_planned = as.integer(active$n_reps_planned),
    exists = exists,
    size_bytes = size_bytes,
    stringsAsFactors = FALSE
  )
  if (isTRUE(require_all)) {
    missing_file <- which(!audit$exists)
    if (length(missing_file)) {
      stop(
        "Missing pilot chunk output: ",
        audit$chunk_id[missing_file[[1]]],
        " at ",
        audit$chunk_path[missing_file[[1]]]
      )
    }
    empty_file <- which(
      audit$exists & (is.na(audit$size_bytes) | audit$size_bytes <= 0)
    )
    if (length(empty_file)) {
      stop(
        "Empty pilot chunk output: ",
        audit$chunk_id[empty_file[[1]]],
        " at ",
        audit$chunk_path[empty_file[[1]]]
      )
    }
  }
  audit
}

pilot_run_chunk_manifest <- function(
  manifest,
  runner = m3_run_cell,
  ci_level = PILOT_CI_LEVEL,
  verbose = FALSE
) {
  stopifnot(is.function(runner))
  pilot_assert_manifest(manifest, require_unique_result_path = FALSE)
  report <- data.frame(
    chunk_id = character(0),
    cell_id = character(0),
    status = character(0),
    n_reps = integer(0),
    chunk_path = character(0),
    size_bytes = numeric(0),
    wall_s = numeric(0),
    error = character(0),
    stringsAsFactors = FALSE
  )
  if (is.null(manifest) || !is.data.frame(manifest) || nrow(manifest) == 0L) {
    return(report)
  }
  required <- c(
    "campaign_id",
    "chunk_id",
    "cell_id",
    "harness_family",
    "d",
    "n_units",
    "signal",
    "lambda_scale",
    "chunk_path",
    "n_before",
    "n_reps_planned",
    "rep_start",
    "rep_end",
    "n_boot",
    "run_seed_base",
    "batch_seed_base"
  )
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop(
      "Pilot chunk runner missing required columns: ",
      paste(missing, collapse = ", ")
    )
  }
  active <- manifest[manifest$n_reps_planned > 0L, , drop = FALSE]
  if (!nrow(active)) {
    return(report)
  }
  bad_mode <- if ("output_mode" %in% names(active)) {
    active$output_mode != "chunk"
  } else {
    rep(TRUE, nrow(active))
  }
  if (any(bad_mode)) {
    stop(
      "Pilot chunk runner requires output_mode = 'chunk' for chunk_id: ",
      active$chunk_id[which(bad_mode)[1]]
    )
  }

  for (i in seq_len(nrow(active))) {
    row <- active[i, , drop = FALSE]
    n_reps <- as.integer(row$n_reps_planned)
    n_before <- as.integer(row$n_before)
    if (!is.finite(n_before) || n_before < 0L) {
      stop("Invalid pilot chunk n_before for chunk_id: ", row$chunk_id)
    }
    if (!nzchar(row$chunk_path)) {
      stop("Missing pilot chunk path for chunk_id: ", row$chunk_id)
    }
    dir.create(dirname(row$chunk_path), recursive = TRUE, showWarnings = FALSE)

    cat(sprintf(
      paste0(
        "[chunk] RUN  %s: %d reps (cell=%s n_before=%d; ",
        "family=%s d=%d n=%d signal=%.1f seed_base=%d)\n"
      ),
      row$chunk_id,
      n_reps,
      row$cell_id,
      n_before,
      row$harness_family,
      as.integer(row$d),
      as.integer(row$n_units),
      as.numeric(row$signal),
      as.integer(row$batch_seed_base)
    ))

    t0 <- Sys.time()
    res <- tryCatch(
      runner(
        family = row$harness_family,
        d = as.integer(row$d),
        n_reps = n_reps,
        seed_base = as.integer(row$batch_seed_base),
        n_units = as.integer(row$n_units),
        n_traits = PILOT_N_TRAITS,
        lambda_scale = as.numeric(row$lambda_scale),
        targets = "Sigma_unit_diag",
        n_boot = as.integer(row$n_boot),
        ci_level = ci_level,
        verbose = verbose
      ),
      error = function(e) e
    )
    wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (inherits(res, "error")) {
      msg <- conditionMessage(res)
      msg <- iconv(msg, to = "ASCII", sub = "?")
      msg <- gsub("[\r\n]+", " ", msg)
      report <- rbind(
        report,
        data.frame(
          chunk_id = row$chunk_id,
          cell_id = row$cell_id,
          status = "error",
          n_reps = 0L,
          chunk_path = row$chunk_path,
          size_bytes = NA_real_,
          wall_s = wall,
          error = msg,
          stringsAsFactors = FALSE
        )
      )
      stop("Pilot chunk runner failed for chunk_id ", row$chunk_id, ": ", msg)
    }
    if (!is.data.frame(res)) {
      stop(
        "Pilot chunk runner returned non-data-frame for chunk_id: ",
        row$chunk_id
      )
    }

    res <- pilot_reindex_reps(res, n_before)
    res$pilot_campaign_id <- row$campaign_id
    res$pilot_chunk_id <- row$chunk_id
    res$pilot_cell_id <- row$cell_id
    res$pilot_rep_start <- as.integer(row$rep_start)
    res$pilot_rep_end <- as.integer(row$rep_end)
    res$pilot_run_seed_base <- as.integer(row$run_seed_base)
    res$pilot_batch_seed_base <- as.integer(row$batch_seed_base)

    saveRDS(res, row$chunk_path)
    size_bytes <- file.info(row$chunk_path)$size
    out_reps <- pilot_accum_count(res)
    cat(sprintf(
      "[chunk] OK   %s in %.1fs: wrote %d rep(s) to %s\n",
      row$chunk_id,
      wall,
      out_reps,
      row$chunk_path
    ))
    report <- rbind(
      report,
      data.frame(
        chunk_id = row$chunk_id,
        cell_id = row$cell_id,
        status = "written",
        n_reps = as.integer(out_reps),
        chunk_path = row$chunk_path,
        size_bytes = as.numeric(size_bytes),
        wall_s = wall,
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    )
  }

  rownames(report) <- NULL
  report
}

pilot_bind_rows_union <- function(rows) {
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) {
    return(data.frame())
  }
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) {
      x[[nm]] <- NA
    }
    x[, cols, drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

pilot_read_chunk_outputs <- function(manifest, require_all = TRUE) {
  pilot_assert_chunk_outputs(manifest, require_all = require_all)
  if (is.null(manifest) || !is.data.frame(manifest) || nrow(manifest) == 0L) {
    return(data.frame())
  }
  active <- manifest[manifest$n_reps_planned > 0L, , drop = FALSE]
  if (!nrow(active)) {
    return(data.frame())
  }
  required_manifest <- c(
    "campaign_id",
    "chunk_id",
    "cell_id",
    "chunk_path",
    "rep_start",
    "rep_end"
  )
  missing_manifest <- setdiff(required_manifest, names(active))
  if (length(missing_manifest)) {
    stop(
      "Pilot chunk aggregate missing manifest columns: ",
      paste(missing_manifest, collapse = ", ")
    )
  }

  chunks <- vector("list", nrow(active))
  for (i in seq_len(nrow(active))) {
    row <- active[i, , drop = FALSE]
    chunk <- tryCatch(readRDS(row$chunk_path), error = function(e) e)
    if (inherits(chunk, "error")) {
      stop(
        "Cannot read pilot chunk output for chunk_id ",
        row$chunk_id,
        ": ",
        conditionMessage(chunk)
      )
    }
    if (!is.data.frame(chunk) || !nrow(chunk)) {
      stop("Pilot chunk output is not a non-empty data frame: ", row$chunk_id)
    }
    missing_chunk <- setdiff(c("rep", "trait_id"), names(chunk))
    if (length(missing_chunk)) {
      stop(
        "Pilot chunk output missing required columns for chunk_id ",
        row$chunk_id,
        ": ",
        paste(missing_chunk, collapse = ", ")
      )
    }

    expected_reps <- seq.int(as.integer(row$rep_start), as.integer(row$rep_end))
    observed_reps <- sort(unique(as.integer(chunk$rep)))
    if (!identical(observed_reps, expected_reps)) {
      stop(
        "Pilot chunk rows do not match manifest replicate window for chunk_id ",
        row$chunk_id,
        ": expected rep ",
        paste(expected_reps, collapse = ","),
        "; got ",
        paste(observed_reps, collapse = ",")
      )
    }

    if ("pilot_chunk_id" %in% names(chunk)) {
      vals <- unique(as.character(chunk$pilot_chunk_id))
      vals <- vals[!is.na(vals)]
      if (!identical(vals, as.character(row$chunk_id))) {
        stop("Pilot chunk_id metadata mismatch for chunk_id: ", row$chunk_id)
      }
    } else {
      chunk$pilot_chunk_id <- as.character(row$chunk_id)
    }
    if ("pilot_cell_id" %in% names(chunk)) {
      vals <- unique(as.character(chunk$pilot_cell_id))
      vals <- vals[!is.na(vals)]
      if (!identical(vals, as.character(row$cell_id))) {
        stop("Pilot cell_id metadata mismatch for chunk_id: ", row$chunk_id)
      }
    } else {
      chunk$pilot_cell_id <- as.character(row$cell_id)
    }
    if ("pilot_campaign_id" %in% names(chunk)) {
      vals <- unique(as.character(chunk$pilot_campaign_id))
      vals <- vals[!is.na(vals)]
      if (!identical(vals, as.character(row$campaign_id))) {
        stop("Pilot campaign_id metadata mismatch for chunk_id: ", row$chunk_id)
      }
    } else {
      chunk$pilot_campaign_id <- as.character(row$campaign_id)
    }
    chunk$pilot_chunk_path <- as.character(row$chunk_path)
    chunks[[i]] <- chunk
  }

  pilot_bind_rows_union(chunks)
}

pilot_assert_unique_chunk_rows <- function(chunks) {
  required <- c("pilot_cell_id", "rep", "trait_id")
  missing <- setdiff(required, names(chunks))
  if (length(missing)) {
    stop(
      "Pilot chunk aggregate missing duplicate-key columns: ",
      paste(missing, collapse = ", ")
    )
  }
  key_cols <- required
  if ("target" %in% names(chunks)) {
    key_cols <- c(key_cols, "target")
  }
  key_df <- chunks[, key_cols, drop = FALSE]
  keys <- do.call(
    paste,
    c(lapply(key_df, as.character), sep = "\r")
  )
  dup <- which(duplicated(keys))
  if (length(dup)) {
    i <- dup[[1]]
    key_values <- vapply(
      key_cols,
      function(col) as.character(chunks[[col]][i]),
      character(1)
    )
    stop(
      "Duplicate pilot chunk aggregate rows for key: ",
      paste(
        sprintf("%s=%s", key_cols, key_values),
        collapse = ", "
      )
    )
  }
  invisible(TRUE)
}

pilot_aggregate_chunk_outputs <- function(
  manifest,
  aggregate_dir = NULL,
  write = FALSE
) {
  chunks <- pilot_read_chunk_outputs(manifest, require_all = TRUE)
  report <- data.frame(
    cell_id = character(0),
    n_chunks = integer(0),
    n_rows = integer(0),
    n_reps = integer(0),
    rep_min = integer(0),
    rep_max = integer(0),
    aggregate_path = character(0),
    size_bytes = numeric(0),
    stringsAsFactors = FALSE
  )
  if (!nrow(chunks)) {
    return(list(report = report, cells = list()))
  }
  pilot_assert_unique_chunk_rows(chunks)
  if (isTRUE(write)) {
    if (is.null(aggregate_dir) || !nzchar(aggregate_dir)) {
      stop("aggregate_dir is required when write = TRUE.")
    }
    dir.create(aggregate_dir, recursive = TRUE, showWarnings = FALSE)
  }

  cells <- split(chunks, chunks$pilot_cell_id)
  out_cells <- vector("list", length(cells))
  names(out_cells) <- names(cells)
  for (cid in names(cells)) {
    cell <- cells[[cid]]
    order_cols <- intersect(c("rep", "trait_id", "target"), names(cell))
    if (length(order_cols)) {
      ord <- do.call(order, cell[, order_cols, drop = FALSE])
      cell <- cell[ord, , drop = FALSE]
    }
    rownames(cell) <- NULL
    out_cells[[cid]] <- cell

    aggregate_path <- if (isTRUE(write)) {
      file.path(aggregate_dir, paste0(cid, ".rds"))
    } else {
      NA_character_
    }
    size_bytes <- NA_real_
    if (isTRUE(write)) {
      saveRDS(cell, aggregate_path)
      size_bytes <- as.numeric(file.info(aggregate_path)$size)
    }
    reps <- sort(unique(as.integer(cell$rep)))
    report <- rbind(
      report,
      data.frame(
        cell_id = cid,
        n_chunks = length(unique(cell$pilot_chunk_id)),
        n_rows = nrow(cell),
        n_reps = length(reps),
        rep_min = min(reps),
        rep_max = max(reps),
        aggregate_path = aggregate_path,
        size_bytes = size_bytes,
        stringsAsFactors = FALSE
      )
    )
  }
  rownames(report) <- NULL
  list(report = report, cells = out_cells)
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
      idx <- pilot_index_upsert(
        idx,
        data.frame(
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
        )
      )
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
    idx <- pilot_index_upsert(
      idx,
      data.frame(
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
      )
    )
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
    cat(
      "preliminary signal-zero coverage diagnostic (signal=0): <no done cells yet>\n"
    )
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
## space (cell seed_base < 1.2e6, plus 100000*family_index <= 5e5, plus
## 1000*d + r); a 5e6 stride leaves a wide margin so run-number blocks
## never overlap. Per-cell seed bases are separated by
## PILOT_CELL_SEED_STRIDE so same-run cells also do not share rep_seed
## values after the harness family/d seed offset is added. R seeds are
## 32-bit, so batch_seed_base MUST stay inside the
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
      report <- rbind(
        report,
        data.frame(
          cell_id = cid,
          action = "skip_at_cap",
          n_before = n_before,
          n_after = n_before,
          coverage_primary = NA_real_,
          error = NA_character_,
          stringsAsFactors = FALSE
        )
      )
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
      idx <- pilot_index_upsert(
        idx,
        data.frame(
          cell_id = cid,
          status = status,
          n_sim = n_before,
          n_boot = as.integer(n_boot),
          wall_s = wall,
          coverage_primary = prior_sum$coverage_primary,
          primary_gate_status = prior_sum$primary_gate_status %||%
            NA_character_,
          error = msg,
          timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
          stringsAsFactors = FALSE
        )
      )
      pilot_save_index(idx, results_dir)
      report <- rbind(
        report,
        data.frame(
          cell_id = cid,
          action = "error",
          n_before = n_before,
          n_after = n_before,
          coverage_primary = prior_sum$coverage_primary,
          error = msg,
          stringsAsFactors = FALSE
        )
      )
      next
    }

    ## Success: renumber the new batch's reps above the prior max, then
    ## combine with the prior stored grid.
    prior_max_rep <- if (
      !is.null(prior) &&
        is.data.frame(prior) &&
        "rep" %in% names(prior) &&
        nrow(prior)
    ) {
      suppressWarnings(max(prior$rep, na.rm = TRUE))
    } else {
      0L
    }
    if (!is.finite(prior_max_rep)) {
      prior_max_rep <- 0L
    }
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

    idx <- pilot_index_upsert(
      idx,
      data.frame(
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
      )
    )
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
    report <- rbind(
      report,
      data.frame(
        cell_id = cid,
        action = if (status == "done") "advanced_to_cap" else "advanced",
        n_before = n_before,
        n_after = n_after,
        coverage_primary = prim$coverage_primary,
        error = NA_character_,
        stringsAsFactors = FALSE
      )
    )
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
