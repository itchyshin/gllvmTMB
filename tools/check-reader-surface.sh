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
# 5. Milestone/decision identifiers with a dotted or hyphenated suffix —
#    "M1.8", "D-28" — which the original three patterns did not match. SIX D-43
#    panels withheld this milestone; each found a cell of a two-dimensional
#    class (SURFACE x CODE SHAPE) that the guard did not cover. Sweeping the
#    shapes it already knew, on the surfaces it already scanned, was itself
#    instance-thinking one level up.
#
register_codes='\b[A-Z]{2,4}-[0-9]{2,}\b'
phase_codes='\bM[0-9]\b'
milestone_codes='\bM[0-9]\.[0-9]\b'
decision_codes='\bD-[0-9]{1,3}\b'
design_refs='\bDesign [0-9]{2}\b'
dead_paths='docs/(design|dev-log)/'

pattern="${register_codes}|${phase_codes}|${milestone_codes}|${decision_codes}|${design_refs}|${dead_paths}"

# --- surfaces a user actually reads ---------------------------------------
#
# R/ IS A READER SURFACE. cli_abort/cli_warn/cli_inform message text and string
# VALUES returned in data frames are printed to users at runtime. CLAUDE.md's
# rule names "printed output" explicitly, but this guard scanned five FILE
# surfaces and never R/. A panel found `Design 73 C1`, `Phase 1b`, `M2/M3` and
# `D-28` being printed to users while this script reported PASS.
#
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

# --- R/ runtime output: string literals ONLY --------------------------------
#
# Internal code COMMENTS in R/ legitimately carry these identifiers — that is
# where engineering bookkeeping belongs, and a guard that fired on them would
# cry wolf until it was ignored. What reaches a user is MESSAGE TEXT and string
# VALUES: cli_abort/cli_warn/cli_inform, stop/warning/message, and character
# columns returned in data frames.
#
# So: scan R/ for the pattern inside a double-quoted string, on lines that are
# not comments. Roxygen (#') is excluded here because it is already covered
# transitively — it generates man/, which is scanned above.
#
if [ -d R ]; then
  r_violations=$(grep -rInE "\"[^\"]*(${pattern})" R 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+: *#' \
    | grep -vE "$exclude_re" || true)
  if [ -n "$r_violations" ]; then
    violations=$(printf '%s\n%s' "$violations" "$r_violations")
  fi
fi

# --- shipped vignettes must not link to unshipped articles ------------------
#
# .Rbuildignore strips ^vignettes/articles$, so a RELATIVE link like
# (morphometrics.html) from the one shipped vignette is a DEAD LINK for every
# CRAN reader. R CMD check does not catch this. man/ already uses absolute
# https://itchyshin.github.io/... URLs, which resolve; the vignette was the
# outlier. A panel found this by building the tarball and enumerating it.
#
for vig in vignettes/*.Rmd; do
  [ -e "$vig" ] || continue
  dead_links=$(grep -noE '\]\([a-z0-9_-]+\.html\)' "$vig" 2>/dev/null || true)
  if [ -n "$dead_links" ]; then
    violations=$(printf '%s\n%s' "$violations" \
      "$(printf '%s\n' "$dead_links" | sed "s|^|${vig}:|")")
  fi
done

violations=$(printf '%s' "$violations" | sed '/^$/d')

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

echo "READER-SURFACE CHECK: PASS"
echo "  files    : README.md, NEWS.md, DESCRIPTION, man/, vignettes/"
echo "  runtime  : R/ string literals (cli/stop/warning message text and"
echo "             character values returned to users; comments exempt)"
echo "  links    : shipped vignettes carry no relative *.html links to"
echo "             articles that .Rbuildignore strips from the tarball"
echo
echo "NOT covered: whether the prose that replaced a removed identifier is TRUE."
echo "No grep can establish that. Four panels withheld on exactly that gap."
