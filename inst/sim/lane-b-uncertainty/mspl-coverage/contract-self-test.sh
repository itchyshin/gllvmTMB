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
MSPL_COVERAGE_CAMPAIGN_ID=test-campaign
MSPL_COVERAGE_SOURCE_SHA=test-source
export MSPL_COVERAGE_ROOT MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA
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
[[ "$(mspl_remaining_cluster_contract nibi)" == $'1\t6\t594' && \
   "$(mspl_remaining_cluster_contract narval)" == $'7\t10\t396' && \
   "$(mspl_remaining_cluster_contract rorqual)" == $'11\t12\t198' ]] ||
  mspl_die "Self-test failure: cluster-local remaining-map monitor counts changed."
awk -F '\t' 'BEGIN { OFS = "\t" } NR == 2 { $3 = 1 } { print }' \
  "$QUOTED_PRODUCTION_ROOT/remaining-production-array-map.tsv" > "$BAD_REMAINING_MAP"
if (mspl_validate_remaining_production_map "$BAD_REMAINING_MAP") >/dev/null 2>&1; then
  mspl_die "Self-test failure: production remaining map accepted a reused pre-run shard."
fi
[[ "$(MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" mspl_campaign_id)" == "quoted-production" ]] ||
  mspl_die "Self-test failure: campaign_id lookup rejected a write.csv-quoted header."
if (MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" MSPL_COVERAGE_CAMPAIGN_ID=quoted-production \
  MSPL_COVERAGE_SOURCE_SHA=new-runtime-source mspl_validate_manifest_binding) >/dev/null 2>&1; then
  mspl_die "Self-test failure: stale source-112 manifest was accepted under a new runtime source binding."
fi
if (MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" MSPL_COVERAGE_CAMPAIGN_ID=wrong-campaign \
  MSPL_COVERAGE_SOURCE_SHA=quoted-source mspl_validate_manifest_binding) >/dev/null 2>&1; then
  mspl_die "Self-test failure: manifest was accepted under a different campaign binding."
fi
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
  observed="$(MSPL_COVERAGE_ROOT="$QUOTED_SMOKE_ROOT" MSPL_COVERAGE_CAMPAIGN_ID=quoted-smoke MSPL_COVERAGE_SOURCE_SHA=quoted-source MSPL_COVERAGE_STAGE=smoke \
    MSPL_COVERAGE_CLUSTER=nibi SLURM_ARRAY_TASK_ID="$task" mspl_array_task)"
  [[ "$observed" == "$expected_case"$'\t'"1" ]] ||
    mspl_die "Self-test failure: quoted smoke map task $task resolved to '$observed', expected $expected_case shard 1."
done
[[ "$(MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" MSPL_COVERAGE_CAMPAIGN_ID=quoted-production MSPL_COVERAGE_SOURCE_SHA=quoted-source MSPL_COVERAGE_STAGE=production \
  MSPL_COVERAGE_CLUSTER=nibi SLURM_ARRAY_TASK_ID=1 mspl_array_task)" == C001$'\t'2 ]] ||
  mspl_die "Self-test failure: production task 1 did not select C001 shard 002 from the remaining map."
[[ "$(MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT" MSPL_COVERAGE_CAMPAIGN_ID=quoted-production MSPL_COVERAGE_SOURCE_SHA=quoted-source MSPL_COVERAGE_STAGE=production \
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
WRONG_BUNDLE_ENV="$TEST_ROOT/wrong-bundle.env"
UNKNOWN_ENV="$TEST_ROOT/unknown-key.env"
DUPLICATE_ENV="$TEST_ROOT/duplicate-key.env"
COMMAND_ENV="$TEST_ROOT/command.env"
UNSAFE_ENV="$TEST_ROOT/unsafe-value.env"
MISSING_ENV="$TEST_ROOT/missing-required.env"
COMMAND_MARKER="$TEST_ROOT/job-env-command-ran"
mkdir -p "$STAGED_LAUNCHER" "$SPOOL_DIR"
for launcher_file in README.md contract-self-test.sh drac-array.sbatch drac-monitor.sh drac-setup.sbatch drac-smoke.sbatch lib-mspl-coverage.sh; do
  cp "$SCRIPT_DIR/$launcher_file" "$STAGED_LAUNCHER/$launcher_file"
done
(cd "$STAGED_LAUNCHER" && sha256sum README.md contract-self-test.sh drac-array.sbatch drac-monitor.sh drac-setup.sbatch drac-smoke.sbatch lib-mspl-coverage.sh > LAUNCHER-SHA256SUMS)
HELPER_SHA256="$(sha256sum "$STAGED_LAUNCHER/lib-mspl-coverage.sh" | awk '{print $1}')"
LAUNCHER_BUNDLE_SHA256="$(sha256sum "$STAGED_LAUNCHER/LAUNCHER-SHA256SUMS" | awk '{print $1}')"
MANIFEST_SHA256="$(sha256sum "$TEST_ROOT/manifest.csv" | awk '{print $1}')"
write_bootstrap_env() {
  local file="$1" helper_hash="$2" source_sha="${3:-}"
  printf 'MSPL_COVERAGE_ROOT=%s\nMSPL_COVERAGE_LAUNCHER_DIR=%s\nMSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256=%s\nMSPL_COVERAGE_HELPER_SHA256=%s\nMSPL_COVERAGE_CAMPAIGN_ID=test-campaign\nMSPL_COVERAGE_MANIFEST_SHA256=%s\n' \
    "$TEST_ROOT" "$STAGED_LAUNCHER" "$LAUNCHER_BUNDLE_SHA256" "$helper_hash" "$MANIFEST_SHA256" > "$file"
  [[ -z "$source_sha" ]] || printf 'MSPL_COVERAGE_SOURCE_SHA=%s\n' "$source_sha" >> "$file"
}
run_spooled_bootstrap() {
  local script="$1" env_file="$2"
  (
    unset MSPL_COVERAGE_ROOT MSPL_COVERAGE_LAUNCHER_DIR MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 MSPL_COVERAGE_HELPER_SHA256 MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA MSPL_COVERAGE_MANIFEST_SHA256
    MSPL_COVERAGE_JOB_ENV="$env_file" MSPL_COVERAGE_BOOTSTRAP_ONLY=true \
      bash "$SPOOL_DIR/$script"
  )
}
write_bootstrap_env "$JOB_ENV" "$HELPER_SHA256" test-source
write_bootstrap_env "$WRONG_HASH_ENV" wrong-helper-hash test-source
cp "$JOB_ENV" "$WRONG_BUNDLE_ENV"
awk -F= -v OFS== -v bad="$(printf 'f%.0s' $(seq 1 64))" '$1=="MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256" {$2=bad} {print}' "$WRONG_BUNDLE_ENV" > "$WRONG_BUNDLE_ENV.tmp"
mv "$WRONG_BUNDLE_ENV.tmp" "$WRONG_BUNDLE_ENV"
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
if run_spooled_bootstrap drac-setup.sbatch "$WRONG_BUNDLE_ENV" >/dev/null 2>&1; then
  mspl_die "Self-test failure: spooled setup accepted the wrong launcher-bundle hash."
fi
printf '\n# tampered spool\n' >> "$SPOOL_DIR/drac-setup.sbatch"
if run_spooled_bootstrap drac-setup.sbatch "$JOB_ENV" >/dev/null 2>&1; then
  mspl_die "Self-test failure: launcher ledger accepted a byte-different spooled script."
fi
cp "$SCRIPT_DIR/drac-setup.sbatch" "$SPOOL_DIR/drac-setup.sbatch"
printf '\nTampered staged README.\n' >> "$STAGED_LAUNCHER/README.md"
if run_spooled_bootstrap drac-setup.sbatch "$JOB_ENV" >/dev/null 2>&1; then
  mspl_die "Self-test failure: launcher ledger accepted a byte-different staged file."
fi
cp "$SCRIPT_DIR/README.md" "$STAGED_LAUNCHER/README.md"

# Build exact Gate 3/Gate 4 unlock fixtures under the production root.
GATES="$QUOTED_PRODUCTION_ROOT/gates"
mkdir -p "$GATES"
SOURCE_ARCHIVE_HASH="$(printf 'a%.0s' $(seq 1 64))"
SOURCE_BUNDLE_HASH="$(printf 'b%.0s' $(seq 1 64))"
NIBI_RUNTIME_HASH="$(printf 'c%.0s' $(seq 1 64))"
NARVAL_RUNTIME_HASH="$(printf 'd%.0s' $(seq 1 64))"
RORQUAL_RUNTIME_HASH="$(printf 'e%.0s' $(seq 1 64))"
PRODUCTION_MANIFEST_HASH="$(mspl_sha256 "$QUOTED_PRODUCTION_ROOT/manifest.csv")"
cp "$QUOTED_SMOKE_ROOT/manifest.csv" "$GATES/gate3-smoke-manifest.csv"
printf 'receipt_type: gate3-smoke-statistical\nlauncher_unlock_eligible: FALSE\n' > "$GATES/gate3-smoke-receipt.txt"
for case_id in C001 C005 C009; do printf '%064d  %s-shard-001.rds\n' 1 "$case_id"; done > "$GATES/gate3-smoke-shard-hashes.sha256"
GATE3_SMOKE_MANIFEST_HASH="$(mspl_sha256 "$GATES/gate3-smoke-manifest.csv")"
GATE3_AGGREGATE_HASH="$(mspl_sha256 "$GATES/gate3-smoke-receipt.txt")"
GATE3_LEDGER_HASH="$(mspl_sha256 "$GATES/gate3-smoke-shard-hashes.sha256")"
write_gate3_ready() {
  cat > "$GATES/gate3-ready.receipt" <<EOF
receipt_type=gate3-smoke-ready-v1
gate_status=PASS
campaign_id=quoted-production
source_sha=quoted-source
manifest_sha256=$PRODUCTION_MANIFEST_HASH
smoke_manifest_sha256=$GATE3_SMOKE_MANIFEST_HASH
source_archive_sha256=$SOURCE_ARCHIVE_HASH
source_bundle_sha256=$SOURCE_BUNDLE_HASH
launcher_bundle_sha256=$LAUNCHER_BUNDLE_SHA256
launcher_helper_sha256=$HELPER_SHA256
cluster=nibi
runtime_archive_sha256=$NIBI_RUNTIME_HASH
gate3_smoke_receipt_sha256=$GATE3_AGGREGATE_HASH
gate3_shard_ledger_sha256=$GATE3_LEDGER_HASH
shard_count=3
outer_fit_rows=3
bootstrap_attempt_rows=6
endpoint_rows=27
calibration_gate_eligible=FALSE
EOF
}
write_gate3_ready

printf 'receipt_type: gate4-prerun-statistical\nlauncher_unlock_eligible: FALSE\n' > "$GATES/gate4-prerun-receipt.txt"
for i in $(seq 1 12); do printf '%064d  C%03d-shard-001.rds\n' "$i" "$i"; done > "$GATES/gate4-shard-hashes.sha256"
GATE4_AGGREGATE_HASH="$(mspl_sha256 "$GATES/gate4-prerun-receipt.txt")"
GATE4_LEDGER_HASH="$(mspl_sha256 "$GATES/gate4-shard-hashes.sha256")"
write_gate4_ready() {
  cat > "$GATES/gate4-prerun-ready.receipt" <<EOF
receipt_type=gate4-prerun-ready-v1
gate_status=PASS
campaign_id=quoted-production
source_sha=quoted-source
manifest_sha256=$PRODUCTION_MANIFEST_HASH
source_archive_sha256=$SOURCE_ARCHIVE_HASH
source_bundle_sha256=$SOURCE_BUNDLE_HASH
launcher_bundle_sha256=$LAUNCHER_BUNDLE_SHA256
launcher_helper_sha256=$HELPER_SHA256
gate4_prerun_receipt_sha256=$GATE4_AGGREGATE_HASH
gate4_shard_ledger_sha256=$GATE4_LEDGER_HASH
nibi_runtime_archive_sha256=$NIBI_RUNTIME_HASH
narval_runtime_archive_sha256=$NARVAL_RUNTIME_HASH
rorqual_runtime_archive_sha256=$RORQUAL_RUNTIME_HASH
case_count=12
shard_count=12
outer_fit_rows=120
bootstrap_attempt_rows=60000
endpoint_rows=1080
calibration_gate_eligible=FALSE
launcher_unlock_eligible=TRUE
approved_by=maintainer
approved_at_utc=2026-08-14T12:00:00Z
EOF
}
write_gate4_ready

MSPL_COVERAGE_ROOT="$QUOTED_PRODUCTION_ROOT"
MSPL_COVERAGE_CAMPAIGN_ID=quoted-production
MSPL_COVERAGE_SOURCE_SHA=quoted-source
MSPL_COVERAGE_MANIFEST_SHA256="$PRODUCTION_MANIFEST_HASH"
MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256="$SOURCE_ARCHIVE_HASH"
MSPL_COVERAGE_SOURCE_BUNDLE_SHA256="$SOURCE_BUNDLE_HASH"
MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256="$LAUNCHER_BUNDLE_SHA256"
MSPL_COVERAGE_HELPER_SHA256="$HELPER_SHA256"
MSPL_COVERAGE_CLUSTER=nibi
MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256="$NIBI_RUNTIME_HASH"
export MSPL_COVERAGE_ROOT MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA MSPL_COVERAGE_MANIFEST_SHA256 \
  MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 MSPL_COVERAGE_SOURCE_BUNDLE_SHA256 MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 \
  MSPL_COVERAGE_HELPER_SHA256 MSPL_COVERAGE_CLUSTER MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256
MSPL_COVERAGE_STAGE=pre-run mspl_require_gate_receipt
MSPL_COVERAGE_STAGE=production mspl_require_gate_receipt

mv "$GATES/gate3-ready.receipt" "$GATES/gate3-ready.saved"
if (MSPL_COVERAGE_STAGE=pre-run mspl_require_gate_receipt) >/dev/null 2>&1; then
  mspl_die "Self-test failure: statistical Gate 3 receipt unlocked pre-run."
fi
mv "$GATES/gate3-ready.saved" "$GATES/gate3-ready.receipt"

# A local statistical receipt alone is never a launcher unlock.
mv "$GATES/gate4-prerun-ready.receipt" "$GATES/gate4-prerun-ready.saved"
if (MSPL_COVERAGE_STAGE=production mspl_require_gate_receipt) >/dev/null 2>&1; then
  mspl_die "Self-test failure: statistical Gate 4 receipt unlocked production."
fi
mv "$GATES/gate4-prerun-ready.saved" "$GATES/gate4-prerun-ready.receipt"

mutate_ready_field() {
  local input="$1" output="$2" key="$3" value="$4"
  awk -F= -v OFS== -v key="$key" -v value="$value" '$1 == key {$2=value} {print}' "$input" > "$output"
}
BAD_READY="$TEST_ROOT/bad-ready.receipt"
for key in manifest_sha256 gate4_prerun_receipt_sha256 gate4_shard_ledger_sha256 nibi_runtime_archive_sha256 launcher_helper_sha256 source_archive_sha256 source_bundle_sha256 launcher_bundle_sha256; do
  mutate_ready_field "$GATES/gate4-prerun-ready.receipt" "$BAD_READY" "$key" "$(printf 'f%.0s' $(seq 1 64))"
  mv "$GATES/gate4-prerun-ready.receipt" "$GATES/gate4-prerun-ready.good"
  cp "$BAD_READY" "$GATES/gate4-prerun-ready.receipt"
  if (MSPL_COVERAGE_STAGE=production mspl_require_gate_receipt) >/dev/null 2>&1; then
    mspl_die "Self-test failure: Gate 4 unlock accepted wrong $key."
  fi
  mv "$GATES/gate4-prerun-ready.good" "$GATES/gate4-prerun-ready.receipt"
done
cp "$GATES/gate4-prerun-ready.receipt" "$BAD_READY"; printf 'unknown_field=safe\n' >> "$BAD_READY"
for mode in unknown duplicate missing; do
  case "$mode" in
    unknown) cp "$BAD_READY" "$GATES/gate4-prerun-ready.test" ;;
    duplicate) cp "$GATES/gate4-prerun-ready.receipt" "$GATES/gate4-prerun-ready.test"; printf 'campaign_id=quoted-production\n' >> "$GATES/gate4-prerun-ready.test" ;;
    missing) awk '$0 !~ /^approved_by=/' "$GATES/gate4-prerun-ready.receipt" > "$GATES/gate4-prerun-ready.test" ;;
  esac
  mv "$GATES/gate4-prerun-ready.receipt" "$GATES/gate4-prerun-ready.good"; mv "$GATES/gate4-prerun-ready.test" "$GATES/gate4-prerun-ready.receipt"
  if (MSPL_COVERAGE_STAGE=production mspl_require_gate_receipt) >/dev/null 2>&1; then mspl_die "Self-test failure: Gate 4 unlock accepted $mode fields."; fi
  mv "$GATES/gate4-prerun-ready.good" "$GATES/gate4-prerun-ready.receipt"
done
cp "$GATES/gate4-shard-hashes.sha256" "$GATES/gate4-shard-hashes.good"
awk 'NR == 1 {sub(/shard-001/, "shard-002")} {print}' "$GATES/gate4-shard-hashes.good" > "$GATES/gate4-shard-hashes.sha256"
if (MSPL_COVERAGE_STAGE=production mspl_require_gate_receipt) >/dev/null 2>&1; then mspl_die "Self-test failure: Gate 4 ledger mixed a non-pre-run shard."; fi
mv "$GATES/gate4-shard-hashes.good" "$GATES/gate4-shard-hashes.sha256"

# Exercise the read-only monitor against real schema-v2 RDS bytes and scheduler
# fixtures. Filename presence alone must never count as campaign progress.
MONITOR_ROOT="$TEST_ROOT/monitor-production"
MONITOR_QUEUE="$TEST_ROOT/monitor-squeue.txt"
MONITOR_ACCT="$TEST_ROOT/monitor-sacct.txt"
mkdir -p "$MONITOR_ROOT/shards" "$MONITOR_ROOT/receipts"
cp "$QUOTED_PRODUCTION_ROOT/manifest.csv" "$MONITOR_ROOT/manifest.csv"
cp "$QUOTED_PRODUCTION_ROOT/remaining-production-array-map.tsv" "$MONITOR_ROOT/remaining-production-array-map.tsv"
cp -R "$STAGED_LAUNCHER" "$MONITOR_ROOT/launcher"
MONITOR_MANIFEST_HASH="$(mspl_sha256 "$MONITOR_ROOT/manifest.csv")"
MONITOR_SHARD="$MONITOR_ROOT/shards/C001-shard-002.rds"
write_monitor_shard() {
  Rscript --vanilla - "$MONITOR_ROOT" "$SOURCE_ARCHIVE_HASH" "$SOURCE_BUNDLE_HASH" \
    "$LAUNCHER_BUNDLE_SHA256" "$HELPER_SHA256" "$NIBI_RUNTIME_HASH" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
root <- args[[1L]]
manifest <- utils::read.csv(file.path(root, "manifest.csv"), stringsAsFactors = FALSE)
case <- manifest[manifest$case_id == "C001", , drop = FALSE]
provenance <- data.frame(
  manifest_version = case$manifest_version,
  campaign_id = "quoted-production",
  source_sha = "quoted-source",
  cluster = "nibi",
  case_id = "C001",
  shard_id = 2L,
  runtime_fingerprint = "monitor-test-runtime",
  source_archive_sha256 = args[[2L]],
  source_bundle_sha256 = args[[3L]],
  launcher_bundle_sha256 = args[[4L]],
  launcher_helper_sha256 = args[[5L]],
  runtime_archive_sha256 = args[[6L]],
  stringsAsFactors = FALSE
)
identity <- provenance[rep(1L, 10L), c(
  "manifest_version", "campaign_id", "source_sha", "cluster", "case_id",
  "shard_id", "runtime_fingerprint"
), drop = FALSE]
outer_fits <- cbind(identity, outer_id = 11:20)
bootstrap_attempts <- cbind(
  identity[rep(seq_len(10L), each = 500L), , drop = FALSE],
  outer_id = rep(11:20, each = 500L),
  attempt_id = rep(seq_len(500L), 10L)
)
endpoint_grid <- expand.grid(
  outer_id = 11:20,
  method = c("wald", "profile", "bootstrap"),
  target = 1:3,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
endpoints <- cbind(
  identity[rep(seq_len(10L), each = 9L), , drop = FALSE],
  endpoint_grid
)
profile_traces <- identity[FALSE, , drop = FALSE]
saveRDS(list(
  schema_version = "gate0-shard-v2",
  provenance = provenance,
  outer_fits = outer_fits,
  bootstrap_attempts = bootstrap_attempts,
  endpoints = endpoints,
  profile_traces = profile_traces
), file.path(root, "shards", "C001-shard-002.rds"), compress = "gzip")
RS
}
run_monitor_fixture() {
  local now_epoch="$1"
  (
    unset MSPL_COVERAGE_JOB_ENV
    MSPL_COVERAGE_MONITOR_TEST_MODE=true \
    MSPL_COVERAGE_ROOT="$MONITOR_ROOT" \
    MSPL_COVERAGE_LAUNCHER_DIR="$MONITOR_ROOT/launcher" \
    MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256="$LAUNCHER_BUNDLE_SHA256" \
    MSPL_COVERAGE_HELPER_SHA256="$HELPER_SHA256" \
    MSPL_COVERAGE_CLUSTER=nibi \
    MSPL_COVERAGE_CAMPAIGN_ID=quoted-production \
    MSPL_COVERAGE_SOURCE_SHA=quoted-source \
    MSPL_COVERAGE_MANIFEST_SHA256="$MONITOR_MANIFEST_HASH" \
    MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256="$SOURCE_ARCHIVE_HASH" \
    MSPL_COVERAGE_SOURCE_BUNDLE_SHA256="$SOURCE_BUNDLE_HASH" \
    MSPL_COVERAGE_RUNTIME_ARCHIVE_SHA256="$NIBI_RUNTIME_HASH" \
    MSPL_COVERAGE_JOB_ID=monitor-test \
    MSPL_COVERAGE_SQUEUE_FIXTURE="$MONITOR_QUEUE" \
    MSPL_COVERAGE_SACCT_FIXTURE="$MONITOR_ACCT" \
    MSPL_COVERAGE_MONITOR_NOW_EPOCH="$now_epoch" \
      "$MONITOR_ROOT/launcher/drac-monitor.sh"
  )
}
write_monitor_shard
printf 'RUNNING|100|200|00:10:00\n' > "$MONITOR_QUEUE"
printf 'COMPLETED|100|200|00:10:00\n' > "$MONITOR_ACCT"
MONITOR_OUTPUT="$(run_monitor_fixture 800)"
grep -qx 'completed=1' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: monitor did not validate the schema-v2 shard."
grep -qx 'invalid=0' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: monitor rejected a valid schema-v2 shard."
grep -qx 'stop_recommended=FALSE' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: monitor stopped a healthy fixture."

Rscript --vanilla -e 'p <- commandArgs(TRUE)[1]; x <- readRDS(p); x$provenance$source_sha <- "stale-source"; saveRDS(x, p, compress = "gzip")' "$MONITOR_SHARD"
MONITOR_OUTPUT="$(run_monitor_fixture 800)"
grep -qx 'completed=0' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: corrupt provenance counted as completed."
grep -qx 'invalid=1' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: corrupt provenance was not typed invalid."
grep -q 'stop_reasons=.*invalid_shard' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: invalid shard did not trigger the stop contract."
mv "$MONITOR_SHARD" "$MONITOR_SHARD.invalid"

printf 'RUNNING|1000|2000|00:15:00\n' > "$MONITOR_QUEUE"
printf 'RUNNING|1000|2000|00:15:00\n' > "$MONITOR_ACCT"
MONITOR_OUTPUT="$(run_monitor_fixture 2500)"
grep -q 'stop_reasons=.*task_over_2x_gate4_median' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: 2x-median task age was not detected."
printf 'RUNNING|1000|2000|00:30:00\n' > "$MONITOR_QUEUE"
MONITOR_OUTPUT="$(run_monitor_fixture 3000)"
grep -q 'stop_reasons=.*task_at_30m_hard_limit' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: 30-minute hard limit was not detected."
printf 'RUNNING|1000|2000|01:10:00\n' > "$MONITOR_QUEUE"
MONITOR_OUTPUT="$(run_monitor_fixture 7001)"
grep -q 'stop_reasons=.*no_first_valid_shard_60m' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: 60-minute first-shard stop was not detected."
printf 'PENDING|1000|N/A|00:00:00\n' > "$MONITOR_QUEUE"
printf 'PENDING|1000|Unknown|00:00:00\n' > "$MONITOR_ACCT"
MONITOR_OUTPUT="$(run_monitor_fixture 4001)"
grep -q 'stop_reasons=.*no_start_45m' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: 45-minute no-start reroute was not detected."
MONITOR_OUTPUT="$(run_monitor_fixture 9001)"
grep -q 'stop_reasons=.*pending_over_2h' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: two-hour pending reroute was not detected."

# A terminal task that vanishes from squeue must still start the no-shard clock.
printf '\n' > "$MONITOR_QUEUE"
printf 'COMPLETED|1000|2000|00:10:00\n' > "$MONITOR_ACCT"
MONITOR_OUTPUT="$(run_monitor_fixture 6001)"
grep -q 'stop_reasons=.*no_first_valid_shard_60m' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: completed no-shard task lost its sacct start time."

# Only pending rows contribute to pending age; an old running submit must not
# age a newly pending task into either reroute threshold.
printf 'RUNNING|100|5500|00:01:00\nPENDING|5900|N/A|00:00:00\n' > "$MONITOR_QUEUE"
printf 'RUNNING|100|5500|00:01:00\nPENDING|5900|Unknown|00:00:00\n' > "$MONITOR_ACCT"
MONITOR_OUTPUT="$(run_monitor_fixture 6000)"
grep -qx 'oldest_pending_age_seconds=100' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: pending age included a non-pending task."
if grep -Eq 'stop_reasons=.*(no_start_45m|pending_over_2h)' <<< "$MONITOR_OUTPUT"; then
  mspl_die "Self-test failure: old running submit falsely aged a new pending task."
fi

printf '\n' > "$MONITOR_QUEUE"
printf 'FAILED|100|200|00:00:01\n' > "$MONITOR_ACCT"
MONITOR_OUTPUT="$(run_monitor_fixture 1000)"
grep -q 'stop_reasons=.*failed_task' <<< "$MONITOR_OUTPUT" || mspl_die "Self-test failure: terminal scheduler failure was not detected."
mv "$MONITOR_QUEUE" "$MONITOR_QUEUE.saved"
if run_monitor_fixture 1000 >/dev/null 2>&1; then
  mspl_die "Self-test failure: unreadable scheduler fixture did not fail closed."
fi
mv "$MONITOR_QUEUE.saved" "$MONITOR_QUEUE"

CONTRACT="$TEST_ROOT/runtime-library.contract"
printf 'cluster=nibi\ncampaign_id=quoted-production\nsource_sha=quoted-source\nmanifest_sha256=%s\nsource_archive_sha256=%s\nsource_bundle_sha256=%s\nlauncher_bundle_sha256=%s\nlauncher_helper_sha256=%s\narchitecture=%s\n' \
  "$PRODUCTION_MANIFEST_HASH" "$SOURCE_ARCHIVE_HASH" "$SOURCE_BUNDLE_HASH" "$LAUNCHER_BUNDLE_SHA256" "$HELPER_SHA256" "$(uname -m)" > "$CONTRACT"
MSPL_COVERAGE_CLUSTER=nibi
MSPL_COVERAGE_CAMPAIGN_ID=quoted-production
MSPL_COVERAGE_SOURCE_SHA=quoted-source
MSPL_COVERAGE_MANIFEST_SHA256="$PRODUCTION_MANIFEST_HASH"
MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256="$SOURCE_ARCHIVE_HASH"
MSPL_COVERAGE_SOURCE_BUNDLE_SHA256="$SOURCE_BUNDLE_HASH"
MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256="$LAUNCHER_BUNDLE_SHA256"
MSPL_COVERAGE_HELPER_SHA256="$HELPER_SHA256"
export MSPL_COVERAGE_CLUSTER MSPL_COVERAGE_CAMPAIGN_ID MSPL_COVERAGE_SOURCE_SHA MSPL_COVERAGE_MANIFEST_SHA256 \
  MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256 MSPL_COVERAGE_SOURCE_BUNDLE_SHA256 \
  MSPL_COVERAGE_LAUNCHER_BUNDLE_SHA256 MSPL_COVERAGE_HELPER_SHA256
mspl_verify_runtime_contract "$CONTRACT"
MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256=wrong-source-archive-hash
export MSPL_COVERAGE_SOURCE_ARCHIVE_SHA256
if (mspl_verify_runtime_contract "$CONTRACT") >/dev/null 2>&1; then
  mspl_die "Self-test failure: source-archive/runtime mismatch was accepted."
fi

printf 'launcher-contract-self-test=PASS\n'
