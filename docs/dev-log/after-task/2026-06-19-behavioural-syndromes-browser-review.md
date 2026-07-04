# After-task report: behavioural-syndromes browser review

Date: 2026-06-19 04:35 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closed the true-browser review gap for the internal
`behavioural-syndromes` article. It did not change model code or article
source. The article remains internal until a final public-placement decision.

## Browser Evidence

The in-app browser was unavailable. A system Google Chrome executable was
available, so the review used headless Chrome and the Chrome DevTools Protocol
with:

`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`

Checked page:

- `pkgdown-site/articles/behavioural-syndromes.html`

Viewport checks:

- Desktop: 1440 x 1600
- Mobile: 390 x 844

Evidence:

- Page title was `Behavioural syndromes (2-level GLLVM) • gllvmTMB`.
- H1 was `Behavioural syndromes (2-level GLLVM)`.
- Internal article gate was present.
- Bad-claim scan found no release-ready, scientific-coverage, bridge-complete,
  or publication-ready wording beyond the intended internal gate.
- Local image/link parser found six images with no missing image targets and 47
  local links with no missing targets.
- All six rendered images loaded with nonzero natural dimensions.
- The five article figures have descriptive alt text; the package logo is
  decorative.
- Mobile layout metrics showed `documentScrollWidth = 390` at viewport width
  `390`; overflow findings were expected scrollable code spans.
- Desktop and mobile screenshots were inspected locally.
- Full-page desktop and mobile captures were inspected locally for gross layout
  or figure failures.

Screenshots inspected locally:

- `/tmp/behavioural-syndromes-desktop-after.png`
- `/tmp/behavioural-syndromes-mobile-after.png`
- `/tmp/behavioural-syndromes-desktop-full.png`
- `/tmp/behavioural-syndromes-mobile-full.png`

## Checks

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed and wrote `pkgdown-site/articles/behavioural-syndromes.html`.
- Chrome desktop screenshot command wrote
  `/tmp/behavioural-syndromes-desktop-after.png`.
- Chrome mobile screenshot command wrote
  `/tmp/behavioural-syndromes-mobile-after.png`.
- Chrome DevTools Protocol layout and image probe passed.
- Rendered HTML stale-claim scan found only the intended internal-gate wording.

## Files Touched

- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-19-behavioural-syndromes-browser-review.md`

## Definition-Of-Done Notes

- Implementation: no model behavior changed.
- Simulation recovery: not applicable.
- Documentation: dashboard, article council ledger, check-log, and after-task
  evidence updated.
- Runnable example: unchanged; this was browser/render review.
- Check-log: this task has a dated entry with exact evidence.
- Review/scope: article remains internal; final public-placement review remains
  open.

## Not Claimed

- No public promotion or final placement decision.
- No interval calibration or uncertainty upgrade.
- No model-code change.
- No bridge completion.
- No release readiness.
- No scientific coverage completion.
