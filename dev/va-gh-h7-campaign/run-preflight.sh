#!/usr/bin/env bash
set -euo pipefail

# Fit-running preflight. On DRAC this must run inside an allocation; on Totoro
# it may run directly. The explicit context prevents accidental login-node fits.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER="$SCRIPT_DIR/run-cell.R"

: "${GATE_E_RECEIPT:?Set GATE_E_RECEIPT to the structured Gate-E receipt}"
: "${VA_RUNTIME_MANIFEST:?Set VA_RUNTIME_MANIFEST to runtime.dcf}"
: "${VA_PREFLIGHT_RECEIPT:?Set VA_PREFLIGHT_RECEIPT to preflight.dcf}"
: "${PREFLIGHT_CONTEXT:?Set PREFLIGHT_CONTEXT to local, totoro, or slurm}"

host_short="$(hostname -s | tr '[:upper:]' '[:lower:]')"
case "$host_short" in
  fir*|nibi*|rorqual*|trillium*|narval*|killarney*|vulcan*|tamia*)
    [[ -n "${SLURM_JOB_ID:-}" ]] || {
      echo "Timed preflight fits are forbidden on DRAC login host $host_short." >&2
      exit 2
    }
    ;;
esac

case "$PREFLIGHT_CONTEXT" in
  local) ;;
  totoro)
    case "$host_short" in totoro*) ;; *)
      echo "PREFLIGHT_CONTEXT=totoro requires a Totoro host (got $host_short)." >&2
      exit 2
    esac
    ;;
  slurm)
    [[ -n "${SLURM_JOB_ID:-}" ]] || {
      echo "PREFLIGHT_CONTEXT=slurm requires an allocated SLURM job." >&2
      exit 2
    }
    ;;
  *) echo "PREFLIGHT_CONTEXT must be local, totoro, or slurm." >&2; exit 2 ;;
esac

export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

# The receipt path is exported for the later fit, but this first check must
# validate only Gate E + the immutable runtime.  An absent preflight receipt is
# the expected state on a first run.
VA_PREFLIGHT_RECEIPT= Rscript --vanilla "$DRIVER" --mode=verify-runtime \
  --gate-receipt="$GATE_E_RECEIPT" \
  --runtime-manifest="$VA_RUNTIME_MANIFEST"

if [[ ! -f "$VA_PREFLIGHT_RECEIPT" ]]; then
  Rscript --vanilla "$DRIVER" --mode=preflight \
    --gate-receipt="$GATE_E_RECEIPT" \
    --runtime-manifest="$VA_RUNTIME_MANIFEST" \
    --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
fi

Rscript --vanilla "$DRIVER" --mode=verify-runtime \
  --gate-receipt="$GATE_E_RECEIPT" \
  --runtime-manifest="$VA_RUNTIME_MANIFEST" \
  --preflight-receipt="$VA_PREFLIGHT_RECEIPT"
