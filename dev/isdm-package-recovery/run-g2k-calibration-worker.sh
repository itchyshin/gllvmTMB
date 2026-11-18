#!/usr/bin/env bash
set -euo pipefail
seed="$1"
root="$2"
pkg="$3"
sha="$4"
exec Rscript --vanilla "${pkg}/dev/isdm-package-recovery/run-g2i-recovery-prerun.R" \
  --mode=prerun --seed="${seed}" --output="${root}/seeds/seed-$(printf '%05d' "${seed}")" \
  --pkg="${pkg}" --campaign-sha="${sha}"
