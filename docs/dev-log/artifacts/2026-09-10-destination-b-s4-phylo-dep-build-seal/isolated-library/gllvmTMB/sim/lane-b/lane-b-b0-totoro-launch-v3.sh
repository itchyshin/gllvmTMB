#!/usr/bin/env bash
set -eu

SOURCE_DIR=${GLLVMTMB_LANE_B_B0_SOURCE:?set GLLVMTMB_LANE_B_B0_SOURCE}
CAMPAIGN_ROOT=${GLLVMTMB_LANE_B_CAMPAIGN:?set GLLVMTMB_LANE_B_CAMPAIGN}
R_LIBRARY=${GLLVMTMB_LANE_B_RLIB:?set GLLVMTMB_LANE_B_RLIB}
WORKERS=${GLLVMTMB_LANE_B_B0_WORKERS:-30}

mkdir -p "$CAMPAIGN_ROOT/logs-b0-exact-v3" "$CAMPAIGN_ROOT/session"
cd "$SOURCE_DIR"

R_LIBS="$R_LIBRARY" Rscript --vanilla -e '
  frozen <- readRDS(file.path(commandArgs(TRUE)[1], "frozen", "lane-b-b2-frozen.rds"))
  cat(frozen$queue$shard_id[frozen$queue$table == "ordinary"], sep = "\n")
' "$CAMPAIGN_ROOT" |
  xargs -P"$WORKERS" -I{} sh -c '
    shard_id="$1"
    env R_LIBS="$2" \
      OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
      Rscript --vanilla "$3/inst/sim/lane-b/3_run_lane_b_b0_shard.R" \
        --root "$4" --shard-id "$shard_id" \
        > "$4/logs-b0-exact-v3/${shard_id}.log" 2>&1
  ' _ {} "$R_LIBRARY" "$SOURCE_DIR" "$CAMPAIGN_ROOT"

R_LIBS="$R_LIBRARY" Rscript --vanilla -e '
  root <- commandArgs(TRUE)[1]
  source_dir <- commandArgs(TRUE)[2]
  source(file.path(source_dir, "inst/sim/lane-b/lane-b-b2-runner.R"))
  source(file.path(source_dir, "inst/sim/lane-b/lane-b-b2-adjudication.R"))
  frozen <- readRDS(file.path(root, "frozen", "lane-b-b2-frozen.rds"))
  expected <- sum(frozen$queue$table == "ordinary")
  observed <- length(list.files(file.path(root, "b0-exact-v3"), pattern = "\\.rds$"))
  registry_files <- list.files(file.path(root, "b0-exact-v3"),
                               pattern = "\\.rds$", full.names = TRUE)
  receipt <- list(
    completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    expected_shards = expected,
    observed_shards = observed,
    complete = identical(as.integer(observed), as.integer(expected)),
    manifest_version = frozen$manifest_version,
    detector_version = as.character(utils::packageVersion("detectseparation")),
    source_sha256 = lane_b_b0_source_receipt(),
    registry_sha256 = setNames(vapply(registry_files, lane_b_sha256_file, character(1L)),
                               basename(registry_files))
  )
  saveRDS(receipt, file.path(root, "session", "b0-exact-receipt-v3.rds"))
  print(receipt)
  if (!isTRUE(receipt$complete)) quit(save = "no", status = 1L)
' "$CAMPAIGN_ROOT" "$SOURCE_DIR"
