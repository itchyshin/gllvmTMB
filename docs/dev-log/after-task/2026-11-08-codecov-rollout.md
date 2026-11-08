# After Task: Codecov rollout for gllvmTMB

**Branch**: `cursor/codecov-rollout-d7d6`
**Date**: `2026-11-08`
**Roles (engaged)**: Grace, Rose, Shannon

## 1. Goal

Collect real R test coverage for `itchyshin/gllvmTMB` and prepare a Codecov
upload path using GitHub OIDC, without merging, without a Codecov token, and
without changing scientific code, tests, or campaign fixtures.

## 2. Implemented

Coverage is measured with covr on a dedicated GitHub Actions workflow that
reuses `GLLVMTMB_TEST_SHARD="k/4"` so the four jobs partition the suite once,
on Ubuntu and R-release only, against the fast suite
(`GLLVMTMB_HEAVY_TESTS` unset). Existing `R-CMD-check` shards are unchanged.
Upload uses GitHub OIDC from a separate main-only `workflow_run` job: the
producer never holds `id-token: write`; the uploader downloads the four
`cobertura.xml` artifacts after a successful same-repo main push. Pull-request
runs keep the reports as 7-day artifacts. No README badge was added.

D-50 is preserved as a campaign boundary. Line coverage is classified as a
package-check. `tools/check-actions-boundary.sh` now allowlists the two new
workflows, still forbids package-check artifacts, and requires 7-day retention
on coverage coberturas.

## 3. Files Changed

- `.github/workflows/test-coverage.yaml` (new producer)
- `.github/workflows/codecov-upload.yaml` (new main-only OIDC uploader)
- `.github/workflows/R-CMD-check.yaml` (wire the Python guard; shards unchanged)
- `codecov.yml`
- `tools/check-actions-boundary.sh`
- `tools/tests/test_codecov_workflow.py`
- `.Rbuildignore` (`^tools/tests$`; `^codecov\.yml$` was already present)
- `AGENTS.md` (D-50 vs line-coverage distinction; CI Policy note)
- `CONTRIBUTING.md` (Test coverage section)
- this after-task note
- `docs/dev-log/check-log.d/2026-11-08-codecov-rollout.md`

Intentionally not touched: `R/`, `src/`, `tests/`, scientific campaign
branches, `NEWS.md`, README badge, `DESCRIPTION`, pigauto, GLLVModels.jl.

## 3a. Decisions and Rejected Alternatives

- **Decision:** dedicated producer + main-only `workflow_run` OIDC uploader,
  not in-PR Codecov upload and not covr on `R-CMD-check`.
  **Rationale:** `workflow_run` is loaded from the default branch, so this PR
  cannot upload even with `id-token: write` on the producer. Attaching covr to
  the existing four `R-CMD-check` shards would slow every PR check and risk
  double-counting if a second coverage job also ran. gllvmTMB already shards
  with `GLLVMTMB_TEST_SHARD`; reuse that partition.
  **Rejected:** copy DRModels PR-OIDC upload blindly; instrument R-CMD-check
  in place.
  **Confidence:** high for the upload constraint; medium for shard wall-clock
  under covr (120 min ceiling, not yet measured here).
- **Decision:** leave `GLLVMTMB_HEAVY_TESTS` unset.
  **Rationale:** measure the same fast suite routine CI runs; heavy tests are
  the weekly `full-check` regression net, not line-coverage input.
  **Rejected:** enable heavy tests on the coverage producer.
  **Confidence:** high.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-08-codecov-rollout.md`.

## 5. Tests of the Tests

`tools/tests/test_codecov_workflow.py` is prophylactic. It would catch a
producer that gained `id-token`, `CODECOV_TOKEN`, or `codecov-action`; an
uploader that was no longer a main-push `workflow_run` OIDC job; missing
shard files in the upload list; or covr leaking onto `R-CMD-check` /
`full-check`. `tools/check-actions-boundary.sh` would catch a sixth workflow,
package-check `upload-artifact`, missing 7-day retention, or heavy tests on
the producer. No scientific test was added or weakened.

## 6. Consistency Audit

Patterns recorded in the check-log. Verdicts: no README badge; no
`CODECOV_TOKEN`; producer has no `id-token`; uploader is main-only OIDC;
existing four-way shard env name unchanged.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

No relevant open issue for Codecov line coverage on this repository; no new
issue created. Open PRs inspected for collision (`#1700`, `#1506`, `#1283`,
`#1065`, `#981`) do not own CI coverage files.

## 8. What Did Not Go Smoothly

This cloud image has no R, so covr was not run locally. GitHub Actions on the
PR is the coverage runner. Live Codecov publish is main-only by design and
cannot execute until this workflow file exists on the default branch.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Grace: D-50's artifact cap is about campaign dumps, not 7-day coberturas, but
the boundary script had to be taught that distinction or the new workflows
would fail closed on every job.

Rose: "coverage" in this repo already means interval-coverage campaigns. The
AGENTS.md D-50 sentence now says interval-coverage campaigns vs line coverage
of the test suite.

Shannon: this is an isolated `cursor/codecov-rollout-d7d6` lane. Existing
coverage-named branches (`agent/coverage-target-fix`,
`claude/blv-coverage-campaign`, and similar) are scientific campaigns and
were not reused.

## 10. Known Limitations And Next Actions

Status is `NOT_VERIFIED` for a live Codecov commit report. Design requires a
default-branch workflow (owner merge of this PR, then a successful main
`test-coverage` push) before `codecov-upload` can run. No merge is authorized
here. Next slice after merge: confirm the uploader run and a Codecov commit
document with non-null totals for that SHA. C++/TMB `gcov` is not specially
enabled. `skip_on_covr()` tests remain skipped during measurement.
