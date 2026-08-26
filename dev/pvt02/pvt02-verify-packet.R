## Pure PVT-02 outer-packet verifier: no simulation, fitting, profiling, or writes.
script_path <- sub(
  "^--file=",
  "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)
)
root <- normalizePath(file.path(dirname(script_path), "..", ".."))
source(file.path(root, "dev", "pvt02", "pvt02-contract.R"))

cell <- list(
  family = "gaussian",
  tier = "unit",
  mode = "latent",
  unique = TRUE,
  d = 2L,
  n_units = 400L,
  n_traits = 3L,
  target_scale = "log_V",
  level = 0.95
)
manifest <- pvt02_campaign_manifest(
  cell,
  "0123456789abcdef",
  reps = 50001:50002
)
stopifnot(
  nrow(manifest) == 2L,
  identical(manifest$seed, pvt02_campaign_seed(manifest$rep))
)
canonical <- do.call(
  rbind,
  lapply(seq_len(nrow(manifest)), function(i) {
    targets <- do.call(
      rbind,
      list(
        pvt02_target_payload(1L, 2, 2, 1, 3),
        pvt02_target_payload(2L, 2, 2, 1, 3)
      )
    )
    pvt02_outer_attempt_row(manifest[i, , drop = FALSE], TRUE, targets)
  })
)
retry <- pvt02_operational_retry_row(
  manifest[1L, , drop = FALSE],
  2L,
  "SLURM node failure while reading batch",
  "fit"
)
merged <- pvt02_merge_batch_receipts(
  manifest,
  list(pvt02_batch_receipt(manifest, canonical, retry))
)
summary <- pvt02_summarise_campaign(merged, manifest)
stopifnot(identical(summary$coverage, c(`1` = 1, `2` = 1)))
stopifnot(
  !pvt02_campaign_promotion_verdict(cell, manifest, merged, TRUE, 5000L)$promote
)

bad <- merged$canonical[-1L, , drop = FALSE]
stopifnot(inherits(
  try(
    pvt02_validate_batch_receipt(
      pvt02_batch_receipt(manifest, bad, retry),
      manifest
    ),
    silent = TRUE
  ),
  "try-error"
))
cat("PVT02_PACKET_OK\n")
