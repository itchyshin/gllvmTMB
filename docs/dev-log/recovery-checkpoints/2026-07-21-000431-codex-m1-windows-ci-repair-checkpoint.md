# Recovery Checkpoint: M1 Windows CI Repair

**Timestamp**: 2026-07-21 00:04:31 MDT

**Owner**: root Codex, sole writer

## Branch and working-tree status

Command: `git status --short --branch`

```text
## codex/gllvmtmb-060-m1-baseline-20260720...origin/codex/gllvmtmb-060-m1-baseline-20260720
 M R/plot-gllvmTMB.R
 M tests/testthat/test-plot-gllvmTMB.R
```

Builder: `/private/tmp/gllvmtmb-060-m1-builder`.

Committed source head before this repair:
`f4628a8cdda885ee66da6b806923c9c2501f463a`.

Draft PR: `#778`, open and merge-clean. The dirty primary checkout and every
parked worktree remain untouched.

## Current diff stat before durable receipt files

Command: `git diff --stat`

```text
 R/plot-gllvmTMB.R                   |  3 ++-
 tests/testthat/test-plot-gllvmTMB.R | 20 ++++++++++++++++++--
 2 files changed, 20 insertions(+), 3 deletions(-)
```

The later check-log amendment and this checkpoint intentionally enlarge that
literal two-file pre-receipt stat.

## Retained platform attempt

- PR Ubuntu run `29804219087`: PASS at `f4628a8c`.
- Manual three-OS run `29804302347`: FAIL at `f4628a8c`.
  - Ubuntu: PASS.
  - macOS: PASS.
  - Windows job `88551611475`: FAIL, one assertion at
    `tests/testthat/test-plot-gllvmTMB.R:447`; 7,235 passes, 786 skips, one
    warning, one failure.
- Manual Ubuntu-heavy run `29804303658`: still in progress at this checkpoint.

The failed Windows attempt is immutable evidence and stays in the final M1
denominator.

## Diagnosis and repair

The failing test required bitwise equality after floating-point division and
summation. Direct local reproduction produced one stack total at
`1 + .Machine$double.eps`. Types, attributes, factor order, and scientific
proportions were correct. Two independent read-only reviews classified the
failure as a test-contract defect.

The repair changes only an internal accuracy comment and the test contract. It
uses a component-scaled machine-roundoff bound, asserts finite non-negative
rendering values, and adds a deterministic pure-logic roundoff fixture. It does
not alter model, extractor, or plot behavior.

## Commands already run

- GitHub authentication and PR metadata inspection: PASS.
- Shared-file coordination census: only PR #778, no competing recent commit;
  the historical Windows-repair worktree was clean and the quarantined overlap
  remained unrelated to this four-file slice.
- Exact failed-job log inspection: one Windows assertion isolated.
- Direct numeric/type reproduction: one-machine-epsilon discrepancy reproduced.
- `devtools::test(filter = "plot-gllvmTMB")`: 250 passes, zero failures,
  errors, warnings, or skips.
- Parse checks for both modified R files: PASS.
- `git diff --check`: PASS.
- Independent pre-edit reviews: PASS only for the strict machine-roundoff
  repair; masking, loose tolerance, platform skip, rounding, and production
  residual-forcing fixes were rejected.
- Independent post-edit review: PASS; the bound retained sensitivity to
  deliberate `1e-12` and larger normalization defects.

## Commands still required

1. Commit and push the focused Windows repair with this durable receipt.
2. Run exact-head local standard package and pkgdown gates.
3. Dispatch a fresh exact-head manual three-OS package check and Ubuntu-heavy
   check; retain every attempt.
4. Amend the M1 after-task report, append the final run ledger, create a final
   platform-closeout checkpoint, and update PR #778 and Mission Control.
5. Obtain three fresh NOT-DONE-default completion reviews before closing M1.

## Next safest action

Commit this focused repair and run the local exact-head package/pkgdown gates.
Do not rerun only Windows: the new source head requires a complete new
exact-head platform cycle.

## Blocking question

None for the M1 repair. Separate maintainer authority remains required before
Design 86, Totoro/DRAC scientific compute, public EVA admission, candidate
freeze, tags, CRAN submission, or any release/readiness claim.
