#!/usr/bin/env bash
set -u

if [ "$#" -ne 7 ]; then
  echo "usage: capture-source-qualification.sh VERSION JULIA_HOME JULIA_DEPOT GLLVM_PATH ARTIFACT_ROOT RUN_ROOT SCRIPT_ROOT" >&2
  exit 64
fi

version=$1
julia_home=$2
julia_depot=$3
gllvm_path=$4
artifact_root=$5
run_root=$6
script_root=$7
slug=$(printf '%s' "$version" | tr '.' '_')
process_root="$artifact_root/process"
mkdir -p "$process_root"

direct_stdout="process/julia-${slug}-direct.stdout.log"
direct_stderr="process/julia-${slug}-direct.stderr.log"
bridge_stdout="process/julia-${slug}-bridge.stdout.log"
bridge_stderr="process/julia-${slug}-bridge.stderr.log"
receipt="process/julia-${slug}.receipt"

started_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
direct_command="env JULIA_DEPOT_PATH=$julia_depot $julia_home/julia --startup-file=no --project=$gllvm_path -e using_GLLVM_bridge_capabilities"
set +e
env JULIA_DEPOT_PATH="$julia_depot" \
  "$julia_home/julia" --startup-file=no --project="$gllvm_path" \
  -e 'using GLLVM; println("JULIA_VERSION=", VERSION); println("BRIDGE_CAPABILITIES=", GLLVM.bridge_capabilities())' \
  >"$artifact_root/$direct_stdout" 2>"$artifact_root/$direct_stderr"
direct_status=$?

bridge_command="env R_LIBS_USER=$run_root/Rlib:$HOME/R/lib JULIA_DEPOT_PATH=$julia_depot JULIA_HOME=$julia_home OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript --vanilla $script_root/qualify-two-cell-source.R $artifact_root $run_root $gllvm_path"
env R_LIBS_USER="$run_root/Rlib:$HOME/R/lib" \
  JULIA_DEPOT_PATH="$julia_depot" \
  JULIA_HOME="$julia_home" \
  OPENBLAS_NUM_THREADS=1 \
  OMP_NUM_THREADS=1 \
  Rscript --vanilla "$script_root/qualify-two-cell-source.R" \
  "$artifact_root" "$run_root" "$gllvm_path" \
  >"$artifact_root/$bridge_stdout" 2>"$artifact_root/$bridge_stderr"
bridge_status=$?
set -e
finished_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

{
  printf 'schema=bridge-source-qualification-v1\n'
  printf 'version=%s\n' "$version"
  printf 'julia_home=%s\n' "$julia_home"
  printf 'julia_depot=%s\n' "$julia_depot"
  printf 'gllvm_path=%s\n' "$gllvm_path"
  printf 'started_at=%s\n' "$started_at"
  printf 'finished_at=%s\n' "$finished_at"
  printf 'direct_command=%s\n' "$direct_command"
  printf 'direct_stdout=%s\n' "$direct_stdout"
  printf 'direct_stderr=%s\n' "$direct_stderr"
  printf 'direct_exit_status=%s\n' "$direct_status"
  printf 'bridge_command=%s\n' "$bridge_command"
  printf 'bridge_stdout=%s\n' "$bridge_stdout"
  printf 'bridge_stderr=%s\n' "$bridge_stderr"
  printf 'bridge_exit_status=%s\n' "$bridge_status"
  printf 'fit_started=false\n'
} >"$artifact_root/$receipt"

printf 'QUALIFICATION_RECEIPT=%s DIRECT_EXIT=%s BRIDGE_EXIT=%s\n' "$receipt" "$direct_status" "$bridge_status"
exit 0
