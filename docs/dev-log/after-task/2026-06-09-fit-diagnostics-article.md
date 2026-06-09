# After Task: Fit Diagnostics Article

**Branch**: `codex/fit-diagnostics-article-2026-06-09`
**Date**: `2026-06-09`
**Roles (lenses engaged)**: `Ada / Pat / Rose / Fisher / Florence / Grace`

## 1. Goal

Add a first-click public methods article that answers: can a user trust this
fit enough to interpret it? The page needed to route readers through
`check_gllvmTMB()`, diagnostic residuals, fitted-model predictive plots, and
`diagnostic_table()` without turning the article into a validation ledger.

## 2. Implemented

- Added `vignettes/articles/fit-diagnostics.Rmd`.
- Added `fit-diagnostics` to the public pkgdown Methods navbar and article
  index.
- Updated README routing and the current diagnostics status row.
- Added a NEWS entry for the new article.
- Updated ROADMAP public-surface and diagnostics queue wording.
- Added an article-gate-matrix row for `fit-diagnostics`.

The article uses a small Poisson behavioural-count example with both long and
`traits(...)` wide `gllvmTMB()` calls. It demonstrates:

- `check_gllvmTMB()` fit-health rows;
- the `gllvmTMBcontrol(se = FALSE)` no-SE status path;
- exact randomized-quantile residuals for a covered Poisson fit;
- `diagnostic_table()` row-status, fit-health-status, and diagnostic-row
  extraction;
- `predictive_check(type = "rq_qq")` and `predictive_check(type =
  "rootogram")`.

## 3. Scope Boundary

IN: DIA-08, DIA-10, DIA-11, DIA-12, and DIA-13 public diagnostics.

PARTIAL: the Q-Q plot and rootogram are fitted-model diagnostic displays for
the scoped Gaussian / Poisson / NB2 diagnostic rows. They do not calibrate
intervals, prove latent rank, or run formal residual tests.

OUT / PLANNED: Bayesian posterior predictive checks and exact residual support
for delta, hurdle, truncated, ordinal, and mixture-family rows.

## 4. Files Changed

- `_pkgdown.yml`
- `README.md`
- `NEWS.md`
- `ROADMAP.md`
- `vignettes/articles/fit-diagnostics.Rmd`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-09-fit-diagnostics-article.md`

## 5. Checks Run

- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/fit-diagnostics", quiet = FALSE, new_process = FALSE)'`
  -> rendered `pkgdown-site/articles/fit-diagnostics.html`.
- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgdown::build_articles_index(pkg = pkgdown::as_pkgdown("."))'`
  -> wrote `pkgdown-site/articles/index.html`.
- `env NOT_CRAN=true PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-predictive-diagnostics.R")'`
  -> `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 117`.
- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgdown::build_site(lazy = TRUE)'`
  -> rebuilt the homepage and reference pages, then was stopped during a heavy
  internal-article rebuild after the page-specific render had already passed.
  The stopped process left scratch PNGs in `vignettes/`; those were removed.
- Rendered HTML scans:
  `rg -n "Can I trust this fit|fit-diagnostics|Randomized-quantile residual Q-Q|Rootogram|Articles|Methods|Convergence and start values" pkgdown-site/articles/fit-diagnostics.html pkgdown-site/articles/index.html pkgdown-site/index.html`
  -> new page, article index, and homepage contain the new article link and
  rendered figure references.
- Rendered figure inspection:
  `pkgdown-site/articles/fit-diagnostics_files/figure-html/residual-qq-1.png`
  and `pkgdown-site/articles/fit-diagnostics_files/figure-html/rootogram-1.png`
  are non-empty 1190 x 806 PNGs. Figure-quality gate: PASS for a diagnostic
  vignette display; these are not presented as calibrated uncertainty figures.
- In-app browser attempt:
  Browser Use refused direct `file://` navigation to
  `pkgdown-site/articles/fit-diagnostics.html` under its URL policy, so no
  browser-side screenshot was taken.
- `git diff --check`
  -> clean.

Stale-wording / Rose scans:

- `rg -n "posterior predictive|posterior-predictive|posterior draws|Bayesian posterior|formal residual test|interval calibration|latent-rank proof|DIA-08|DIA-10|DIA-11|DIA-12|DIA-13" README.md NEWS.md ROADMAP.md vignettes/articles/fit-diagnostics.Rmd docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> intentional diagnostic-boundary and row-ID hits only.
- `rg -n "gllvmTMB\\(" vignettes/articles/fit-diagnostics.Rmd README.md NEWS.md ROADMAP.md`
  -> the new article's long-format calls include `trait = "trait"` and
  `unit = "individual"`; the wide call uses `traits(...)`.
- `rg -n "random-slopes-nongaussian|cross-lineage-coevolution|random-regression-reaction-norms|Structured random slopes|Cross-lineage coevolution|Behavioural reaction norms" pkgdown-site/articles/index.html pkgdown-site/index.html README.md ROADMAP.md _pkgdown.yml`
  -> public rendered index/home do not route hidden advanced articles from the
  article dropdown; `_pkgdown.yml` intentionally keeps the hidden slugs in the
  internal bucket.
- `rg -n "x \\\\|x \\|sp|Scope boundary|RE-12|PARTIAL|PLANNED|REJECTED|posterior predictive check|pp_check|gllvmTMB_wide\\(Y|already removed|primary new-user API|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|trio" vignettes/articles/fit-diagnostics.Rmd README.md NEWS.md ROADMAP.md _pkgdown.yml docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> intentional historical / compatibility hits only outside the new article.

## 6. Definition of Done Accounting

1. Implementation: documentation-only branch, not yet merged.
2. Simulation recovery test: not applicable; no likelihood, family, keyword, or
   estimator changed.
3. Documentation: article and routing updated; no roxygen or Rd changed.
4. Runnable user-facing example: yes, the article includes long and wide calls.
5. Check-log entry: added in this branch.
6. Review pass: Pat/Rose/Fisher/Florence/Grace lenses applied locally; external
   maintainer/CI review remains the PR gate.
