## dev/power-pilot-run.R
## =====================
## Design 66 power-study CAMPAIGN runner -- the per-shard entry point for
## the self-scheduling sweep workflow (.github/workflows/power-pilot-sweep.yaml).
##
## This is a THIN command-line wrapper around the accumulate engine in
## dev/m3-pilot-launch.R (run_accumulate_pilot_batch / pilot_accum_status).
## It does NOT reimplement the DGP, the estimand machinery, or the
## accumulation logic -- it only: (1) selects this shard's slice of the
## 48-cell pilot grid, (2) calls the accumulate engine for those cells,
## (3) emits machine-readable outputs the workflow's guard/summary jobs
## consume (the run-level failure rate, and an all-complete flag).
##
## Modes (one --mode=... per invocation):
##   shard   -- run one shard's cells: accumulate +n_sim_step reps toward
##              the cap for every cell in this shard that is below cap.
##   slice   -- copy only this shard's touched per-cell files + runstats
##              into a clean artifact directory for the persist job.
##   status  -- print pilot_accum_status() over the store and write a
##              compact status payload (used by the guard + summary jobs).
##
## Usage (from repo root):
##   Rscript dev/power-pilot-run.R --mode=shard --shard=1 --n-shards=8 \
##     --n-sim-step=200 --n-sim-cap=2000 --seed-base=$GITHUB_RUN_NUMBER \
##     --results-dir=dev/m3-pilot-results --n-boot=25
##   Rscript dev/power-pilot-run.R --mode=status \
##     --n-sim-cap=2000 --results-dir=dev/m3-pilot-results \
##     --status-out=dev/m3-pilot-results/_status.txt
##
##   dry_run smoke (cheap): --dry-run=true restricts to <=2 cells and a
##   tiny n_sim_step regardless of the passed step, so the maintainer can
##   confirm the whole pipeline on GHA before trusting the cron.
##
## This file is in dev/ (.Rbuildignore) -- NOT shipped with the package.

suppressWarnings(suppressMessages({
  ## Load gllvmTMB itself (the harness fits models with it) and the
  ## harness + accumulate engine. In CI the package is installed
  ## (local::.); library() is the supported load path.
  library(gllvmTMB)
  source("dev/m3-grid.R")
  source("dev/m3-pilot-launch.R")
  source("dev/m3-pilot-report.R")
}))

## ---- Argument parsing (mirrors dev/precompute-m3-grid.R) --------------

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

as_truthy <- function(x) {
  isTRUE(tolower(as.character(x)) %in% c("true", "1", "yes", "y"))
}

mode <- arg_value("--mode", "shard")
results_dir <- arg_value("--results-dir", PILOT_RESULTS_DIR_DEFAULT)
n_sim_cap <- as.integer(arg_value("--n-sim-cap", as.character(ACCUM_N_SIM_CAP_DEFAULT)))
n_sim_step <- as.integer(arg_value("--n-sim-step", as.character(ACCUM_N_SIM_STEP_DEFAULT)))
n_boot <- as.integer(arg_value("--n-boot", as.character(PILOT_N_BOOT_DEFAULT)))
dry_run <- as_truthy(arg_value("--dry-run", "false"))

## Append a single KEY=VALUE line to the GitHub Actions step-output file
## ($GITHUB_OUTPUT), if present. No-op locally. Used so downstream jobs
## (guards, summary) can branch on this run's results.
emit_output <- function(key, value) {
  gh_out <- Sys.getenv("GITHUB_OUTPUT", "")
  line <- sprintf("%s=%s", key, value)
  cat(line, "\n", sep = "")
  if (nzchar(gh_out)) {
    cat(line, "\n", sep = "", file = gh_out, append = TRUE)
  }
  invisible(NULL)
}

## ---- Shard -> cell-id slice ------------------------------------------

## Deterministic round-robin assignment of the 48 pilot cells to shards.
## Round-robin (rather than contiguous blocks) spreads the slow families
## (nbinom2 / ordinal_probit) across shards so no single shard is the
## long pole. Shards are 1-indexed.
shard_cell_ids <- function(shard, n_shards) {
  grid <- pilot_grid()
  ord <- order(grid$cell_id) # stable, family-grouped order
  assign <- ((seq_along(ord) - 1L) %% n_shards) + 1L
  grid$cell_id[ord][assign == shard]
}

## ---- Modes ------------------------------------------------------------

if (identical(mode, "shard")) {
  shard <- as.integer(arg_value("--shard", "1"))
  n_shards <- as.integer(arg_value("--n-shards", "8"))
  seed_base <- arg_value("--seed-base", NULL)
  if (is.null(seed_base)) {
    stop("--seed-base is required (the GHA run number).")
  }
  seed_base <- as.integer(seed_base)

  cells <- shard_cell_ids(shard, n_shards)

  if (dry_run) {
    ## Cheap smoke: at most 2 cells, tiny step, so the maintainer can
    ## confirm the whole pipeline (run -> persist -> summary) on GHA
    ## without paying for real reps. Keep only cells in this shard so a
    ## dry-run still exercises the matrix.
    cells <- utils::head(cells, 1L) # 1 cell per shard
    n_sim_step <- 4L
    cat("[power-pilot] DRY RUN: tiny step, 1 cell/shard.\n")
  }

  cat(sprintf(
    "[power-pilot] shard %d/%d: %d cell(s); step=%d cap=%d n_boot=%d seed_base=%d\n",
    shard,
    n_shards,
    length(cells),
    n_sim_step,
    n_sim_cap,
    n_boot,
    seed_base
  ))
  if (length(cells) == 0L) {
    cat("[power-pilot] no cells for this shard; nothing to do.\n")
    emit_output("fail_rate", "0")
    quit(save = "no", status = 0L)
  }

  res <- run_accumulate_pilot_batch(
    cell_ids = cells,
    n_sim_step = n_sim_step,
    n_sim_cap = n_sim_cap,
    seed_base = seed_base,
    results_dir = results_dir,
    n_boot = n_boot,
    verbose = FALSE
  )

  ## Per-shard failure rate -> step output for the failure-rate guard.
  emit_output("fail_rate", formatC(res$fail_rate, format = "f", digits = 4))
  emit_output("n_attempted", as.character(res$n_attempted))
  emit_output("n_errored", as.character(res$n_errored))

  ## Also drop a per-shard run-stat file INTO the store so the persist
  ## job can aggregate this run's failure rate ACROSS shards (a matrix
  ## job's `outputs` only surfaces one arbitrary shard's value, so the
  ## aggregate must be reconstructed from these files). One line:
  ## "<n_attempted> <n_errored>". Lives under _runstats/ in the store.
  rs_dir <- file.path(results_dir, "_runstats")
  if (!dir.exists(rs_dir)) {
    dir.create(rs_dir, recursive = TRUE, showWarnings = FALSE)
  }
  writeLines(
    sprintf("%d %d", res$n_attempted, res$n_errored),
    file.path(rs_dir, sprintf("shard-%s.txt", shard))
  )
  quit(save = "no", status = 0L)
}

if (identical(mode, "slice")) {
  shard <- as.integer(arg_value("--shard", "1"))
  n_shards <- as.integer(arg_value("--n-shards", "8"))
  slice_dir <- arg_value("--slice-dir", NULL)
  if (is.null(slice_dir) || !nzchar(slice_dir)) {
    stop("--slice-dir is required for --mode=slice.")
  }

  cells <- shard_cell_ids(shard, n_shards)
  if (dry_run) {
    cells <- utils::head(cells, 1L)
  }

  if (dir.exists(slice_dir)) {
    unlink(slice_dir, recursive = TRUE, force = TRUE)
  }
  dir.create(slice_dir, recursive = TRUE, showWarnings = FALSE)

  copied <- 0L
  for (cid in cells) {
    src <- file.path(results_dir, paste0(cid, ".rds"))
    if (!file.exists(src)) {
      next
    }
    if (file.copy(src, file.path(slice_dir, basename(src)), overwrite = TRUE)) {
      copied <- copied + 1L
    }
  }

  rs_src <- file.path(results_dir, "_runstats", sprintf("shard-%s.txt", shard))
  if (file.exists(rs_src)) {
    rs_dir <- file.path(slice_dir, "_runstats")
    dir.create(rs_dir, recursive = TRUE, showWarnings = FALSE)
    file.copy(rs_src, file.path(rs_dir, basename(rs_src)), overwrite = TRUE)
  }

  cat(sprintf(
    "[power-pilot] shard %d/%d slice: copied %d/%d cell file(s) to %s\n",
    shard,
    n_shards,
    copied,
    length(cells),
    slice_dir
  ))
  quit(save = "no", status = 0L)
}

if (identical(mode, "status")) {
  st <- pilot_accum_status(results_dir = results_dir, n_sim_cap = n_sim_cap)
  emit_output("all_complete", tolower(as.character(st$all_complete)))
  emit_output("reps_total", as.character(st$counts[["reps_total"]]))
  emit_output("reps_target", as.character(st$counts[["reps_target"]]))
  emit_output("cells_complete", as.character(st$counts[["complete"]]))
  emit_output("cells_total", as.character(st$counts[["total"]]))

  ## ---- Issue + result recording (Design 66 report layer) ----
  ## Fold the accumulated per-cell stores into the tidy report table and
  ## derive a one-line ISSUES string (per-cell fit/non-PD/convergence
  ## failure rates) for the #340 board. Fail-soft: a report error must
  ## never break the summary job, so default to "none" on any error.
  report_df <- tryCatch(
    pilot_collect(results_dirs = results_dir),
    error = function(e) NULL
  )
  top_issues <- tryCatch(
    if (is.null(report_df)) "none" else pilot_issue_oneline(report_df),
    error = function(e) "none"
  )
  emit_output("top_issues", top_issues)

  ## Optional human-readable status file (markdown table) for the issue
  ## summary job to post.
  status_out <- arg_value("--status-out", NULL)
  if (!is.null(status_out)) {
    cells <- st$cells
    cells <- cells[order(cells$family_label, cells$d, cells$n_units, cells$signal), ]
    lines <- c(
      "| cell | n_sim | complete | coverage_primary | >=94% | >=95% |",
      "|------|------:|:--------:|-----------------:|:-----:|:-----:|"
    )
    fmt_cov <- function(x) ifelse(is.na(x), "-", formatC(x, format = "f", digits = 3))
    fmt_lgl <- function(x) ifelse(is.na(x), "-", ifelse(x, "Y", "n"))
    for (i in seq_len(nrow(cells))) {
      lines <- c(lines, sprintf(
        "| %s | %d | %s | %s | %s | %s |",
        cells$cell_id[i],
        as.integer(cells$n_sim[i]),
        if (isTRUE(cells$complete[i])) "Y" else "n",
        fmt_cov(cells$coverage_primary[i]),
        fmt_lgl(cells$passes_94[i]),
        fmt_lgl(cells$passes_95[i])
      ))
    }
    ## Append the ISSUES block (flagged cells with failure / non-PD /
    ## convergence rates) so the board carries issues beside coverage/power.
    if (!is.null(report_df)) {
      issue_block <- tryCatch(
        pilot_issue_lines(report_df),
        error = function(e) c("## ISSUES", "", "(issue summary unavailable)")
      )
      lines <- c(lines, "", issue_block)
    }
    writeLines(lines, status_out)
    cat(sprintf("[power-pilot] wrote status table to %s\n", status_out))
  }
  quit(save = "no", status = 0L)
}

stop(sprintf("unknown --mode=%s (expected 'shard' or 'status')", mode))
