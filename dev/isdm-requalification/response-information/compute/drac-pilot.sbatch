#!/bin/bash
# Submit only after G3: R_LIBS_USER=<verified-base-library> sbatch --account=<measured-account> --time=00:20:00 --mem=8G --cpus-per-task=1 --array=1-16%16 drac-pilot.sbatch <root> <lib> <out>
#SBATCH --job-name=isdm-ri-pilot
#SBATCH --output=logs/isdm-ri-pilot-%A_%a.out
set -euo pipefail
mkdir -p logs
bash "$1/dev/isdm-requalification/response-information/compute/run-pilot.sh" "$1" "$2" "$SLURM_ARRAY_TASK_ID" "$3"
