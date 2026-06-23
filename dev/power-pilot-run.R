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
##   preflight -- build + validate this shard's manifest and exit before
##              fitting; used for Totoro/DRAC manifest-parse smoke tests.
##   chunk   -- build this shard's immutable-chunk manifest, run the active
##              chunk rows, and write one chunk RDS per planned row.
##   chunk-audit -- read chunk manifests and require every planned chunk
##              file to exist before a future aggregation job runs.
##   chunk-aggregate -- read validated chunk outputs and write derived
##              per-cell aggregate RDS files for downstream reporting.
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
##   Rscript dev/power-pilot-run.R --mode=preflight --shard=1 --n-shards=48 \
##     --n-sim-step=2 --n-sim-cap=10 --seed-base=1 \
##     --results-dir=/tmp/pilot-smoke --n-boot=0 --output-mode=chunk
##   Rscript dev/power-pilot-run.R --mode=chunk --shard=1 --n-shards=48 \
##     --n-sim-step=2 --n-sim-cap=10 --seed-base=1 \
##     --results-dir=/tmp/pilot-smoke --n-boot=0
##   Rscript dev/power-pilot-run.R --mode=chunk-audit \
##     --results-dir=/tmp/pilot-smoke
##   Rscript dev/power-pilot-run.R --mode=chunk-aggregate \
##     --results-dir=/tmp/pilot-smoke
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
n_sim_cap <- as.integer(arg_value(
  "--n-sim-cap",
  as.character(ACCUM_N_SIM_CAP_DEFAULT)
))
n_sim_step <- as.integer(arg_value(
  "--n-sim-step",
  as.character(ACCUM_N_SIM_STEP_DEFAULT)
))
n_boot <- as.integer(arg_value("--n-boot", as.character(PILOT_N_BOOT_DEFAULT)))
dry_run <- as_truthy(arg_value("--dry-run", "false"))
output_mode <- arg_value("--output-mode", "accumulate")
aggregate_dir <- arg_value(
  "--aggregate-dir",
  pilot_chunk_aggregate_dir(results_dir)
)

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

if (identical(mode, "preflight")) {
  shard <- as.integer(arg_value("--shard", "1"))
  n_shards <- as.integer(arg_value("--n-shards", "8"))
  seed_base <- arg_value("--seed-base", NULL)
  if (is.null(seed_base)) {
    stop("--seed-base is required for --mode=preflight.")
  }
  seed_base <- as.integer(seed_base)

  cells <- shard_cell_ids(shard, n_shards)
  if (dry_run) {
    cells <- utils::head(cells, 1L)
  }

  manifest <- pilot_build_manifest(
    cell_ids = cells,
    n_sim_step = n_sim_step,
    n_sim_cap = n_sim_cap,
    seed_base = seed_base,
    results_dir = results_dir,
    n_boot = n_boot,
    shard = shard,
    n_shards = n_shards,
    output_mode = output_mode
  )
  pilot_assert_manifest(
    manifest,
    require_unique_result_path = !identical(output_mode, "chunk")
  )
  manifest_path <- pilot_write_manifest(manifest, results_dir, shard)
  active_chunks <- sum(manifest$n_reps_planned > 0L)
  emit_output("manifest_rows", as.character(nrow(manifest)))
  emit_output("active_chunks", as.character(active_chunks))
  cat(sprintf(
    paste0(
      "[power-pilot] preflight shard %d/%d: wrote %d row(s), ",
      "%d active chunk(s), output_mode=%s to %s\n"
    ),
    shard,
    n_shards,
    nrow(manifest),
    active_chunks,
    output_mode,
    manifest_path
  ))
  quit(save = "no", status = 0L)
}

if (identical(mode, "chunk-audit")) {
  manifest_df <- pilot_read_manifests(results_dir)
  if (!nrow(manifest_df)) {
    emit_output("chunk_outputs_ok", "false")
    stop("power-pilot chunk output audit found no manifest rows.")
  }
  audit <- tryCatch(
    pilot_assert_chunk_outputs(manifest_df),
    error = function(e) e
  )
  chunk_outputs_ok <- !inherits(audit, "error")
  emit_output("chunk_outputs_ok", tolower(as.character(chunk_outputs_ok)))
  if (!chunk_outputs_ok) {
    emit_output("chunk_outputs_error", conditionMessage(audit))
    stop("power-pilot chunk output audit failed: ", conditionMessage(audit))
  }
  emit_output("chunk_output_rows", as.character(nrow(audit)))
  cat(sprintf(
    "[power-pilot] chunk audit: validated %d planned chunk output(s) in %s\n",
    nrow(audit),
    results_dir
  ))
  quit(save = "no", status = 0L)
}

if (identical(mode, "chunk-aggregate")) {
  manifest_df <- pilot_read_manifests(results_dir)
  if (!nrow(manifest_df)) {
    emit_output("chunk_aggregate_ok", "false")
    stop("power-pilot chunk aggregate found no manifest rows.")
  }
  aggregate <- tryCatch(
    pilot_aggregate_chunk_outputs(
      manifest_df,
      aggregate_dir = aggregate_dir,
      write = TRUE
    ),
    error = function(e) e
  )
  aggregate_ok <- !inherits(aggregate, "error")
  emit_output("chunk_aggregate_ok", tolower(as.character(aggregate_ok)))
  if (!aggregate_ok) {
    emit_output("chunk_aggregate_error", conditionMessage(aggregate))
    stop("power-pilot chunk aggregate failed: ", conditionMessage(aggregate))
  }
  report <- aggregate$report
  emit_output("chunk_aggregate_cells", as.character(nrow(report)))
  emit_output("chunk_aggregate_rows", as.character(sum(report$n_rows)))
  emit_output("chunk_aggregate_dir", aggregate_dir)
  cat(sprintf(
    "[power-pilot] chunk aggregate: wrote %d cell aggregate(s), %d row(s) to %s\n",
    nrow(report),
    sum(report$n_rows),
    aggregate_dir
  ))
  quit(save = "no", status = 0L)
}

if (identical(mode, "chunk")) {
  shard <- as.integer(arg_value("--shard", "1"))
  n_shards <- as.integer(arg_value("--n-shards", "8"))
  seed_base <- arg_value("--seed-base", NULL)
  if (is.null(seed_base)) {
    stop("--seed-base is required for --mode=chunk.")
  }
  seed_base <- as.integer(seed_base)

  cells <- shard_cell_ids(shard, n_shards)
  if (dry_run) {
    cells <- utils::head(cells, 1L)
    n_sim_step <- 1L
    cat("[power-pilot] DRY RUN: tiny chunk step, 1 cell/shard.\n")
  }
  if (length(cells) == 0L) {
    cat("[power-pilot] no cells for this chunk shard; nothing to do.\n")
    emit_output("chunk_rows", "0")
    emit_output("chunk_output_rows", "0")
    emit_output("n_errored", "0")
    quit(save = "no", status = 0L)
  }

  manifest <- pilot_build_manifest(
    cell_ids = cells,
    n_sim_step = n_sim_step,
    n_sim_cap = n_sim_cap,
    seed_base = seed_base,
    results_dir = results_dir,
    n_boot = n_boot,
    shard = shard,
    n_shards = n_shards,
    output_mode = "chunk"
  )
  pilot_assert_manifest(manifest, require_unique_result_path = FALSE)
  manifest_path <- pilot_write_manifest(manifest, results_dir, shard)
  cat(sprintf("[power-pilot] wrote chunk manifest to %s\n", manifest_path))

  report <- pilot_run_chunk_manifest(manifest, verbose = FALSE)
  audit <- pilot_assert_chunk_outputs(manifest)
  emit_output("chunk_rows", as.character(nrow(report)))
  emit_output("chunk_output_rows", as.character(nrow(audit)))
  emit_output("n_errored", as.character(sum(report$status == "error")))
  cat(sprintf(
    "[power-pilot] chunk shard %d/%d: wrote %d planned chunk output(s)\n",
    shard,
    n_shards,
    nrow(report)
  ))
  quit(save = "no", status = 0L)
}

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

  manifest <- pilot_build_manifest(
    cell_ids = cells,
    n_sim_step = n_sim_step,
    n_sim_cap = n_sim_cap,
    seed_base = seed_base,
    results_dir = results_dir,
    n_boot = n_boot,
    shard = shard,
    n_shards = n_shards
  )
  pilot_assert_manifest(manifest)
  manifest_path <- pilot_write_manifest(manifest, results_dir, shard)
  cat(sprintf("[power-pilot] wrote shard manifest to %s\n", manifest_path))

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
  manifest_src <- pilot_manifest_path(results_dir, shard)
  if (file.exists(manifest_src)) {
    manifest_dir <- file.path(slice_dir, PILOT_MANIFEST_DIR)
    dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
    file.copy(
      manifest_src,
      file.path(manifest_dir, basename(manifest_src)),
      overwrite = TRUE
    )
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
  manifest_df <- pilot_read_manifests(results_dir)
  manifest_ok <- TRUE
  manifest_error <- NA_character_
  tryCatch(
    pilot_assert_manifest(manifest_df),
    error = function(e) {
      manifest_ok <<- FALSE
      manifest_error <<- conditionMessage(e)
    }
  )
  emit_output("manifest_ok", tolower(as.character(manifest_ok)))
  if (!manifest_ok) {
    emit_output("manifest_error", manifest_error)
    stop("power-pilot manifest validation failed: ", manifest_error)
  }

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
    if (!is.null(report_df) && nrow(report_df)) {
      report_cols <- intersect(
        c(
          "cell_id",
          "evidence_family",
          "coverage_eligible_n",
          "coverage_mcse",
          "fit_failure_rate",
          "nonpd_rate",
          "sdreport_ok_rate",
          "boot_fail_rate"
        ),
        names(report_df)
      )
      cells <- merge(
        cells,
        report_df[, report_cols, drop = FALSE],
        by = "cell_id",
        all.x = TRUE
      )
      if ("evidence_family.y" %in% names(cells)) {
        cells$evidence_family <- ifelse(
          !is.na(cells$evidence_family.y),
          cells$evidence_family.y,
          cells$evidence_family.x
        )
      } else if ("evidence_family.x" %in% names(cells)) {
        cells$evidence_family <- cells$evidence_family.x
      }
    }
    cells <- cells[
      order(cells$family_label, cells$d, cells$n_units, cells$signal),
    ]
    lines <- c(
      paste0(
        "| cell | evidence | n_sim | complete | ci_rows | coverage_primary |",
        " mcse | >=94% | >=95% | fit-fail | nonPD | sdreport | boot-fail |"
      ),
      paste0(
        "|------|----------|------:|:--------:|--------:|-----------------:|",
        "-----:|:-----:|:-----:|---------:|------:|---------:|----------:|"
      )
    )
    fmt_cov <- function(x) {
      ifelse(is.na(x), "-", formatC(x, format = "f", digits = 3))
    }
    fmt_int <- function(x) ifelse(is.na(x), "-", as.character(as.integer(x)))
    fmt_pct <- function(x) ifelse(is.na(x), "-", sprintf("%.0f%%", 100 * x))
    fmt_lgl <- function(x) ifelse(is.na(x), "-", ifelse(x, "Y", "n"))
    for (i in seq_len(nrow(cells))) {
      lines <- c(
        lines,
        sprintf(
          paste0(
            "| %s | %s | %d | %s | %s | %s | %s | %s | %s |",
            " %s | %s | %s | %s |"
          ),
          cells$cell_id[i],
          if (
            "evidence_family" %in%
              names(cells) &&
              !is.na(cells$evidence_family[i])
          ) {
            cells$evidence_family[i]
          } else {
            cells$family_label[i]
          },
          as.integer(cells$n_sim[i]),
          if (isTRUE(cells$complete[i])) "Y" else "n",
          if ("coverage_eligible_n" %in% names(cells)) {
            fmt_int(cells$coverage_eligible_n[i])
          } else {
            "-"
          },
          fmt_cov(cells$coverage_primary[i]),
          if ("coverage_mcse" %in% names(cells)) {
            fmt_cov(cells$coverage_mcse[i])
          } else {
            "-"
          },
          fmt_lgl(cells$passes_94[i]),
          fmt_lgl(cells$passes_95[i]),
          if ("fit_failure_rate" %in% names(cells)) {
            fmt_pct(cells$fit_failure_rate[i])
          } else {
            "-"
          },
          if ("nonpd_rate" %in% names(cells)) {
            fmt_pct(cells$nonpd_rate[i])
          } else {
            "-"
          },
          if ("sdreport_ok_rate" %in% names(cells)) {
            fmt_pct(cells$sdreport_ok_rate[i])
          } else {
            "-"
          },
          if ("boot_fail_rate" %in% names(cells)) {
            fmt_pct(cells$boot_fail_rate[i])
          } else {
            "-"
          }
        )
      )
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

stop(sprintf(
  paste0(
    "unknown --mode=%s (expected 'preflight', 'chunk', 'chunk-audit', ",
    "'chunk-aggregate', 'shard', 'slice', or 'status')"
  ),
  mode
))
