#!/usr/bin/env Rscript
## Pure CI-09 packet verification. No fits or simulations are run here.

source("dev/interval-calibration/ci09/ci09-kernels.R")

manifest <- ci09_attempt_manifest(source_sha = "VERIFY-SOURCE-SHA")
attempts <- ci09_synthetic_all_covered(manifest, n_eff = 150L)
summary <- ci09_summarise(ci09_merge_attempts(manifest, attempts))
stopifnot(isTRUE(ci09_promote(summary)$promotion$promote))

subset <- ci09_attempt_manifest(
  cell_ids = 1L,
  rep_ids = 1:100,
  source_sha = "VERIFY-SOURCE-SHA"
)
subset_summary <- ci09_summarise(ci09_merge_attempts(
  subset,
  ci09_synthetic_all_covered(subset, n_eff = 150L)
))
stopifnot(!isTRUE(ci09_promote(subset_summary)$promotion$promote))

cat("CI09_PACKET_OK\n")
