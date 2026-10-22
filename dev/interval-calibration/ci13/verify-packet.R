#!/usr/bin/env Rscript
## Pure CI-13 packet verification. No fits or simulations run here.

source("dev/interval-calibration/ci13/ci13-kernels.R")

manifest <- ci13_attempt_manifest(
  cell_ids = 2L,
  rep_ids = 1:100,
  source_sha = "VERIFY-SOURCE-SHA"
)
targets <- ci13_cell_targets(manifest$spec, 2L)$target_id
payload <- setNames(rep("covered", length(targets)), targets)
positive <- lapply(manifest$expected, function(x) {
  ci13_outer_attempt(
    manifest,
    x$cell_id,
    x$rep,
    "eligible",
    ci13_target_results(manifest, x$cell_id, payload)
  )
})
## A 100-replicate verifier deliberately cannot certify the 20,000-row campaign.
stopifnot(!isTRUE(ci13_promote(manifest, positive)$promotion$promote))
stopifnot(!isTRUE(ci13_promote(manifest, positive)$promotion$campaign_complete))

negative <- positive
for (i in seq_len(10L)) {
  negative[[i]]$target_results[[1L]]$outcome <- "ci_failed"
}
stopifnot(!isTRUE(ci13_promote(manifest, negative)$promotion$promote))

cat("CI13_PACKET_OK\n")
