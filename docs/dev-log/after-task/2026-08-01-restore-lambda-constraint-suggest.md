# After Task: restore the loading-orientation guide

## Task goal

Restore a public pkgdown article for `suggest_lambda_constraint()` without
reviving the retired page's post-selection loading-inference claims.

## Mathematical contract

No likelihood, formula grammar, response family, or public R API changed. The
article teaches the identification statement
\(\boldsymbol\Lambda\boldsymbol\Lambda^\top =
(\boldsymbol\Lambda\mathbf Q)(\boldsymbol\Lambda\mathbf Q)^\top\) for an
orthogonal \(\mathbf Q\): the lower-triangular pins select a reproducible
orientation, while the shared covariance remains the interpretation target.
LAM-04 directly covers the helper matrix contract and has end-to-end
suggestion-to-refit recovery evidence for binary IRT; the binary JSDM is
explicitly an orientation demonstration, not an ecological
confirmatory-loading claim.

## Files changed

- `vignettes/articles/lambda-constraint-suggest.Rmd` — new public guide,
  pre-specified constraint-matrix figure, fast exploratory-comparison figure,
  and an optional profile-retention workflow.
- `_pkgdown.yml` — article navigation and index entry.
- `vignettes/articles/joint-sdm.Rmd` — safe reader-facing route to the guide.
- `README.md` — distinguishes the narrow orientation guide from deferred
  confirmatory-loading guidance.
- `docs/dev-log/check-log.md` — compact command receipt.
- This report.

No function source, roxygen, generated Rd file, NEWS entry, ROADMAP row, or
validation-debt row changed. This is not a convention change.

## Checks run

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint-suggest", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  — PASS; rendered the article and its `constraint-figure-1.png`.
- `Rscript --vanilla -e 'devtools::test(filter = "suggest-lambda-constraint", reporter = "summary")'`
  — PASS for the ordinary helper tests. The four M2.4 binary recovery tests
  were skipped because `GLLVMTMB_HEAVY_TESTS` was not set.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — PASS, `No problems found.`
- Final title, navigation, and article-render pass:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint-suggest", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = TRUE); pkgdown::build_article("articles/joint-sdm", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = TRUE); cat("AFFECTED_ARTICLES_DONE\\n")'`
  — the restored page rendered with the final title and both figures; the
  JSDM page's navigation link rendered independently in the preceding check.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/joint-sdm", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = TRUE); cat("JOINT_SDM_DONE\\n")'`
  — PASS; the rendered JSDM page carries the new link.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_articles(lazy = FALSE, quiet = FALSE); cat("BUILD_ARTICLES_DONE\\n")'`
  — did not reach `BUILD_ARTICLES_DONE`; it rendered pre-existing articles
  through `behavioural-syndromes` without emitting a diagnostic before the
  process ended. The two affected articles were therefore rendered separately
  and passed; this wider batch outcome is not attributed to this change.
- `git diff --check` — PASS.

## Consistency audit

The new article, README, navbar, index, and JSDM next-step link agree that
the helper supplies an exploratory orientation only. The following scans had
their expected results:

```sh
rg -n 'lambda-constraint-suggest\\.html|Orient latent loadings|exploratory orientation' pkgdown-site/articles/index.html pkgdown-site/articles/lambda-constraint-suggest.html pkgdown-site/articles/joint-sdm.html
rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S' vignettes/articles/lambda-constraint-suggest.Rmd README.md vignettes/articles/joint-sdm.Rmd || true
rg -n 'gllvmTMB_wide|meta_known_V' vignettes/articles/lambda-constraint-suggest.Rmd README.md vignettes/articles/joint-sdm.Rmd || true
rg -n 'profile_retention.*AIC|AIC.*profile_retention|BIC.*profile_retention|Confidence Eye|fit\\$' vignettes/articles/lambda-constraint-suggest.Rmd || true
rg -n 'LAM-04|suggest_lambda_constraint' docs/design/35-validation-debt-register.md docs/design/01-formula-grammar.md docs/design/04-random-effects.md README.md vignettes/articles/lambda-constraint-suggest.Rmd
```

The first and final scans found the intended routes and LAM-04 evidence. The
middle three found no stale notation, deprecated primary syntax, private
fitted-object access, Confidence Eye claim, or same-data IC comparison.

## Tests of the tests

No new test was added: this is a documentation-only restoration. Existing
`test-suggest-lambda-constraint.R` exercises the lower-triangular matrix
shape, names, pin count, and usage hint; the heavy LAM-04 suite exercises the
binary suggester-to-refit recovery cycle. The targeted render would fail if
the displayed formula, fixture lookup, helper contract, or figure code broke.

## What did not go smoothly

The historical page's most memorable figures were deliberately unevaluated
and depended on data-selected constraints, non-PD fits, and private slots.
They were not republished. The replacement renders exact-identification and
fast exploratory-comparison matrices; profile retention is written as an
explicit, non-rendered expensive sensitivity step, with its post-fit health
check visible and its non-confirmatory status stated.

## Team learning

Rose/Fisher reviewed the restoration boundary. They identified the old
same-data selection-plus-confirmation workflow as the load-bearing risk and
required its removal; they also caught and corrected an overbroad statement
about the LAM-04 recovery regime. Pat's reader-path check is represented by
the new purpose-first explanation of `NA` versus exact numeric pins and the
link back to the JSDM guide. Grace's pkgdown gate passed for the index and both
affected article renders, while the full article batch remains a separate
pre-publish gate.

## Design-doc updates

None. The article cites existing LAM-04 evidence and does not change its
status or scope.

## Pkgdown/documentation updates

The `Model Guides` navbar now lists `Explore loading constraints`. The rendered
article includes the pre-specified constraint-matrix PNG, a fast
varimax-threshold/Wald-retention comparison PNG, and an explicit optional
profile-retention workflow; the JSDM page links to it. Pat passed the applied
reader review after internal tracker and raw-helper jargon were removed. Rose
passed the final claim audit after the text distinguished a data-derived
constrained refit from a rotation-equivalent display.

## Roadmap tick

N/A — no roadmap capability status changed.

## GitHub issue ledger

`gh pr list --state open --limit 30` was attempted during lane preflight but
could not reach `api.github.com`; no issue was created, commented on, or
closed. No issue number was available locally that specifically owns this
documentation restoration.

## Known limitations and next actions

The public guide intentionally excludes data-derived zero-selection inference,
post-selection loading intervals, and same-data AIC/BIC/LRT confirmation. A
future article that teaches those conventions needs held-out or external
validation and calibrated post-selection uncertainty first.
