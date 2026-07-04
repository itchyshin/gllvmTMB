# After-task report -- article unique cleanup

Date: 2026-06-18 19:40 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

Continued the post-coevolution `unique()` deprecation lane on twenty article
sources: `convergence-start-values`, `choose-your-model`,
`profile-likelihood-ci`, `functional-biogeography`,
`cross-package-validation`, `simulation-verification`, `morphometrics`,
`api-keyword-grid`, `pitfalls`, `joint-sdm`, `response-families`, and
`model-selection-latent-rank`, plus `fit-diagnostics`, `mixed-family-extractors`,
`psychometrics-irt`, `phylogenetic-gllvm`, Tier-3 internal drafts
`data-shape-flowchart`, `stacked-trait-gllvm`, `behavioural-syndromes`,
`random-regression-reaction-norms`, and the main `gllvmTMB` vignette. This slice
changes teaching examples, prose, the morphometrics / latent-rank model-selection
teaching fixture formulas, and the ordinary Gaussian augmented `latent()`
random-regression default. It does not remove any keyword, rename extractor
parts, or expand `kernel_unique()` for Paper 2 multi-kernel coevolution.

## Implementation

- `vignettes/articles/convergence-start-values.Rmd`
  - Teaches ordinary `latent()` as the default
    `Lambda Lambda^T + Psi` decomposition.
  - Removes explicit ordinary `unique()` from the runnable long-format fit and
    the wide `traits()` example.
  - Names `latent(..., residual = FALSE)` as the no-Psi subset and explicit
    `unique()` as compatibility syntax.
- `vignettes/articles/choose-your-model.Rmd`
  - Uses `dep()` for full unstructured covariance.
  - Uses `indep()` for standalone diagonal tiers.
  - Uses ordinary default `latent()` for non-phylogenetic decomposed tiers.
  - Updates runnable examples that previously taught ordinary explicit
    `unique()` as the default site-level Psi spelling.
- `vignettes/articles/profile-likelihood-ci.Rmd`
  - Uses ordinary default `latent()` for the site-level decomposition in the
    runnable long and wide examples.
  - Uses `indep()` for the standalone `site_species` diagonal tier.
- `vignettes/articles/functional-biogeography.Rmd`
  - Uses ordinary default `latent()` for the live between-site and within-site
    decompositions.
  - Uses `indep()` for the standalone non-phylogenetic species diagonal
    control.
  - Keeps source-specific `spatial_unique()` and `phylo_unique()` partitioning
    examples as compatibility/scope-bound syntax for later source-specific
    folding work.
- `vignettes/articles/cross-package-validation.Rmd`
  - Uses ordinary default `latent()` for the gllvmTMB side of the live
    gllvmTMB-vs-glmmTMB log-likelihood comparison.
  - Keeps glmmTMB's `rr() + diag()` syntax explicit because this article tests
    cross-package objective agreement.
  - Describes the diagonal comparison as the default `latent()` diagonal `Psi`
    companion rather than `unique()`.
- `vignettes/articles/simulation-verification.Rmd`
  - Uses ordinary default `latent()` for the live known-DGP recovery fit.
  - States that this default includes the diagonal `Psi` companion.
- `vignettes/articles/morphometrics.Rmd`
  - Uses ordinary default `latent()` for the canonical rank-2 morphometric
    model and for the stored long/wide fixture formulas.
  - Names explicit `+ unique()` as compatibility syntax only.
  - Names `latent(..., residual = FALSE)` as the no-Psi subset.
  - Keeps `extract_Sigma(part = "unique")` as the current diagonal `Psi`
    component extractor contract.
- `data-raw/examples/make-morphometrics-example.R` and
  `inst/extdata/examples/morphometrics-example.rds`
  - Regenerated the teaching fixture so the formulas printed in the article
    no longer include explicit ordinary `unique()`.
- `tests/testthat/test-example-morphometrics.R`
  - Adds a fixture guard that the stored long and wide formulas do not regress
    to explicit ordinary `unique()`.
- `vignettes/gllvmTMB.Rmd`
  - Teaches ordinary `latent()` as the first-fit default for both shared
    low-rank covariance and diagonal trait-specific `Psi`.
  - Keeps the old explicit `latent() + unique()` spelling as compatibility
    syntax only.
- `vignettes/articles/api-keyword-grid.Rmd`
  - Teaches ordinary `latent()` as the no-prefix decomposed model.
  - Moves explicit `latent() + unique()` to compatibility wording.
  - Names `latent(..., residual = FALSE)` as the no-Psi reduced-rank subset and
    `indep()` as the standalone diagonal baseline.
- `vignettes/articles/pitfalls.Rmd`
  - Uses `latent(..., residual = FALSE)` where the diagnostic target is
    deliberately no-Psi.
  - Replaces advice to add ordinary `+ unique()` with default `latent()` for
    diagonal `Psi`.
  - Updates the phylogenetic fallback wording so ordinary `latent()` carries
    the non-phylogenetic diagonal `Psi`.
- `vignettes/articles/joint-sdm.Rmd`
  - Keeps the binary JSDM formula as `latent()` alone because the logit link
    supplies fixed latent-scale residual variance.
  - Updates the Gaussian contrast and See Also text to point to default
    `latent()` rather than `latent() + unique()`.
  - Uses `indep()` rather than standalone ordinary `unique()` for the
    between/within repeatability aside.
- `vignettes/articles/response-families.Rmd`
  - Uses default ordinary `latent()` in the long and wide Gaussian examples.
  - Keeps `unique()` only as compatibility syntax or identifiable OLRE syntax.
  - Uses `indep()` for standalone diagonal covariance tiers.
- `vignettes/articles/model-selection-latent-rank.Rmd`
  - Uses ordinary default `latent()` for candidate ranks with `d >= 1`.
  - Uses `indep()` for the `d = 0` diagonal baseline.
  - Reads the repo-local teaching fixture before falling back to an installed
    package copy, so local renders show current source-of-truth formulas.
- `data-raw/examples/make-model-selection-rank-example.R` and
  `inst/extdata/examples/model-selection-rank-example.rds`
  - Regenerated the latent-rank teaching fixture so stored long/wide formulas
    no longer include explicit ordinary `unique()`.
- `tests/testthat/test-example-model-selection-rank.R`
  - Adds fixture guards that stored formulas and rank labels do not regress to
    explicit ordinary `unique()`, and that the diagonal baseline uses `indep()`.
- `vignettes/articles/fit-diagnostics.Rmd`
  - Reframes the morphometrics pointer as a default-`latent()` Gaussian
    covariance-decomposition tutorial rather than `latent() + unique()`.
- `vignettes/articles/mixed-family-extractors.Rmd`
  - Teaches the compact mixed-family fixture as ordinary default `latent()`
    with diagonal `Psi`, and removes stale future-facing
    `latent() + unique()` wording.
- `vignettes/articles/psychometrics-irt.Rmd`
  - Reframes the exploratory loading preview as a mixed-family diagnostic
    surface rather than a full `latent + unique` covariance-decomposition
    example.
- `vignettes/articles/phylogenetic-gllvm.Rmd`
  - Keeps `phylo_unique()` as the explicit source-specific phylogenetic `Psi`
    component.
  - Removes ordinary explicit `unique()` from the non-phylogenetic default
    `latent()` examples.
  - Uses `indep()` for the standalone population-tier diagonal.
  - Reframes "two-Psi" prose around `phylo_latent() + phylo_unique() +
    latent()` rather than ordinary `latent() + unique()`.
- `vignettes/articles/simulation-recovery-validated.Rmd`
  - Names the validation target as per-trait diagonal `Psi` variance under the
    default-`latent()` formula, while preserving the same $\psi_t$ coverage
    estimand.
- `vignettes/articles/data-shape-flowchart.Rmd`
  - Reframes the functional-biogeography branch around default `latent()`.
- `vignettes/articles/stacked-trait-gllvm.Rmd`
  - Uses default `latent()` for site and site-species decompositions.
  - Uses `indep()` for the standalone non-phylogenetic species diagonal.
- `vignettes/articles/behavioural-syndromes.Rmd`
  - Uses default `latent()` at the between- and within-individual tiers.
  - Keeps the same `Psi_B` / `Psi_W` interpretation without explicit ordinary
    `unique()` syntax.
- `R/fit-multi.R`
  - Turns on the augmented ordinary diagonal `Psi_B,aug` block by default for
    Gaussian `latent(1 + x | unit, d = K)` terms.
  - Leaves non-Gaussian augmented `latent()` low-rank-only and keeps explicit
    augmented `unique()` as Gaussian-only compatibility syntax.
- `R/unique-keyword.R` and `man/diag_re.Rd`
  - Document that ordinary Gaussian random-regression `latent()` now supplies
    the augmented diagonal `Psi` companion by default.
- `data-raw/examples/make-behavioural-reaction-norm-example.R` and
  `inst/extdata/examples/behavioural-reaction-norm-example.rds`
  - Regenerated the behavioural reaction-norm teaching fixture so stored long
    and wide formulas no longer include explicit augmented ordinary `unique()`.
- `tests/testthat/test-ordinary-latent-random-regression.R` and
  `tests/testthat/test-example-behavioural-reaction-norm.R`
  - Assert default Gaussian augmented `latent()` composition, long/wide fixture
    agreement, and the non-Gaussian low-rank-only boundary.
- `vignettes/articles/random-regression-reaction-norms.Rmd`
  - Uses one augmented ordinary `latent()` term in long and wide formulas.
  - Describes `extract_Sigma(level = "unit_slope", part = "unique")` as the
    default Gaussian diagonal `Psi` component, not an explicit `unique()` term.
  - Keeps the explicit non-Gaussian augmented `unique()` error as a boundary
    example.
- `README.md`
  - Updates the front-door status table and current-boundaries section so
    Gaussian ordinary reaction norms use default augmented `latent()`, with
    explicit augmented `unique()` retained as compatibility syntax.
- `R/brms-sugar.R`
  - Adds `common = FALSE` to `indep()` and rewrites
    `indep(form, common = TRUE)` through the existing scalar diagonal map path.
  - Documents `indep(..., common = TRUE)` as the standalone scalar marginal
    replacement for legacy standalone `unique(..., common = TRUE)`.
- `tests/testthat/test-canonical-keywords.R`
  - Adds an objective-equivalence gate for standalone
    `indep(..., common = TRUE)` versus legacy standalone
    `unique(..., common = TRUE)`.
  - Keeps paired `latent() + unique(..., common = TRUE)` compatibility tests on
    `latent(..., residual = FALSE)` so they remain explicit-Psi tests.
- `R/unique-keyword.R`, `man/indep.Rd`, and `man/diag_re.Rd`
  - Record that scalar standalone marginal users should migrate to
    `indep(..., common = TRUE)`, while paired `unique(..., common = TRUE)`
    remains compatibility syntax.
- `R/brms-sugar.R` and `man/unique_keyword.Rd`
  - Align the `?unique` reference page with the same standalone scalar
    `indep(..., common = TRUE)` boundary.
  - Stop describing `unique(..., common = TRUE)` as the new standalone
    recommendation; retain it as compatibility syntax.
- `docs/design/01-formula-grammar.md`
  - Cleans the ordinary long/wide first examples, non-default trait examples,
    and nested `unit` / `unit_obs` example so they use default ordinary
    `latent()` rather than `latent() + unique()`.
  - Keeps compatibility rows and boundary prose for explicit `unique()` syntax.
- `docs/design/35-validation-debt-register.md`
  - Updates RE-12 to name `latent(1 + x | unit, d = K)` as the canonical
    Gaussian random-regression syntax and to cite the behavioural fixture test.
  - Updates FG-07 with `test-canonical-keywords.R` evidence for the standalone
    scalar `indep(..., common = TRUE)` gate.
- `NEWS.md`, `docs/dev-log/check-log.md`, and the dashboard JSON files record
  the slice and keep the guardrails explicit.

## Checks

- Coordination check:
  - `gh pr list --state open`
    -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"`
    -> recent commits were the current coevolution stack headed by `5346391`.
  - Process note: this continuation refreshed git state before editing but
    missed the explicit pre-edit lane check until after the first
    `functional-biogeography` edit. The coordination check was then rerun
    before further shared-file edits and showed no collision.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/convergence-start-values", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/choose-your-model", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully, including after the final stale phrase cleanup.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/profile-likelihood-ci", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/functional-biogeography", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully, including after the final stale prose cleanup.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/cross-package-validation", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully, including after the summary-table stale cell
  cleanup.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/simulation-verification", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla data-raw/examples/make-morphometrics-example.R`
  -> regenerated `inst/extdata/examples/morphometrics-example.rds` with default
  `latent()` formulas.
- `Rscript --vanilla -e 'devtools::test(filter = "example-morphometrics", reporter = "summary")'`
  -> passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/morphometrics", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("gllvmTMB", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/api-keyword-grid", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/pitfalls", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/joint-sdm", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/response-families", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla data-raw/examples/make-model-selection-rank-example.R`
  -> regenerated `inst/extdata/examples/model-selection-rank-example.rds` with
  default `latent()` candidate formulas and an `indep()` diagonal baseline.
- `Rscript --vanilla -e 'devtools::test(filter = "example-model-selection-rank", reporter = "summary")'`
  -> passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/model-selection-latent-rank", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully after changing the article to prefer the repo-local
  fixture over the installed package copy during local builds.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/fit-diagnostics", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/mixed-family-extractors", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/psychometrics-irt", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/phylogenetic-gllvm", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/profile-likelihood-ci", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully after the final phylogenetic-signal wording cleanup.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/simulation-recovery-validated", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully after the validation-grid wording cleanup.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/data-shape-flowchart", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully with pre-existing Pandoc math warnings for `\rm`
  fragments in the internal draft.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/stacked-trait-gllvm", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> rendered successfully.
- `Rscript --vanilla data-raw/examples/make-behavioural-reaction-norm-example.R`
  -> regenerated `inst/extdata/examples/behavioural-reaction-norm-example.rds`
  with default augmented `latent()` long/wide formulas.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/diag_re.Rd` after the augmented random-regression
  compatibility note.
- `air format R/fit-multi.R R/unique-keyword.R tests/testthat/test-ordinary-latent-random-regression.R tests/testthat/test-example-behavioural-reaction-norm.R data-raw/examples/make-behavioural-reaction-norm-example.R`
  -> completed cleanly.
- `Rscript --vanilla -e 'devtools::test(filter = "ordinary-latent-random-regression|example-behavioural-reaction-norm", reporter = "summary")'`
  -> passed.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/random-regression-reaction-norms", pkg = ".", lazy = FALSE, quiet = FALSE)'`
  -> failed because the default `new_process = TRUE` local render picked up an
  older installed namespace that did not yet include the augmented default
  `Psi` fold.
- `Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); ex <- readRDS("inst/extdata/examples/behavioural-reaction-norm-example.rds"); fit <- suppressMessages(suppressWarnings(gllvmTMB(ex$formula_long, data=ex$data_long, trait=ex$fit_args$trait, unit=ex$fit_args$unit, unit_obs=ex$fit_args$unit_obs, family=ex$fit_args$family, control=gllvmTMBcontrol(se=FALSE, optimizer="optim", optArgs=list(method="BFGS"))))); print(fit$use[c("rr_B_slope","diag_B_slope","diag_B_slope_default")]); print(extract_Sigma(fit, level="unit_slope", part="unique")$s)'`
  -> confirmed `rr_B_slope`, `diag_B_slope`, and `diag_B_slope_default` were
  all `TRUE`, and `part = "unique"` returned the augmented diagonal `Psi`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/random-regression-reaction-norms", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> rendered successfully and wrote
  `pkgdown-site/articles/random-regression-reaction-norms.html`.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|extract-sigma|ordinary-latent-random-regression|example-behavioural-reaction-norm", reporter = "summary")'`
  -> passed with twelve expected heavy skips.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.` after the morphometrics fixture/article and main
  vignette / keyword-grid updates.
- `Rscript --vanilla -e 'devtools::test(filter = "ordinary-latent|unique-family", reporter = "summary")'`
  -> passed.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-sigma-table|extract-correlations|unique-family", reporter = "summary")'`
  -> passed with six expected heavy skips.
- `rg -n 'unique\(0 \+ trait \| site\)|unique\(1 \| site\)|full unstructured.*unique|add a third per-trait diagonal tier unique|latent \+ unique' vignettes/articles/convergence-start-values.Rmd vignettes/articles/choose-your-model.Rmd pkgdown-site/articles/convergence-start-values.html pkgdown-site/articles/choose-your-model.html`
  -> no hits after the final article render.
- `rg -n 'latent\(0 \+ trait \| site, d = 1\) \+ unique\(0 \+ trait \| site\)|latent\(1 \| site, d = 1\) \+ unique\(1 \| site\)|unique\(0 \+ trait \| site_species\)|unique\(1 \| site_species\)' vignettes/articles/profile-likelihood-ci.Rmd pkgdown-site/articles/profile-likelihood-ci.html`
  -> no hits after the profile article render.
- `rg -n 'unique\(0 \+ trait \| site\)|unique\(0 \+ trait \| site_species\)|unique\(0 \+ trait \| species\)' vignettes/articles/functional-biogeography.Rmd pkgdown-site/articles/functional-biogeography.html`
  -> no hits after the functional-biogeography render.
- `rg -n 'unique\(0 \+ trait \| site\)|canonical latent\(\) / unique\(\)' vignettes/articles/cross-package-validation.Rmd pkgdown-site/articles/cross-package-validation.html`
  -> no hits after the final cross-package-validation render.
- `rg -n 'unique\(0 \+ trait \| site\)|latent\(0 \+ trait \| site, d = 1\) \+ unique' vignettes/articles/simulation-verification.Rmd pkgdown-site/articles/simulation-verification.html`
  -> no hits after the simulation-verification render.
- `rg -n 'latent \+ unique|\+ unique\(\)|without `?\+ unique\(\)`?|Pick `?latent \+ unique|latent\(d = 2\) \+ unique|pairs `?latent|`?unique\(\)`? matters' vignettes/articles/morphometrics.Rmd pkgdown-site/articles/morphometrics.html`
  -> no hits after the morphometrics render.
- `rg -n 'shared \(`latent\(\)`\) and unique|via `latent\(\)` and `unique\(\)`|Fit a .*latent\(\) \+ unique|That.s the whole model.*unique\(\)|latent\(\) \+ unique\(\)|latent \+ unique' vignettes/gllvmTMB.Rmd pkgdown-site/articles/gllvmTMB.html`
  -> only the intentional compatibility note remained after the main vignette
  render.
- `rg -n 'core Gaussian `latent\(\) \+ unique\(\)`|start with `latent\(\) \+ unique\(\)`|Standalone `latent\(\)` fits|most common decomposed model pairs|The most common decomposed model pairs|Use `unique\(\)` when you want to name' vignettes/articles/api-keyword-grid.Rmd pkgdown-site/articles/api-keyword-grid.html`
  -> no hits after the keyword-grid render.
- `rg -n 'unique\(0 \+ trait \| site\)|\+ unique\(0 \+ trait \| site\)|add `\+ unique|phylo_latent \+ latent \+ unique|phylo_latent \+ phylo_unique \+ latent \+ unique|four-component|Standalone `latent\(\)` fits|latent \+ unique' vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html`
  -> no hits after the pitfalls render.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique\(0 \+ trait \| site\)|unique\(0 \+ trait \| site_species\)|Gaussian `latent|Morphometrics.*unique|needs a paired `unique' vignettes/articles/joint-sdm.Rmd pkgdown-site/articles/joint-sdm.html`
  -> no hits after the joint-sdm render.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique\(1 \| individual\)|unique\(0 \+ trait \| individual\)|share a `latent\(\) \+ unique\(\)`|use `unique\(\)` for the explicit Psi component' vignettes/articles/response-families.Rmd pkgdown-site/articles/response-families.html`
  -> no hits after the response-families render.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique\(0 \+ trait \| individual\)|unique\(1 \| individual\)|trait-specific diagonal from `unique\(\)`|explicit `Psi`.*unique|default-`latent' vignettes/articles/model-selection-latent-rank.Rmd pkgdown-site/articles/model-selection-latent-rank.html data-raw/examples/make-model-selection-rank-example.R tests/testthat/test-example-model-selection-rank.R`
  -> only the intentional `default-`latent()` phrase remained.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|full `latent\(\) \+ unique\(\)`|unique\(' vignettes/articles/fit-diagnostics.Rmd pkgdown-site/articles/fit-diagnostics.html`
  -> no hits after the fit-diagnostics render.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|full `latent \+ unique`|full `latent\(\) \+ unique\(\)`|free `unique\(\)` component|Sigma = shared \+ unique' vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/psychometrics-irt.Rmd pkgdown-site/articles/mixed-family-extractors.html pkgdown-site/articles/psychometrics-irt.html`
  -> no hits after the mixed-family and psychometrics renders.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|phylo_latent \+ latent \+ unique|phylo_latent \+ phylo_unique \+ latent \+ unique|unique\(0 \+ trait \| individual\)|unique\(1 \| individual\)|unique\(0 \+ trait \| species\)|unique\(1 \| species\)|same `latent\(\) \+ unique\(\)`|simplest non-phylogenetic\s+`latent\(\) \+ unique\(\)`' vignettes/articles/phylogenetic-gllvm.Rmd vignettes/articles/profile-likelihood-ci.Rmd pkgdown-site/articles/phylogenetic-gllvm.html pkgdown-site/articles/profile-likelihood-ci.html`
  -> no hits after the phylogenetic/profile renders.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique-tier variance|same `latent\(\) \+ unique\(\)` machinery' vignettes/articles/simulation-recovery-validated.Rmd pkgdown-site/articles/simulation-recovery-validated.html`
  -> no hits after the simulation-recovery render.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique\(0 \+ trait \| site\)|unique\(1 \| site\)|unique\(0 \+ trait \| site_species\)|unique\(0 \+ trait \| species\)|`unique\(species\)`|canonical decomposition mode' vignettes/articles/data-shape-flowchart.Rmd vignettes/articles/stacked-trait-gllvm.Rmd pkgdown-site/articles/data-shape-flowchart.html pkgdown-site/articles/stacked-trait-gllvm.html`
  -> only the new "Default `latent()` is the canonical decomposition mode"
  wording remained.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique\(0 \+ trait \| individual\)|unique\(1 \| individual\)|unique\(0 \+ trait \| session_id\)|unique\(1 \| session_id\)|unique\(' vignettes/articles/behavioural-syndromes.Rmd pkgdown-site/articles/behavioural-syndromes.html`
  -> no hits after the behavioural-syndromes render.
- `rg -n 'latent\(\) \+ unique\(\)|latent \+ unique|unique\(0 \+ trait \+ \(0 \+ trait\):temperature \| individual\)|unique\(1 \+ temperature \| individual\)|paired augmented latent\(\) \+ unique\(\)|non-slope latent \+ unique|fitted diagonal contribution from unique\(\)' vignettes/articles/random-regression-reaction-norms.Rmd pkgdown-site/articles/random-regression-reaction-norms.html data-raw/examples/make-behavioural-reaction-norm-example.R tests/testthat/test-example-behavioural-reaction-norm.R tests/testthat/test-ordinary-latent-random-regression.R R/unique-keyword.R docs/design/01-formula-grammar.md`
  -> remaining hits were intentional compatibility tests, the explicit
  non-Gaussian boundary example, and canonical compatibility/history prose.
- `rg -n 'latent\(1 \+ x \| unit, d = K\) \+ unique\(1 \+ x \| unit\)|latent \+ unique decomposition|Gaussian unit-tier augmented latent \+ unique|Gaussian ordinary latent \+ unique|non-Gaussian augmented unique\(\) remains guarded while the non-Gaussian' README.md docs/design/35-validation-debt-register.md docs/design/01-formula-grammar.md NEWS.md`
  -> no hits after the README, RE-12, and older NEWS random-regression entry
  were aligned to the default augmented `latent()` spelling.
- `Rscript --vanilla -e 'devtools::test(filter = "ordinary-latent|unique-family|extract-sigma-table", reporter = "summary")'`
  -> passed.
- `Rscript --vanilla -e 'devtools::test(filter = "ordinary-latent|unique-family|stage2-rr-diag", reporter = "summary")'`
  -> passed with one expected glmmTMB non-PD Hessian skip in
  `test-stage2-rr-diag.R`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/indep.Rd` and `man/diag_re.Rd` after the
  `indep(common = TRUE)` roxygen and `unique()` compatibility-note updates.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|unique-family-deprecation|stage2-rr-diag", reporter = "summary")'`
  -> passed with three expected INLA-dependent spatial skips and one expected
  glmmTMB non-PD comparison skip.
- `rg -n 'latent\\([^\\n]+\\) \\+\\s*unique|\\+\\s*unique\\(|unique\\(0 \\+ trait \\| site\\)|unique\\(1 \\| individual\\)|unique\\(0 \\+ behavior \\| individual\\)|unique\\(0 \\+ trait \\| individual\\)|unique\\(0 \\+ trait \\| session_id\\)' docs/design/01-formula-grammar.md`
  -> only intentional compatibility mentions remain.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/unique_keyword.Rd` after the reference common-boundary
  cleanup.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|unique-family-deprecation", reporter = "summary")'`
  -> passed with three expected INLA-dependent spatial skips.
- `rg -n 'pass \`common = TRUE\`|pass \\code\\{common = TRUE\\}|Use .*unique\\(.*common = TRUE|unique\\(\\.\\.\\., common = TRUE\\).*replacement|common = TRUE.*indep|paired.*common' R/brms-sugar.R man/unique_keyword.Rd man/diag_re.Rd man/indep.Rd docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md NEWS.md docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json`
  -> hits are intended current boundary statements; no stale active-reference
  recommendation to use `unique(..., common = TRUE)` for new standalone scalar
  models remains.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`

## Definition of Done status

- Implementation: local article/prose cleanup plus the Gaussian augmented
  ordinary `latent()` default diagonal-`Psi` fold plus the standalone scalar
  `indep(common = TRUE)` parser/documentation gate; not pushed.
- Simulation/recovery evidence: targeted Gaussian recovery / composition tests
  passed; non-Gaussian augmented `latent()` remains low-rank-only and explicit
  augmented `unique()` remains guarded.
- Documentation: article source, fixture source, NEWS, dashboard, check log,
  and this report updated.
- Runnable example: all twenty touched article sources plus the main vignette
  rendered successfully.
- Check-log entry: present.
- Review pass: lifecycle/prose/article surface plus formula-grammar contract;
  no TMB likelihood template or bridge behavior changed.

## Still not claimed

- No `unique()` / `*_unique()` removal.
- No `part = "unique"` rename.
- No paired `latent() + unique(..., common = TRUE)` re-homing. The standalone
  scalar marginal replacement is now `indep(..., common = TRUE)`.
- No source-specific or `kernel_*()` latent-Psi fold.
- No Paper 2 multi-kernel explicit-Psi implementation.
- No bridge completion, release readiness, or scientific coverage completion.
