#!/usr/bin/env bash
## K2 smoke-first (local only). Hard OUT: no Totoro.
## 1-rep near-tail (K2a) then 1-rep new interior seed (K2b).
## Same runner + flags later take --n_rep=50.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

Rscript --vanilla dev/mspl-forkB-l2-smoke.R \
  --n_rep=1 --cell=L1-neartail-n40-T4 --seed_base=20260821

Rscript --vanilla dev/mspl-forkB-l2-smoke.R \
  --n_rep=1 --cell=L1-anchor-n80-T8 --seed_base=20260819
