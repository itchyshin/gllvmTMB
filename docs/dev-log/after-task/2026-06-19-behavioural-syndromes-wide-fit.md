# After-task report: behavioural-syndromes wide-format fit gate

Date: 2026-06-19 00:07 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Remove one article-council blocker from the internal
`behavioural-syndromes` candidate Tier 1 worked example by adding a runnable
wide-format fit beside the long-format fit.

## Files touched

- `vignettes/articles/behavioural-syndromes.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-behavioural-syndromes-wide-fit.md`

## What changed

- Added `df_wide` construction from the simulated behavioural-syndromes matrix.
- Added a wide `gllvmTMB()` call using the `traits(...)` LHS shorthand and the
  same individual/session latent structure as the long-format fit.
- Rendered and recorded the long/wide log-likelihood comparison. The rendered
  difference was `3.886697e-06`.
- Updated the article council ledger and dashboard so the wide-call blocker is
  removed, while diagnostic-table evidence, reader-path cleanup, Florence
  figure review, and final rendered HTML review still block public promotion.

## Checks run

- `gh pr list --state open`
  - Only draft PR #489 was open.
- `git log --all --oneline --since="6 hours ago"`
  - No commits returned.
- `git diff --check`
  - Clean before this slice.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed and rendered `pkgdown-site/articles/behavioural-syndromes.html`.
- `sed -n '520,536p' pkgdown-site/articles/behavioural-syndromes.html`
  - Confirmed rendered long/wide log-likelihood comparison.
- `Rscript --vanilla -e 'devtools::test(filter = "example-behavioural|ordinary-latent|unique-family-deprecation", reporter = "summary")'`
  - Passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - No problems found.

## Definition-of-done status

- Implementation: local article/docs slice only; not merged.
- Simulation recovery: not applicable to this article-readiness slice.
- Documentation: article source and rendered HTML checked for this slice.
- Runnable user-facing example: the wide call now runs locally, but the article
  remains internal until the remaining gates pass.
- Check-log entry: added.
- Review pass: article-tier audit applied; Florence/Pat/Darwin final promotion
  review still pending.

## Not claimed

- Not a public-promotion decision.
- Not a release-readiness claim.
- Not bridge completion.
- Not scientific coverage completion.
