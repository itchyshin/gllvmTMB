# After-task report: mixed-family-extractors browser review

Date: 2026-06-19 04:40 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closed the true-browser review gap for the internal
`mixed-family-extractors` article. It did not change model code or article
source. The article remains internal until the broader mixed-response teaching
fixture and final public-placement review are ready.

## Browser Evidence

The in-app browser was unavailable. A system Google Chrome executable was
available, so the review used headless Chrome and the Chrome DevTools Protocol
with:

`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`

Checked page:

- `pkgdown-site/articles/mixed-family-extractors.html`

Viewport checks:

- Desktop: 1440 x 1600
- Mobile: 390 x 844

Evidence:

- Page title was
  `Mixed-family fits: latent-scale covariance and correlations • gllvmTMB`.
- H1 was `Mixed-family fits: latent-scale covariance and correlations`.
- Internal article gate was present.
- Bad-claim scan found no release-ready, scientific-coverage, bridge-complete,
  or publication-ready wording beyond the intended internal gate.
- Local image/link parser found two images with no missing image targets and 49
  local links with no missing targets.
- The point-estimate heatmap loaded at natural size 1113 x 921 and has
  descriptive alt text.
- Mobile layout metrics showed `documentScrollWidth = 390` at viewport width
  `390`; overflow findings were expected scrollable code/output spans.
- Targeted mobile H1 check showed the heading rectangle inside the viewport
  (`left = 12`, `right = 378`) with `overflow-wrap: break-word`.
- Desktop and mobile screenshots were inspected locally.
- Full-page desktop and mobile captures were inspected locally for gross layout
  or figure failures.

Screenshots inspected locally:

- `/tmp/mixed-family-extractors-desktop.png`
- `/tmp/mixed-family-extractors-mobile.png`
- `/tmp/mixed-family-extractors-desktop-full.png`
- `/tmp/mixed-family-extractors-mobile-full.png`

## Checks

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/mixed-family-extractors", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed and wrote `pkgdown-site/articles/mixed-family-extractors.html`.
- Chrome desktop screenshot command wrote
  `/tmp/mixed-family-extractors-desktop.png`.
- Chrome mobile screenshot command wrote
  `/tmp/mixed-family-extractors-mobile.png`.
- Chrome DevTools Protocol layout and image probe passed.
- Rendered HTML stale-claim scan found only the intended internal-gate wording.

## Files Touched

- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-mixed-family-extractors-browser-review.md`

## Definition-Of-Done Notes

- Implementation: no model behavior changed.
- Simulation recovery: not applicable.
- Documentation: dashboard, article council ledger, check-log, and after-task
  evidence updated.
- Runnable example: unchanged; this was browser/render review.
- Check-log: this task has a dated entry with exact evidence.
- Review/scope: article remains internal; broader NB/beta teaching and final
  public-placement review remain open.

## Not Claimed

- No public promotion or final placement decision.
- No runnable NB/beta teaching fixture.
- No CI-10 promotion.
- No MIX-10 closure for delta/hurdle mixed-family latent-scale correlations.
- No model-code change.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
