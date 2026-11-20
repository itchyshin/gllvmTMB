#!/usr/bin/env Rscript
## Design 118 B1 -- calibration-campaign harness consolidator.
## docs/design/118-mspl-interval-calibration-protocol.md s2.5, s5.6, s5.7.
##
## Reads every shard CSV under <out>/shards/ (STRICT filename match --
## tempfiles and any other stray file are excluded) and reports, PER
## (CELL, CALIBRATION TARGET), the profile-route coverage (Wilson 90% CI,
## three-way PASS/FAIL/INDETERMINATE verdict + the s2.5 one-shot escalation
## rule for hold-out cells) and the fence refusal rate.
##
## Freeze discipline (pre-launch review fix 5): s5.7 rule 1 is "hold-out
## blocks are read once". The DEFAULT run here shows TRAINING cells only,
## and the calibrator-input export filters to split == "train" -- reading
## hold-out coverage is a separate, explicit act. Pass --holdout to also
## print the hold-out table and the G1/G2 gate verdicts; that flag is the
## map-freeze acknowledgement, not a technical control -- the orchestrator
## is responsible for actually freezing the calibrator map first (s5.2)
## before ever passing it.
##
## Completeness (pre-launch review fix 6): before computing anything, every
## shard CSV present is checked for its expected row count
## (outer-datasets-in-shard x 3 calibration targets), and -- for the cells
## found under shards/, or the full registered grid under --expect-full --
## every expected shard file is checked for existence. Any missing or
## short shard is reported by name and the script exits nonzero WITHOUT
## printing a coverage summary (a silently short hold-out cell must never
## look like a valid gate result).
##
## Usage:
##   Rscript consolidate-b1.R --out /path/outside/repo/b1-calibration \
##     [--outer-per-shard 10] [--reps 600] [--expect-full] [--holdout] \
##     [--out-calibrator-input /path/calibrator-input.csv]

args <- commandArgs(trailingOnly = FALSE)
cli_args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- match(name, cli_args)
  if (is.na(hit)) return(default)
  if (hit == length(cli_args)) stop("Missing value for ", name, call. = FALSE)
  cli_args[[hit + 1L]]
}
arg_flag <- function(name) name %in% cli_args

file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) normalizePath(sub("^--file=", "", file_arg[[1L]])) else normalizePath("consolidate-b1.R")
script_dir <- dirname(script_path)
source(file.path(script_dir, "..", "b0-fence-roc", "lib-b0-fence-roc.R"))
source(file.path(script_dir, "lib-b1-calibration.R"))

out_root <- arg_value("--out")
if (is.null(out_root)) stop("Usage: Rscript consolidate-b1.R --out /path/outside/repo/b1-calibration", call. = FALSE)
outer_per_shard <- as.integer(arg_value("--outer-per-shard", "10"))
reps <- as.integer(arg_value("--reps", "600"))
show_holdout <- arg_flag("--holdout")
expect_full <- arg_flag("--expect-full")
calibrator_input_path <- arg_value("--out-calibrator-input")

shard_dir <- file.path(out_root, "shards")
## Strict shard-name glob (fix 6): exactly <cell_id>-shard-<NNN>.csv --
## excludes the `.tmp` publish-in-progress tempfile pattern and anything
## else that happens to live in shards/.
shard_name_re <- "^B[0-9]{3}-shard-[0-9]{3}\\.csv$"
all_files <- if (dir.exists(shard_dir)) list.files(shard_dir) else character(0)
matched <- all_files[grepl(shard_name_re, all_files)]
if (!length(matched)) stop("No shard CSVs matching ", shard_name_re, " found under ", shard_dir, call. = FALSE)
files <- sort(file.path(shard_dir, matched))

## ---- Completeness (fix 6) ------------------------------------------------
grid <- b1_grid()
present_cells <- sort(unique(sub("-shard-.*$", "", matched)))
check_cells <- if (expect_full) sort(grid$cell_id) else present_cells
shards_per_cell <- b1_shards_per_cell(outer_per_shard, reps)

problems <- character(0)
for (cid in check_cells) {
  for (sid in seq_len(shards_per_cell)) {
    fname <- sprintf("%s-shard-%03d.csv", cid, sid)
    fpath <- file.path(shard_dir, fname)
    if (!file.exists(fpath)) {
      problems <- c(problems, sprintf("MISSING: %s", fname))
      next
    }
    first_outer <- (sid - 1L) * outer_per_shard + 1L
    last_outer <- min(sid * outer_per_shard, reps)
    expected_rows <- (last_outer - first_outer + 1L) * 3L ## 3 calibration targets/outer
    n_rows <- tryCatch(nrow(utils::read.csv(fpath, stringsAsFactors = FALSE)), error = function(e) NA_integer_)
    if (is.na(n_rows) || n_rows != expected_rows) {
      problems <- c(problems, sprintf(
        "SHORT: %s (%s rows, expected %d)", fname, if (is.na(n_rows)) "unreadable" else n_rows, expected_rows
      ))
    }
  }
}
if (length(problems)) {
  cat(sprintf(
    "COMPLETENESS FAILED for %d cell(s) checked (%s):\n", length(check_cells),
    if (expect_full) "--expect-full: the entire registered 132-cell grid" else "cells present under shards/"
  ))
  cat(paste(" -", problems, collapse = "\n"), "\n")
  cat("Refusing to summarise on incomplete data. Fix the missing/short shards and re-run.\n")
  quit(save = "no", status = 1L)
}
cat(sprintf(
  "Completeness OK: %d cell(s) x %d shard(s) each, all present with expected row counts.\n",
  length(check_cells), shards_per_cell
))

rows <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE))
cat(sprintf("Read %d rows from %d shard files.\n", nrow(rows), length(files)))

ok <- rows$status == "ok"
cat(sprintf("ok rows: %d / %d (%.1f%%)\n", sum(ok), nrow(rows), 100 * mean(ok)))

## ---- Wilson 90% CI and the Design 118 s2.5 three-way verdict ------------
wilson_ci <- function(x, n, conf = 0.90) {
  if (n == 0L) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(1 - (1 - conf) / 2)
  phat <- x / n
  denom <- 1 + z^2 / n
  centre <- phat + z^2 / (2 * n)
  half <- z * sqrt(phat * (1 - phat) / n + z^2 / (4 * n^2))
  pmax(0, pmin(1, c((centre - half) / denom, (centre + half) / denom)))
}

verdict <- function(phat, ci, band = c(0.92, 0.98)) {
  if (is.na(phat)) return("NO_DATA")
  if (phat < band[[1L]] || phat > band[[2L]]) return("FAIL")
  if (ci[[1L]] >= band[[1L]] && ci[[2L]] <= band[[2L]]) return("PASS")
  "INDETERMINATE"
}

## Per-(cell, target) coverage -- Design 118 s2.5's Wilson arithmetic and
## the archive's own failure accounting (e.g. "C007 t2") are at this grain,
## not pooled across the 3 calibration targets within a cell.
cell_target_summary <- function(d, split_label) {
  keys <- unique(d[, c("cell_id", "target_slot")])
  out <- do.call(rbind, lapply(seq_len(nrow(keys)), function(k) {
    cid <- keys$cell_id[[k]]
    slot <- keys$target_slot[[k]]
    dc <- d[d$cell_id == cid & d$target_slot == slot, ]
    dc_ok <- dc[dc$status == "ok", ]
    n_rows <- nrow(dc_ok)
    n_refused <- sum(dc_ok$refused %in% TRUE)
    refusal_rate <- if (n_rows) n_refused / n_rows else NA_real_

    avail <- dc_ok$profile_attempted %in% TRUE & dc_ok$profile_available %in% TRUE
    n_avail <- sum(avail)
    n_cov <- sum(dc_ok$profile_covered[avail] %in% TRUE)
    phat <- if (n_avail) n_cov / n_avail else NA_real_
    ci <- wilson_ci(n_cov, n_avail)
    v <- verdict(phat, ci)

    boot_avail <- dc_ok$bootstrap_attempted %in% TRUE & dc_ok$bootstrap_available %in% TRUE
    n_boot_avail <- sum(boot_avail)
    n_boot_cov <- sum(dc_ok$bootstrap_covered[boot_avail] %in% TRUE)
    boot_phat <- if (n_boot_avail) n_boot_cov / n_boot_avail else NA_real_

    ## Escalation trigger in REP units (fix from the review: the previous
    ## version compared n_avail, a coordinate-availability count, to 2000,
    ## a replicate count). Reps for this (cell, target) is the number of
    ## outer datasets contributing an "ok" row here.
    n_reps <- n_rows
    escalate <- split_label == "holdout" && identical(v, "INDETERMINATE") && n_reps < 2000L
    fail_closed <- split_label == "holdout" && identical(v, "INDETERMINATE") && n_reps >= 2000L

    data.frame(
      cell_id = cid, block = dc$block[[1L]], split = split_label, target_slot = slot,
      n_reps = n_reps, n_refused = n_refused, refusal_rate = refusal_rate,
      profile_n_available = n_avail, profile_coverage = phat,
      wilson_lo = ci[[1L]], wilson_hi = ci[[2L]],
      verdict = if (fail_closed) "FAIL" else v, escalate_to_2000 = escalate,
      bootstrap_n_available = n_boot_avail, bootstrap_coverage = boot_phat,
      stringsAsFactors = FALSE
    )
  }))
  out[order(out$cell_id, out$target_slot), ]
}

train <- rows[rows$split == "train", ]
holdout <- rows[rows$split == "holdout", ]

cat("\n---- TRAIN (calibration) cells -- per (cell, target); never pooled with hold-out ----\n")
train_summary <- if (nrow(train)) cell_target_summary(train, "train") else data.frame()
print(train_summary, row.names = FALSE)

if (show_holdout) {
  cat("\n---- HOLD-OUT cells (--holdout: map-freeze acknowledged) -- per (cell, target) ----\n")
  holdout_summary <- if (nrow(holdout)) cell_target_summary(holdout, "holdout") else data.frame()
  print(holdout_summary, row.names = FALSE)

  if (nrow(holdout_summary)) {
    esc <- unique(holdout_summary$cell_id[holdout_summary$escalate_to_2000 %in% TRUE])
    if (length(esc)) {
      cat(sprintf(
        "\nESCALATE (s2.5 one-shot, n -> 2000) for hold-out cell(s): %s\n",
        paste(esc, collapse = ", ")
      ))
    }
    g1 <- mean(holdout_summary$verdict == "PASS", na.rm = TRUE)
    g2 <- !any(holdout_summary$profile_coverage < 0.90, na.rm = TRUE)
    cat(sprintf(
      "\nG1 (>=90%% hold-out (cell,target) rows PASS): %.1f%% PASS -> %s\n",
      100 * g1, if (g1 >= 0.90) "MEETS G1" else "FAILS G1"
    ))
    cat(sprintf("G2 (no hold-out coverage < 0.90): %s\n", if (g2) "MEETS G2" else "FAILS G2 -- C011-class guard tripped"))
  }
} else if (nrow(holdout)) {
  cat(sprintf(
    "\n%d hold-out row(s) present under %s but NOT summarised.\n", nrow(holdout), out_root
  ))
  cat("Pass --holdout (after freezing the calibrator map, Design 118 s5.2/s5.7) to read the gate.\n")
}

## ---- Calibrator-input export: TRAIN ONLY (fix 5) ------------------------
## One row per non-refused, profile-available coordinate -- the
## observables + endpoints + covered flags a later, separate calibrator-
## fitting step consumes (Design 118 s2.1, s2.4). Hold-out rows are never
## written here even if present in the shards: the export is filtered on
## `split == "train"` before any other filter, so pointing a calibrator fit
## at this file cannot accidentally consume hold-out data.
if (!is.null(calibrator_input_path)) {
  avail <- rows$split == "train" & rows$status == "ok" &
    rows$profile_attempted %in% TRUE & rows$profile_available %in% TRUE
  v_cols <- c(
    "cell_id", "block", "split", "link", "pi_target", "n_site", "n_trait", "q",
    "structure", "target", "target_name", "target_slot", "seed",
    "c_n", "N_eff", "p_free", "k", "n_obs", "screen_status", "screen_severity",
    "s_j", "probe_class", "estimate", "se_penalised", "truth",
    "profile_lower", "profile_upper", "profile_covered",
    "bootstrap_attempted", "bootstrap_available", "bootstrap_lower",
    "bootstrap_upper", "bootstrap_covered"
  )
  utils::write.csv(rows[avail, v_cols], calibrator_input_path, row.names = FALSE, na = "NA")
  cat(sprintf(
    "\nWrote calibrator-input observables table (%d TRAIN-only rows) to %s\n",
    sum(avail), calibrator_input_path
  ))
}
