# After-Task Report: Paired Phylogenetic Terminology

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Rose, Pat, Grace
**Spawned subagents:** none

## Scope

Replaced remaining new-facing `two-U` wording in the `phylo_unique()` reference
path and adjacent source comments. New wording uses paired phylogenetic PGLLVM
or two-psi language, matching the `Psi` notation used elsewhere.

This is a terminology-only cleanup. It does not change phylogenetic parsing,
likelihood code, covariance extraction, or examples.

## Files Touched

- `R/brms-sugar.R`
- `R/bootstrap-sigma.R`
- `R/extract-sigma.R`
- `R/extract-two-psi-cross-check.R`
- `R/fit-multi.R`
- `man/phylo_unique.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-paired-phylogenetic-terminology.md`

## What Changed

- `phylo_unique()` reference text now labels the recommended co-fit mode as a
  paired PGLLVM rather than a two-U PGLLVM.
- Adjacent implementation comments now use "paired phylogenetic PGLLVM" or
  "two-psi layouts" where appropriate.

## Validation

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/phylo_unique.Rd`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/phylo_unique.Rd; grep -Hc '^\\keyword' man/phylo_unique.Rd`
  -> normal ending; no `\keyword{}` entries.
- Stale wording scan:

  ```sh
  rg -n 'two-U|Two-U|U \(uniqueness\)|diag\(U\)' R/brms-sugar.R R/bootstrap-sigma.R R/extract-sigma.R R/extract-two-psi-cross-check.R R/fit-multi.R man/phylo_unique.Rd
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: terminology only; local branch, not merged or pushed.
- Simulation recovery test: not applicable.
- Documentation: roxygen source and generated Rd agree.
- Runnable user-facing example: unchanged.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Rose terminology check; Pat reader wording; Grace pkgdown check.

## Residuals

- Tests were not rerun because this slice changed comments and roxygen wording
  only.
- Historical design/dev-log references to the old two-U task label remain when
  they describe older work.
- No 3-OS CI is available until the branch is pushed.
