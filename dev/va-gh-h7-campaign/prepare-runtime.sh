#!/usr/bin/env bash
set -euo pipefail

# Build one immutable installed package and write its revision-bound runtime
# manifest. Run this on local/Totoro or an allocated DRAC compute node, never a
# DRAC login node. Timed fit preflight is a separate step.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DRIVER="$SCRIPT_DIR/run-cell.R"

: "${CAMPAIGN_PROJECT_ROOT:?Set CAMPAIGN_PROJECT_ROOT to durable campaign storage}"
: "${GATE_E_RECEIPT:?Set GATE_E_RECEIPT to the structured Gate-E receipt}"

host_short="$(hostname -s | tr '[:upper:]' '[:lower:]')"
case "$host_short" in
  fir*|nibi*|rorqual*|trillium*|narval*|killarney*|vulcan*|tamia*)
    [[ -n "${SLURM_JOB_ID:-}" ]] || {
      echo "Runtime preparation compiles code and must run in a DRAC allocation, not on $host_short." >&2
      exit 2
    }
    ;;
esac

Rscript --vanilla "$DRIVER" --mode=verify-gate \
  --gate-receipt="$GATE_E_RECEIPT"

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "Runtime preparation requires a clean checkout bound to Gate E." >&2
  exit 5
fi

revision="$(Rscript --vanilla -e \
  'x <- read.dcf(commandArgs(TRUE)[1]); cat(x[1, "git_revision"])' \
  "$GATE_E_RECEIPT")"
runtime_root="$CAMPAIGN_PROJECT_ROOT/runtime/$revision"
package_lib="$runtime_root/library"
build_root="$runtime_root/va-r3-build"
runtime_manifest="$runtime_root/runtime.dcf"

mkdir -p "$runtime_root" "$build_root"

Rscript --vanilla -e \
  'if (!requireNamespace("tweedie", quietly=TRUE)) quit(status=2)' || {
  echo "The suggested R package 'tweedie' is required before preparation." >&2
  exit 6
}

if [[ ! -d "$package_lib/gllvmTMB" ]]; then
  stage="$runtime_root/.library-stage-$$"
  [[ ! -e "$stage" ]] || { echo "staging library already exists: $stage" >&2; exit 7; }
  mkdir -p "$stage"
  R CMD INSTALL --no-multiarch --with-keep.source --library="$stage" "$REPO_ROOT"
  [[ -d "$stage/gllvmTMB" ]] || { echo "package installation did not materialise" >&2; exit 7; }
  if ! mv "$stage" "$package_lib"; then
    echo "could not atomically publish installed package library" >&2
    exit 7
  fi
fi

export GLLVMTMB_VA_R3_BUILD_ROOT="$build_root"
Rscript --vanilla "$DRIVER" --mode=runtime-manifest \
  --gate-receipt="$GATE_E_RECEIPT" \
  --package-lib="$package_lib" --build-root="$build_root" \
  --runtime-manifest="$runtime_manifest"

Rscript --vanilla "$DRIVER" --mode=verify-runtime \
  --gate-receipt="$GATE_E_RECEIPT" \
  --runtime-manifest="$runtime_manifest"

cat <<EOF
Runtime installed and manifest verified; no fit was run.
VA_PACKAGE_LIB=$package_lib
GLLVMTMB_VA_R3_BUILD_ROOT=$build_root
VA_RUNTIME_MANIFEST=$runtime_manifest
EOF
