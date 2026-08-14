# After Task: LA-MSPL coverage production-launch hardening

**Branch:** `codex/lane-b-mspl-interval-feasibility`
**Date:** 2026-08-14
**Roles engaged:** Ada, Curie, Grace, Rose, Shannon, Fisher

## 1. Goal

Make the approved LA-MSPL coverage campaign safe to resume under a new
immutable source identity by closing source/runtime/shard/unlock provenance and
monitoring gaps before any production submission.

## 2. Implemented

The runner emits schema-v2 shards with exact source, archive, launcher,
cluster-runtime, case, shard, and row provenance. Strict aggregation requires
an externally supplied expected source SHA and writes immutable canonical
shard ledgers and named receipts for Gate 3, Gate 4, and production.

The Slurm launchers authenticate the exact staged seven-file bundle, their
spooled bytes, manifest identity, source artifacts, and cluster-native runtime.
Production requires a closed Gate 4 ready receipt and the exact runner-emitted
1,188-key remaining map. A statistical Gate 4 receipt alone cannot unlock it.

The monitor opens and validates every candidate schema-v2 RDS before counting
it. It reports valid/invalid counts and enforces every predeclared failure and
age stop, including terminal-task start history from `sacct` and pending-only
age accounting.

## 3. Files Changed

Runner and tests:

- `inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R`
- `tests/testthat/test-mspl-coverage-runner.R`

Launcher bundle:

- `inst/sim/lane-b-uncertainty/mspl-coverage/README.md`
- `inst/sim/lane-b-uncertainty/mspl-coverage/contract-self-test.sh`
- `inst/sim/lane-b-uncertainty/mspl-coverage/drac-array.sbatch`
- `inst/sim/lane-b-uncertainty/mspl-coverage/drac-monitor.sh`
- `inst/sim/lane-b-uncertainty/mspl-coverage/drac-setup.sbatch`
- `inst/sim/lane-b-uncertainty/mspl-coverage/drac-smoke.sbatch`
- `inst/sim/lane-b-uncertainty/mspl-coverage/lib-mspl-coverage.sh`

Durable records:

- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-coverage-calibration.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-08-14-123524-codex-mspl-coverage-production-launch.md`
- this report

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, README, NEWS, ROADMAP, validation-register, or pkgdown navigation
changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** invalidate the old Gate 4 shards for production rather than
grandfather their weaker provenance. **Rationale:** a mixed source/runtime shard
set could otherwise pass cardinality checks. **Rejected:** trusting manifest
labels or translating schema-v1 shards. **Confidence:** high.

**Decision:** mark exact full production as eligible for calibration
adjudication, independently of public API activation. **Rationale:** Gate 4 and
smoke are operational only; full production is the evidence the adjudicator is
designed to evaluate. **Rejected:** hard-coding every receipt ineligible or
treating eligibility as automatic public promotion. **Confidence:** high.

## 4. Checks Run

```sh
Rscript --vanilla -e \
  'testthat::test_file("tests/testthat/test-mspl-coverage-runner.R", reporter="summary", stop_on_failure=TRUE)'
# PASS: 192 expectations.

bash inst/sim/lane-b-uncertainty/mspl-coverage/contract-self-test.sh
# PASS: launcher-contract-self-test=PASS.

for file in inst/sim/lane-b-uncertainty/mspl-coverage/*.sh \
            inst/sim/lane-b-uncertainty/mspl-coverage/*.sbatch; do
  bash -n "$file"
done
# PASS.

Rscript --vanilla -e 'devtools::test(filter = "mspl", stop_on_failure = TRUE)'
# PASS: 1,431 passed, 0 failed, 0 warnings, 1 intentional skip; 175.5 s.

git diff --check
# PASS.
```

No package-wide test, `R CMD check`, roxygen, pkgdown, or CI run belongs to this
private pre-compute phase. Those gates remain required if calibration earns a
public-method change.

## 5. Tests of the Tests

The new tests reproduce real pre-launch failures: Slurm spool-relative paths,
concatenated dependency names, unexported job variables, quoted CSV fields,
unbound source labels, and insufficient unlock provenance. Negative fixtures
reject stale/mixed source, runtime, archive, launcher, row identity, duplicate,
missing, unsafe-environment, and malformed-ledger inputs.

Monitor tests exercise both acceptance and rejection: one exact schema-v2 RDS
counts as complete; a provenance-corrupted RDS does not. Scheduler fixtures
cover every stop and two review-discovered boundaries: a completed task with no
shard must preserve its start clock, and an old running task must not age a new
pending task.

## 6. Consistency Audit

```sh
git diff -- NAMESPACE R
# PASS: no public API or R inference-dispatch change.

rg -n 'gllvmTMB_mspl_inference_abort|gllvmTMB_mspl_assert_inference' \
  R/vcov-coef.R R/z-confint-gllvmTMB.R R/profile-targets.R \
  R/profile-ci.R R/bootstrap-sigma.R R/standard-errors.R
# PASS: all existing MSPL public refusals remain present.

rg -n 'gate0-shard-v2|expected-source-sha|shard-hashes.sha256|ready.receipt' \
  inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R \
  inst/sim/lane-b-uncertainty/mspl-coverage tests/testthat/test-mspl-coverage-runner.R
# PASS: strict shard identity, ledgers, and ready-receipt contracts are visible
# in source and tests.

rg -n 'invalid_shard|failed_task|task_over_2x_gate4_median|task_at_30m_hard_limit|no_first_valid_shard_60m|no_start_45m|pending_over_2h' \
  inst/sim/lane-b-uncertainty/mspl-coverage
# PASS: every declared stop appears in the monitor and executable contract test.
```

The status inventory requires no change because no user-facing capability was
promoted. The old Gate 4 record remains true historical evidence and is now
explicitly separated from the schema-v2 production identity.

## 7. Roadmap Tick

**Roadmap tick:** N/A. This is private campaign infrastructure; no public
roadmap capability changed.

## 7a. GitHub Issue Ledger

Issue #345 (first CRAN readiness) was inspected. Private coverage-launch
hardening does not advance its public release status. No issue was commented,
closed, or created.

## 8. What Did Not Go Smoothly

The first permanent launcher candidate passed its local tests but still trusted
an internally consistent manifest source label and a weak ready receipt. The
independent audit caught both before remote mutation. A second review found two
monitor timing edges after the main provenance repair: completed tasks vanished
from the start-time clock, and non-pending submits contaminated pending age.
Both were repaired and tested before the GO verdict.

## 9. Team Learning

**Curie:** exact cardinality is insufficient unless each statistical row is
bound to immutable source/runtime provenance.

**Grace:** install success and scheduler acceptance are separate gates; the
exact runner path, launcher bytes, and receipt must all be authenticated.

**Rose:** a monitor claiming “valid” must inspect the artifact, and each timing
rule needs a scheduler-transition edge fixture rather than only a steady-state
fixture.

**Fisher:** `calibration_gate_eligible: TRUE` means eligible for adjudication,
not calibrated and not public.

**Shannon:** same-platform iSDM lanes are active but do not own this lane or its
files; the full campaign remains isolated to this worktree.

## 10. Known Limitations And Next Actions

No coverage result exists yet under schema v2. The previous 120-outer Gate 4
result remains useful timing/operational evidence but cannot unlock the new
campaign. Public MSPL inference remains fail-closed.

Next: seal the immutable commit, rebuild each cluster-native runtime, repeat
Gates 1--4 under that identity, audit the ready receipt, run 1,188 remaining
shards, aggregate the exact 1,200-shard campaign, and adjudicate all 108 cells.
Only passing routes may enter a separately tested public-method change.
