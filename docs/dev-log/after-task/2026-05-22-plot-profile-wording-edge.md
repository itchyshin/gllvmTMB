# After-Task Report: Plot/Profile Wording Edge Cleanup

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned two small but visible wording edges in plot/profile helper surfaces:
the plot method's old B/W default-collapse note and malformed cli markup in
profile-derived wrong-object errors.

This does not change profile algorithms, plot data, extraction, or formula
grammar.

## Files Touched

- `R/plot-gllvmTMB.R`
- `R/profile-derived.R`
- `man/plot.gllvmTMB_multi.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-plot-profile-wording-edge.md`

## What Changed

- `plot.gllvmTMB_multi()` now says a reflexive `match.arg(level)` would
  collapse the default to `"unit"` and drop the `unit_obs` panel.
- Profile-derived wrong-object errors now use cli's `{.fn gllvmTMB}` markup.

## Validation

- `air format R/plot-gllvmTMB.R R/profile-derived.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/plot.gllvmTMB_multi.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "profile-ci|profile-targets|plot-gllvmTMB", stop_on_failure = TRUE)'`
  -> 250 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/plot.gllvmTMB_multi.Rd; grep -Hc '^\\keyword' man/plot.gllvmTMB_multi.Rd`
  -> normal ending; no `\keyword{}` entries.
- Stale wording scan:

  ```sh
  rg -n '\{\.fun gllvmTMB\}|collapse the default to `"B"`|drop the W panel|collapse the default to \\code\{"B"\}|drop the W panel' R/plot-gllvmTMB.R R/profile-derived.R man/plot.gllvmTMB_multi.Rd
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: wording and cli-markup only; local branch, not merged or
  pushed.
- Simulation recovery test: not applicable.
- Documentation: roxygen source and generated Rd agree.
- Runnable user-facing example: unchanged.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose wording; Grace focused tests and pkgdown.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this
  narrow cleanup.
- No 3-OS CI is available until the branch is pushed.
