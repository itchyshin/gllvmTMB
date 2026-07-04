# After-task report: phylogenetic-gllvm browser review

Date: 2026-06-19 03:48 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closed one article-council review gap for
`vignettes/articles/phylogenetic-gllvm.Rmd`: browser-level review of the
already-rendered local pkgdown HTML. It did not change article source.

## Browser evidence

The in-app browser was unavailable, and Playwright's bundled Chromium was not
installed. A system Google Chrome executable was available, so the review used
Playwright with:

`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`

Checked page:

- `pkgdown-site/articles/phylogenetic-gllvm.html`

Viewport checks:

- Desktop: 1440 x 1000
- Mobile: 390 x 844

Evidence:

- Page title was `Phylogenetic trait covariance • gllvmTMB`.
- H1 was `Phylogenetic trait covariance`.
- Console messages: none.
- Page errors: none.
- Internal article gate was present.
- Bad-claim scan found none for `release ready`, `release-ready`,
  `scientific coverage passed`, `scientific-coverage passed`,
  `publication-ready`, `publication grade`, or `publication-grade`.
- The logo and total-correlation heatmap loaded.
- The heatmap natural size was 1420 x 883 and it carried descriptive alt text.
- Mobile rendered the heatmap at 366 x 228.
- Desktop overflow scan found only the expected hidden skip link.
- Mobile overflow scan found expected narrow-layout table/math overflow; visual
  screenshot inspection did not show incoherent text overlap.

Screenshots inspected locally:

- `/tmp/gllvm-phylogenetic-desktop.png`
- `/tmp/gllvm-phylogenetic-mobile.png`

## Files touched

- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-phylogenetic-gllvm-browser-review.md`

## Definition-of-done notes

- Implementation: no source/article implementation changed.
- Simulation recovery: not applicable.
- Documentation: dashboard and check-log evidence updated.
- Runnable example: not changed; this was a rendered-browser review.
- Check-log: this task has a dated entry with exact evidence.
- Review/scope: article remains internal; this is not public promotion.

## Not claimed

- No public promotion or final placement.
- No interval calibration.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
