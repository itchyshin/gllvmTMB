#!/usr/bin/env Rscript
## Design 118 B0 -- fence-ROC harness consolidator.
## docs/design/118-mspl-interval-calibration-protocol.md s5.3, s5.4.
##
## Reads every shard CSV under <out>/shards/, and reports the probe gate
## (Route A detection/false-refusal at s_j >= 1), the Route A/B agreement,
## and predictions P2/P5. Read-only; writes nothing back unless --out-summary
## is given.
##
## Usage:
##   Rscript consolidate-b0.R --out /path/outside/repo/b0-fence-roc

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- match(name, args)
  if (is.na(hit)) return(default)
  if (hit == length(args)) stop("Missing value for ", name, call. = FALSE)
  args[[hit + 1L]]
}

out_root <- arg_value("--out")
if (is.null(out_root)) stop("Usage: Rscript consolidate-b0.R --out /path/outside/repo/b0-fence-roc", call. = FALSE)

shard_dir <- file.path(out_root, "shards")
files <- sort(list.files(shard_dir, pattern = "\\.csv$", full.names = TRUE))
if (!length(files)) stop("No shard CSVs found under ", shard_dir, call. = FALSE)

rows <- do.call(rbind, lapply(files, utils::read.csv, stringsAsFactors = FALSE))
cat(sprintf("Read %d rows from %d shard files.\n", nrow(rows), length(files)))

ok <- rows$status == "ok"
cat(sprintf("ok rows: %d / %d (%.1f%%)\n", sum(ok), nrow(rows), 100 * mean(ok)))

## ---- Probe gate (s5.3): detection on C011 target-3 L2 rows, ------------
## false-refusal on the well-identified anchors C001/C004/C005/C008.
threshold <- 1.0
diseased <- ok & rows$case_id == "C011" & rows$target == 3 & rows$label_l2 %in% TRUE
anchors <- ok & rows$case_id %in% c("C001", "C004", "C005", "C008")

detect_rate <- if (sum(diseased)) mean(rows$s_j[diseased] >= threshold, na.rm = TRUE) else NA_real_
false_refusal_rate <- if (sum(anchors)) mean(rows$s_j[anchors] >= threshold, na.rm = TRUE) else NA_real_

cat(sprintf(
  "Route A detection on C011 target-3 L2 rows (n=%d): %.4f (gate: >= 0.90)\n",
  sum(diseased), detect_rate
))
cat(sprintf(
  "Route A false-refusal on anchors C001/C004/C005/C008 (n=%d): %.4f (gate: <= 0.05)\n",
  sum(anchors), false_refusal_rate
))

## ---- Route A/B agreement (s1.2 switch rule) -----------------------------
both <- ok & is.finite(rows$s_j) & is.finite(rows$route_b_s_surr) & rows$route_b_s_surr != 0
if (sum(both) > 2L) {
  corr <- suppressWarnings(stats::cor(
    log(abs(rows$s_j[both])), log(abs(rows$route_b_s_surr[both]))
  ))
  cat(sprintf("Route A/B corr(log|S|, log|S_surr|) (n=%d): %.4f (switch rule: >= 0.95)\n", sum(both), corr))
} else {
  cat("Route A/B agreement: insufficient finite paired rows.\n")
}

## ---- P2: median s_3 ordering cloglog > probit > logit at high prevalence -
hp3 <- ok & rows$regime == "high_prevalence" & rows$target == 3
if (sum(hp3)) {
  meds <- tapply(rows$s_j[hp3], rows$link[hp3], median, na.rm = TRUE)
  cat("P2 median s_3 by link at high_prevalence:\n")
  print(meds)
}

## ---- P5: C011 saturated (L1) target-3 rows -- observed vs predicted -----
p5 <- ok & rows$case_id == "C011" & rows$target == 3 & rows$label_l1 %in% TRUE
if (sum(p5)) {
  cat(sprintf(
    "P5 (n=%d): mean estimate_half_cn=%.6f (predicted 1.715161), mean estimate_double_cn=%.6f (predicted 1.466704)\n",
    sum(p5), mean(rows$estimate_half_cn[p5], na.rm = TRUE), mean(rows$estimate_double_cn[p5], na.rm = TRUE)
  ))
}

## ---- Timing corners (D-139) ----------------------------------------------
timing_cols <- c("fit_elapsed_seconds", "probe_elapsed_seconds", "hessian_elapsed_seconds", "screen_elapsed_seconds")
rows$total_elapsed_seconds <- rowSums(rows[, timing_cols], na.rm = TRUE)
by_cell <- aggregate(total_elapsed_seconds ~ case_id, data = rows[ok, ], FUN = mean)
cat("Mean seconds per outer dataset (3 fits + hessian + screen), by cell:\n")
print(by_cell)
