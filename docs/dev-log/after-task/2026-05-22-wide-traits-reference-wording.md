# After-Task Report: Wide Traits Reference Wording

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned public reference wording that still made long-format data sound like
the primary user path.

This is a roxygen-only documentation slice. It does not change parser behavior,
likelihoods, tests, or examples.

## Files Touched

- `R/methods-gllvmTMB.R`
- `R/traits-keyword.R`
- `man/gllvmTMB_multi-methods.Rd`
- `man/traits.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-wide-traits-reference-wording.md`

## What Changed

- Reworded the S3 methods reference to describe fits returned by
  `gllvmTMB()` from either wide `traits(...)` calls or already-stacked
  long data.
- Reworded the `traits()` reference so wide data are introduced as a direct
  path, not as a deviation from "canonical long-format" data.
- Replaced "same long-format engine" public wording with "same
  stacked-trait model after internal stacking".
- Kept the legacy `gllvmTMB_wide(Y, ...)` wording as a soft-deprecated
  migration path only.

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/gllvmTMB_multi-methods.Rd` and `man/traits.Rd`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/gllvmTMB_multi-methods.Rd man/traits.Rd; grep -Hc '^\\keyword' man/gllvmTMB_multi-methods.Rd man/traits.Rd || true`
  -> normal endings; zero keyword entries.
- Stale wording scan:

  ```sh
  rg -n 'on long-format multivariate data|canonical long-format|Both taught shapes reach the same long-format engine|for the long-format engine|long-format engine; `traits\(\)`|level = "B"|level = "W"|Long data are canonical|Stacked-Trait GLLVMs with TMB|standalone Template Model Builder' R/methods-gllvmTMB.R man/gllvmTMB_multi-methods.Rd R/traits-keyword.R man/traits.Rd README.md DESCRIPTION pkgdown-site/index.html
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: documentation only; local branch, not merged or pushed.
- Simulation recovery test: not applicable.
- Documentation: roxygen source and generated Rd agree.
- Runnable user-facing example: not applicable; examples unchanged.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose wording pass; Grace pkgdown check.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this
  wording-only cleanup.
- No 3-OS CI is available until the branch is pushed.
