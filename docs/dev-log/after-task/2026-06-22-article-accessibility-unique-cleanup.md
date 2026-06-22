# After Task: Article accessibility and unique compatibility cleanup

## Goal

Make the public landing path easier for an applied reader and sweep article
sources so `unique()` / `*_unique()` are no longer taught as first-line syntax
unless the current engine still requires an explicit compatibility spelling.

## Implemented

- Reworked `README.md` and `vignettes/gllvmTMB.Rmd` so the first model story
  defines `Sigma`, `Lambda`, `Psi`, and `psi_t` before asking readers to
  interpret covariance extractors.
- Added `vignettes/articles/gllvm-vocabulary.Rmd` to the pkgdown Concepts
  navigation.
- Moved the reference index into first-line covariance keywords versus
  soft-deprecated covariance compatibility syntax.
- Updated article examples and prose so standalone diagonal examples prefer
  `indep()` / source-specific `*_indep()` where supported.
- Labelled remaining explicit-Psi syntax as compatibility or guarded:
  explicit `phylo_unique()` for the two-Psi helper diagnostics and ordinary
  `unique()` for augmented random-regression slope diagonals.
- After #528 merged, updated the cross-lineage article to use folded
  `kernel_latent()` as the current dense-kernel `Lambda Lambda^T + Psi`
  example.
- Fixed `lambda-constraint-suggest.Rmd` so the current
  `profile_retention` fixture teaches the valid zero-pin outcome instead of
  failing when `loading_ci()` refuses unidentified per-entry `Lambda` CIs.
- Removed the duplicate `gllvm-vocabulary` entry from the internal article
  list; the page remains public under Concepts only.
- Replaced the first-screen plain-text covariance equation in `README.md` and
  `vignettes/gllvmTMB.Rmd` with rendered LaTeX plus a plain-English fallback,
  and added the key interpretation guard: start from `Sigma`, correlations, or
  communality before reading individual `Lambda` entries.
- Follow-up from Pat and the pkgdown editor team: `vignettes/gllvmTMB.Rmd` now
  starts from the actual Gaussian teaching model
  `y_it = alpha_t + lambda_t^T u_i + e_it`, then presents `Sigma` as the
  covariance summary implied by the latent part of the model. The first-copy
  code now appears before the symbol glossary and uses clean ordinary
  `latent()` syntax.
- Regenerated the morphometrics teaching fixture so its alignment labels teach
  ordinary `latent()` and trait-specific diagonal `Psi` rather than
  `latent() + unique()`. The Morphometrics article now prefers the worktree
  fixture during local rendering and avoids printing raw internal
  `unique_unit` fit metadata.

## Mathematical Contract

The public notation now uses one contract consistently:

```text
Sigma = Lambda Lambda^T + Psi
Psi = diag(psi_1, ..., psi_T)
```

`Lambda` is the loading matrix created by the shared latent axes. `Psi` is the
diagonal matrix of trait-specific variance, and `psi_t` is the scalar diagonal
entry for trait `t`. `latent(..., unique = FALSE)` remains the canonical
loadings-only subset in the current implementation; `residual = FALSE` is not
used in these article edits.

No TMB likelihood, parser, extractor, or fitted-model parameterization changed.

## Files Changed

- `README.md`
- `_pkgdown.yml`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/animal-model.Rmd`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/cross-lineage-coevolution.Rmd`
- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/gllvm-vocabulary.Rmd`
- `vignettes/articles/lambda-constraint-suggest.Rmd`
- `vignettes/articles/lambda-constraint.Rmd`
- `vignettes/articles/mixed-family-extractors.Rmd`
- `vignettes/articles/model-selection-latent-rank.Rmd`
- `vignettes/articles/morphometrics.Rmd`
- `data-raw/examples/make-morphometrics-example.R`
- `inst/extdata/examples/morphometrics-example.rds`
- `vignettes/articles/ordinal-probit.Rmd`
- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `vignettes/articles/pitfalls.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`
- `vignettes/articles/random-regression-reaction-norms.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-article-accessibility-unique-cleanup.md`

## Checks Run

- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); cat("load_all ok\n")'`
  -> PASS.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS.
- `Rscript --vanilla -e 'pkgdown::build_home(quiet = FALSE); articles <- c("gllvmTMB", "articles/gllvm-vocabulary", "articles/api-keyword-grid", "articles/covariance-correlation"); for (a in articles) { message("BUILD ", a); pkgdown::build_article(a, lazy = FALSE, quiet = FALSE, new_process = FALSE) }'`
  -> PASS.
- Focused renders passed for `functional-biogeography`, `phylogenetic-gllvm`,
  `profile-likelihood-ci`, `mixed-family-extractors`, `psychometrics-irt`,
  `pitfalls`, and `random-regression-reaction-norms`.
- Post-#528 rebase render:
  `Rscript --vanilla -e 'pkgdown::build_article("articles/cross-lineage-coevolution", lazy = FALSE, quiet = FALSE, new_process = FALSE)'`
  -> PASS.
- Post-#528 rebase lightweight gates:
  `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS;
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); cat("load_all ok\n")'`
  -> PASS;
  `git diff --check HEAD~1..HEAD` -> PASS.
- Follow-up render after fixing the Lambda-suggestion guard:
  `Rscript --vanilla -e 'pkgdown::build_article("articles/lambda-constraint-suggest", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> PASS; rendered `pkgdown-site/articles/lambda-constraint-suggest.html`
  with a diagnostic table for the zero-pin `profile_retention` outcome.
- Full article render:
  `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> PASS; rendered the article index, visible articles, internal drafts, the
  formerly failing `lambda-constraint-suggest` page, and the slow
  `lambda-constraint` page.
- Follow-up gates after the full render:
  `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS;
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); cat("load_all ok\n")'`
  -> PASS;
  `git diff --check` -> PASS.
- Follow-up equation-accessibility render:
  `Rscript --vanilla -e 'pkgdown::build_home(quiet = FALSE); pkgdown::build_article("gllvmTMB", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> PASS; rendered the homepage and Getting Started page with the LaTeX
  `Sigma = Lambda Lambda^T + Psi` equation.
- Follow-up equation-accessibility gates:
  `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS;
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); cat("load_all ok\n")'`
  -> PASS;
  `git diff --check` -> PASS.
- Follow-up model-first accessibility render:
  `Rscript --vanilla -e 'pkgdown::build_article("gllvmTMB", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> PASS after rewriting the Getting Started opening around the actual
  Gaussian teaching model and after splitting equations for mobile rendering.
- Morphometrics fixture regeneration:
  `Rscript --vanilla data-raw/examples/make-morphometrics-example.R`
  -> PASS.
- Focused fixture test:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-example-morphometrics.R", reporter = "summary")'`
  -> PASS.
- Follow-up Morphometrics article render:
  `Rscript --vanilla -e 'pkgdown::build_article("articles/morphometrics", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> PASS after making local renders prefer the worktree fixture and removing
  the raw fit-object print.
- Follow-up pkgdown / whitespace gates:
  `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS;
  `git diff --check` -> PASS.
- Earlier focused renders in this branch passed for
  `model-selection-latent-rank`, `morphometrics`, `choose-your-model`,
  `stacked-trait-gllvm`, `ordinal-probit`, `animal-model`, and
  `cross-lineage-coevolution`.

The unsupported `pkgdown::build_home(quiet = FALSE, new_process = FALSE)`
command failed because this pkgdown version does not accept `new_process` for
`build_home()`. It was rerun successfully with the supported signature.

## Tests Of The Tests

No new automated tests were added because this was a source-documentation and
pkgdown navigation cleanup. The integration check was article rendering. It
caught two real mismatches:

- `functional-biogeography` used shorthand `phylo_indep(species, tree = tree)`
  in an evaluated chunk; the parser requires `phylo_indep(0 + trait | species,
  tree = tree)` there.
- `random-regression-reaction-norms` asked for the augmented slope diagonal
  without the current explicit ordinary `unique()` companion.
- `lambda-constraint-suggest` assumed `profile_retention` would always return
  explicit pins. The current fixture returns zero pins, so the article now
  explains why no per-entry `Lambda` Confidence Eye is drawn and points readers
  to rotation-invariant summaries or confirmatory pins.

## Consistency Audit

Exact scans recorded in the check-log:

- ``rg -n 'Lamdba|depreciat|diag\(psi\)|diag\(\\boldsymbol\\Psi\)|mathrm\{diag\}\(\\boldsymbol\\Psi\)|the Greek letter Psi|trait-specific diagonal from `unique\(\)`|why `unique\(\)` matters|bare phylo_latent|loadings-only by default|Use `phylo_latent\(\) \+ phylo_unique|Use `animal_latent\(\) \+ animal_unique|Use `spatial_unique|append `spatial_unique|recommended when traits|unique\(\) matters|ordinary `latent\(\)` by default' README.md vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd``
  -> no matches.
- ``rg -n '`[a-z_]*unique\(|\b[a-z_]*unique\(' README.md vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd``
  -> remaining hits manually reviewed as compatibility labels, keyword tables,
  or guarded random-regression examples.
- ``rg -n 'Sigma = Lambda|Lambda Lambda\^T|Psi|psi_t|loading matrix|trait-specific diagonal|soft-deprecated|compatibility' README.md vignettes/gllvmTMB.Rmd vignettes/articles/gllvm-vocabulary.Rmd vignettes/articles/covariance-correlation.Rmd``
  -> confirmed landing-path definitions and compatibility wording.
- `ruby -e 'require "yaml"; y=YAML.load_file("_pkgdown.yml"); h=Hash.new(0); y["articles"].each{|s| (s["contents"] || []).each{|c| h[c]+=1 }}; dup=h.select{|k,v| v>1}; abort("duplicate articles: #{dup.inspect}") unless dup.empty?; puts "pkgdown-article-nav-unique-ok"'`
  -> PASS.
- `rg -n 'No profile_retention Confidence Eye drawn|profile_retention returned 0 explicit pins|Plain-English vocabulary|Internal drafts and technical notes|gllvm-vocabulary.html|profile-likelihood-ci.html|troubleshooting-profile.html' pkgdown-site/articles/lambda-constraint-suggest.html pkgdown-site/articles/index.html pkgdown-site/articles/gllvmTMB.html pkgdown-site/index.html`
  -> confirmed the rendered zero-pin explanation and the intended public /
  internal article navigation.
- `rg -n 'boldsymbol\{|operatorname\{diag\}|rotation-dependent|For a first fit, read' README.md vignettes/gllvmTMB.Rmd pkgdown-site/index.html pkgdown-site/articles/gllvmTMB.html`
  -> confirmed the source and rendered HTML contain the clean equation and the
  `Lambda` interpretation guard.
- `rg -n 'unique\(|latent\(\) \+ unique|unique_unit|trait-specific unique variance|model in one sentence|fitted Gaussian model starts|Read the covariance summaries first|Then inspect loadings|trait-specific diagonal variance' vignettes/gllvmTMB.Rmd vignettes/articles/morphometrics.Rmd pkgdown-site/articles/gllvmTMB.html pkgdown-site/articles/morphometrics.html data-raw/examples/make-morphometrics-example.R`
  -> no stale `unique()` / `unique_unit` / "model in one sentence" hits in the
  two affected rendered articles; expected positive hits confirmed the new
  model-first headings and diagonal-variance wording.
- `rg -n 'formula_wide|Covstructs|latent\(1 \| individual' pkgdown-site/articles/gllvmTMB.html`
  -> confirmed the rendered Getting Started formula output shows clean
  `latent(1 | individual, d = 2)` and no `Covstructs` internal print.

Validation-debt row status did not move. This PR does not advertise a new model
capability; it clarifies syntax and reader path around existing covered,
partial, and guarded rows.

## What Did Not Go Smoothly

The first Pat pass recommended `residual = FALSE`, but Rose found the current
implementation and tests still treat `unique = FALSE` as canonical and
`residual =` as a soft-deprecated alias. The article edits therefore keep
`unique = FALSE`.

The two-Psi cross-check helpers still recognise the explicit
`phylo_latent(..., unique = FALSE) + phylo_unique(...)` spelling rather than
the folded `phylo_latent()` form. The phylogenetic article now labels those
helper calls as compatibility diagnostics and leaves them unevaluated.

## Team Learning

Pat's key accessibility point was right: the first page was asking readers to
absorb notation, validation boundaries, and future-work caveats before giving
them the model sentence. The revised landing path now teaches one sentence
first: total covariance equals shared latent structure plus trait-specific
variance.

Pat's follow-up correction was also right: `Sigma` is not the model. The
Getting Started page now teaches the observation model first, then treats
`Sigma` as the covariance summary readers extract from that model.

Rose's key systems point was also right: "soft-deprecated" is not enough if
the code examples still present `*_unique()` as canonical. The article sweep
had to touch both prose and executable chunks.

## Known Limitations

- `devtools::test()` and `devtools::check()` were not rerun for this article
  slice; no R, TMB, Rd, parser, or compiled-code source changed.
- Several advanced articles still belong under the explicit
  `Internal drafts and technical notes` section by the 2026-06-09 navigation
  decision. They now build, but buildable is not the same as Tier-1 public
  teaching readiness.
- The cross-lineage article now uses folded `kernel_latent()` because PR #528
  has landed on `main`.

## Next Actions

- Consider a small follow-up for `compare_indep_vs_two_psi()` /
  `compare_dep_vs_two_psi()` so the helpers recognise folded `phylo_latent()`
  fits directly.
- Keep Pat in the loop for the next article promotion pass; the main remaining
  question is nav ordering and which advanced pages should become true Tier-1
  reader paths rather than technical notes.
