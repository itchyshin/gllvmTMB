#!/usr/bin/env bash
# Pure-shell fail-closed checks for launcher-only contracts. No R or scheduler.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-mspl-coverage.sh
source "$SCRIPT_DIR/lib-mspl-coverage.sh"

TEST_ROOT="$(mktemp -d /private/tmp/mspl-coverage-contract.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT"
MANIFEST="$TEST_ROOT/manifest.csv"
PRE_RUN_MAP="$TEST_ROOT/pre-run-array-map.tsv"
BAD_MAP="$TEST_ROOT/bad-pre-run-array-map.tsv"
BAD_MANIFEST="$TEST_ROOT/downgraded-manifest.csv"

printf 'case_id,case_number,regime,link,beta_shift,lambda_scale,seed_base,n_outer,bootstrap_reps,minimum_usable_bootstrap,outer_per_shard,n_shards,assigned_cluster,availability_min,coverage_wilson_level,coverage_equivalence_lower,coverage_equivalence_upper,wald_min_available,manifest_version,campaign_id,source_sha\n' > "$MANIFEST"
printf 'array_index\tcase_id\tshard_id\n' > "$PRE_RUN_MAP"
printf 'array_index\tcase_id\tshard_id\n' > "$BAD_MAP"
for i in $(seq 1 12); do
  case_id="$(printf 'C%03d' "$i")"
  regime_index=$(( (i - 1) % 4 + 1 ))
  case "$regime_index" in
    1) regime=baseline; beta_shift=0; lambda_scale=1 ;;
    2) regime=low_prevalence; beta_shift=-1.5; lambda_scale=1 ;;
    3) regime=high_prevalence; beta_shift=1.5; lambda_scale=1 ;;
    4) regime=strong_signal; beta_shift=0; lambda_scale=1.75 ;;
  esac
  if [[ "$i" -le 4 ]]; then link=logit; elif [[ "$i" -le 8 ]]; then link=probit; else link=cloglog; fi
  if [[ "$i" -le 6 ]]; then cluster=nibi; elif [[ "$i" -le 10 ]]; then cluster=narval; else cluster=rorqual; fi
  seed_base=$((1900000000 + i * 10000000))
  printf '%s,%d,%s,%s,%s,%s,%d,1000,500,475,10,100,%s,0.95,0.90,0.92,0.98,500,lane-b-mspl-coverage-gate0-v1-2026-08-14,test-campaign,test-source\n' \
    "$case_id" "$i" "$regime" "$link" "$beta_shift" "$lambda_scale" "$seed_base" "$cluster" >> "$MANIFEST"
  if [[ "$i" -lt 12 ]]; then
    printf '%d\t%s\t1\n' "$i" "$case_id" >> "$PRE_RUN_MAP"
  else
    printf '%d\t%s\t1' "$i" "$case_id" >> "$PRE_RUN_MAP"
  fi
  bad_shard=1
  [[ "$i" -eq 12 ]] && bad_shard=2
  printf '%d\t%s\t%d\n' "$i" "$case_id" "$bad_shard" >> "$BAD_MAP"
done

MSPL_COVERAGE_ROOT="$TEST_ROOT"
export MSPL_COVERAGE_ROOT
mspl_validate_production_manifest "$MANIFEST"
awk -F, 'BEGIN { OFS = "," } NR == 1 { print; next } { if (NR == 7) $9 = 2; print }' "$MANIFEST" > "$BAD_MANIFEST"
if (mspl_validate_production_manifest "$BAD_MANIFEST") >/dev/null 2>&1; then
  mspl_die "Self-test failure: downgraded bootstrap manifest was accepted."
fi
mspl_validate_prerun_map "$PRE_RUN_MAP"
if (mspl_validate_prerun_map "$BAD_MAP") >/dev/null 2>&1; then
  mspl_die "Self-test failure: invalid Gate 4 pre-run map was accepted."
fi

CONTRACT="$TEST_ROOT/runtime-library.contract"
printf 'cluster=nibi\nsource_sha=test-source\nsource_archive_sha256=source-archive-hash\nsource_bundle_sha256=source-bundle-hash\narchitecture=%s\n' "$(uname -m)" > "$CONTRACT"
MSPL_COVERAGE_CLUSTER=nibi
MSPL_COVERAGE_SOURCE_SHA=test-source
MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256=source-archive-hash
MSPL_COVERAGE_SOURCE_BUNDLE_SHA256=source-bundle-hash
export MSPL_COVERAGE_CLUSTER MSPL_COVERAGE_SOURCE_SHA \
  MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 MSPL_COVERAGE_SOURCE_BUNDLE_SHA256
mspl_verify_runtime_contract "$CONTRACT"
MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256=wrong-source-archive-hash
export MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256
if (mspl_verify_runtime_contract "$CONTRACT") >/dev/null 2>&1; then
  mspl_die "Self-test failure: source-archive/runtime mismatch was accepted."
fi

printf 'launcher-contract-self-test=PASS\n'
