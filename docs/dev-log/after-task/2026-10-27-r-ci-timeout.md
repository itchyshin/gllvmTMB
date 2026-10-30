## 1. Goal

Give the complete R package checks enough time to finish when runner setup is
slow, while retaining the existing test matrix and coverage.

## 2. Implemented

Raised the `R-CMD-check` job limit from 75 to 120 minutes. This sets a
ceiling; it does not speed up dependency downloads or guarantee completion.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, or package documentation
changed.

## 4. Files Changed

- `.github/workflows/R-CMD-check.yaml`
- `docs/dev-log/check-log.d/2026-10-27-r-ci-timeout.md`
- `docs/dev-log/after-task/2026-10-27-r-ci-timeout.md`

## 5. Evidence and Checks

- Main run `40489901964`, attempt 2: shard 1 spent 46 minutes in dependency
  setup and was cancelled after eight minutes of `R CMD check` at the job's
  75-minute limit. The other three shards passed.
- PR run `40443072779`: shard 1 completed `R CMD check` in 23 minutes.
- The retry restored its exact R package cache. Slow Ubuntu system-package
  downloads, including repeated Pandoc downloads, consumed setup time.
- `bash tools/check-actions-boundary.sh`: passed.
- Ruby YAML comparison: passed; the timeout is the only parsed setting that
  changed. `git diff --check`: passed.

## 6. Tests of the Tests

The structured comparison checks the old and new timeout values and rejects
any other parsed workflow change. It does not emulate GitHub Actions or prove
that a slow runner will finish within 120 minutes.

## 7. Issue Ledger and Roadmap

No issue was opened or closed. No roadmap row changed. No open PR was found
to be editing this workflow during the ownership check.

## 8. Consistency Audit

`rg -n 'timeout-minutes|setup-r-dependencies|GLLVMTMB_TEST_SHARD|cancel-in-progress' .github/workflows/R-CMD-check.yaml`
confirmed the new limit alongside the existing dependency, sharding, and
concurrency settings. The Actions boundary checker passed. No design or
pkgdown update was needed for this CI-only change.

## 9. What Did Not Go Smoothly

The first main run and one retry timed out. Increasing the limit cannot repair
a persistently slow or unavailable package mirror. The new limit still needs
verification on GitHub Actions.

## 10. Team Learning and Remaining Work

Grace perspective: measure setup and check phases separately before changing
CI. Rose verdict: pending remote verification; local structural checks pass.
Push and open a PR only after the maintainer authorizes this new branch, then
check the new workflow on its exact PR head.
