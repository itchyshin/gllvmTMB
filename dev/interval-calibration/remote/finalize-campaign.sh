#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: finalize-campaign.sh PACKET TASK_TSV OUT_ROOT SOURCE_ROOT" >&2
  exit 64
fi
packet=$1
task_tsv=$2
out_root=$3
source_root=$4
cd "$source_root"
Rscript --vanilla dev/interval-calibration/remote/validate-task-manifest.R \
  "$packet" "$task_tsv"
expected=$(($(wc -l < "$task_tsv") - 1))
actual=$(find "$out_root/canonical" -type f -name '*.rds' | wc -l | tr -d ' ')
if [ "$actual" -ne "$expected" ]; then
  echo "cannot finalize $packet: $actual canonical shards, expected $expected" >&2
  exit 66
fi
checksum_path=$out_root/canonical-checksums.sha256
if [ -e "$checksum_path" ]; then
  echo "refusing existing checksum manifest: $checksum_path" >&2
  exit 66
fi
checksum_tmp=$(mktemp "$out_root/.canonical-checksums.XXXXXX")
trap 'rm -f "$checksum_tmp"' EXIT HUP INT TERM
cd "$out_root"
find canonical -type f -name '*.rds' -print0 |
  sort -z |
  xargs -0 sha256sum > "$checksum_tmp"
mv "$checksum_tmp" "$checksum_path"
mkdir -p "$out_root/aggregate"
cd "$source_root"
Rscript --vanilla dev/interval-calibration/remote/aggregate-campaign.R \
  "$packet" "$out_root" "$out_root/aggregate/result.rds"
