#!/usr/bin/env bash
# Verify every repo-relative path cited in this lane's documents actually exists.
# A dead path in a handover is how the next session loses time.
cd "$(dirname "$0")/../.." || exit 1
docs=(
  docs/dev-log/audits/2026-07-31-aghq-truthstart-shipped-engine.md
  docs/dev-log/audits/2026-07-31-aghq-convergence-nladder.md
  docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md
  docs/dev-log/after-task/2026-07-31-aghq-truthstart-843.md
  docs/dev-log/after-task/2026-07-31-aghq-campaign-design.md
  docs/dev-log/handover/2026-07-31-aghq-campaign-designed-blocked-on-874.md
)
bad=0
for d in "${docs[@]}"; do
  [ -f "$d" ] || { echo "MISSING DOC: $d"; bad=1; continue; }
  # paths that look like repo files: R/..., src/..., dev/..., docs/..., tests/...
  grep -oE '(^|[^A-Za-z0-9_/.-])(R|src|dev|docs|tests)/[A-Za-z0-9_./-]+\.(R|md|csv|cpp|log|html)' "$d" \
    | sed -E 's/^[^A-Za-z]*//' | sort -u | while read -r p; do
      p="${p%%:*}"
      [ -e "$p" ] || echo "  DEAD REF in $d -> $p"
    done
done
echo "--- done (no 'DEAD REF' lines above = all cited paths exist) ---"
exit $bad
