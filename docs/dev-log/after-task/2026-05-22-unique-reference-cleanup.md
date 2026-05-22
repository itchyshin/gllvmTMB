# After-Task Report: Unique Reference Cleanup

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned stale public reference wording in the `unique()` / `diag_re` help
topic.

This is a documentation-only slice. It does not change formula parsing,
likelihood code, examples that run on CRAN, or user-facing behavior.

## Files Touched

- `R/unique-keyword.R`
- `man/diag_re.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-unique-reference-cleanup.md`

## What Changed

- Replaced the old phylogenetic decomposition wording
  `Sigma_non,shared + U` with canonical `Sigma_non = Lambda_non Lambda_non^T +
  Psi_non`.
- Replaced teaching examples that used `level = "B"` with
  `level = "unit"`.
- Replaced old `unique-S` / `unique(S)` wording with plain
  unique-variance wording.
- Replaced one stale "explicit `diag()` term" phrase with
  "explicit `unique()` term".

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/diag_re.Rd`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/diag_re.Rd && grep -c '^\\keyword' man/diag_re.Rd`
  -> normal ending; one expected `internal` keyword.
- Stale wording scan:

  ```sh
  rg -n "unique\\(S\\)|s_\\{|S_B|S_W| U\\.|# U|level = \\\"B\\\"|level = \\\"W\\\"|diag\\(\\) term|unique-S|non,shared|Long data are canonical|attached plot data" R/unique-keyword.R man/diag_re.Rd
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: documentation only; local branch, not merged or pushed.
- Simulation recovery test: not applicable.
- Documentation: roxygen source and generated Rd agree.
- Runnable user-facing example: not applicable; examples remain `\dontrun`.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose wording pass; Grace pkgdown check.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this
  roxygen-only cleanup.
- No 3-OS CI is available until the branch is pushed.
