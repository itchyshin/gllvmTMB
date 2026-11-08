#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow_dir=${GLLVMTMB_WORKFLOW_DIR:-"$repo_root/.github/workflows"}

expected=$(printf '%s\n' \
  R-CMD-check.yaml \
  codecov-upload.yaml \
  full-check.yaml \
  pkgdown.yaml \
  test-coverage.yaml | LC_ALL=C sort)
actual=$(find "$workflow_dir" -maxdepth 1 -type f \
  \( -name '*.yaml' -o -name '*.yml' \) \
  -exec basename {} \; | LC_ALL=C sort)

if [[ "$actual" != "$expected" ]]; then
  printf '%s\n' \
    'D-50 violation: .github/workflows must contain only package checks, pkgdown, and the Codecov line-coverage pair.' \
    'Expected:' "$expected" 'Observed:' "$actual" >&2
  exit 1
fi

# Active (non-comment) lines only. A commented CODECOV_TOKEN must not satisfy
# or fail a gate by itself.
active_text() {
  grep -Ev '^[[:space:]]*(#|$)' "$1"
}

package_check_workflows=(
  "$workflow_dir/R-CMD-check.yaml"
  "$workflow_dir/full-check.yaml"
)

# Direct Actions artifacts remain forbidden on package-check and pkgdown jobs.
# test-coverage.yaml may keep 7-day coberturas; codecov-upload.yaml downloads
# those artifacts but must not create new GitHub artifacts.
if grep -En 'uses:[[:space:]]*actions/upload-artifact@' \
  "${package_check_workflows[@]}" \
  "$workflow_dir/pkgdown.yaml" \
  "$workflow_dir/codecov-upload.yaml"; then
  printf '%s\n' \
    'D-50 violation: direct Actions artifacts are prohibited on package-check, pkgdown, and codecov-upload jobs.' >&2
  exit 1
fi

for package_workflow in "${package_check_workflows[@]}"; do
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
  "${package_check_workflows[@]}" \
  "$workflow_dir/test-coverage.yaml" \
  "$workflow_dir/codecov-upload.yaml"; then
  printf '%s\n' 'D-50 violation: only pkgdown may upload a Pages artifact.' >&2
  exit 1
fi

producer="$workflow_dir/test-coverage.yaml"
producer_active=$(active_text "$producer")
if grep -Eq 'id-token|CODECOV_TOKEN|codecov/|pull_request_target' <<<"$producer_active"; then
  printf '%s\n' \
    'D-50 violation: test-coverage.yaml must not hold OIDC, a Codecov token, codecov-action, or pull_request_target.' >&2
  exit 1
fi
if ! grep -Eq 'GLLVMTMB_TEST_SHARD' <<<"$producer_active"; then
  printf '%s\n' 'D-50 violation: test-coverage.yaml must partition with GLLVMTMB_TEST_SHARD.' >&2
  exit 1
fi
if ! grep -Eq 'retention-days:[[:space:]]*7' <<<"$producer_active"; then
  printf '%s\n' 'D-50 violation: test-coverage.yaml artifacts must use 7-day retention.' >&2
  exit 1
fi
if grep -Eq 'GLLVMTMB_HEAVY_TESTS' <<<"$producer_active"; then
  printf '%s\n' \
    'D-50 violation: test-coverage.yaml must not enable heavy tests; it measures the fast suite only.' >&2
  exit 1
fi

uploader="$workflow_dir/codecov-upload.yaml"
uploader_active=$(active_text "$uploader")
if ! grep -Eq 'id-token:[[:space:]]*write' <<<"$uploader_active"; then
  printf '%s\n' 'D-50 violation: codecov-upload.yaml must use job-level id-token: write.' >&2
  exit 1
fi
if ! grep -Eq 'use_oidc:[[:space:]]*true' <<<"$uploader_active"; then
  printf '%s\n' 'D-50 violation: codecov-upload.yaml must set use_oidc: true.' >&2
  exit 1
fi
if ! grep -Fq "github.event.workflow_run.event == 'push' &&" <<<"$uploader_active"; then
  printf '%s\n' 'D-50 violation: codecov-upload.yaml must require a main push workflow_run.' >&2
  exit 1
fi
if grep -Eq 'CODECOV_TOKEN|pull_request_target|secrets.CODECOV_TOKEN' <<<"$uploader_active"; then
  printf '%s\n' \
    'D-50 violation: codecov-upload.yaml must not read CODECOV_TOKEN or use pull_request_target.' >&2
  exit 1
fi

printf '%s\n' \
  'GitHub Actions boundary PASS: R-CMD-check, full-check, pkgdown, test-coverage, and codecov-upload; package-check artifacts remain forbidden; coverage coberturas are 7-day only.'
