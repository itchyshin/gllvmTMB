# After-task report: behavioural-syndromes diagnostic-table gate

Date: 2026-06-19 00:07 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Add diagnostic-table evidence to the internal `behavioural-syndromes`
candidate worked example, and keep the article internal if that evidence
shows unresolved fit-health rows.

## Files touched

- `vignettes/articles/behavioural-syndromes.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-behavioural-syndromes-diagnostic-table.md`

## What changed

- Added randomized-quantile residual objects for long and wide fits.
- Added `diagnostic_table(..., table = "check_gllvmTMB")` output for
  optimizer convergence, maximum gradient, `sdreport`, and `pd_hessian`.
- Added article prose saying WARN/FAIL rows block public promotion.
- Updated the article council ledger and dashboards so the diagnostic table is
  no longer missing, but diagnostic repair or explanation remains required.

## Evidence

The rendered article shows:

- long layout: `optimizer_convergence = FAIL`, `max_gradient = PASS`,
  `sdreport = PASS`, `pd_hessian = PASS`;
- wide layout: all four key rows `PASS`.

A BFGS probe made optimizer convergence pass on both layouts, but changed both
maximum-gradient rows to `WARN`, so this slice did not change the article fit
calls.

## Checks run

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed.
- `rg -n "diagnostic-table|optimizer_convergence|max_gradient|pd_hessian|sdreport|long|wide" pkgdown-site/articles/behavioural-syndromes.html`
  - Confirmed rendered diagnostic rows.
- `git diff --check`
  - Clean after the article edit.
- `Rscript --vanilla -e 'devtools::test(filter = "example-behavioural|ordinary-latent|unique-family-deprecation|predictive-diagnostics", reporter = "summary")'`
  - Passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - No problems found.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null`
  - Passed.
- `python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  - Passed.
- Stale current-dashboard wording scan for missing diagnostic-table language
  - No matches.

## Definition-of-done status

- Implementation: local article/docs slice only; not merged.
- Simulation recovery: not applicable to this article-readiness slice.
- Documentation: article source and rendered HTML checked.
- Runnable user-facing example: diagnostic table now renders, but the article
  remains internal.
- Check-log entry: added.
- Review pass: article-tier audit discipline applied; Pat/Darwin/Flo review
  still pending before any public promotion.

## Not claimed

- Not a public-promotion decision.
- Not a release-readiness claim.
- Not bridge completion.
- Not scientific coverage completion.
