# Mixed-Family Name-Guard Truth Lock

Date: 2026-07-05 04:48 MDT
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `a5b9d1b0`

## Goal

Continue the gllvmTMB completion Ultra-Plan Phase 2 missing/mixed correctness
lane by tightening the already-local mixed-family named-list repair and
separating local evidence from public GitHub issue state.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation change. This is a test/register truth-lock for
the existing `family = list(...)` + `family_var` dispatch contract.

## Files Changed

- `tests/testthat/test-stage37-mixed-family.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-mixed-family-name-guards.md`

## Changes

- Added Stage 37 regression tests so duplicate named mixed-family lists fail
  with the unique-name guard.
- Added Stage 37 regression tests so named lists whose names do not match the
  selector levels fail before `family_id_vec`, `link_id_vec`, or
  `family_per_row` are constructed.
- Updated validation register row MIX-02 to say the local branch addresses
  issue #610, while public issue closure still waits for push/PR/merge.
- Checked the adjacent missing-response weight path and left it unchanged:
  `test-weights-unified.R` already pins `drop_masked = FALSE` masked cells to
  zero weights, and `test-wide-weights-matrix.R` pins wide per-cell weight
  alignment and NA-mask matching.

## Evidence

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-stage37-mixed-family.R", reporter = "summary")'
```

Result: `test-stage37-mixed-family.R` passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-weights-unified.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-wide-weights-matrix.R", reporter = "summary")'
```

Result: both missing/weight focused files passed.

## Consistency Audit

```sh
gh pr list --state open --limit 20
git log --all --oneline --since='6 hours ago' --max-count=40
gh issue view 610 --repo itchyshin/gllvmTMB --json number,title,state,url,labels
gh issue list --repo itchyshin/gllvmTMB --state open --search 'mixed-family OR "mixed family"' --limit 10 --json number,title,state,url
rg -n "closes issue #610|issue #610|#610" docs R tests README.md NEWS.md
rg -n "mixed-family list|sorted/level|family_var" docs/dev-log/check-log.md docs/dev-log/after-task docs/design/35-validation-debt-register.md docs/design/61-capability-status.md
```

Verdict: no open PR was listed; issue #610 is still open on GitHub; the
validation register now avoids public-closure wording. Remaining historical
check-log and after-task wording records the original local repair goal, not a
new public closure claim.

## Tests Of The Tests

The new tests call `.align_mixed_family_list()` directly on malformed lists.
They would fail if future refactors removed the duplicate-name guard or allowed
named lists whose names drift from the selector levels.

## Team Notes

Ada kept the slice scoped to one truth-lock change after confirming the
missing-response weight path was already covered.

Boole owns the selector/name grammar boundary: named lists are authoritative
only when fully named, unique, and level-matched.

Fisher and Rose keep the interval and claim boundary unchanged: this does not
promote mixed-family CIs, masked mixed-family fits, or calibration claims.

Grace checked focused validation commands rather than launching broad compute.

Shannon checked open PR state before shared dev-log/register edits and kept
GitHub issue closure separate from local branch evidence.

## Design Docs

- MIX-02 in `docs/design/35-validation-debt-register.md` now records local
  #610 evidence without claiming public closure.

## Pkgdown And Documentation

No generated documentation, pkgdown navigation, README, NEWS, or article source
changed.

## Roadmap Tick

N/A. No roadmap row, dashboard metric, or public capability status changed.

## GitHub Issue Ledger

- Inspected #610: still open on GitHub.
- Inspected open mixed-family search results; #610 remains the direct issue for
  this slice.
- No issue commented, closed, or created.

## Known Limitations And Next Actions

- The branch is local and ahead of origin; #610 should stay open until the
  relevant commits are pushed, reviewed, and merged.
- Continue Phase 2 with the next missing/mixed correctness guard or move to the
  first focused implementation gap if review identifies one.
