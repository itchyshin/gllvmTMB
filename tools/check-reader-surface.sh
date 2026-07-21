#!/usr/bin/env bash
#
# check-reader-surface.sh — enforce the reader-facing-surface rule.
#
# NEWS.md states: "Reader-facing pages no longer expose internal validation
# identifiers, development phases, agent roles, or capability bookkeeping."
#
# That sentence was, twice, an ASSERTION rather than an enforced property, and
# twice a D-43 completion panel withheld a milestone because the artifact
# contradicted it. This script makes it a property: it fails the build if an
# internal identifier or an unshipped path appears on a surface a user reads.
#
# It is deliberately run against the SHIPPED surfaces only — the things a CRAN
# user can actually see. Internal engineering records (docs/, LOOP/, dev/,
# tests/) are exempt by design: identifiers belong there.
#
# Usage: bash tools/check-reader-surface.sh
# Exit:  0 clean, 1 violations found.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

# --- what counts as a violation -------------------------------------------
#
# 1. Validation-register codes: two-to-four uppercase letters, hyphen, digits.
#    e.g. FAM-20, CI-11, RE-14, PHY-11, SPA-08, MIS-33, ANI-11.
# 2. Internal phase identifiers: a bare M followed by a single digit (M1..M9).
# 3. Internal design-document references: "Design NN".
# 4. Paths under docs/, which are stripped from the tarball by .Rbuildignore
#    (^docs$) and are therefore DEAD LINKS for the CRAN reader they address.
#
register_codes='\b[A-Z]{2,4}-[0-9]{2,}\b'
phase_codes='\bM[0-9]\b'
design_refs='\bDesign [0-9]{2}\b'
dead_paths='docs/(design|dev-log)/'

pattern="${register_codes}|${phase_codes}|${design_refs}|${dead_paths}"

# --- surfaces a user actually reads ---------------------------------------
surfaces=(README.md NEWS.md DESCRIPTION)
[ -d man ] && surfaces+=(man)
[ -d vignettes ] && surfaces+=(vignettes)

# --- documented exclusions -------------------------------------------------
#
# refs.bib   : bibliography. R Journal DOIs (RJ-2018-017, RJ-2018-009) match the
#              register-code shape and are entirely legitimate citations. A guard
#              that fires on a DOI is worse than no guard, because it trains the
#              reader to ignore it.
# README URL : README links to design docs via absolute https://github.com/...
#              URLs. Those RESOLVE for a reader, so they are not dead links. Only
#              bare docs/ paths are a defect.
#
exclude_re='refs\.bib|https?://[^ )]*docs/'

# -I skips binary files: man/figures/*.png can match these byte patterns by
# chance, and a guard that reports a logo as a documentation defect is noise.
violations=$(grep -rInE "$pattern" "${surfaces[@]}" 2>/dev/null \
  | grep -vE "$exclude_re" || true)

if [ -n "$violations" ]; then
  echo "READER-SURFACE CHECK: FAIL"
  echo
  echo "Internal identifiers or unshipped paths found on user-facing surfaces."
  echo "These contradict the claim NEWS.md makes about itself, and docs/ paths"
  echo "are dead links because .Rbuildignore strips ^docs\$ from the tarball."
  echo
  echo "$violations"
  echo
  echo "Fix at SOURCE: for man/*.Rd edit the roxygen in R/ and re-document."
  exit 1
fi

echo "READER-SURFACE CHECK: PASS — no internal identifiers or unshipped paths"
echo "on README.md, NEWS.md, DESCRIPTION, man/, or vignettes/."
