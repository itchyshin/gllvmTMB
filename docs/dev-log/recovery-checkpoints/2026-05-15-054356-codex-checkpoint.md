# Codex Recovery Checkpoint

Generated: 2026-05-15 05:43:56 MDT
Repository: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
Goal: Adopt drmTMB's codex-checkpoint.R tool (Jason cross-team scout action item)
Suggested next step: Open PR for the lift; then proceed to Phase 1b item 3 (check_auto_residual safeguard)

## Purpose

This file is a durable handoff for a long or interrupted Codex thread. The
working tree is still authoritative: rerun `git status` and `git diff` before
editing, testing, committing, or summarizing the package state.

## Git State

### Branch And Status

`git status --short --branch`

```text
## agent/lift-codex-checkpoint-from-drmtmb
?? docs/dev-log/recovery-checkpoints/
?? tools/
```

### Changed Files

`git diff --name-status`

```text
(no output)
```

`git ls-files --others --exclude-standard`

```text
docs/dev-log/recovery-checkpoints/.gitkeep
docs/dev-log/recovery-checkpoints/README.md
tools/codex-checkpoint.R
```

### Diff Stat

`git diff --stat`

```text
(no output)
```

### Current Head

`git log -1 --oneline`

```text
d47a833 Phase 1b: mu_t Beta/betabinomial clamp prevents trigamma blow-up (#100)
```

## Recent Project Evidence

### Newest `docs/dev-log/check-log.md` Entries (3 sections)

# Check log

Append-only record of `R CMD check`, `devtools::test()`, and
`pkgdown` runs that produced meaningful evidence. Keep entries
date-stamped.

## 2026-05-10 -- drmTMB-parity match exposes unstated tidyselect

Scope:

- removed `--no-manual --ignore-vignettes` / `--no-build-vignettes`
  overrides from `.github/workflows/R-CMD-check.yaml` so R CMD check
  runs drmTMB-exact defaults;
- the strict defaults surfaced `* checking for unstated dependencies
  in 'tests' ... WARNING` (1 WARNING, 0 ERROR, 0 NOTE) on ubuntu and
  macos runs of PR #3 (run id 25640098258);
- root cause: `tidyselect` was in DESCRIPTION `Imports` (for
  `R/traits-keyword.R` and `R/gllvmTMB-wide.R`) but not in
  `Suggests` (for the test files that use `tidyselect::all_of` and
  related verbs);
- added `tidyselect` to `Suggests:` so R CMD check finds the test-
  side namespace declaration too.

Decision: the drmTMB-parity strictness is doing exactly what it
should -- surfacing real issues our skip-args were masking. Keep
the strictness; fix the underlying declarations.

## 2026-05-10 -- mgcv unstated in tests (second pass of the same class)

Scope:

- after the tidyselect fix above, PR #3 R-CMD-check #6 surfaced a
  second instance of the same warning class: `'::' or ':::' import
  not declared from: 'mgcv'` (Ubuntu + macOS; Windows cancelled);
- root cause: `tests/testthat/test-tweedie-recovery.R` uses
  `mgcv::rTweedie` (line 27, 77) to simulate Tweedie responses, but
  the bootstrap dropped `mgcv` from DESCRIPTION entirely when it cut
  the sdmTMB smoother machinery;
- proactive sweep: greped every `pkg::` use in `tests/testthat/*.R`
  against current Imports + Suggests. Found exactly one other
  missing declaration (mgcv) -- no third pass expected;
- added `mgcv` to `Suggests:` (tests use it; R/ does not need it).

Lesson encoded: a single warning of class X should trigger a sweep
for the whole class, not a fix-then-wait-for-next-instance cycle.

## 2026-05-10 -- Windows wall-time accommodation (45 min temporary)

Scope:

- PR #3 set `timeout-minutes: 30` to match drmTMB exactly;
- Ubuntu (21-24m) and macOS (21m) finish well within the budget;
- Windows-latest R CMD check ran 28m 40s before being cancelled by
  the 30-min cap (run id 25640098258, then 25641006745, then
  25642532495 -- all same Windows cap-hit);
- root cause: Windows TMB compilation + 1250-test execution is
  intrinsically slower than Linux/macOS for this package size.
  drmTMB does 3-OS in 7 min total because their package has ~700
  tests and ~30 exports vs our 1250 tests and ~60 exports;
- bumped `timeout-minutes` 30 -> 45 as a documented temporary;
  this still catches real regressions while letting Windows complete
  its current workload.

Decision: keep the 45-min budget through Phase 1 of ROADMAP. The
Phase 1 task is to gate the slowest 20% of tests behind
`Sys.getenv("RUN_SLOW_TESTS") != ""` so Windows fits in drmTMB's
30-min budget. Once gated, lower `timeout-minutes` back to 30 to
re-establish the strict discipline gate.


### Newest After-Task Reports

- `docs/dev-log/after-task/2026-05-14-phase-1a-close.md` (2026-05-14 17:56): # After-task: Phase 1a close (Batch E + PIC/U retirement + README fix) -- 2026-05-14
- `docs/dev-log/after-task/2026-05-14-phase-1a-batch-d.md` (2026-05-14 17:56): # After-task: Phase 1a Batch D -- 2026-05-14
- `docs/dev-log/after-task/2026-05-14-phase-1a-batch-b.md` (2026-05-14 17:12): # After-task: Phase 1a Batch B + NS-3b/NS-4/NS-5 stragglers -- 2026-05-14
- `docs/dev-log/after-task/2026-05-14-roadmap-refresh.md` (2026-05-14 16:40): # After-task: Roadmap page refresh + pkgdown exposure -- 2026-05-14
- `docs/dev-log/after-task/2026-05-14-phase-1a-batch-a.md` (2026-05-14 14:20): # After-task: Phase 1a Batch A + notation-switch stragglers -- 2026-05-14
- `docs/dev-log/after-task/2026-05-14-notation-switch-ns5-articles-part2-news.md` (2026-05-14 11:23): # After-task: Notation switch NS-5 -- articles part 2 + NEWS -- 2026-05-14
- `docs/dev-log/after-task/2026-05-14-notation-switch-ns4-articles-part1.md` (2026-05-14 11:23): # After-task: Notation switch NS-4 -- articles part 1 math prose -- 2026-05-14
- `docs/dev-log/after-task/2026-05-14-notation-switch-ns3b-r-roxygen.md` (2026-05-14 09:35): # After-task: Notation switch NS-3b -- R/ roxygen math-prose sweep -- 2026-05-14

## Recovery Commands

Run these at the start of the next task before assuming this checkpoint is
still current:

```sh
git status --short --branch
git diff --stat
git diff
sed -n '1,240p' docs/dev-log/check-log.md
ls -lt docs/dev-log/after-task | head
```

## Notes For The Next Agent

- Do not treat this checkpoint as approval for broad changes.
- Preserve unrelated user, Codex, or Claude Code edits.
- If the diff is large, identify the smallest safe next step before editing.
- If validation is stale or incomplete, report that explicitly.
