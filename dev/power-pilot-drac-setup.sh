#!/usr/bin/env bash
# Prepare a DRAC login-node checkout for power-pilot SLURM smoke jobs.
#
# Run this from the gllvmTMB repository root on a DRAC login node before
# submitting fit-running jobs. It creates a version-pinned user R library,
# installs this checkout into it, and verifies that library(gllvmTMB) works.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash dev/power-pilot-drac-setup.sh

Environment variables:
  R_MODULE          R module to load             (default: r/4.5.0)
  JULIA_MODULE      Julia module to load         (default: julia/1.12.5)
  COMPILER_MODULE   optional compiler module     (default: unset)
  DRAC_EXTRA_MODULES optional modules to load first (default: unset)
  R_LIBS_USER_DIR   user R library               (default: $PROJECT/$USER/R/<R>, else $SCRATCH/gllvmtmb-r-libs/<R>, else $HOME/.local/R/<R>)
  CRAN_REPO         CRAN mirror                  (default: https://cloud.r-project.org)
  INSTALL_PACKAGE   true | false                 (default: true)

Examples:
  # Prepare the default fir library from a checked-out repo on the login node.
  bash dev/power-pilot-drac-setup.sh

  # Use an explicit library without recording private project paths in docs.
  R_LIBS_USER_DIR=$SCRATCH/gllvmtmb-r-libs/4.5.0 bash dev/power-pilot-drac-setup.sh

Boundaries:
  - Run this on a login node, not inside thousands of array tasks.
  - It prepares R package dependencies only; it launches no fits and submits no jobs.
  - No account, quota, or private allocation value is written into the repository.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

R_MODULE="${R_MODULE:-r/4.5.0}"
JULIA_MODULE="${JULIA_MODULE:-julia/1.12.5}"
DRAC_EXTRA_MODULES="${DRAC_EXTRA_MODULES:-}"
CRAN_REPO="${CRAN_REPO:-https://cloud.r-project.org}"
INSTALL_PACKAGE="${INSTALL_PACKAGE:-true}"
R_MODULE_VERSION="${R_MODULE##*/}"

if [[ -n "${COMPILER_MODULE:-}" ]]; then
  module load "$COMPILER_MODULE"
fi
if [[ -n "$DRAC_EXTRA_MODULES" ]]; then
  module load $DRAC_EXTRA_MODULES
fi
module load "$R_MODULE"
module load "$JULIA_MODULE"

if [[ -n "${EBROOTUDUNITS:-}" ]]; then
  export UDUNITS2_INCLUDE="${UDUNITS2_INCLUDE:-$EBROOTUDUNITS/include}"
  if [[ -d "$EBROOTUDUNITS/lib64" ]]; then
    export UDUNITS2_LIBS="${UDUNITS2_LIBS:-$EBROOTUDUNITS/lib64}"
  else
    export UDUNITS2_LIBS="${UDUNITS2_LIBS:-$EBROOTUDUNITS/lib}"
  fi
fi
if command -v gdal-config >/dev/null 2>&1; then
  export GDAL_CONFIG="${GDAL_CONFIG:-$(command -v gdal-config)}"
fi
if command -v geos-config >/dev/null 2>&1; then
  export GEOS_CONFIG="${GEOS_CONFIG:-$(command -v geos-config)}"
fi

if [[ -z "${R_LIBS_USER_DIR:-}" ]]; then
  if [[ -n "${PROJECT:-}" ]]; then
    R_LIBS_USER_DIR="$PROJECT/$USER/R/$R_MODULE_VERSION"
  elif [[ -n "${SCRATCH:-}" ]]; then
    R_LIBS_USER_DIR="$SCRATCH/gllvmtmb-r-libs/$R_MODULE_VERSION"
  elif [[ -n "${HOME:-}" ]]; then
    R_LIBS_USER_DIR="$HOME/.local/R/$R_MODULE_VERSION"
  else
    echo "Set R_LIBS_USER_DIR, PROJECT, SCRATCH, or HOME before running setup." >&2
    exit 2
  fi
fi

mkdir -p "$R_LIBS_USER_DIR"
export R_LIBS_USER="$R_LIBS_USER_DIR"
if [[ -n "${R_LIBS:-}" ]]; then
  export R_LIBS="$R_LIBS_USER:$R_LIBS"
else
  export R_LIBS="$R_LIBS_USER"
fi
export CRAN_REPO
export INSTALL_PACKAGE

echo "[power-pilot-drac-setup] repo_root=$REPO_ROOT"
echo "[power-pilot-drac-setup] modules R=$R_MODULE Julia=$JULIA_MODULE"
if [[ -n "$DRAC_EXTRA_MODULES" ]]; then
  echo "[power-pilot-drac-setup] extra_modules=$DRAC_EXTRA_MODULES"
fi
echo "[power-pilot-drac-setup] r_libs_user_dir=$R_LIBS_USER_DIR"

Rscript --vanilla - <<'RS'
truthy <- function(x) {
  tolower(as.character(x)) %in% c("true", "1", "yes", "y")
}

repos <- Sys.getenv("CRAN_REPO", "https://cloud.r-project.org")
install_package <- truthy(Sys.getenv("INSTALL_PACKAGE", "true"))

if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes", repos = repos)
}

if (install_package) {
  remotes::install_local(
    ".",
    dependencies = c("Depends", "Imports", "LinkingTo"),
    upgrade = "never",
    build_vignettes = FALSE,
    repos = repos
  )
}

if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
  stop("gllvmTMB is not available from the configured R library.", call. = FALSE)
}

cat(
  "[power-pilot-drac-setup] gllvmTMB_version=",
  as.character(utils::packageVersion("gllvmTMB")),
  "\n",
  sep = ""
)
RS

echo "[power-pilot-drac-setup] ready"
