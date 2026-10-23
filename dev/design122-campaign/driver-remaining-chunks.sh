#!/usr/bin/env bash
# Design 122 confirmatory campaign -- sequential driver for the remaining
# chunks. Runs ON Totoro via nohup; NOT committed; scratch deploy artifact.
#
# RESTARTED after the first attempt: chunks 001, 022, 023 are already done
# (022 banked from rung 3; 023 was the GLLVMTMB_VA_R3_BUILD_ROOT
# verification run -- it hit a ONE-TIME race on the shared build root's
# empty directory, 120/300 VGH rows recorded as legitimate error-as-rows,
# NOT re-run, per RESULT-SCHEMA.md's no-automatic-retry policy; 001 ran
# clean AFTER the race settled, confirming the shared .so is now valid and
# stable -- verified directly: dyn.load() succeeds and getParameterOrder is
# registered). Workers from here on only READ the existing .so (no rebuild
# trigger), so the race cannot recur.
set -uo pipefail  # NOT -e: one chunk failing must not kill the loop.

D=~/gllvm_work/campaigns/design122-confirmatory-20260817-646005cf
export R_LIBS=~/gllvm_work/design122-campaign/lib-646005cf:~/R/lib
export DESIGN122_CONFIRM=yes
export CAMPAIGN_PKG_DIR=~/gllvm_work/design122-campaign/src-646005cf
export CAMPAIGN_DEST=$D
export CAMPAIGN_ID=design122-confirmatory-20260817-646005cf
export DESIGN122_CAMPAIGN_ID=$CAMPAIGN_ID
export DESIGN122_DEST=$CAMPAIGN_DEST
export DESIGN122_COMMIT=646005cf
export DESIGN122_WORKERS=96
export GLLVMTMB_VA_R3_BUILD_ROOT=~/gllvm_work/design122-campaign/va-r3-build-646005cf
LAUNCHER=~/gllvm_work/design122-campaign/src-646005cf/dev/design122-campaign/launch-campaign.sh
cd "$D"

echo "[driver] RESTART $(date -u)"

for id in 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 24; do
  cid=$(printf "%03d" "$id")
  if [[ -f "$D/chunk-$cid.csv" ]]; then
    echo "[driver] chunk-$cid.csv already exists -- SKIP"
    continue
  fi
  echo "[driver] === starting chunk $id $(date -u) ==="
  bash "$LAUNCHER" --mode=full --chunk="$id" --launch >> "$D/driver-chunks.log" 2>&1
  status=$?
  echo "[driver] === chunk $id finished exit=$status $(date -u) ==="
  if [[ ! -f "$D/chunk-$cid.csv" ]]; then
    echo "[driver] *** WARNING: chunk-$cid.csv missing after run (exit=$status) -- recording failure and continuing ***"
  fi
done

echo "[driver] ALL DONE $(date -u)"
echo "[driver] final chunk count: $(ls "$D"/chunk-*.csv 2>/dev/null | wc -l) / 24"
