#!/usr/bin/env Rscript
## Pure CI-14/15 packet verification.  No model fit or simulation is run.

source("dev/interval-calibration/ci14-ci15/ci1415-kernels.R")

manifest <- ci1415_attempt_manifest(
  "CI14",
  cell_ids = 1L,
  rep_ids = 1:3,
  source_sha = "VERIFY-SOURCE-SHA"
)
payload <- ci1415_target_results(manifest, "CI14", outcome = "covered")
attempts <- lapply(1:3, function(rep) {
  ci1415_outer_attempt(manifest, 1L, rep, "eligible", payload)
})
merged <- ci1415_merge_attempts(manifest, attempts)
summary <- ci1415_summarise(merged)
stopifnot(
  nrow(summary) == 6L,
  all(summary$coverage == 1),
  !isTRUE(ci1415_promote(manifest, attempts)$promotion$complete_campaign)
)

bad <- ci1415_old_misspecified_loadings_fixture()
rejected <- inherits(
  try(ci1415_validate_truth("CI15_LOADINGS", bad), silent = TRUE),
  "try-error"
)
stopifnot(rejected)

cat("CI1415_PACKET_OK\n")
