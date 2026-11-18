#!/usr/bin/env Rscript
## Design 122 confirmatory campaign -- read all chunk-NNN.csv files under
## dev/design122-campaign/results/ (rsynced from the admitted Totoro
## destination) and compute the MEASUREMENT-ONLY summary that
## CAMPAIGN-RESULTS.md reports. Deliberately does NOT adjudicate K1-K4
## (Design 122 SS6.2) -- that is a separate reviewer's job. This script
## only counts and tabulates.

RESULTS_DIR <- Sys.getenv("CAMPAIGN_RESULTS_DIR",
                           "/private/tmp/gllvmtmb-doc-lane-20260816/dev/design122-campaign/results")
files <- sort(list.files(RESULTS_DIR, pattern = "^chunk-[0-9]{3}\\.csv$", full.names = TRUE))
cat(sprintf("Found %d chunk files in %s\n", length(files), RESULTS_DIR))

all_rows <- do.call(rbind, lapply(files, function(f) {
  d <- read.csv(f, stringsAsFactors = FALSE)
  d$.chunk_file <- basename(f)
  d
}))
cat(sprintf("Total rows: %d\n", nrow(all_rows)))

## --- completion: per (cell_id, family, n, p, truth) x arm ---
cell_keys <- unique(all_rows[, c("cell_id", "family", "n", "p", "truth")])
cell_keys <- cell_keys[order(cell_keys$cell_id), ]
completion <- do.call(rbind, lapply(seq_len(nrow(cell_keys)), function(i) {
  ck <- cell_keys[i, ]
  sub <- all_rows[all_rows$cell_id == ck$cell_id, ]
  do.call(rbind, lapply(c("L0", "L2", "VGH"), function(a) {
    s <- sub[sub$arm == a, ]
    data.frame(cell_id = ck$cell_id, family = ck$family, n = ck$n, p = ck$p,
               truth = ck$truth, arm = a, n_attempted = nrow(s),
               n_ok = sum(s$status == "ok"), n_nonconvergence = sum(s$status == "nonconvergence"),
               n_error = sum(s$status == "error"),
               conv_rate = if (nrow(s)) round(sum(s$status == "ok") / nrow(s), 4) else NA,
               testA_pass_rate = if (nrow(s)) round(mean(s$testA_pass, na.rm = TRUE), 4) else NA,
               n_degenerate = sum(s$degenerate, na.rm = TRUE),
               n_silent_divergent = sum(s$silent_divergent, na.rm = TRUE),
               wall_mean_s = round(mean(s$wall_time_s, na.rm = TRUE), 2),
               wall_max_s = round(max(s$wall_time_s, na.rm = TRUE), 2),
               stringsAsFactors = FALSE)
  }))
}))
write.csv(completion, file.path(RESULTS_DIR, "..", "campaign-completion-by-cell-arm.csv"), row.names = FALSE)

## --- per-arm campaign-wide summary ---
per_arm <- do.call(rbind, lapply(c("L0", "L2", "VGH"), function(a) {
  s <- all_rows[all_rows$arm == a, ]
  data.frame(arm = a, n_attempted = nrow(s), n_ok = sum(s$status == "ok"),
             n_nonconvergence = sum(s$status == "nonconvergence"),
             n_error = sum(s$status == "error"),
             conv_rate = round(sum(s$status == "ok") / nrow(s), 4),
             testA_pass_rate = round(mean(s$testA_pass, na.rm = TRUE), 4),
             testA_n_evaluated = sum(!is.na(s$testA_pass)),
             n_degenerate = sum(s$degenerate, na.rm = TRUE),
             n_silent_divergent = sum(s$silent_divergent, na.rm = TRUE),
             wall_sum_s = round(sum(s$wall_time_s, na.rm = TRUE), 1),
             wall_mean_s = round(mean(s$wall_time_s, na.rm = TRUE), 2),
             stringsAsFactors = FALSE)
}))

cat("\n=== PER-ARM CAMPAIGN SUMMARY ===\n"); print(per_arm)
cat(sprintf("\nTotal core-seconds (sum of wall_time_s, all rows, all arms): %.1f (%.2f core-hours)\n",
            sum(all_rows$wall_time_s, na.rm = TRUE), sum(all_rows$wall_time_s, na.rm = TRUE) / 3600))

## --- missing cells check ---
expected_cells <- 24
present_cells <- length(unique(all_rows$cell_id))
cat(sprintf("\nCells present: %d / %d\n", present_cells, expected_cells))
missing <- setdiff(1:24, unique(all_rows$cell_id))
if (length(missing)) cat("MISSING cell_ids:", paste(missing, collapse = ", "), "\n")

saveRDS(list(all_rows = all_rows, completion = completion, per_arm = per_arm),
        file.path(RESULTS_DIR, "..", "campaign-aggregate.rds"))
cat("\nWrote campaign-completion-by-cell-arm.csv and campaign-aggregate.rds\n")
