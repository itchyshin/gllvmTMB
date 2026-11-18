#!/usr/bin/env bash
set -euo pipefail

# Run only after the local smoke recorded by run-pa-recovery.R is healthy.
# Usage: bash run-pa-totoro.sh <repo-root> <result-root> [workers]
repo_root=${1:?repo root is required}
result_root=${2:?result root is required}
workers=${3:-30}

if (( workers < 1 || workers > 30 )); then
  echo "workers must be between 1 and 30" >&2
  exit 2
fi
if [[ ! -f "$repo_root/dev/isdm-package-recovery/run-pa-recovery.R" ]]; then
  echo "missing recovery runner in repo root" >&2
  exit 2
fi

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
private_lib="$repo_root/.isdm-r-library"
export R_LIBS_USER="$private_lib:$HOME/R/lib"
if [[ -e "$result_root" ]]; then
  echo "refusing to reuse an immutable result root: $result_root" >&2
  exit 2
fi
mkdir -p "$private_lib" "$result_root"
R CMD INSTALL --library="$private_lib" "$repo_root" >/dev/null

launch() {
  local scenario=$1
  local replicate=$2
  Rscript --vanilla "$repo_root/dev/isdm-package-recovery/run-pa-recovery.R" \
    --mode=fixture --scenario="$scenario" --replicate="$replicate" \
    --output="$result_root" --pkg="$repo_root" --load=installed \
    >"$result_root/${scenario}-replicate-${replicate}.log" 2>&1 &
}

wait_for_slot() {
  while (( $(jobs -pr | wc -l) >= workers )); do
    wait -n || true
  done
}

for replicate in $(seq 1 20); do
  wait_for_slot
  launch ordinary "$replicate"
done
for scenario in disconnected weak_overlap; do
  for replicate in $(seq 1 5); do
    wait_for_slot
    launch "$scenario" "$replicate"
  done
done
wait || true
Rscript --vanilla "$repo_root/dev/isdm-package-recovery/run-pa-recovery.R" \
  --mode=summarize --output="$result_root" --pkg="$repo_root" --load=installed
