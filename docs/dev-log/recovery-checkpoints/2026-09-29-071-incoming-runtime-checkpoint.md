# Recovery checkpoint: gllvmTMB 0.7.1 incoming runtime repair

## Git state

- Branch: `codex/cran-071-first-20260927`
- HEAD: `471211adc01fad1a687c8b806060ea9071649e8a`
- `git status --short --branch`: branch is one commit ahead of `origin/codex/cran-071-first-20260927`; modified `DESCRIPTION`, `cran-comments.md`, `docs/dev-log/check-log.md`, and eight `tests/testthat/` files; untracked prior submission after-task report remains.
- `git diff --stat`: 11 tracked files, 86 insertions and 19 deletions. `git diff --check` passed.
- Isolated worktree: `/Users/z3437171/.codex/worktrees/cran-071-first/gllvmTMB`; primary checkout untouched.
- Active exclusive lease: `codex:cran-071-incoming-resubmission`; paths include `DESCRIPTION`, `inst/WORDLIST`, `tests/testthat/`, `cran-comments.md`, `docs/dev-log/check-log.md`, `docs/dev-log/after-task/`, `.unlazy/cran-071-resubmission/`, and this checkpoint.

## Work completed

- Inspected retained CRAN incoming logs for Windows and Debian. Windows test stage: 20 minutes. Debian test stage: 507 seconds. Both incoming logs show `New submission` and a possible misspelling `TMB (3:55)` in DESCRIPTION.
- Changed the DESCRIPTION title to omit `TMB`; `spelling::spell_check_package('.', vignettes = FALSE)` reported no spelling errors. Exact tarball verification remains open.
- At the user's request, added eight `skip_on_cran()` guards to internal prototype, compiled-objective, and developer-fit test blocks. Full tests remain active outside CRAN.
- Repeated eight-file CRAN-mode profile: 80.1 seconds versus the predecessor 235.5 seconds on this Mac.
- Completed full CRAN-mode file-by-file diagnostic over 515 files: 711.67 seconds. Silent reporter means this is timing evidence only, not a canonical test pass. No uncaught file-level errors were logged. The Windows runtime target remains unproven and likely unmet.
- Updated `.unlazy/cran-071-resubmission/GATES.md` and appended evidence to `docs/dev-log/check-log.md`.

## Exact commands and outcomes

- `Rscript --vanilla -e 'x <- spelling::spell_check_package(".", vignettes = FALSE); ...'`: no spelling errors; title checked to contain no `TMB`.
- CRAN-mode profile of the eight changed test files with `testthat::test_file(..., reporter = "silent")`: 80.1 seconds total.
- CRAN-mode per-file profile of all `tests/testthat/test*.R` files: 515 files, 711.67 seconds; timing only.
- `git diff --check`: passed.
- No replacement tarball, exact-artifact check, fresh Windows check, win-builder upload, or CRAN resubmission exists.

## Next safest action

Wait for Shinichi's answer about whether to broaden the CRAN-only reduction to non-public development/research tests while adding smoke coverage for advertised features. If approved, define the feature coverage matrix first, inspect every proposed skip, and profile the resulting complete CRAN-mode suite. If declined, retain the measured candidate and report R2 blocked. Do not build or upload a replacement until the runtime plan is agreed and R2 passes or has an approved explicit timing justification.

## Blocking decision

The user authorized the broader CRAN-only runtime adjustment. Current additions are recorded in the check log. Files with active branch work were left untouched. No exact candidate has been built. Continue with full local/CI suite verification, then a clean release commit, tarball build, exact-tarball checks, and fresh Windows timing before resubmission.
