#!/usr/bin/env Rscript
## CLI entry point: packet cell_id rep source_sha out_path
## Calling this runs exactly one approved frozen identity; it never launches a
## remote scheduler or expands to a campaign.

source("dev/interval-calibration/ci14-ci15/ci1415-kernels.R")
source("dev/interval-calibration/ci14-ci15/smoke-runners.R")
source("dev/interval-calibration/ci14-ci15/campaign-shard.R")

ci1415_run_campaign_shard_cli()
