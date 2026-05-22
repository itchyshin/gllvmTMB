# After-Task Report: Summary Canonical Levels

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Boole, Rose, Grace
**Spawned subagents:** none

## Scope

Removed legacy `B` / `W` level aliases from the ordinary summary and
extractor-test path where the alias behavior was not under test.

This is a small behavior-polish slice. It does not change the alias support
itself; the dedicated alias tests remain in `test-sigma-rename.R`.

## Files Touched

- `R/methods-gllvmTMB.R`
- `tests/testthat/test-extractors.R`
- `tests/testthat/test-integration-tour.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-summary-canonical-levels.md`

## What Changed

- `summary.gllvmTMB_multi()` now calls `extract_communality()` with
  `level = "unit"` and `level = "unit_obs"` instead of the legacy aliases
  `"B"` and `"W"`.
- Non-legacy extractor/integration tests now use canonical level names, so the
  focused suite no longer emits deprecation warnings.

## Validation

- `air format R/methods-gllvmTMB.R tests/testthat/test-extractors.R tests/testthat/test-integration-tour.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "print-labels|integration-tour|extractors", stop_on_failure = TRUE)'`
  -> 112 passes, 0 failures, 0 warnings, 0 skips.
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Stale internal-call scan:

  ```sh
  rg -n 'extract_communality\([^\n]*"B"|extract_communality\([^\n]*"W"|extract_ordination\([^\n]*"B"|extract_ordination\([^\n]*"W"' R tests/testthat | sed -n '1,180p'
  ```

  -> remaining hits are explicit legacy-alias tests or suppressed rotation
  tests, not the normal summary path.

## Definition-of-Done Notes

- Implementation: local branch only; not merged or pushed.
- Simulation recovery test: not applicable.
- Documentation: not applicable; no roxygen/Rd changes.
- Runnable user-facing example: not applicable.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Boole/Rose checked naming consistency; Grace focused tests.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this
  small behavior-polish slice.
- Some tests intentionally exercise legacy aliases; these remain because alias
  compatibility is still supported in 0.2.0.
