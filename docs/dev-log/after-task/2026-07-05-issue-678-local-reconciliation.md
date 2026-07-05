# Issue #678 Local Reconciliation

Date: 2026-07-05 04:58 MDT
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `9724c38a`

## Goal

Check whether GitHub issue #678 still needs implementation on the current local
branch, then record the local-vs-public truth without changing the engine.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, pkgdown navigation, prediction-interval, or calibration change. This
is a reconciliation note for an already-local point-prediction dispatch fix.

## Files Changed

- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/audits/2026-07-05-open-issue-local-reconciliation.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-issue-678-local-reconciliation.md`

## What Was Verified

- GitHub issue #678 is still open.
- The current branch already has `.modal_integer_id()` in
  `R/methods-gllvmTMB.R`.
- `predict.gllvmTMB_multi(type = "response", newdata = ...)` maps each trait
  to modal categorical family/link IDs rather than numeric medians.
- `tests/testthat/test-missing-data-robustfix.R` includes the even-mix
  `c(2, 4)` regression that would have produced fabricated family ID 3 under
  median/truncation.

## Evidence

```sh
gh issue view 678 --repo itchyshin/gllvmTMB --json number,title,state,url,body
git log --oneline -S 'modal_integer_id' -- R/methods-gllvmTMB.R tests/testthat/test-missing-data-robustfix.R | head -n 20
git log --oneline -S 'median(fid_vec' -- R/methods-gllvmTMB.R | head -n 20
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-missing-data-robustfix.R", reporter = "summary")'
```

Result: #678 is open remotely; local commit `ae761d49` contains the fix;
`test-missing-data-robustfix.R` passed non-heavy checks with heavy rows skipped
as designed.

## Consistency Audit

EXT-33 now says "local branch addresses issue #678" rather than "closes issue
#678". The open-issue reconciliation table includes #678 as fixed locally but
still open on GitHub.

## Tests Of The Tests

The existing pure regression compares `.modal_integer_id(c(2L, 4L))` against
`as.integer(stats::median(c(2L, 4L)))`; it would fail if the implementation
returned to median/truncation semantics.

## Team Notes

Ada treated the remote-open issue as a current-state question, not as proof
that code was missing.

Fisher and Boole confirmed this is categorical dispatch, so mode is the right
class of selector and median is mathematically inappropriate.

Rose blocked public-closure wording until the local branch is pushed, reviewed,
and merged.

Shannon kept this as reconciliation only: no issue was closed, commented, or
created.

## Design Docs

- EXT-33 in `docs/design/35-validation-debt-register.md` now records local
  evidence without public-closure wording.

## Pkgdown And Documentation

No user-facing docs, generated Rd, README, NEWS, vignettes, or pkgdown files
changed.

## Roadmap Tick

N/A. No roadmap row, dashboard metric, or capability status changed.

## GitHub Issue Ledger

- Inspected #678: still open on GitHub.
- No issue commented, closed, or created.

## Known Limitations And Next Actions

- #678 should remain open until the branch is pushed, reviewed, and merged.
- Continue issue reconciliation for already-local fixes before adding new
  implementation work.
