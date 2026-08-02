#!/bin/sh
# ---------------------------------------------------------------------------
# VA claim fence for gllvmTMB  (Design 108 Gate A, Stage 4 verification V1)
#
# WHAT THE FENCE ACTUALLY IS
# --------------------------
# The variational route is a hard-fenced, opt-in RESEARCH surface. It must not
# be advertised on any reader-facing surface (NEWS / README / vignettes).
#
# The fence is NOT "no probit" and NOT "no mixed-family". Both of those are
# legitimately public on the SHIPPED LAPLACE engine:
#   * ordinal_probit() is an exported Laplace family (R/families.R:779)
#   * mixed-family Laplace models are supported and documented
#   * aghq_ridge is a Laplace-path control, publicly documented in NEWS
# A naive grep for "probit|mixed-family|aghq_ridge" returns ~40 legitimate
# hits on a clean tree. A gate that cries wolf 40 times gets ignored, which is
# worse than no gate at all. So this script tests the CONJUNCTION -- gllvmTMB's
# own VARIATIONAL route named on a public surface -- not the individual words.
#
# Known-benign, deliberately excluded:
#   README.md "gllvm ... with variational, extended-variational, and Laplace
#   approximation paths" -- that sentence describes the SISTER PACKAGE and then
#   positions gllvmTMB as "the TMB-Laplace alternative". It is the fence
#   holding, not leaking.
#
# USAGE:  sh dev/design108-stage4/va-claim-fence.sh [git-ref]
#         (default ref: origin/main; pass HEAD to check the working branch)
# EXIT:   0 = fence holds, 1 = leak detected
# ---------------------------------------------------------------------------
set -u
REF="${1:-origin/main}"
SURF="NEWS.md README.md vignettes/"

echo "VA claim fence @ ${REF}"
echo "surfaces: ${SURF}"
echo

# (a) The VA route named by its own API / internal identifiers.
#     NOTE: aghq_ridge is deliberately NOT here -- it is a Laplace control.
echo "-- (a) VA route named by API identifier --"
A=$(git grep -I -n -E 'integration[[:space:]]*=[[:space:]]*.va.|gllvmTMB_va|va_r3|eval_method' \
      "$REF" -- $SURF 2>/dev/null)
if [ -n "$A" ]; then echo "$A"; else echo "  none"; fi

# (b) "variational" attributed to gllvmTMB itself, excluding the gllvm
#     sister-package comparison sentence.
echo "-- (b) 'variational' in gllvmTMB's own voice --"
B=$(git grep -I -n -i -E 'variational' "$REF" -- $SURF 2>/dev/null \
      | grep -v -i 'gllvm.*with variational' \
      | grep -v -i 'extended-variational, and Laplace')
if [ -n "$B" ]; then echo "$B"; else echo "  none"; fi

# (c) The actual leak shape: VA co-occurring with probit / mixed-family.
echo "-- (c) VA co-occurring with probit / mixed-family --"
C=$(git grep -I -n -i -E '(variational|[^a-z]va[^a-z]).*(probit|mixed-family)|(probit|mixed-family).*(variational|[^a-z]va[^a-z])' \
      "$REF" -- $SURF 2>/dev/null)
if [ -n "$C" ]; then echo "$C"; else echo "  none"; fi

N=$(printf '%s\n%s\n%s\n' "$A" "$B" "$C" | grep -c . 2>/dev/null || true)
echo
echo "TOTAL LEAK LINES: ${N}   (fence holds iff 0)"
if [ "$N" -ne 0 ]; then
  echo "FENCE BREACHED -- the variational route is advertised on a public surface."
  exit 1
fi
echo "FENCE HOLDS."
exit 0
