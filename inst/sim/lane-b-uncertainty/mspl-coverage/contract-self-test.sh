#!/usr/bin/env bash
# Fail-closed launcher checks. The real runner only generates manifests; no fit or scheduler runs.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/../run-mspl-coverage-calibration.R"
# shellcheck source=lib-mspl-coverage.sh
source "$SCRIPT_DIR/lib-mspl-coverage.sh"

command -v Rscript >/dev/null || mspl_die "Self-test requires Rscript to generate exact runner manifests."
[[ -f "$RUNNER" ]] || mspl_die "Self-test cannot find the MSPL coverage runner: $RUNNER"

TEST_ROOT="$(mktemp -d /private/tmp/mspl-coverage-contract.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT"
MANIFEST="$TEST_ROOT/manifest.csv"
PRE_RUN_MAP="$TEST_ROOT/pre-run-array-map.tsv"
BAD_MAP="$TEST_ROOT/bad-pre-run-array-map.tsv"
BAD_MANIFEST="$TEST_ROOT/downgraded-manifest.csv"
QUOTED_PRODUCTION_ROOT="$TEST_ROOT/quoted-production"
QUOTED_SMOKE_ROOT="$TEST_ROOT/quoted-smoke"
QUOTED_NO_FINAL_NEWLINE="$TEST_ROOT/quoted-production-no-final-newline.csv"
BAD_REMAINING_MAP="$TEST_ROOT/bad-remaining-production-array-map.tsv"
UNSAFE_IDENTITY_MANIFEST="$TEST_ROOT/unsafe-identity-manifest.csv"

[[ "$(mspl_bootstrap_packages_csv)" == "BH,RcppEigen,TMB" ]] ||
  mspl_die "Self-test failure: bootstrap dependency vector changed."
[[ "$(mspl_remaining_packages_csv)" == "assertthat,cli,fmesher,generics,lifecycle,rlang,tidyselect" ]] ||
  mspl_die "Self-test failure: remaining dependency names were concatenated or reordered."
[[ "$(mspl_dependency_package_lines | paste -sd, -)" == "BH,RcppEigen,TMB,assertthat,cli,fmesher,generics,lifecycle,rlang,tidyselect" ]] ||
  mspl_die "Self-test failure: dependency package parser changed the exact vector."
if (MSPL_COVERAGE_DEPENDENCY_PACKAGES='BH,RcppEigen,TMB,cli,cli' mspl_dependency_package_lines) >/dev/null 2>&1; then
  mspl_die "Self-test failure: duplicate dependency package was accepted."
fi
if (MSPL_COVERAGE_DEPENDENCY_PACKAGES='BH,RcppEigen,TMB,,cli' mspl_dependency_package_lines) >/dev/null 2>&1; then
  mspl_die "Self-test failure: empty dependency package name was accepted."
fi
for consumer in mspl_bootstrap_packages_csv mspl_remaining_packages_csv mspl_source_dependency_inventory; do
  if (MSPL_COVERAGE_DEPENDENCY_PACKAGES='BH,RcppEigen,TMB,cli,cli' "$consumer") >/dev/null 2>&1; then
    mspl_die "Self-test failure: $consumer hid a duplicate trailing dependency."
  fi
  if (MSPL_COVERAGE_DEPENDENCY_PACKAGES='BH,RcppEigen,TMB,cli,bad!' "$consumer") >/dev/null 2>&1; then
    mspl_die "Self-test failure: $consumer hid an invalid trailing dependency."
  fi
  if (MSPL_COVERAGE_DEPENDENCY_PACKAGES='BH,RcppEigen,TMB,cli,' "$consumer") >/dev/null 2>&1; then
    mspl_die "Self-test failure: $consumer hid an empty trailing dependency."
  fi
done
[[ "$(mspl_job_env_record MSPL_COVERAGE_SOURCE_SHA safe-source)" == "MSPL_COVERAGE_SOURCE_SHA=safe-source" ]] ||
  mspl_die "Self-test failure: strict runtime-environment record changed."
if (mspl_job_env_record MSPL_COVERAGE_SOURCE_SHA '$(touch unsafe)') >/dev/null 2>&1; then
  mspl_die "Self-test failure: unsafe runtime-environment data was accepted."
fi

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

# Exercise the exact write.csv-quoted manifests and runner-produced array maps.
Rscript --vanilla "$RUNNER" manifest --root "$QUOTED_PRODUCTION_ROOT" \
  --campaign-id quoted-production --source-sha quoted-source
Rscript --vanilla "$RUNNER" smoke-manifest --root "$QUOTED_SMOKE_ROOT" \
  --campaign-id quoted-smoke --source-sha quoted-source --cluster nibi
mspl_validate_remaining_production_map "$QUOTED_PRODUCTION_ROOT/remaining-production-array-map.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" } NR == 2 { $3 = 1 } { print }' \
  "$QUOTED_PRODUCTION_ROOT/remaining-production-array-map.tsv" > "$BAD_REMAINING_MAP"
if (mspl_validate_remaining_production_map "$BAD_REMAINING_MAP") >/dev/null 2>&1; then
  mspl_die "Self-test failure: production remaining map accepted a reused pre-run shard."
fi
[[ "$(MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" mspl_campaign_id)" == "quoted-production" ]] ||
  mspl_die "Self-test failure: campaign_id lookup rejected a write.csv-quoted header."
awk 'NR == 2 { sub(/"quoted-production"/, "\"bad;identity\"") } { print }' \
  "$QUOTED_PRODUCTION_ROOT/manifest.csv" > "$UNSAFE_IDENTITY_MANIFEST"
if (mspl_manifest_first_field "$UNSAFE_IDENTITY_MANIFEST" campaign_id) >/dev/null 2>&1; then
  mspl_die "Self-test failure: simple CSV lookup accepted unsafe identity grammar."
fi
for task in 1 2 3; do
  case "$task" in
    1) expected_case=C001 ;;
    2) expected_case=C005 ;;
    3) expected_case=C009 ;;
  esac
  observed="$(MSPL_COVERAGE_ROOT="$QUOTED_SMOKE_ROOT" MSPL_COVERAGE_STAGE=smoke \
    MSPL_COVERAGE_CLUSTER=nibi SLURM_ARRAY_TASK_ID="$task" mspl_array_task)"
  [[ "$observed" == "$expected_case"$'\t'"1" ]] ||
    mspl_die "Self-test failure: quoted smoke map task $task resolved to '$observed', expected $expected_case shard 1."
done
[[ "$(MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" MSPL_COVERAGE_STAGE=production \
  MSPL_COVERAGE_CLUSTER=nibi SLURM_ARRAY_TASK_ID=1 mspl_array_task)" == C001$'\t'2 ]] ||
  mspl_die "Self-test failure: production task 1 did not select C001 shard 002 from the remaining map."
[[ "$(MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" MSPL_COVERAGE_STAGE=production \
  MSPL_COVERAGE_CLUSTER=rorqual SLURM_ARRAY_TASK_ID=1188 mspl_array_task)" == C012$'\t'100 ]] ||
  mspl_die "Self-test failure: production task 1188 did not select C012 shard 100 from the remaining map."

# Re-serialize without a terminal newline and verify every frozen production assignment.
awk 'NR > 1 { printf "\n" } { printf "%s", $0 }' \
  "$QUOTED_PRODUCTION_ROOT/manifest.csv" > "$QUOTED_NO_FINAL_NEWLINE"
[[ -s "$QUOTED_NO_FINAL_NEWLINE" ]] || mspl_die "Self-test failure: no-final-newline manifest was not created."
for i in $(seq 1 12); do
  case_id="$(printf 'C%03d' "$i")"
  if [[ "$i" -le 6 ]]; then
    expected_cluster=nibi
  elif [[ "$i" -le 10 ]]; then
    expected_cluster=narval
  else
    expected_cluster=rorqual
  fi
  [[ "$(mspl_manifest_case_field "$QUOTED_PRODUCTION_ROOT/manifest.csv" "$case_id" assigned_cluster)" == "$expected_cluster" ]] ||
    mspl_die "Self-test failure: quoted production manifest assignment disagrees for $case_id."
  [[ "$(mspl_manifest_case_field "$QUOTED_NO_FINAL_NEWLINE" "$case_id" assigned_cluster)" == "$expected_cluster" ]] ||
    mspl_die "Self-test failure: no-final-newline production manifest assignment disagrees for $case_id."
done

# Emulate Slurm by executing spooled script copies outside the launcher bundle.
STAGED_LAUNCHER="$TEST_ROOT/launcher"
SPOOL_DIR="$TEST_ROOT/slurm-spool"
JOB_ENV="$TEST_ROOT/runtime-job.env"
WRONG_HASH_ENV="$TEST_ROOT/wrong-hash.env"
UNKNOWN_ENV="$TEST_ROOT/unknown-key.env"
DUPLICATE_ENV="$TEST_ROOT/duplicate-key.env"
COMMAND_ENV="$TEST_ROOT/command.env"
UNSAFE_ENV="$TEST_ROOT/unsafe-value.env"
MISSING_ENV="$TEST_ROOT/missing-required.env"
COMMAND_MARKER="$TEST_ROOT/job-env-command-ran"
mkdir -p "$STAGED_LAUNCHER" "$SPOOL_DIR"
cp "$SCRIPT_DIR/lib-mspl-coverage.sh" "$STAGED_LAUNCHER/lib-mspl-coverage.sh"
HELPER_SHA256="$(sha256sum "$STAGED_LAUNCHER/lib-mspl-coverage.sh" | awk '{print $1}')"
write_bootstrap_env() {
  local file="$1" helper_hash="$2" source_sha="${3:-}"
  printf 'MSPL_COVERAGE_ROOT=%s\nMSPL_COVERAGE_LAUNCHER_DIR=%s\nMSPL_COVERAGE_HELPER_SHA256=%s\n' \
    "$TEST_ROOT" "$STAGED_LAUNCHER" "$helper_hash" > "$file"
  [[ -z "$source_sha" ]] || printf 'MSPL_COVERAGE_SOURCE_SHA=%s\n' "$source_sha" >> "$file"
}
run_spooled_bootstrap() {
  local script="$1" env_file="$2"
  (
    unset MSPL_COVERAGE_ROOT MSPL_COVERAGE_LAUNCHER_DIR MSPL_COVERAGE_HELPER_SHA256 MSPL_COVERAGE_SOURCE_SHA
    MSPL_COVERAGE_JOB_ENV="$env_file" MSPL_COVERAGE_BOOTSTRAP_ONLY=true \
      bash "$SPOOL_DIR/$script"
  )
}
write_bootstrap_env "$JOB_ENV" "$HELPER_SHA256" test-source
write_bootstrap_env "$WRONG_HASH_ENV" wrong-helper-hash test-source
write_bootstrap_env "$UNKNOWN_ENV" "$HELPER_SHA256" test-source
printf 'MSPL_COVERAGE_UNKNOWN=clean\n' >> "$UNKNOWN_ENV"
write_bootstrap_env "$DUPLICATE_ENV" "$HELPER_SHA256" test-source
printf 'MSPL_COVERAGE_SOURCE_SHA=duplicate\n' >> "$DUPLICATE_ENV"
write_bootstrap_env "$COMMAND_ENV" "$HELPER_SHA256"
printf 'MSPL_COVERAGE_SOURCE_SHA=$(touch %s)\n' "$COMMAND_MARKER" >> "$COMMAND_ENV"
write_bootstrap_env "$UNSAFE_ENV" "$HELPER_SHA256"
printf 'MSPL_COVERAGE_SOURCE_SHA=bad value\n' >> "$UNSAFE_ENV"
write_bootstrap_env "$MISSING_ENV" "$HELPER_SHA256"

for script in drac-setup.sbatch drac-smoke.sbatch drac-array.sbatch; do
  cp "$SCRIPT_DIR/$script" "$SPOOL_DIR/$script"
  run_spooled_bootstrap "$script" "$JOB_ENV" >/dev/null
  for rejected_env in "$UNKNOWN_ENV" "$DUPLICATE_ENV" "$COMMAND_ENV" "$UNSAFE_ENV" "$MISSING_ENV"; do
    if run_spooled_bootstrap "$script" "$rejected_env" >/dev/null 2>&1; then
      mspl_die "Self-test failure: $script accepted unsafe/incomplete job data: $rejected_env"
    fi
  done
done
[[ ! -e "$COMMAND_MARKER" ]] || mspl_die "Self-test failure: job-environment command text executed."
if run_spooled_bootstrap drac-setup.sbatch "$WRONG_HASH_ENV" >/dev/null 2>&1; then
  mspl_die "Self-test failure: spooled setup accepted the wrong helper hash."
fi

# A local statistical aggregation receipt is never the maintainer-approved launcher unlock.
printf 'manifest_md5: local-statistical-only\nlauncher_unlock_eligible: FALSE\n' \
  > "$QUOTED_PRODUCTION_ROOT/gate4-prerun-receipt.txt"
if (MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" MSPL_COVERAGE_STAGE=production \
  MSPL_COVERAGE_SOURCE_SHA=quoted-source mspl_require_gate_receipt) >/dev/null 2>&1; then
  mspl_die "Self-test failure: statistical Gate 4 receipt unlocked production."
fi

CONTRACT="$TEST_ROOT/runtime-library.contract"
printf 'cluster=nibi\nsource_sha=test-source\nsource_archive_sha256=source-archive-hash\nsource_bundle_sha256=source-bundle-hash\nlauncher_helper_sha256=%s\narchitecture=%s\n' "$HELPER_SHA256" "$(uname -m)" > "$CONTRACT"
MSPL_COVERAGE_CLUSTER=nibi
MSPL_COVERAGE_SOURCE_SHA=test-source
MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256=source-archive-hash
MSPL_COVERAGE_SOURCE_BUNDLE_SHA256=source-bundle-hash
MSPL_COVERAGE_HELPER_SHA256="$HELPER_SHA256"
export MSPL_COVERAGE_CLUSTER MSPL_COVERAGE_SOURCE_SHA \
  MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 MSPL_COVERAGE_SOURCE_BUNDLE_SHA256 \
  MSPL_COVERAGE_HELPER_SHA256
mspl_verify_runtime_contract "$CONTRACT"
MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256=wrong-source-archive-hash
export MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256
if (mspl_verify_runtime_contract "$CONTRACT") >/dev/null 2>&1; then
  mspl_die "Self-test failure: source-archive/runtime mismatch was accepted."
fi

printf 'launcher-contract-self-test=PASS\n'
