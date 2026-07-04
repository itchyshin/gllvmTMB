# Augmented Diagonal Runtime / Article Alignment

Date: 2026-06-18 23:20 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Finish the next narrow `unique()` deprecation cleanup by aligning runtime
diagnostics and the random-regression article. The article's displayed
non-Gaussian boundary error still quoted the old "ordinary `unique()`
random-regression" wording after the code had moved toward default
`latent()` plus diagonal `Psi`.

## Changed

- Updated `R/fit-multi.R` diagnostics so the augmented ordinary diagonal path
  is labelled "diagonal-compatibility random-regression" rather than
  "`unique()` random-regression" when describing path constraints.
- Preserved `unique(1 + x | unit)` only where it names explicit compatibility
  syntax.
- Updated `vignettes/articles/random-regression-reaction-norms.Rmd` so the
  displayed non-Gaussian error matches the runtime wording.

Article-tier audit: this remains a narrow Tier-1 article consistency repair.

## Verification

- `Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); devtools::test(filter = "ordinary-latent|canonical-keywords|keyword-grid|unique-family-deprecation", reporter = "summary")'`
  -> passed with 3 expected INLA skips.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/random-regression-reaction-norms", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> rendered `pkgdown-site/articles/random-regression-reaction-norms.html`.
- `rg -n -F '{.fn unique} random-regression' R/fit-multi.R R man vignettes tests || true; rg -n -F 'ordinary `unique()` random-regression' vignettes R man tests || true; rg -n -F 'ordinary unique random-regression' R man vignettes tests || true`
  -> no hits.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

## Definition-Of-Done Notes

- Implementation: runtime diagnostics and article quote changed locally.
- Simulation recovery: not applicable; no model behavior changed.
- Documentation: article rendered and pkgdown checked.
- Runnable example: existing non-Gaussian boundary example remains intentionally
  non-evaluated and now matches runtime wording.
- Check log: updated in `docs/dev-log/check-log.md`.
- Review pass: lifecycle and article-tier guidance applied. No likelihood,
  formula grammar, or TMB parameterization changed.

Still not claimed: keyword removal, source-specific/kernel latent-Psi folding,
Paper 2 multi-kernel explicit-Psi support, bridge completion, release
readiness, or scientific coverage completion.
