# After-Task Report: Omega Extractor User-Path Cleanup

**Date:** 2026-05-22
**Branch:** `codex/reference-function-audit-2026-05-22`
**Review lenses:** Ada, Pat, Rose, Grace
**Spawned subagents:** none

## Scope

Cleaned small user-facing reference and advisory wording in the
Omega/proportion extractor family. This slice helps readers see the public
entry point (`gllvmTMB()`) and canonical `Psi` notation instead of internal
class names or old two-U language.

This does not change the extractor calculations, likelihoods, formula grammar,
examples, or variance decomposition definitions.

## Files Touched

- `R/extract-omega.R`
- `man/extract_Omega.Rd`
- `man/extract_phylo_signal.Rd`
- `man/extract_proportions.Rd`
- `man/extract_residual_split.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-omega-extractor-user-path.md`

## What Changed

- `extract_residual_split()`, `extract_Omega()`, `extract_phylo_signal()`, and
  `extract_proportions()` roxygen now describe `fit` as a result returned by
  `gllvmTMB()`, not as an internal `gllvmTMB_multi` object.
- Wrong-object errors in the same functions now say: "Provide a fit returned
  by `gllvmTMB()`."
- The phylogenetic signal advisory now reports `Psi_non = 0` for the missing
  non-phylogenetic unique component instead of the old `U (uniqueness)` wording.
- Internal comments now use "paired phylogenetic PGLLVM" rather than "two-U
  PGLLVM".

## Validation

- `air format R/extract-omega.R`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/extract_residual_split.Rd`, `man/extract_Omega.Rd`,
  `man/extract_phylo_signal.Rd`, and `man/extract_proportions.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-omega|olre-separation|m1-7-extract-omega|mixed-response-sigma", stop_on_failure = TRUE)'`
  -> 68 passes, 0 failures, 0 warnings, 0 skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before the check-log / after-task entry.
- Rd spot-check:
  `tail -5 man/extract_Omega.Rd man/extract_phylo_signal.Rd man/extract_proportions.Rd man/extract_residual_split.Rd; grep -Hc '^\\keyword' man/extract_Omega.Rd man/extract_phylo_signal.Rd man/extract_proportions.Rd man/extract_residual_split.Rd`
  -> normal endings; only `extract_residual_split.Rd` keeps its expected
  `internal` keyword.
- Stale wording scan:

  ```sh
  rg -n 'A `gllvmTMB_multi` fit|A \\code\{gllvmTMB_multi\} fit|Provide a \{\.cls gllvmTMB_multi\} fit|requires a gllvmTMB_multi|U \(uniqueness\)|U_diag|Two-U|two-U' R/extract-omega.R man/extract_Omega.Rd man/extract_phylo_signal.Rd man/extract_proportions.Rd man/extract_residual_split.Rd
  ```

  -> no hits.

## Definition-of-Done Notes

- Implementation: wording and advisory cleanup only; local branch, not merged
  or pushed.
- Simulation recovery test: not applicable because no estimator, family,
  likelihood, or formula grammar changed.
- Documentation: roxygen source and generated Rd agree.
- Runnable user-facing example: unchanged.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: Pat/Rose user-path and terminology pass; Grace pkgdown check.

## Residuals

- Full `devtools::test()` and `devtools::check()` were not rerun for this small
  extractor wording and advisory cleanup.
- No 3-OS CI is available until the branch is pushed.
