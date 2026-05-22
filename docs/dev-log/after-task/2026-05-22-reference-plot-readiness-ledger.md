# After-task report: reference/plot readiness ledger

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice closed the 12-slice block by refreshing visual-debt ledgers and
recording a PR-readiness audit. It did not change package code, examples, Rd
files, or exported behavior.

## What changed

- `docs/design/46-visualization-grammar.md` now records the current visual
  debt ledger rather than the stale "Phase 1c-viz at 0/7" wording.
- `docs/design/53-report-ready-extractor-plot-contract.md` now names the
  remaining visual QA debt before the figure surface can be called stable.
- `docs/design/35-validation-debt-register.md` now describes confidence eyes
  as soft filled compatibility displays and corrects `rotate_loadings()` to
  varimax / promax wording.
- `docs/design/06-extractors-contract.md` now matches the implemented
  `getLoadings(..., rotate = ...)` and `rotate_loadings(..., method = ...)`
  contracts.
- Added `docs/dev-log/audits/2026-05-22-reference-plot-readiness.md`.

## Validation

- `Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'`
  returned 2547 passes, 13 skips, 1 warning, 0 failures.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  returned `No problems found.`
- `git diff --check` was clean before adding this report.
- Stale wording scan:
  `rg -n 'Phase 1c-viz at 0/7|quartimax|Confidence-I|confidence-I|randrop|raindrop shows|Tight drops|ci-correlation-raindrop' docs/design NEWS.md README.md vignettes R man tests _pkgdown.yml`
  returned no hits.
- Raindrop compatibility scan:
  `rg -n 'style = "raindrop"|raindrop|Raindrop|raindrop_level' R man tests NEWS.md docs/design vignettes README.md _pkgdown.yml`
  returned expected alias/documentation/test hits only.

## Review lenses

- Ada closed the 12-slice block around actual local evidence.
- Florence kept the visual ledger honest: confidence-eye QA improved, but the
  package still needs rendered article QA or visual snapshots.
- Pat: wide-first and confidence-eye paths are easier to teach, but the gallery
  should wait until helper churn slows.
- Fisher: confidence eyes remain frequentist compatibility displays, not
  posterior densities or interval calibration evidence.
- Grace: full tests and pkgdown pass locally; no `devtools::check()` or 3-OS CI
  yet.
- Rose: stale `quartimax`, old Phase 1c-viz wording, and primary `raindrop`
  wording were removed or classified.
- Shannon: no open PRs were visible; branch remains local/ahead and unpushed.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no estimator, likelihood, family, or
   formula grammar changed.
3. Documentation: design ledgers and audit report updated.
4. Runnable user-facing example: no new example source changed in this slice;
   existing tests and pkgdown cover the branch state.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Florence, Pat, Fisher, Grace, Rose, and Shannon lenses
   applied as above.

## Residual risk

- `devtools::check(args = "--no-manual")` was not rerun after this final
  design-ledger slice.
- No 3-OS CI and no `vdiffr` snapshots yet.
- The full-test run still has one known warning from legacy `level = "spde"`
  usage in `test-spatial-latent-recovery.R`.
