#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow_dir=${GLLVMTMB_WORKFLOW_DIR:-"$repo_root/.github/workflows"}

expected=$(printf '%s\n' \
  R-CMD-check.yaml \
  full-check.yaml \
  pkgdown.yaml | LC_ALL=C sort)
actual=$(find "$workflow_dir" -maxdepth 1 -type f \
  \( -name '*.yaml' -o -name '*.yml' \) \
  -exec basename {} \; | LC_ALL=C sort)

if [[ "$actual" != "$expected" ]]; then
  printf '%s\n' \
    'D-50 violation: .github/workflows must contain only package checks and pkgdown.' \
    'Expected:' "$expected" 'Observed:' "$actual" >&2
  exit 1
fi

workflow_files=(
  "$workflow_dir/R-CMD-check.yaml"
  "$workflow_dir/full-check.yaml"
  "$workflow_dir/pkgdown.yaml"
)

if grep -En 'uses:[[:space:]]*actions/upload-artifact@' "${workflow_files[@]}"; then
  printf '%s\n' \
    'D-50 violation: direct Actions artifacts are prohibited; pkgdown Pages is the only artifact route.' >&2
  exit 1
fi

for package_workflow in \
  "$workflow_dir/R-CMD-check.yaml" \
  "$workflow_dir/full-check.yaml"; do
  if ! grep -Eq '^[[:space:]]+upload-snapshots:[[:space:]]+false[[:space:]]*$' "$package_workflow"; then
    printf 'D-50 violation: %s must set upload-snapshots: false.\n' "$package_workflow" >&2
    exit 1
  fi
  if ! grep -Eq '^[[:space:]]+upload-results:[[:space:]]+never[[:space:]]*$' "$package_workflow"; then
    printf 'D-50 violation: %s must set upload-results: never.\n' "$package_workflow" >&2
    exit 1
  fi
done

if grep -En 'uses:[[:space:]]*actions/upload-pages-artifact@' \
  "$workflow_dir/R-CMD-check.yaml" "$workflow_dir/full-check.yaml"; then
  printf '%s\n' 'D-50 violation: only pkgdown may upload a Pages artifact.' >&2
  exit 1
fi

printf '%s\n' 'GitHub Actions boundary PASS: R-CMD-check, full-check, and pkgdown only; no package-check artifacts.'
