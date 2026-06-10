# After Task: Public Binary JSDM Article

**Branch**: `codex/public-jsdm-article-2026-06-09`
**Date**: `2026-06-09`
**Roles (engaged)**: `Ada / Pat / Rose / Florence / Grace`

## 1. Goal

Promote the binary joint species distribution model article from an internal direct-link page to a public Model guide article without overclaiming spatial SDM support. The public path should answer the applied question: after an environmental gradient is accounted for, which species retain residual co-occurrence?

## 2. Implemented

- `joint-sdm.Rmd` is now Tier 1 and appears in the public `Articles > Model guide` dropdown.
- The article opens with the SDM/JSDM question, then shows runnable long and `traits(...)` wide formulas.
- The scope boundary maps public claims to FG-02, FG-03, FG-04, and FAM-02, and keeps CI-08 / CI-10 interval coverage caveats explicit.
- The article now includes the requested loading workflow: `suggest_lambda_constraint()`, constrained refit, `flag_unreliable_loadings()`, and `plot_loadings_confidence_eye()`.
- Added `suggest_lambda_constraints()`, a plural comparison helper that runs
  several existing `suggest_lambda_constraint()` conventions and returns a
  summary table plus the full suggestion objects.
- The JSDM article now compares `varimax_threshold` and `wald_retention`,
  selects the Wald-retention suggestion for the constrained refit, and shows
  `profile_retention` as the explicit slower likelihood-ratio confirmation
  path.
- The prose keeps single-species spatial SDMs assigned to `sdmTMB` and treats multivariate `spatial_*()` fields as a later advanced article, not part of the first public binary JSDM path.

## 3. Files Changed

- `_pkgdown.yml`
- `NAMESPACE`
- `NEWS.md`
- `R/loading-uncertainty-helpers.R`
- `R/loading-ci.R`
- `R/suggest-lambda-constraint.R`
- `docs/design/35-validation-debt-register.md`
- `vignettes/articles/joint-sdm.Rmd`
- `vignettes/articles/lambda-constraint-suggest.Rmd`
- `tests/testthat/test-suggest-lambda-constraint.R`
- `man/loading_ci.Rd`
- `man/suggest_lambda_constraints.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-09-public-jsdm-article.md`

## 3a. Decisions and Rejected Alternatives

Decision: publish the binary JSDM article before a spatial-field SDM article.
Rationale: the tested fixture and long/wide parity are already stable, while a public `spatial_*()` SDM story needs its own reader path.
Rejected alternative: combine binary JSDM, spatial fields, loading constraints, and interval methods into one large article.
Confidence: high.

Decision: show Confidence Eyes only after a suggested loading constraint and constrained refit.
Rationale: `loading_ci()` correctly refuses unconstrained exploratory loadings because they are rotation-indeterminate.
Rejected alternative: draw loading intervals directly on the exploratory fit.
Confidence: high.

Decision: add `suggest_lambda_constraints()` rather than overloading the
singular helper with a table mode.
Rationale: the singular helper already returns the exact matrix for one
convention; the plural helper is an orchestration layer for comparing
threshold, Wald, and profile suggestions before choosing one.
Rejected alternative: only edit the article to call
`suggest_lambda_constraint()` several times by hand.
Confidence: high.

## 4. Checks Run

- `gh pr list --state open --limit 20 --json number,title,headRefName,updatedAt,isDraft` -> no open PRs.
- `git log --all --oneline --since="6 hours ago"` -> only already-merged docs workflow commits.
- `Rscript --vanilla -e 'devtools::test(filter = "example-joint-sdm|joint-sdm-binary-long-wide", stop_on_failure = TRUE)'` -> 58 pass, 0 fail, 0 warn, 0 skip.
- `Rscript --vanilla -e 'devtools::test(filter = "suggest-lambda-constraint|example-joint-sdm|joint-sdm-binary-long-wide", stop_on_failure = TRUE)'` -> final rerun passed with 98 pass, 0 fail, 0 warn, 4 heavy skips.
- `Rscript --vanilla -e 'devtools::test(filter = "loading-ci|suggest-lambda-constraint|example-joint-sdm|joint-sdm-binary-long-wide", stop_on_failure = TRUE)'` -> passed with 98 pass, 0 fail, 0 warn, 36 heavy skips after correcting stale `loading_ci()` profile/bootstrap wording.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> generated `NAMESPACE` and `man/suggest_lambda_constraints.Rd`.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/joint-sdm", pkg = ".")'` -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/lambda-constraint-suggest", pkg = ".")'` -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_reference(pkg = ".")'` -> generated `reference/suggest_lambda_constraints.html`.
- `Rscript --vanilla -e 'pkgdown::build_reference(pkg = ".")'` -> rerun after the `loading_ci()` wording fix generated `reference/loading_ci.html`.
- `R CMD INSTALL -l /Users/z3437171/Library/R/arm64/4.5/library .` -> installed current source into the R 4.5 library used by `Rscript`.
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` -> completed successfully after the corrected install.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found`.
- `git diff --check` -> clean.

Rendered-output checks:

- `curl -sS http://localhost:8123/articles/joint-sdm.html | rg -n "Check loadings before naming axes|jsdm-loading-confidence-eye|Confidence Eye plot|Suggesting a Lambda constraint|Confirmatory loadings|Internal direct-link"` -> found the new loading path and no old internal note.
- `rg -n "suggest_lambda_constraints|wald_retention|profile_retention|varimax_threshold|recommended_method|asymmetric Wald retention|profile LRT retention" pkgdown-site/articles/joint-sdm.html` -> found the plural helper, threshold/Wald comparison, `wald_retention` recommendation, and optional profile code.
- Public navbar loop over all public article HTML files -> every page contains `Joint species distribution model`.
- Browser check on `http://localhost:8123/articles/joint-sdm.html` -> title, loading section, Confidence Eye image, and `suggest_lambda_constraint()` path present; old internal note absent.

## 5. Tests of the Tests

Added lightweight tests for `suggest_lambda_constraints()` in
`tests/testthat/test-suggest-lambda-constraint.R`: comparison-table shape,
recommendation ranking, returned suggestion agreement, and unsupported-method
errors. Existing JSDM fixture tests still cover the data object contract,
complete long/wide shapes, long/wide likelihood equivalence, correlation
extraction, and ordination plot readiness. Existing heavy tests for
`suggest_lambda_constraint()` binary reliability remain gated behind
`GLLVMTMB_HEAVY_TESTS=1`.

## 6. Consistency Audit

- `rg -n "Internal direct-link|tier: 3|Joint species distribution model \\(binary GLLVM\\)|gllvmTMB_wide|meta_known_V|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|REML.*non-Gaussian|non-Gaussian.*REML" vignettes/articles/joint-sdm.Rmd _pkgdown.yml pkgdown-site/articles/joint-sdm.html || true` -> no hits.
- `rg -n "joint-sdm|Joint species distribution|Internal direct-link|tier: 3|Scope boundary|CI-08|CI-10|FG-02|FG-03|FG-04|FAM-02|spatial_\\*|sdmTMB" _pkgdown.yml vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/joint-sdm.html pkgdown-site/articles/index.html README.md docs/design/35-validation-debt-register.md` -> public claims have register-row backing and the spatial boundary matches README.
- Rose pre-publish checks found no export/reference mismatch. LAM-04 now names
  `suggest_lambda_constraint()` and `suggest_lambda_constraints()`; the plural
  helper is documented as a comparison wrapper over the same covered suggester
  surface.
- Stale wording checks confirm profile retention is current, not queued. The
  only remaining bootstrap-retention wording is the planned future-method note
  in `lambda-constraint-suggest.Rmd`.

## 7. Roadmap Tick

N/A. This is a public article promotion within the existing article-completion lane, not a new capability milestone.

## 7a. GitHub Issue Ledger

Open issue search:

`gh issue list --repo itchyshin/gllvmTMB --state open --limit 30 --search "JSDM OR SDM OR species distribution OR article" --json number,title,url,labels,updatedAt`

Relevant trackers:

- #230 Article surface reset and user-first tooling gate.
- #347 Article completion (public learning path).

This slice advances both but does not close either.

## 8. What Did Not Go Smoothly

The local installed package was stale. `pkgdown::build_articles(lazy = FALSE)` first failed in the internal cross-lineage article because `library(gllvmTMB)` could not see `make_cross_kernel()`. A later public rebuild also saw an old `gllvmTMB()` without the `REML` argument. The first `R CMD INSTALL .` installed into a non-`Rscript` library. Explicitly installing into `/Users/z3437171/Library/R/arm64/4.5/library` fixed the local environment, after which the full article build passed.

The first Confidence Eye render included an unused `estimated` legend category. The article plot call now overrides the colour scale to show only categories present in this diagnostic.

## 9. Team Learning

Ada: Keep the first SDM article narrow and public-ready; do not mix it with the spatial-field article.

Pat: The page now shows code before deep theory, uses both long and wide formulas, and includes the loading check a reader naturally expects after seeing an ordination.

Rose: Navigation is synchronized across the public article pages, stale internal wording is gone, and claims point to register rows.

Boole: The plural helper preserves the existing singular convention API and
keeps the comparison layer explicit rather than adding a hidden mode to
`suggest_lambda_constraint()`.

Florence: The Confidence Eye figure is readable as a vignette diagnostic after removing the unused legend item.

Grace: The key reproducibility lesson is that pkgdown article builds can silently use a stale installed package unless the active `Rscript` library is explicit.

## 10. Known Limitations And Next Actions

- Calibrated covariance / loading interval coverage remains partial under CI-08 and CI-10.
- The loading constraint here is a statistical fallback, not a biological hypothesis.
- `profile_retention` is available but deliberately shown as optional in the
  JSDM article because it performs one likelihood-ratio refit per testable
  loading entry.
- A separate advanced SDM article should cover multivariate `spatial_*()` fields, SPDE meshes, and how that differs from single-species `sdmTMB`.
- The `lambda-constraint` and `lambda-constraint-suggest` articles are linked as loading companions but are not yet promoted into the main dropdown.
