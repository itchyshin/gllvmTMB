# Codex Recovery Checkpoint

Generated: 2026-06-03 01:30:28 MDT
Repository: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
Goal: complete PR cleanup, publish pkgdown, rebase Track A, split binary-JSDM citation and missing-data docs branches
Suggested next step: wait for pkgdown run 26870028110 to finish, then merge rebuilt PR #428 if still clean

## Purpose

This file is a durable handoff for a long or interrupted Codex thread. The
working tree is still authoritative: rerun `git status` and `git diff` before
editing, testing, committing, or summarizing the package state.

## Git State

### Branch And Status

`git status --short --branch`

```text
## docs/coev-kernel-article...origin/docs/coev-kernel-article [gone]
 M DESCRIPTION
 M NEWS.md
 M R/gllvmTMB.R
 M R/methods-gllvmTMB.R
 M R/missing-predictor.R
 M README.md
 M _pkgdown.yml
 M docs/design/35-validation-debt-register.md
 M docs/design/61-capability-status.md
 M docs/dev-log/check-log.md
 M man/add_utm_columns.Rd
 M man/extract_correlations.Rd
 M man/gllvmTMB-package.Rd
 M man/gllvmTMB.Rd
 M man/impute_model.Rd
 M man/make_mesh.Rd
 M man/miss_control.Rd
 M man/predict_missing.Rd
 M man/reexports.Rd
 M vignettes/articles/missing-data.Rmd
 M vignettes/gllvmTMB.Rmd
?? docs/dev-log/after-task/2026-06-02-binary-jsdm-package-citation.md
?? docs/dev-log/recovery-checkpoints/2026-06-02-203104-codex-coevolution-merge-resume.md
```

### Changed Files

`git diff --name-status`

```text
M	DESCRIPTION
M	NEWS.md
M	R/gllvmTMB.R
M	R/methods-gllvmTMB.R
M	R/missing-predictor.R
M	README.md
M	_pkgdown.yml
M	docs/design/35-validation-debt-register.md
M	docs/design/61-capability-status.md
M	docs/dev-log/check-log.md
M	man/add_utm_columns.Rd
M	man/extract_correlations.Rd
M	man/gllvmTMB-package.Rd
M	man/gllvmTMB.Rd
M	man/impute_model.Rd
M	man/make_mesh.Rd
M	man/miss_control.Rd
M	man/predict_missing.Rd
M	man/reexports.Rd
M	vignettes/articles/missing-data.Rmd
M	vignettes/gllvmTMB.Rmd
```

`git ls-files --others --exclude-standard`

```text
docs/dev-log/after-task/2026-06-02-binary-jsdm-package-citation.md
docs/dev-log/recovery-checkpoints/2026-06-02-203104-codex-coevolution-merge-resume.md
```

### Diff Stat

`git diff --stat`

```text
 DESCRIPTION                                |  4 ++
 NEWS.md                                    |  8 +++-
 R/gllvmTMB.R                               | 46 +++++++++++++---------
 R/methods-gllvmTMB.R                       |  4 +-
 R/missing-predictor.R                      | 62 +++++++++++++++++-------------
 README.md                                  | 21 ++++++----
 _pkgdown.yml                               |  2 +-
 docs/design/35-validation-debt-register.md | 16 ++++++--
 docs/design/61-capability-status.md        | 34 ++++++++--------
 docs/dev-log/check-log.md                  | 60 +++++++++++++++++++++++++++++
 man/add_utm_columns.Rd                     |  2 +-
 man/extract_correlations.Rd                |  2 +-
 man/gllvmTMB-package.Rd                    |  7 +---
 man/gllvmTMB.Rd                            | 40 +++++++++++--------
 man/impute_model.Rd                        | 19 +++++----
 man/make_mesh.Rd                           |  6 +--
 man/miss_control.Rd                        |  6 ++-
 man/predict_missing.Rd                     |  4 +-
 man/reexports.Rd                           |  2 +-
 vignettes/articles/missing-data.Rmd        | 54 +++++++++++++-------------
 vignettes/gllvmTMB.Rmd                     | 16 +++++---
 21 files changed, 267 insertions(+), 148 deletions(-)
```

### Current Head

`git log -1 --oneline`

```text
50de43e docs(coevolution): add cross-lineage kernel article
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

- `docs/dev-log/after-task/2026-06-02-binary-jsdm-package-citation.md` (2026-06-02 19:56): # After Task: Binary JSDM Package Citation
- `docs/dev-log/after-task/2026-06-02-coevolution-article-closeout.md` (2026-06-02 06:35): # Coevolution Article Closeout
- `docs/dev-log/after-task/2026-05-31-kernel-c2-coevolution-recovery.md` (2026-05-31 20:47): # After Task: Kernel C2 Coevolution Recovery
- `docs/dev-log/after-task/2026-05-31-missing-data-evidence-base.md` (2026-05-31 19:56): # Evidence base: model-based missing-data layer (FIML via Laplace)
- `docs/dev-log/after-task/2026-05-31-pkgdown-phylo-signal-mi-hotfix.md` (2026-05-31 16:05): # After Task: pkgdown `phylo_signal_mi()` reference hotfix
- `docs/dev-log/after-task/2026-05-31-kernel-c1-equivalence.md` (2026-05-31 15:23): # After Task: C1 Dense `kernel_*()` Equivalence
- `docs/dev-log/after-task/2026-05-31-cluster2-tier.md` (2026-05-31 15:23): # After Task: cluster2 -- second independent diagonal grouping tier
- `docs/dev-log/after-task/2026-05-31-kernel-c0-coevolution-prototype.md` (2026-05-31 11:32): # 2026-05-31 -- C0 cross-lineage coevolution kernel helper + prototype

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
