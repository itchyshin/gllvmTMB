# After-Task Report: Stacked Response Reference Wording

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned small public-reference phrases that still described user-facing paths
as "long-format engine/vector" rather than stacked-trait model plumbing.

This is a roxygen-only documentation slice. It does not change fitting,
weight handling, spatial parsing, or examples.

## Files Touched

- `R/gllvmTMB.R`
- `R/spde-keyword.R`
- `man/gllvmTMB.Rd`
- `man/spde.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-stacked-response-reference-wording.md`

## What Changed

- `gllvmTMB()` weights documentation now says wide and long accepted weight
  shapes normalize to the same stacked response vector.
- `spde()` deprecated-alias documentation no longer calls the alias page the
  "canonical place" to document SPDE details.
- The `spde()` `trait` parameter now says the stacked-trait fit treats factor
  levels as responses.

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/gllvmTMB.Rd` and `man/spde.Rd`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/gllvmTMB.Rd man/spde.Rd; grep -Hc '^\\keyword' man/gllvmTMB.Rd man/spde.Rd`
  -> normal endings; `spde` keeps its expected `internal` keyword.
- Stale wording scan:

  ```sh
  rg -n 'canonical place to document|long-format engine treats|long-format vector before fitting|same long-format vector|long-format engine|canonical long-format' R/spde-keyword.R R/gllvmTMB.R man/spde.Rd man/gllvmTMB.Rd
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: documentation only; local branch, not merged or pushed.
- Simulation recovery test: not applicable.
- Documentation: roxygen source and generated Rd agree.
- Runnable user-facing example: unchanged.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose wording pass; Grace pkgdown check.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this
  roxygen-only cleanup.
- No 3-OS CI is available until the branch is pushed.
