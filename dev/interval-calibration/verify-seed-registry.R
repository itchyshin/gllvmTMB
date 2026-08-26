#!/usr/bin/env Rscript
## Pure programme-wide seed verification. No fitting or simulation occurs.

source("dev/interval-calibration/seed-registry-contract.R")

registry_path <- "docs/dev-log/artifacts/interval-calibration/seed-registry.csv"
registry <- ic_read_seed_registry(registry_path)
expanded <- ic_expand_seed_registry(registry)
verdict <- ic_validate_seed_registry(registry, expanded)

tracked_csv <- system2(
  "git",
  c("ls-files", "--", "*.csv"),
  stdout = TRUE,
  stderr = TRUE
)
current_programme_seed_evidence <- c(
  "docs/dev-log/artifacts/interval-calibration/2026-08-25-pvt02-r50001-cross-root-ledger.csv"
)
tracked_csv <- setdiff(tracked_csv, registry_path)
history <- ic_collect_historical_seeds(
  tracked_csv,
  exclude_paths = current_programme_seed_evidence
)
collisions <- ic_historical_seed_collisions(expanded, history)
known_historical <- data.frame(
  seed = 18065153L,
  packet = "CI10",
  source = "dev/aghq-evidence/24-campaign-stage1.csv",
  stringsAsFactors = FALSE
)
collisions <- collisions[
  order(collisions$seed, collisions$packet, collisions$source),
]
known_historical <- known_historical[
  order(
    known_historical$seed,
    known_historical$packet,
    known_historical$source
  ),
]
if (!identical(unname(collisions), unname(known_historical))) {
  preview <- utils::capture.output(print(
    utils::head(collisions, 20L),
    row.names = FALSE
  ))
  stop(
    "historical collision set differs from the one reviewed exception:\n",
    paste(preview, collapse = "\n"),
    call. = FALSE
  )
}

cat(sprintf(
  "SEED_REGISTRY_DISJOINT_OK planned=%d historical=%d current_collisions=0 reviewed_historical_exceptions=%d\n",
  verdict$n_planned,
  length(unique(history$seed)),
  nrow(collisions)
))
