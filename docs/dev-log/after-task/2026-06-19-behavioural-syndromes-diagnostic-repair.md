# After-task report: behavioural-syndromes diagnostic repair

Date: 2026-06-19 00:21 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Repair the fit-health blocker exposed by the rendered diagnostic table in the
internal `behavioural-syndromes` candidate worked example.

## Files touched

- `vignettes/articles/behavioural-syndromes.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-behavioural-syndromes-diagnostic-repair.md`

## What changed

- Added one shared `fit_control` object using
  `gllvmTMBcontrol(start_method = list(method = "indep"))`.
- Passed that control object to both long and wide article fits.
- Updated article prose so the diagnostic table now records a passing fit-health
  gate under the independent-diagonal warm start.
- Updated the article council ledger and dashboards so diagnostics are no
  longer the current blocker.

## Evidence

The repair was chosen from a probe of existing controls:

- default control: long optimizer convergence failed; wide passed;
- `n_init = 3`: long passed but wide optimizer convergence failed;
- `optim`/BFGS: optimizer convergence passed but both maximum-gradient rows
  warned;
- `start_method = list(method = "indep")`: both long and wide layouts passed
  optimizer convergence, maximum gradient, `sdreport`, and `pd_hessian`, with
  long/wide logLik difference about `2.6e-09`.

## Still required

The article remains Tier 3/internal. Public promotion still requires reader-path
cleanup, Florence figure review, and final rendered HTML review.

## Checks run

- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Passed.
- `sed -n '536,542p' pkgdown-site/articles/behavioural-syndromes.html`
  - Confirmed rendered long/wide logLik difference `-2.590241e-09`.
- `sed -n '660,682p' pkgdown-site/articles/behavioural-syndromes.html`
  - Confirmed rendered long and wide key diagnostic rows all `PASS`.
- `Rscript --vanilla -e 'devtools::test(filter = "example-behavioural|ordinary-latent|unique-family-deprecation|predictive-diagnostics", reporter = "summary")'`
  - Passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - No problems found.
- `git diff --check`
  - Clean after the article edit.

## Not claimed

- Not a public-promotion decision.
- Not release readiness.
- Not bridge completion.
- Not scientific coverage completion.
