#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: install-packet-library.sh PACKET DETACHED_SOURCE LIBRARY_ROOT ORCHESTRATOR_ROOT" >&2
  exit 64
fi
packet=$1
scientific_root=$2
library_root=$3
orchestrator_root=$4
dependency_libraries=${R_LIBS_USER-}

source_sha=$(Rscript --vanilla -e \
  'source(commandArgs(TRUE)[1]); cat(interval_approved_source(commandArgs(TRUE)[2]))' \
  "$orchestrator_root/dev/interval-calibration/remote/shard-io.R" "$packet")
head_sha=$(git -C "$scientific_root" rev-parse HEAD)
if [ "$head_sha" != "$source_sha" ]; then
  echo "detached scientific checkout does not equal approved source" >&2
  exit 65
fi
if git -C "$scientific_root" symbolic-ref -q HEAD >/dev/null 2>&1; then
  echo "scientific checkout must be detached at the approved commit" >&2
  exit 65
fi
if [ -n "$(git -C "$scientific_root" status --porcelain --untracked-files=all)" ]; then
  echo "refusing dirty or untracked detached scientific checkout" >&2
  exit 65
fi
if [ -e "$library_root" ]; then
  echo "refusing existing packet library root: $library_root" >&2
  exit 65
fi
mkdir -p "$library_root"
R CMD INSTALL --preclean --clean --library="$library_root" "$scientific_root"
if [ -n "$(git -C "$scientific_root" status --porcelain --untracked-files=all)" ]; then
  echo "scientific checkout changed during package installation" >&2
  exit 65
fi
package_path=$(Rscript --vanilla -e \
  '.libPaths(commandArgs(TRUE)[1]); cat(find.package("gllvmTMB"))' \
  "$library_root")
printf '%s\n' "$source_sha" > "$package_path/.interval-scientific-source-sha"
campaign_libraries=$library_root
if [ -n "$dependency_libraries" ]; then
  campaign_libraries=$library_root:$dependency_libraries
fi
R_LIBS_USER="$campaign_libraries" Rscript --vanilla -e \
  'source(commandArgs(TRUE)[1]); interval_assert_installed_package(commandArgs(TRUE)[2]); cat("INTERVAL_LIBRARY_OK\n")' \
  "$orchestrator_root/dev/interval-calibration/remote/shard-io.R" "$source_sha"
