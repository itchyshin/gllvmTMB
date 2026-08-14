# After Task: LA-MSPL coverage Rorqual quota failover

**Branch:** `codex/lane-b-mspl-interval-feasibility`
**Date:** 2026-08-14
**Roles engaged:** Ada, Grace, Rose, Shannon

## 1. Goal

Replace the blocked Rorqual share without changing any LA-MSPL statistical
case, seed, method, or replicate key, and keep every source/runtime/receipt
gate fail-closed.

## 2. Implemented

The production manifest now assigns `C001`--`C006`,`C011` to Nibi and
`C007`--`C010`,`C012` to Narval. R and shell validators freeze the same route.
The monitor owns explicit non-contiguous case lists with 693/495 remaining
shards, and the Gate 4 ready receipt binds exactly the two admitted runtimes.
Legacy 6/4/2 manifests and Rorqual production tasks are rejected.

## 3. Files Changed

- `inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R`
- `tests/testthat/test-mspl-coverage-runner.R`
- `inst/sim/lane-b-uncertainty/mspl-coverage/README.md`
- `inst/sim/lane-b-uncertainty/mspl-coverage/contract-self-test.sh`
- `inst/sim/lane-b-uncertainty/mspl-coverage/drac-monitor.sh`
- `inst/sim/lane-b-uncertainty/mspl-coverage/lib-mspl-coverage.sh`
- `docs/dev-log/plan-actual/2026-08-14-lane-b-mspl-coverage-calibration.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-08-14-123524-codex-mspl-coverage-production-launch.md`
- this report

No public R API, likelihood, formula grammar, family, NAMESPACE, Rd, vignette,
README, NEWS, ROADMAP, validation-register, or pkgdown navigation changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** create a new source identity for the 7/5 route. **Rationale:**
`aee65e79` correctly rejected an external manifest rewrite. **Rejected:**
campaign-local runner/helper edits or waiting indefinitely for Rorqual quota.
**Confidence:** high.

## 4. Checks Run

```sh
inst/sim/lane-b-uncertainty/mspl-coverage/contract-self-test.sh
# PASS.

for file in inst/sim/lane-b-uncertainty/mspl-coverage/*.sh \
            inst/sim/lane-b-uncertainty/mspl-coverage/*.sbatch; do
  bash -n "$file"
done
# PASS.

Rscript --vanilla -e \
  'testthat::test_file("tests/testthat/test-mspl-coverage-runner.R", stop_on_failure=TRUE)'
# PASS: 191 expectations, zero failures/warnings/skips.

git diff --check
# PASS.
```

No remote task, package-wide test, check, pkgdown, or CI run belongs to this
bounded routing repair.

## 5. Tests of the Tests

The failure-before-fix is the real Rorqual `mkdir` quota error. Boundary tests
require C011 task 991 on Nibi, C012 task 1188 on Narval, and reject C011 on
Rorqual. The aggregator rejects a legacy 6/4/2 manifest. The maps remain exact,
disjoint, ordered, and unchanged.

## 6. Consistency Audit

```sh
rg -n 'production_cluster_assignment|expected_cluster|mspl_remaining_cluster_contract' \
  inst/sim/lane-b-uncertainty/run-mspl-coverage-calibration.R \
  inst/sim/lane-b-uncertainty/mspl-coverage
# PASS: R, shell validation, routing, and monitor ownership agree.

rg -n 'rorqual_runtime_archive_sha256|NR != 23|594|396|198' \
  inst/sim/lane-b-uncertainty/mspl-coverage tests/testthat/test-mspl-coverage-runner.R
# PASS: no stale three-runtime receipt or old production counts; the remaining
# Rorqual mentions are explicit rejection/generic setup compatibility.

git diff -- NAMESPACE R
# PASS: no public inference change.
```

## 7. Roadmap Tick

**Roadmap tick:** N/A. Compute routing changed; package capability did not.

## 7a. GitHub Issue Ledger

Issue #345 remains adjacent but unchanged. This private infrastructure failover
does not advance CRAN readiness. No issue was commented, closed, or created.

## 8. What Did Not Go Smoothly

Rorqual reported nominal file headroom immediately before refusing the campaign
root. More importantly, the first proposed external 7/5 rewrite could not pass
the reviewed immutable contract. Execution stopped rather than weakening it.

## 9. Team Learning

**Grace:** quota reports are forecasts; a successful write is the admission
test. **Rose:** failover routing belongs in the same immutable source contract
as validation, monitoring, and receipts. **Shannon:** the abandoned `r1` roots
remain distinct retained evidence and are never amended into `r2`.

## 10. Known Limitations And Next Actions

The two-cluster route has not run remotely. Seal the new commit, create a fresh
campaign identity, and repeat Gates 1--4 on Nibi/Narval before producing a new
ready receipt. Public MSPL inference remains fail-closed.
