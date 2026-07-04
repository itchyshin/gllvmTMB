# After-task report: animal-model browser review

Date: 2026-06-19 03:54 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closed the true-browser review gap for
`vignettes/articles/animal-model.Rmd` and repaired the rendered
genetic-correlation heatmap's missing alt text. It did not change model code or
scientific claim status.

## Files touched

- `vignettes/articles/animal-model.Rmd`
- `pkgdown-site/articles/animal-model.html`
- `pkgdown-site/articles/animal-model_files/figure-html/G3-correlation-1.png`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-animal-model-browser-review.md`

## Browser evidence

The in-app browser was unavailable, and Playwright's bundled Chromium was not
installed. A system Google Chrome executable was available, so the review used
Playwright with:

`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`

Checked page:

- `pkgdown-site/articles/animal-model.html`

Viewport checks:

- Desktop: 1440 x 1000
- Mobile: 390 x 844

Evidence:

- Page title was
  `The animal model: heritability and genetic covariance • gllvmTMB`.
- H1 was `The animal model: heritability and genetic covariance`.
- Console messages: none.
- Page errors: none.
- Internal article gate was present.
- Bad-claim scan found none for `release ready`, `release-ready`,
  `scientific coverage passed`, `scientific-coverage passed`,
  `publication-ready`, `publication grade`, or `publication-grade`.
- Pre-edit rendered HTML had an empty alt attribute on
  `G3-correlation-1.png`.
- The `G3-correlation` chunk now has descriptive `fig.alt` text.
- The rendered heatmap natural size was 1113 x 921.
- The mobile heatmap displayed at 366 x 303.
- Desktop overflow scan found only the expected hidden skip link plus one
  horizontally scrollable code block.
- Mobile overflow scan found expected narrow-layout table/math overflow; visual
  screenshot inspection did not show incoherent text overlap.

Screenshots inspected locally:

- `/tmp/gllvm-animal-model-desktop-after.png`
- `/tmp/gllvm-animal-model-mobile-after.png`

## Checks

- `Rscript --vanilla -e 'pkgdown::build_article("articles/animal-model", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  - Passed and wrote `pkgdown-site/articles/animal-model.html`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Passed with `No problems found.`

## Definition-of-done notes

- Implementation: no model behavior changed.
- Simulation recovery: not applicable.
- Documentation: source article and rendered pkgdown HTML were updated.
- Runnable example: unchanged; this was browser/accessibility review.
- Check-log: this task has a dated entry with exact evidence.
- Review/scope: article remains internal; this is not public promotion.

## Not claimed

- No public promotion or final placement.
- No larger-pedigree validation.
- No cross-package agreement promotion.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
