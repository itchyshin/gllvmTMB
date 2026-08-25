#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: prepare-remote-host.sh HOST_CLASS DEPLOY_ROOT" >&2
  exit 64
fi

host_class=$1
deploy_root=$2
host=$(hostname -f)

case "$host_class:$host" in
  totoro:totoro.biology.ualberta.ca)
    expected_deploy=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/deployment
    packets="PVT02 CI09 CI13 CI14 CI15"
    ;;
  fir:fir.alliancecan.ca)
    expected_deploy=/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/deployment
    packets="CI10_COST"
    ;;
  *)
    echo "deployment host is outside the approved Totoro/Fir envelope" >&2
    exit 65
    ;;
esac

if [ "$deploy_root" != "$expected_deploy" ]; then
  echo "deployment root differs from the approved immutable root" >&2
  exit 65
fi

base_root=$(dirname "$deploy_root")
bundle=$deploy_root/gllvmTMB-interval-dispatch.bundle
spec=$deploy_root/approved-dispatch.tsv
checksums=$deploy_root/remote-payload-checksums.sha256
orchestrator_root=$base_root/orchestrator
branch=codex/interval-calibration-release

cd "$deploy_root"
sha256sum -c "$checksums"

field() {
  key=$1
  value=$(awk -F '\t' -v key="$key" '$1 == key {print $2}' "$spec")
  count=$(awk -F '\t' -v key="$key" '$1 == key {n += 1} END {print n + 0}' "$spec")
  if [ "$count" -ne 1 ] || [ -z "$value" ]; then
    echo "approved-dispatch.tsv must contain exactly one $key" >&2
    exit 65
  fi
  printf '%s\n' "$value"
}

schema=$(field schema)
expected_sha=$(field orchestrator_sha)
expected_branch=$(field branch)
if [ "$schema" != "INTERVAL_CALIBRATION_APPROVED_DISPATCH_V1" ] || \
   [ "$expected_branch" != "$branch" ]; then
  echo "approved dispatch schema or branch is invalid" >&2
  exit 65
fi

bundle_sha=$(git ls-remote "$bundle" "refs/heads/$branch" | awk '{print $1}')
if [ "$bundle_sha" != "$expected_sha" ]; then
  echo "portable bundle branch tip differs from approved dispatch" >&2
  exit 65
fi

if [ ! -e "$orchestrator_root" ]; then
  git clone --quiet --branch "$branch" --single-branch \
    "$bundle" "$orchestrator_root"
fi
if [ "$(git -C "$orchestrator_root" rev-parse HEAD)" != "$expected_sha" ] || \
   [ -n "$(git -C "$orchestrator_root" status --porcelain --untracked-files=all)" ]; then
  echo "orchestration checkout is not the exact clean approved commit" >&2
  exit 65
fi

mkdir -p "$base_root/scientific" "$base_root/libraries"
for packet in $packets; do
  source_sha=$(Rscript --vanilla -e \
    'source(commandArgs(TRUE)[1]); cat(interval_approved_source(commandArgs(TRUE)[2]))' \
    "$orchestrator_root/dev/interval-calibration/remote/shard-io.R" "$packet")
  scientific_root=$base_root/scientific/$source_sha
  library_root=$base_root/libraries/$source_sha
  if [ ! -e "$scientific_root" ]; then
    git -C "$orchestrator_root" worktree add --quiet --detach \
      "$scientific_root" "$source_sha"
  fi
  if [ "$(git -C "$scientific_root" rev-parse HEAD)" != "$source_sha" ] || \
     git -C "$scientific_root" symbolic-ref -q HEAD >/dev/null 2>&1 || \
     [ -n "$(git -C "$scientific_root" status --porcelain --untracked-files=all)" ]; then
    echo "scientific checkout is not exact, detached, and clean: $source_sha" >&2
    exit 65
  fi
  if [ ! -e "$library_root" ]; then
    sh "$orchestrator_root/dev/interval-calibration/remote/install-packet-library.sh" \
      "$packet" "$scientific_root" "$library_root" "$orchestrator_root"
  else
    R_LIBS_USER=$library_root Rscript --vanilla -e \
      'source(commandArgs(TRUE)[1]); interval_assert_installed_package(commandArgs(TRUE)[2])' \
      "$orchestrator_root/dev/interval-calibration/remote/shard-io.R" "$source_sha"
  fi
done

receipt=$deploy_root/prepared-$host_class.tsv
if [ -e "$receipt" ]; then
  echo "host preparation receipt already exists" >&2
  exit 65
fi
{
  printf 'schema\tINTERVAL_CALIBRATION_HOST_PREPARED_V1\n'
  printf 'host_class\t%s\n' "$host_class"
  printf 'host\t%s\n' "$host"
  printf 'orchestrator_sha\t%s\n' "$expected_sha"
  printf 'prepared_at_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$receipt"
printf 'INTERVAL_HOST_PREPARED %s\n' "$receipt"
