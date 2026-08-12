#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: launch-totoro-production.sh OUTPUT_DIR SOURCE_ARCHIVE SOURCE_SHA256" >&2
  exit 2
fi
output_dir="$1"
archive="$2"
expected_sha="$3"
readonly TOTORO_CORE_CAP=150
workers="${NWORKERS:-$TOTORO_CORE_CAP}"

if [ "$workers" -lt 1 ] || [ "$workers" -gt "$TOTORO_CORE_CAP" ] || [ "$workers" -gt "$(( $(nproc) - 4 ))" ]; then
  echo "NWORKERS=$workers exceeds the 150-core Totoro cap or host capacity." >&2
  exit 2
fi
if [ -e "$output_dir" ]; then
  echo "Output directory already exists: $output_dir" >&2
  exit 2
fi
actual_sha="$(sha256sum "$archive" | awk '{print $1}')"
if [ "$actual_sha" != "$expected_sha" ]; then
  echo "Source archive SHA-256 mismatch." >&2
  exit 2
fi
mkdir -p "$output_dir/extracted" "$output_dir/library"
tar -xf "$archive" -C "$output_dir/extracted"
source_root="$output_dir/extracted/gllvmTMB"
R CMD INSTALL --library="$output_dir/library" "$source_root" >"$output_dir/install.log" 2>&1
NWORKERS="$workers" OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  Rscript --vanilla "$source_root/inst/sim/cran07-aa03/run-production.R" \
  --output "$output_dir" --source-archive "$archive" --source-archive-sha "$expected_sha" \
  --library "$output_dir/library" >"$output_dir/production.log" 2>&1
