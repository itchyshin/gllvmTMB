# After-task report: confidence-eye wording alignment

Date: 2026-05-22
Branch: `codex/reference-function-audit-2026-05-22`
Commit: pending at report time

## Scope

This slice aligned NEWS, the report-ready plotting contract, and the validation
debt register with the maintained name `confidence eye`. It did not change code
behavior: `style = "eye"` was already the primary plotting style and
`style = "raindrop"` remains a compatibility alias.

## What changed

- Updated NEWS so user-facing release text says `style = "eye"` and describes
  the display as a confidence eye.
- Updated `docs/design/53-report-ready-extractor-plot-contract.md` so metadata
  tables name `correlations_confidence_eye` and `sigma_table_confidence_eye`.
- Updated validation-debt rows EXT-19, EXT-24, and MIS-22 to describe
  confidence-eye plots, with raindrop retained only as alias language.

## Validation

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned `No problems
  found.`
- `git diff --check` was clean before adding this report.
- Primary-name scan:
  `rg -n 'style = "eye"|confidence-eye|confidence eye|Confidence eye|Confidence eyes|confidence eyes|confidence_eye' NEWS.md docs/design/53-report-ready-extractor-plot-contract.md docs/design/35-validation-debt-register.md`
  returned expected confidence-eye hits.
- Legacy-primary scan:
  `rg -n 'correlations_raindrop|sigma_table_raindrop|style = "raindrop"|raindrop plots|forest/raindrop|Raindrops|raindrops|Raindrop' NEWS.md docs/design/53-report-ready-extractor-plot-contract.md docs/design/35-validation-debt-register.md`
  returned compatibility-alias hits only.

## Review lenses

- Ada kept this as a wording alignment, not a plotting rewrite.
- Florence: name and caption language now match the intended hollow-circle /
  pale-compatibility visual.
- Pat: user-facing NEWS now leads with the name users should type.
- Rose: stale `*_raindrop` plot-type names were removed from the design
  contract.
- Grace: pkgdown check passed locally.

## Definition of done notes

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation recovery: not applicable; no model, estimator, likelihood, or
   formula grammar changed.
3. Documentation: NEWS and design/register docs updated.
4. Runnable example: not changed in this slice; the morphometrics article still
   exercises the compatibility alias and is left for a later article pass.
5. Check-log: updated in `docs/dev-log/check-log.md`.
6. Review pass: Ada, Florence, Pat, Rose, and Grace lenses applied as above.

## Residual risk

- Article chunks still contain `style = "raindrop"` in the cached
  morphometrics example. That is supported by the alias, but a later
  article-specific pass should switch visible examples to `style = "eye"`.
