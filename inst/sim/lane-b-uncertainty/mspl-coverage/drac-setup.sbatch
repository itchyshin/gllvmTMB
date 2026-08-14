#!/usr/bin/env bash
#SBATCH --account=def-snakagaw_cpu
#SBATCH --job-name=msplcov_setup
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mspl-coverage.sh
source "$SCRIPT_DIR/lib-mspl-coverage.sh"

mspl_validate_common_inputs
mspl_load_modules
mspl_prepare_workdir
mspl_stage_source_archive
mspl_stage_source_bundle
mspl_install_native_runtime
mspl_archive_native_runtime
mspl_write_setup_receipt
printf 'runtime_environment=%s\n' "${MSPL_COVERAGE_RUNTIME_ARCHIVE%.tar.gz}.env"
