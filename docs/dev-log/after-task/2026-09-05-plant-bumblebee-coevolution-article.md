# After Task: synthetic plant--bumblebee cross-lineage covariance article

## 1. Goal

Add a small, runnable PCM article that teaches the existing fixed-rho
cross-lineage kernel and `extract_Gamma()` workflow, while keeping the
point-estimate and non-causal limits visible.

## 2. Implemented

Added `plant-bumblebee-coevolution.Rmd`, a synthetic 12-plant by 8-bumblebee
Gaussian teaching example. It builds one `make_cross_kernel()` object, fits one
named `kernel_latent()` tier, and extracts the flower-trait by bumblebee-trait
shared covariance block. The article is indexed once under Phylogenetic
comparative models.

### Mathematical Contract

No public R API, likelihood, formula grammar, response family, NAMESPACE, or
generated Rd change. The article's exact fitted model is
`Y = M + G Lambda^T + E`, with `G ~ MVN(0, K_cross)` and
`Gamma = Lambda_plant Lambda_bumblebee^T`. `K_cross` is supplied by
`make_cross_kernel(A_plant, A_bumblebee, W, rho)`; `rho` is fixed, not fitted.
The article does not claim a causal coevolution effect, calibrated intervals,
or an empirical result.

## 3a. Decisions and Rejected Alternatives

The intended real-data route was Liang et al.'s CC0 Dryad record. Its public
download page currently requires a browser proof-of-work screen and its
documented API requires a download token. We did not bypass either route.
The maintainer explicitly authorized a synthetic fallback, so this article
uses fictional names and values and says so on its first screen. A partial
article that implied an empirical re-analysis was rejected.

## 4. Files Touched

- `_pkgdown.yml`: one PCM menu entry and one article-index placement.
- `vignettes/articles/plant-bumblebee-coevolution.Rmd`: new Tier-1 article.
- `data-raw/examples/make-plant-bumblebee-coevolution-example.R`: deterministic
  synthetic-fixture generator.
- `inst/extdata/examples/plant-bumblebee-coevolution-example.rds`: generated
  teaching fixture.
- `dev/plant-bumblebee-coevolution-smoke.R`: actual-fit smoke check.
- `tests/testthat/test-example-plant-bumblebee-coevolution.R`: fixture contract.
- `README.md`, `NEWS.md`, `ROADMAP.md`, `docs/design/`, `R/`, `NAMESPACE`, and
  `man/`: not changed; this adds no new user API or capability claim.

## 5. Checks Run

- `Rscript --vanilla data-raw/examples/make-plant-bumblebee-coevolution-example.R`
  -> wrote the 7,117-byte fixture; minimum kernel eigenvalue `0.005660774`.
- `Rscript --vanilla dev/plant-bumblebee-coevolution-smoke.R` ->
  `plant_bumblebee_point_estimate=PASS`, convergence `0`, log likelihood
  `79.432965`.
- `Rscript --vanilla -e 'devtools::test(filter = "example-plant-bumblebee-coevolution")'`
  -> 8 expectations, 0 failures/warnings/skips.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/plant-bumblebee-coevolution", lazy = FALSE)'`
  -> rendered `articles/plant-bumblebee-coevolution.html`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `git diff --check` -> clean.
- The canonical after-task structure validator passed. Its repository-wide
  acceptance-ledger sweep remains blocked by unrelated live iJSDM and
  navigation ledgers; this article's own five-gate ledger reports `ALL MET`.

## 6. Tests of the Tests

The fixture test is prophylactic: it combines the exported cross-kernel helper
with the intentionally block-missing teaching data, so a changed generator,
misordered association matrix, or broken source alignment fails before the
article can silently teach a different model. Its first direct invocation
failed because the package namespace was not attached; replacing the bare
helper call with `gllvmTMB::make_cross_kernel()` made it runnable both directly
and through `devtools::test()`. Its second invocation caught an invalid
balanced-lineage assumption; the final assertions derive missing-cell counts
from the actual plant and bumblebee labels.

## 7a. Issue Ledger

Inspected open issue #361, "Cross-lineage coevolution via a generic kernel_*()
engine (C0-C5)". It remains open: this documentation-only slice does not move
COE-02 from partial, add new engine evidence, or close its inference gates. No
issue was created, commented on, or closed.

## 8. Consistency Audit

- `rg -n 'COE-|KER-02|extract_Gamma|cross-lineage' docs/design/35-validation-debt-register.md`
  -> the article maps helper construction to covered KER-01 and the extractor
  workflow to partial COE-02; it names the latter's fixed-rho and interval
  limits in reader language.
- `rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S|gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(' vignettes/articles/plant-bumblebee-coevolution.Rmd`
  -> no stale notation or deprecated primary syntax.
- `rg -n 'gllvmTMB\\(' vignettes/articles/plant-bumblebee-coevolution.Rmd`
  -> long call explicitly supplies `trait = "trait"`; wide call uses
  `traits(...)` and no `trait` argument.
- `rg -n 'in prep|in preparation' vignettes/articles/plant-bumblebee-coevolution.Rmd`
  -> no unsupported foundational citation.

Rose pre-publish verdict: PASS. The added explicit In / Partial / Not provided
scope block prevents the article from promoting partial COE-02 evidence to a
general inference claim.

## 9. What Did Not Go Smoothly

Dryad exposes the intended CC0 Liang data record but now places an anti-bot
proof-of-work barrier in front of individual downloads; its documented API
requires a token for download. This task did not bypass that barrier. The user
authorized a synthetic fallback, which is labelled prominently in the article.
The first pkgdown invocation also used a bare slug; this pkgdown installation
indexes it as `articles/plant-bumblebee-coevolution`.

## 10. Known Residuals

The fixture is synthetic; the article covers one fixed-rho Gaussian point fit,
not an empirical plant--bumblebee analysis. The model has no calibrated
uncertainty for `Gamma`, no in-engine rho estimation, and no causal
coevolution interpretation.

## 11. Team Learning

Pat: the reader route now begins with a concrete question and says that plants
do not acquire bumblebee traits merely to fill missing cells. The long and wide
calls make the data shape recoverable.

Rose: the scope boundary was promoted into its own visible block, and the
fixture's synthetic status is in the first screenful rather than a footer.

Gauss: the displayed equation, data generator, `kernel_latent()` formula, and
`extract_Gamma()` call all use the same `K_cross`, `G`, `Lambda`, and `Gamma`
objects. No likelihood or parameterization changed.

### Design and Documentation Updates

No design-doc update: this is a worked route over existing KER-01 / COE-02
capabilities. Pkgdown gains exactly one PCM article placement and navigation
target.

**Roadmap tick**: N/A; no ROADMAP status changed.

## 12. Cross-Product Coverage

This documentation slice covers the existing native-TMB, Gaussian,
single-dense-kernel, fixed-rho point-estimate path in long and wide syntax.
It does NOT cover real-data provenance beyond citing the blocked Dryad route;
estimated rho; interval, bootstrap, or profile calibration; non-Gaussian or
mixed-family cross-lineage examples; multiple separately interpreted kernels;
tree uncertainty; or causal coevolution. Those cells remain COE-02/COE-04
follow-up work, not consequences of the rendered teaching example.

### Next Actions

If the Dryad files become available through a normal user download, build a
separate empirical follow-up that records exact source checksums, aligns real
species labels, and retains the same scope boundary. Do not relabel this
synthetic teaching output as empirical evidence.
