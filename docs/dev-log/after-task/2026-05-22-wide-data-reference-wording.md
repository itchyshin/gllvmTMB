# After-Task Report: Wide Data Reference Wording

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned `traits()` and `gllvmTMB_wide()` reference wording so wide data is
presented as a public stacked-trait workflow rather than as a secondary route
to a "long-format engine."

This is a reference wording cleanup. It does not change parsing, pivoting,
weight normalisation, missing-response handling, or the soft-deprecation status
of `gllvmTMB_wide()`.

## Files Touched

- `R/traits-keyword.R`
- `R/gllvmTMB-wide.R`
- `man/traits.Rd`
- `man/gllvmTMB_wide.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-wide-data-reference-wording.md`

## What Changed

- The `traits()` source comment now says the wide formula path dispatches to
  the same stacked-trait model fit.
- The `traits()` docs now describe `gllvmTMB_wide()` as retained for legacy
  matrix-wrapper workflows, not "matrix-first workflows."
- `gllvmTMB_wide()` weights docs now say weights normalise to the same stacked
  response vector.
- The NA-cell filtering comment now says the stacked response cannot contain NA
  rows, matching the missing-response contract.

## Validation

- `air format R/traits-keyword.R R/gllvmTMB-wide.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/traits.Rd` and `man/gllvmTMB_wide.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|gllvmTMB-wide|wide-weights-matrix|missing-response", stop_on_failure = TRUE)'`
  -> 105 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/traits.Rd man/gllvmTMB_wide.Rd; grep -Hc '^\\keyword' man/traits.Rd man/gllvmTMB_wide.Rd`
  -> normal endings; `gllvmTMB_wide` keeps its expected `internal` keyword.
- Stale wording scan:

  ```sh
  rg -n 'long-format engine|same long-format vector|matrix-first workflows|The long-format engine errors|canonical long-format' R/traits-keyword.R R/gllvmTMB-wide.R man/traits.Rd man/gllvmTMB_wide.Rd
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: wording only; local branch, not merged or pushed.
- Simulation recovery test: not applicable.
- Documentation: roxygen source and generated Rd agree.
- Runnable user-facing example: unchanged.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose wording pass; Grace focused tests and pkgdown check.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this
  narrow reference wording cleanup.
- No 3-OS CI is available until the branch is pushed.
