#!/usr/bin/env Rscript
## Design 118 B1 -- calibration-campaign harness consolidator.
## docs/design/118-mspl-interval-calibration-protocol.md s2.5, s5.6, s5.7.
##
## Reads every shard CSV under <out>/shards/ and reports, PER CELL, the
## profile-route coverage (Wilson 90% CI, three-way PASS/FAIL/INDETERMINATE
## verdict + the s2.5 one-shot escalation rule for hold-out cells) and the
## fence refusal rate. Train and hold-out cells are summarised in SEPARATE
## tables and never pooled into one aggregate. Also writes a calibrator-
## input observables table (one row per non-refused, profile-available
## coordinate) for a later, separate calibrator-fitting step -- this script
## does not fit gamma itself. Read-only over the shards; writes only the
## optional --out-summary / --out-calibrator-input files.
##
## Usage:
##   Rscript consolidate-b1.R --out /path/outside/repo/b1-calibration \
##     [--out-calibrator-input /path/calibrator-input.csv]

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}

out_root <- arg_value("--out")
if (is.null(out_root)) stop("Usage: Rscript consolidate-b1.R --out /path/outside/repo/b1-calibration", call. = FALSE)
calibrator_input_path <- arg_value("--out-calibrator-input")

shard_dir <- file.path(out_root, "shards")
files <- sort(list.files(shard_dir, pattern = "\\.csv$", full.names = TRUE))
if (!length(files)) stop("No shard CSVs found under ", shard_dir, call. = FALSE)

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

cell_summary <- function(d, split_label) {
  cells <- sort(unique(d$cell_id))
  out <- do.call(rbind, lapply(cells, function(cid) {
    dc <- d[d$cell_id == cid, ]
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

    escalate <- split_label == "holdout" && identical(v, "INDETERMINATE") && n_avail < 2000L
    fail_closed <- split_label == "holdout" && identical(v, "INDETERMINATE") && n_avail >= 2000L

    data.frame(
      cell_id = cid, block = dc$block[[1L]], split = split_label,
      n_rows = n_rows, n_refused = n_refused, refusal_rate = refusal_rate,
      profile_n_available = n_avail, profile_coverage = phat,
      wilson_lo = ci[[1L]], wilson_hi = ci[[2L]],
      verdict = if (fail_closed) "FAIL" else v,
      escalate_to_2000 = escalate,
      bootstrap_n_available = n_boot_avail, bootstrap_coverage = boot_phat,
      stringsAsFactors = FALSE
    )
  }))
  out
}

train <- rows[rows$split == "train", ]
holdout <- rows[rows$split == "holdout", ]

cat("\n---- TRAIN (calibration) cells -- never pooled with hold-out ----\n")
train_summary <- if (nrow(train)) cell_summary(train, "train") else data.frame()
print(train_summary, row.names = FALSE)

cat("\n---- HOLD-OUT cells -- s5.6 gate is evaluated on these only ----\n")
holdout_summary <- if (nrow(holdout)) cell_summary(holdout, "holdout") else data.frame()
print(holdout_summary, row.names = FALSE)

if (nrow(holdout_summary)) {
  esc <- holdout_summary[holdout_summary$escalate_to_2000 %in% TRUE, "cell_id"]
  if (length(esc)) {
    cat(sprintf(
      "\nESCALATE (s2.5 one-shot, n -> 2000) for hold-out cell(s): %s\n",
      paste(esc, collapse = ", ")
    ))
  }
  g1 <- mean(holdout_summary$verdict == "PASS", na.rm = TRUE)
  g2 <- !any(holdout_summary$profile_coverage < 0.90, na.rm = TRUE)
  cat(sprintf(
    "\nG1 (>=90%% hold-out cells PASS): %.1f%% PASS -> %s\n",
    100 * g1, if (g1 >= 0.90) "MEETS G1" else "FAILS G1"
  ))
  cat(sprintf("G2 (no hold-out cell coverage < 0.90): %s\n", if (g2) "MEETS G2" else "FAILS G2 -- C011-class guard tripped"))
}

## ---- Calibrator-input export: one row per non-refused, profile-available
## coordinate -- the observables + endpoints + covered flags a later,
## separate calibrator-fitting step consumes (Design 118 s2.1, s2.4).
if (!is.null(calibrator_input_path)) {
  avail <- rows$status == "ok" & rows$profile_attempted %in% TRUE & rows$profile_available %in% TRUE
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
  cat(sprintf("\nWrote calibrator-input observables table (%d rows) to %s\n", sum(avail), calibrator_input_path))
}
