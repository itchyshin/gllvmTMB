# Retained articles batch B — systems audit

**Date:** 2026-07-12  
**Mode:** article audit followed by the two bounded warning-visibility repairs  
**Reader:** an applied user choosing syntax, missing-data handling, or an
uncertainty route from the public pkgdown site

## Verdict

**PASS (5 of 5 pages).** The source and rendered pages are synchronized, the
API claims checked here agree with the current R functions, internal validation
codes and process prose are absent, all local links resolve, and warnings are
visible by default. The two initial global `warning = FALSE` blockers were
removed and both affected articles rebuilt without emitting a warning.

| Page | Verdict | Evidence |
|---|---|---|
| `profile-likelihood-ci.Rmd` | **PASS** | Render is newer than source and contains the current route table and examples. Long and wide `gllvmTMB()` fits are shown together. `profile_targets()`, `confint_inspect()`, direct profiles, the repeatability Wald fallback, unavailable nonlinear communality profiles, and unavailable profile/bootstrap `B_lv` intervals agree with `R/profile-targets.R`, `R/confint-inspect.R`, `R/extract-repeatability.R`, and `R/extractors.R`. `warning = TRUE`; the prose also states the fallback and coverage limits explicitly. Both local article links resolve. |
| `missing-data.Rmd` | **PASS** | Source and render are synchronized; wide and long response-mask and modelled-predictor examples use the current `gllvmTMB()` entry point. Claims match `miss_control()`, `predict_missing()`, `impute_model()`, `imputed()`, and the missing-data tests. Assumptions, absent interval support, unsupported combinations, and MNAR limits are visible; the `impute_model()` reference link resolves. The global warning suppression was removed and a fresh full render emitted no warning. |
| `gllvm-vocabulary.Rmd` | **PASS** | Source and render are synchronized. It shows both long and `traits(...)` wide calls, teaches the four current covariance modes, keeps the `unique =` latent argument distinct from deprecated covariance-function syntax, and keeps `kernel_indep()`, `kernel_dep()`, and `kernel_latent()` current. Missing-data and interval definitions retain their limitations. All eight local links resolve, including Get Started and the relevant concept guides. Default knitr warning visibility is preserved. |
| `api-keyword-grid.Rmd` | **PASS** | Source and render are synchronized. The page teaches the four-mode public grid and current ordinary, animal, phylogenetic, spatial, and kernel syntax. It correctly states that no `kernel_scalar()` exists. The only deprecated API named is `meta_known_V()`, explicitly labelled a soft-deprecated alias and immediately replaced by `meta_V()`. Long and wide ordinary fits are paired; the technical syntax sections appropriately avoid duplicating a full worked fit for every source. All local links resolve and default warning visibility is preserved. |
| `fixed-effect-zero-constraints.Rmd` | **PASS** | Source and render are synchronized. The worked example shows matching long and `traits(...)` wide fits, explains imposed-zero status and missing standard errors, and matches `R/gllvmTMB.R` / `tests/testthat/test-xcoef-fixed.R`. Error recovery and three navigation links are present. The global warning suppression was removed and a fresh full render emitted no warning. |

## Cross-page checks

- **Source/render synchronization:** all five rendered HTML files have later
  modification times than their Rmd sources and contain page-specific revised
  text from those sources.
- **Internal-code/process sweep:** zero matches in either source or rendered
  HTML for uppercase validation IDs, `validation-debt register`, `register row`,
  `Scope boundary`, `Claim boundary`, or `IN` / `PARTIAL` / `PLANNED` ledgers.
- **Current versus deprecated API:** no deprecated covariance functions or
  `gllvmTMB_wide()` calls occur. `meta_known_V()` occurs only in the keyword
  grid's explicit migration note.
- **Long/wide teaching:** profile likelihood, missing data, the vocabulary, and
  zero constraints show both data shapes. The keyword grid pairs the ordinary
  long/wide fit and uses compact syntax blocks for source-specific lookup.
- **Links and navigation:** every relative Markdown target exists in the built
  site. All five pages appear in `pkgdown-site/articles/index.html` and in the
  sitemap.
- **Repeated stale pattern:** the two global `warning = FALSE` settings were
  removed. All five pages now retain warning visibility, either explicitly or
  through knitr's default behavior.

## Commands and outcomes

```sh
# Headings, calls, limitations, and lifecycle terms
rg -n '^#{1,3} |gllvmTMB\(|traits\(|warning|error|deprecated|coverage' \
  vignettes/articles/{profile-likelihood-ci,missing-data,gllvm-vocabulary,api-keyword-grid,fixed-effect-zero-constraints}.Rmd

# Internal code and process language, in source and rendered pages
rg --pcre2 -n '\b(?!UTF-)[A-Z]{2,5}-[0-9]{2,3}\b|validation-debt register|register row|Scope boundary|Claim boundary|\bIN:|\bPARTIAL:|\bPLANNED:' \
  vignettes/articles/{profile-likelihood-ci,missing-data,gllvm-vocabulary,api-keyword-grid,fixed-effect-zero-constraints}.Rmd \
  pkgdown-site/articles/{profile-likelihood-ci,missing-data,gllvm-vocabulary,api-keyword-grid,fixed-effect-zero-constraints}.html
# Outcome: zero matches.

# Export and implementation checks
rg -n '^export\((profile_targets|confint_inspect|extract_repeatability|extract_correlations|extract_communality|extract_phylo_signal|extract_lv_effects|miss_control|predict_missing|impute_model|imputed|kernel_latent|kernel_indep|kernel_dep|meta_V|meta_known_V)\)' NAMESPACE
rg -n '^(profile_targets|confint_inspect|extract_repeatability|extract_correlations|extract_communality|extract_phylo_signal|extract_lv_effects|miss_control|predict_missing|impute_model|imputed|kernel_latent|kernel_indep|kernel_dep|meta_V|meta_known_V) *<- *function' R/*.R

# Focused executable contract check
Rscript --vanilla -e 'devtools::test(filter = "xcoef-fixed|missing-response-traits|profile-targets$|confint-inspect", reporter = "summary")'
# Outcome: exit 0. Non-skipped Xcoef_fixed and confint_inspect checks passed;
# 17 profile-target and missing-response checks skipped behind the declared
# heavy-test gate.

# Link targets, navigation, and source/render mtimes
test -f pkgdown-site/articles/fit-diagnostics.html
test -f pkgdown-site/articles/convergence-start-values.html
test -f pkgdown-site/reference/impute_model.html
for page in covariance-correlation api-keyword-grid gllvmTMB missing-data \
  morphometrics random-regression-reaction-norms pre-fit-response-screening; do
  test -f "pkgdown-site/articles/${page}.html"
done
test -f pkgdown-site/reference/gllvmTMB.html
rg -n 'profile-likelihood-ci|missing-data|gllvm-vocabulary|api-keyword-grid|fixed-effect-zero-constraints' \
  pkgdown-site/articles/index.html pkgdown-site/sitemap.xml
stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' \
  vignettes/articles/{profile-likelihood-ci,missing-data,gllvm-vocabulary,api-keyword-grid,fixed-effect-zero-constraints}.Rmd \
  pkgdown-site/articles/{profile-likelihood-ci,missing-data,gllvm-vocabulary,api-keyword-grid,fixed-effect-zero-constraints}.html

# Rebuild the two repaired pages with warnings visible and capture all output
set -o pipefail
Rscript --vanilla -e 'for (x in c("articles/missing-data", "articles/fixed-effect-zero-constraints")) { message("BUILD ", x); pkgdown::build_article(x, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }' \
  2>&1 | tee /tmp/gllvmtmb-batch-b-render.log
rg -n -i 'warning|error|execution halted' /tmp/gllvmtmb-batch-b-render.log
# Outcome: build exit 0 for both pages; the final scan returned no matches.
```

## Blocker resolution

Removed the global `warning = FALSE` setting from
`vignettes/articles/missing-data.Rmd` and
`vignettes/articles/fixed-effect-zero-constraints.Rmd`. No local suppression
was needed: both articles rendered successfully with warning visibility enabled,
and the captured output contained no warning or error.
