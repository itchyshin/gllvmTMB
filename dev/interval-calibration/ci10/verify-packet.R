#!/usr/bin/env Rscript
## CI-10/XFI-01 pure ledger controls.  No fits or simulations run here.

source("dev/interval-calibration/ci10/ci10-kernels.R")
source_sha <- Sys.getenv("CI10_SOURCE_SHA", unset = "")
if (!nzchar(source_sha)) {
  stop("CI10_SOURCE_SHA is required", call. = FALSE)
}

all_covered <- function(manifest) {
  ci10_target_results(
    manifest,
    c(
      multiple_r = "covered",
      `contrast_r:cat:2` = "covered",
      `contrast_r:cat:3` = "covered"
    )
  )
}

manifest <- ci10_attempt_manifest(
  ci10_campaign_spec(),
  cell_ids = 1L,
  rep_ids = 1:100,
  source_sha = source_sha
)
positive <- lapply(manifest$expected, function(x) {
  ci10_outer_attempt(
    manifest,
    x$cell_id,
    x$rep,
    "eligible",
    all_covered(manifest)
  )
})
positive_report <- ci10_promote(manifest, positive)
stopifnot(!isTRUE(positive_report$promotion$promote))
stopifnot(!isTRUE(positive_report$promotion$complete_campaign))
stopifnot(isTRUE(positive_report$promotion$target_gates_pass))
stopifnot(isTRUE(ci10_manifest_is_complete_campaign(
  ci10_attempt_manifest(ci10_campaign_spec(), source_sha = source_sha)
)))

negative <- positive
for (i in seq_len(10L)) {
  negative[[i]]$target_results[[1L]]$outcome <- "miss"
}
stopifnot(!isTRUE(ci10_promote(manifest, negative)$promotion$promote))

scientific <- positive
scientific[[1L]] <- ci10_outer_attempt(
  manifest,
  1L,
  1L,
  "scientific_base_failure"
)
scientific_report <- ci10_promote(manifest, scientific)
stopifnot(!isTRUE(scientific_report$promotion$promote))
stopifnot(isTRUE(scientific_report$promotion$target_gates_pass))
stopifnot(scientific_report$targets$scientific_failures[1L] == 1L)

cat("CI10_PACKET_OK\n")
