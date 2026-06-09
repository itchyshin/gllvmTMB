# After Task: Latent-Rank Model Selection Article

**Branch**: `codex/model-selection-aic-bic-2026-06-09`
**Date**: `2026-06-09`
**Roles (lenses engaged)**: `Ada / Curie / Fisher / Pat / Boole / Rose / Grace / Noether`

## 1. Goal

Add one public worked article that answers: how many latent dimensions should
an applied user fit before interpreting a Gaussian `latent() + unique()`
GLLVM? The page needed to compare AIC and BIC without claiming that either
criterion proves the true biological rank.

## 2. Implemented

- Added `data-raw/examples/make-model-selection-rank-example.R`.
- Added `inst/extdata/examples/model-selection-rank-example.rds`.
- Added `tests/testthat/test-example-model-selection-rank.R`.
- Added `vignettes/articles/model-selection-latent-rank.Rmd`.
- Added the article to `_pkgdown.yml` under Model guide and refreshed the local
  article index.
- Updated README, NEWS, ROADMAP, and the article gate matrix.
- Corrected the `logLik()` roxygen / Rd wording so `nobs` is described as
  likelihood-contributing observed response cells rather than `length(y)`.

The article fits a diagonal `unique()` baseline and `latent() + unique()`
candidates with `d = 1`, `d = 2`, and `d = 3`. It reports `logLik`, `df`,
`nobs`, AIC, BIC, deltas, Hessian status, weak-axis status, and fit health
before interpreting the selected `Sigma`.

## 3. Mathematical Contract

The teaching fixture uses

```text
Sigma = Lambda Lambda^T + Psi
```

where `Lambda` contains two planted shared axes and `Psi = diag(psi)` contains
trait-specific variance. The long formula for the selected rank is
`value ~ 0 + trait + latent(0 + trait | individual, d = 2) +
unique(0 + trait | individual)`. The wide formula is
`traits(length, mass, wing, tarsus, bill) ~ 1 +
latent(1 | individual, d = 2) + unique(1 | individual)`.

The article compares invariant covariance summaries (`Sigma`) rather than raw
loading columns because rotations and signs are not unique when `d > 1`.

## 4. Scope Boundary

IN: Gaussian `latent() + unique()` candidate-rank comparison using
`logLik()`, AIC, BIC, `check_gllvmTMB()`, long data, and `traits(...)` wide
data. Capability rows cited: FG-04, FG-06, DIA-03, DIA-08, and DIA-10.

PARTIAL: the article demonstrates one deterministic planted-rank fixture. It
is evidence that the shipped example runs and that both AIC and BIC choose
`d = 2` in this fixture. It is not a Monte Carlo selection-rate study.

OUT / PLANNED: universal AIC/BIC calibration for latent rank, non-Gaussian
high-rank selection grids, cross-approximation likelihood comparison, and
calibrated interval claims.

## 5. Tests And Checks

- `Rscript --vanilla data-raw/examples/make-model-selection-rank-example.R`
  -> saved `inst/extdata/examples/model-selection-rank-example.rds`.
- `/Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/gllvmTMB_multi-methods.Rd`.
- `tail -n 8 man/gllvmTMB_multi-methods.Rd`
  -> `nobs()` section describes observed-response cells.
- `grep -c '^\\keyword' man/gllvmTMB_multi-methods.Rd`
  -> `0`.
- `/Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-example-model-selection-rank.R")'`
  -> `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 32`.
- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/model-selection-latent-rank", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> rendered `pkgdown-site/articles/model-selection-latent-rank.html`.
- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgdown::build_articles_index(pkg = pkgdown::as_pkgdown("."))'`
  -> wrote `pkgdown-site/articles/index.html`.
- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `/Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'devtools::test()'`
  -> `FAIL 0`, `WARN 0`, `SKIP 704`, `PASS 2684`.
- `PATH="/opt/homebrew/bin:$PATH" /Library/Frameworks/R.framework/Resources/bin/Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> `0 errors`, `1 warning`, `2 notes`; local install warning plus future
  timestamp and existing NEWS-title notes.
- `git diff --check`
  -> clean.

## 6. Rendered Output

Rendered HTML exists at
`pkgdown-site/articles/model-selection-latent-rank.html`. The local article
index contains the new Model guide entry.

Rendered-output scans:

- `rg -n "How many latent dimensions|Choosing latent rank|model-selection-latent-rank|latent d = 2|delta_BIC|Truth-versus-fit covariance" pkgdown-site/articles/model-selection-latent-rank.html pkgdown-site/articles/index.html`
  -> title, navbar/index link, `d = 2` table row, `delta_BIC`, and Sigma figure
  references are present.
- `ls -lh pkgdown-site/articles/model-selection-latent-rank_files/figure-html`
  and `file pkgdown-site/articles/model-selection-latent-rank_files/figure-html/*.png`
  -> two non-empty 1228 x 806 PNGs.
- Browser preview through
  `http://127.0.0.1:8123/articles/model-selection-latent-rank.html` confirmed
  H1, navbar entry, two figure images, `latent d = 2`, and `delta_BIC`.

## 7. Stale-Wording Scans

- `rg -n 'public set remains|six visible|Keep profile-likelihood-ci hidden|joint-sdm.*Hidden|profile-likelihood-ci.*Hidden|troubleshooting-profile.*Hidden|random-slope restoration|promotes the covered s = 1' _pkgdown.yml ROADMAP.md README.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> no hits.
- `rg -n 'same likelihood engine|engine = "julia"|engine = "laplace"|cross-engine' vignettes/articles/model-selection-latent-rank.Rmd README.md NEWS.md ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> no hits.
- `rg -n 'prove.*rank|rank.*proof|selected latent rank|scientifically preferred|correct latent rank|calibrate.*rank|posterior predictive|formal residual tests|interval calibration' README.md ROADMAP.md NEWS.md vignettes/articles/model-selection-latent-rank.Rmd docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> intentional negative-boundary hits only.

## 8. Tests Of The Tests

The new tests are partly prophylactic and partly feature-combination tests.
They combine the example object contract with long and wide `gllvmTMB()` calls,
`logLik()`, AIC, BIC, and rank selection. The long/wide likelihood equality
test would catch a formula or data-shape drift; the AIC/BIC selection test
would catch fixture drift that breaks the article's teaching story.

## 9. Definition Of Done Accounting

1. Implementation: documentation/example branch, not merged to `main` yet.
2. Simulation recovery test: not a new likelihood, family, keyword, or
   estimator. The shipped deterministic fixture is tested.
3. Documentation: article, README, NEWS, ROADMAP, pkgdown nav, article matrix,
   roxygen, and Rd updated.
4. Runnable user-facing example: yes; the article contains live long and wide
   calls.
5. Check-log entry: added in this branch.
6. Review pass: Curie, Fisher, Pat, Boole, Rose, Grace, and Noether lenses
   applied locally. External maintainer/CI review remains the PR gate.

## 10. Follow-Up

Do not promote `choose-your-model` as-is. If we want a broader model-selection
page later, rewrite it around the current public surface after this latent-rank
page has been read in HTML. A real simulation article comparing AIC/BIC
selection rates should be a separate ADEMP-style study with precomputed
summaries, not a long live pkgdown sweep.
