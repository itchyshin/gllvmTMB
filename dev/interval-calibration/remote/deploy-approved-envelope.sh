#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: deploy-approved-envelope.sh ACTION DISPATCH_ROOT" >&2
  echo "actions: prepare-totoro prepare-fir launch-totoro launch-fir status-totoro status-fir" >&2
  exit 64
fi

action=$1
dispatch_root=$(cd "$2" && pwd)
totoro_host=snakagaw@totoro.biology.ualberta.ca
fir_host=snakagaw@fir.alliancecan.ca
totoro_socket=/Users/z3437171/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22
fir_socket=/Users/z3437171/.ssh/cm-snakagaw@fir.alliancecan.ca:22
totoro_deploy=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/deployment
fir_deploy=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/deployment
fir_dependency_library=/home/snakagaw/R/lane_b_4.5

ssh_reuse() {
  socket=$1
  host=$2
  shift 2
  if [ ! -S "$socket" ]; then
    echo "approved ControlMaster socket is absent: $socket" >&2
    exit 69
  fi
  ssh -S "$socket" -O check "$host" >/dev/null
  ssh -S "$socket" \
    -o ControlMaster=no -o BatchMode=yes \
    -o PreferredAuthentications=none \
    -o KbdInteractiveAuthentication=no -o PasswordAuthentication=no \
    -o PubkeyAuthentication=no \
    "$host" "$@"
}

scp_reuse() {
  socket=$1
  shift
  scp -q -o ControlPath="$socket" -o ControlMaster=no -o BatchMode=yes \
    -o PreferredAuthentications=none \
    -o KbdInteractiveAuthentication=no -o PasswordAuthentication=no \
    -o PubkeyAuthentication=no \
    "$@"
}

verify_local_payload() {
  (cd "$dispatch_root" && shasum -a 256 -c remote-payload-checksums.sha256)
  expected_sha=$(awk -F '\t' '$1 == "orchestrator_sha" {print $2}' "$dispatch_root/approved-dispatch.tsv")
  expected_branch=$(awk -F '\t' '$1 == "branch" {print $2}' "$dispatch_root/approved-dispatch.tsv")
  if [ -z "$expected_sha" ] || \
     [ "$expected_branch" != "codex/interval-calibration-release" ]; then
    echo "local approved-dispatch.tsv is invalid" >&2
    exit 65
  fi
  bundle_sha=$(git ls-remote "$dispatch_root/gllvmTMB-interval-dispatch.bundle" \
    "refs/heads/$expected_branch" | awk '{print $1}')
  if [ "$bundle_sha" != "$expected_sha" ]; then
    echo "local bundle does not match approved-dispatch.tsv" >&2
    exit 65
  fi
}

prepare_host() {
  host_class=$1
  socket=$2
  host=$3
  deploy=$4
  base=$(dirname "$deploy")
  staging=$deploy.staging
  verify_local_payload
  ssh_reuse "$socket" "$host" \
    "set -eu; umask 077; mkdir -p '$base'; test ! -e '$deploy'; if ! mkdir '$staging'; then echo 'deployment staging root is already reserved' >&2; exit 65; fi; mkdir '$staging/manifests'"
  scp_reuse "$socket" \
    "$dispatch_root/gllvmTMB-interval-dispatch.bundle" \
    "$dispatch_root/approved-dispatch.tsv" \
    "$dispatch_root/remote-payload-checksums.sha256" \
    "$dispatch_root/prepare-remote-host.sh" \
    "$host:$staging/"
  for manifest in "$dispatch_root"/manifests/*-tasks.tsv; do
    scp_reuse "$socket" "$manifest" "$host:$staging/manifests/"
  done
  ssh_reuse "$socket" "$host" \
    "set -eu; cd '$staging'; sha256sum -c remote-payload-checksums.sha256; mv '$staging' '$deploy'; bash '$deploy/prepare-remote-host.sh' '$host_class' '$deploy'"
}

case "$action" in
  prepare-totoro)
    prepare_host totoro "$totoro_socket" "$totoro_host" "$totoro_deploy"
    ;;
  prepare-fir)
    prepare_host fir "$fir_socket" "$fir_host" "$fir_deploy"
    ;;
  launch-totoro)
    ssh_reuse "$totoro_socket" "$totoro_host" \
      "set -eu; test -f '$totoro_deploy/prepared-totoro.tsv'; cd '$(dirname "$totoro_deploy")/orchestrator'; nohup sh dev/interval-calibration/remote/run-approved-totoro-sequence.sh >>'$totoro_deploy/totoro-launch.log' 2>&1 </dev/null & echo \$!"
    ;;
  launch-fir)
    fir_base=$(dirname "$fir_deploy")
    ssh_reuse "$fir_socket" "$fir_host" \
      "set -eu; . /cvmfs/soft.computecanada.ca/custom/software/lmod/lmod/init/bash; module load StdEnv/2023 gcc/12.3 r/4.5.0; test -f '$fir_deploy/prepared-fir.tsv'; cd '$fir_deploy'; sha256sum -c remote-payload-checksums.sha256; expected_sha=\$(awk -F '\t' '\$1 == \"orchestrator_sha\" {print \$2}' approved-dispatch.tsv); test -n \"\$expected_sha\"; fir_orchestrator='$fir_base/orchestrators/'\$expected_sha; test \"\$(git -C \"\$fir_orchestrator\" rev-parse HEAD)\" = \"\$expected_sha\"; test -z \"\$(git -C \"\$fir_orchestrator\" status --porcelain --untracked-files=all)\"; source_sha=\$(Rscript --vanilla -e 'source(commandArgs(TRUE)[1]); cat(interval_approved_source(\"CI10_COST\"))' \"\$fir_orchestrator/dev/interval-calibration/remote/shard-io.R\"); fir_libraries='$fir_base/libraries/'\$source_sha':$fir_dependency_library'; bash \"\$fir_orchestrator/dev/interval-calibration/remote/prepare-ci10-cost-array.sh\" \"\$fir_orchestrator\" '$fir_deploy/manifests/ci10_cost-tasks.tsv' '$fir_base/ci10-cost-array' \"\$fir_libraries\""
    ;;
  status-totoro)
    ssh_reuse "$totoro_socket" "$totoro_host" \
      "set -eu; ls -ld '$totoro_deploy/totoro-sequence-lock' 2>/dev/null || true; ls -l '$totoro_deploy'/*sequence*.tsv 2>/dev/null || true; echo TOTORO_LAUNCH_LOG; tail -n 80 '$totoro_deploy/totoro-launch.log' 2>/dev/null || true; echo TOTORO_SEQUENCE_LOG; tail -n 80 '$totoro_deploy/totoro-sequence.log' 2>/dev/null || true"
    ;;
  status-fir)
    ssh_reuse "$fir_socket" "$fir_host" \
      "set -eu; squeue -u snakagaw || true; find '$(dirname "$fir_deploy")/ci10-cost-array' -maxdepth 2 -type f 2>/dev/null | sort | tail -n 80 || true"
    ;;
  *)
    echo "unknown action: $action" >&2
    exit 64
    ;;
esac
