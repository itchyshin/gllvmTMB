#!/bin/bash
# Submit with R_LIBS_USER=<verified-base-library> sbatch --account=<measured-account> --time=00:20:00 --mem=8G --cpus-per-task=1 --array=3-4%2 drac-qualification.sbatch <root> <lib> <out>
#SBATCH --job-name=isdm-ri-qual
#SBATCH --output=logs/isdm-ri-qual-%A_%a.out
set -euo pipefail
mkdir -p logs
bash "$1/dev/isdm-requalification/response-information/compute/run-qualification.sh" "$1" "$2" "$SLURM_ARRAY_TASK_ID" "$3"
