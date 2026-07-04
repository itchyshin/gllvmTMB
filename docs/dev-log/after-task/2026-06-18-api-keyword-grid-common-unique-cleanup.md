# API Keyword Grid Common-Unique Cleanup

Date: 2026-06-18 23:12 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Close one remaining public wording wrinkle in the post-coevolution
`unique()` deprecation cleanup. The API keyword-grid article already taught
ordinary `latent()` with default diagonal `Psi` and `indep()` for standalone
diagonal models, but one paragraph still implied ordinary users might need
`unique(..., common = TRUE)`.

## Changed

- Updated `vignettes/articles/api-keyword-grid.Rmd` so ordinary
  `common = TRUE` formulas migrate to:
  - `indep(..., common = TRUE)` for standalone diagonal models; or
  - `latent(..., common = TRUE)` for ordinary paired decompositions.
- Kept `unique()` documented as live compatibility syntax for old ordinary
  formulas and source-specific explicit-Psi components.
- Changed the no-correlation example comment to call `unique()` deprecated
  compatibility spelling rather than copy-first syntax.

Article-tier audit: this article remains Tier 2, because it is a technical
formula-grammar lookup, not a worked example.

## Verification

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/api-keyword-grid", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> rendered `pkgdown-site/articles/api-keyword-grid.html`.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")'`
  -> passed with 3 expected INLA skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n 'need.*unique\(\).*common|unique\(\).*common = TRUE|compatibility-only option such as\s*`common = TRUE`|new public examples should use `unique\(\)`' R man vignettes README.md NEWS.md docs/design || true`
  -> only the design rows that explicitly document `indep(..., common = TRUE)`
  as the replacement remained.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  -> dashboard JSON valid and whitespace checks clean.

## Definition-Of-Done Notes

- Implementation: article wording changed locally; not pushed or merged.
- Simulation recovery: not applicable; no model behavior changed.
- Documentation: source article rendered and pkgdown checked.
- Runnable example: the existing keyword-grid examples remain non-evaluated
  syntax examples by article design.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: lifecycle and article-tier guidance applied. No likelihood,
  formula grammar, or TMB parameterization was changed.

Still not claimed: keyword removal, source-specific/kernel latent-Psi folding,
Paper 2 multi-kernel explicit-Psi support, bridge completion, release
readiness, or scientific coverage completion.
