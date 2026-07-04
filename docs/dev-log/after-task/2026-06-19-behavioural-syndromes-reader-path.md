# After-task report: behavioural-syndromes reader-path bridge

Date: 2026-06-19 00:27 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Move the internal `behavioural-syndromes` candidate worked example closer to
Tier 1 shape by adding a compact reader path before the simulation and fit
sections.

## Files touched

- `vignettes/articles/behavioural-syndromes.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-behavioural-syndromes-reader-path.md`

## What changed

- Added a `Reader path` section that maps each biological question to the model
  object, code section, and readout.
- Updated the internal gate to say Pat/Darwin reader review and Florence figure
  review still block public promotion.
- Updated the article council ledger and dashboards with the new state.

## Still required

The article remains Tier 3/internal. Public promotion still requires
Pat/Darwin reader review, Florence figure review, and final rendered HTML
review.

## Checks run

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed.
- `rg -n "Reader path|Do individuals differ|Do sessions carry|Do long and wide|Is the fitted model|Did the example recover|Pat/Darwin|independent-diagonal warm start|optimizer_convergence   PASS" pkgdown-site/articles/behavioural-syndromes.html`
  - Confirmed the rendered reader-path bridge and repaired diagnostic rows.
- `Rscript --vanilla -e 'devtools::test(filter = "example-behavioural|ordinary-latent|unique-family-deprecation|predictive-diagnostics", reporter = "summary")'`
  - Passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - No problems found.
- `git diff --check`
  - Clean.

## Not claimed

- Not a public-promotion decision.
- Not release readiness.
- Not bridge completion.
- Not scientific coverage completion.
