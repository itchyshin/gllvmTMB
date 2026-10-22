# After Task: Response-column slope family and corrected tree-axis bridge

**Branch**: `codex/column-slope-family`
**Date**: 2026-08-24
**Roles (engaged)**: Ada, Boole, Gauss, Noether, Curie, Florence, Pat, Rose, Grace, Shannon

## 1. Goal

Complete a memorable response-column slope API—`slope()`, `phylo_slope()`,
`animal_slope()`, `kernel_slope()`, and `spatial_slope()`—without changing
existing fits, then correct the visual tree-axis article so an ecology graduate
student can distinguish a tree among species units from a tree among species
response columns.

## 2. Implemented

- Every `*_slope()` helper now means predictor coefficients varying across the
  resolved response-column factor. The term never adds a random intercept.
- `|` estimates a full predictor covariance and `||` a diagonal predictor
  covariance. They are identical for one predictor.
- `slope()` uses an identity relationship among response columns;
  `phylo_slope()`, `animal_slope()`, `kernel_slope()`, and `spatial_slope()` use
  a tree, pedigree/relationship matrix, labelled kernel, or labelled SPDE mesh
  projection respectively.
- The existing one-predictor phylogenetic and animal helper path remains
  compatible. Historical non-response-column RHS syntax remains runtime
  compatibility behaviour but is not the teaching API.
- `extract_Sigma(fit, level = "column_slope")` returns named predictor
  covariance and relationship-source metadata.
- The bridge article's comparative example now uses
  `slope(elevation | trait)` for ordinary measured-column deviations and
  `phylo_latent(0 + trait | species, ...)` for tree-related species-unit
  intercept covariance. It no longer implies phylogenetic relationships among
  morphology or life-history columns.
- Legacy recovery harnesses now quote paths and decode R 4.6's `~+~` transport
  spelling, so tests run from worktrees whose paths contain spaces. Synthetic
  V2 forensic tests use a local hashable source inventory while the production
  frozen-predecessor resolver remains strict.
- A joint known-DGP test now distinguishes ordinary response-column slope
  variance from a separate species-axis phylogenetic covariance, rather than
  relying on routing evidence alone.

## Mathematical Contract

For response columns `t = 1, ..., T` and predictors `p = 1, ..., P`, let `B`
be the `T x P` matrix of response-column slope deviations. The implemented
model is

\[
\operatorname{Cov}\{\operatorname{vec}(B^\mathsf{T})\}
  = K_{\mathrm{column}} \otimes \Sigma_{\mathrm{predictor}},
\]

with trait-major coefficient packing. `||` makes
`Sigma_predictor` diagonal; `|` uses a log-Cholesky parameterisation for a full
positive-definite matrix. The relationship source is `I`, phylogeny,
pedigree/`A`/`Ainv`, a labelled dense kernel, or the normalized SPDE projection
`D^-1/2 A_column Q(kappa)^-1 A_column' D^-1/2`. The slope basis excludes an
intercept. Validation-debt rows FG-19, RE-03, and SPA-11 record the admitted
Gaussian long-format point-estimation scope.

## 4. Files Touched

**Implementation and public API**

- `R/brms-sugar.R`, `R/animal-keyword.R`, `R/fit-multi.R`, `R/gllvmTMB.R`,
  `R/extract-sigma.R`, `R/mesh.R`, `R/traits-keyword.R`
- `src/gllvmTMB.cpp`
- `NAMESPACE`, `.Rbuildignore`

**Generated reference and public documentation**

- `man/slope.Rd`, `man/phylo_slope.Rd`, `man/animal_slope.Rd`,
  `man/kernel_slope.Rd`, `man/spatial_slope.Rd`, `man/extract_Sigma.Rd`,
  `man/make_mesh.Rd`, `man/gllvmTMB.Rd`
- `NEWS.md`, `_pkgdown.yml`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/where-does-the-tree-go.Rmd`

**Fixture and executable article gate**

- `data-raw/examples/make-trait-axis-bridge.R`
- `inst/extdata/examples/trait-axis-bridge.rds`
- `dev/trait-axis-bridge/source-current-smoke.R`

**Tests**

- `tests/testthat/test-fixed-column-slope-family.R`
- `tests/testthat/test-ordinary-column-slope-phylo-coexistence.R`
- `tests/testthat/test-phylo-column-slope-indep.R`
- `tests/testthat/test-spatial-column-slope.R`
- `tests/testthat/test-g2c-replicated-pa-harness.R`
- `tests/testthat/test-g2d-six-species-harness.R`
- `tests/testthat/test-g2e-information-diagnostic.R`
- `tests/testthat/test-g2f-pa-replication.R`
- `tests/testthat/test-g2i-recovery-prerun.R`
- `tests/testthat/test-g2n-local-prerun.R`
- `tests/testthat/test-paper1-spde-slope-gauge-nofit-v2-materializer.R`

**Developer harness portability**

- `dev/isdm-package-recovery/run-bfgs-paper1-smoke.R`
- `dev/isdm-package-recovery/run-bfgs-paper2-smoke.R`
- `dev/isdm-package-recovery/run-g2c-replicated-pa-recovery.R`
- `dev/isdm-package-recovery/run-g2d-six-species-recovery.R`
- `dev/isdm-package-recovery/run-g2e-information-diagnostic.R`
- `dev/isdm-package-recovery/run-g2e-information-smoke.R`
- `dev/isdm-package-recovery/run-g2f-pa-replication.R`
- `dev/isdm-package-recovery/run-g2f-pa-replication-smoke.R`
- `dev/isdm-package-recovery/run-g2i-recovery-prerun.R`
- `dev/isdm-package-recovery/run-g2n-local-prerun.R`

**Design and closure**

- `docs/design/130-response-column-slope-family.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- this report

`README.md`, `ROADMAP.md`, `docs/design/00-vision.md`, `AGENTS.md`, and
`CLAUDE.md` were inspected but not changed: their canonical examples do not
teach the response-column slope helper surface.

## 3a. Decisions and Rejected Alternatives

**Decision:** `*_slope()` is the public spelling for predictor coefficients
varying across response columns. **Rationale:** it names the ecological task;
the canonical `*_indep()`/`*_dep()` machinery remains underneath. **Rejected:**
using `*_indep(0 + x1 + x2 | trait)` as the only teaching API, which hides the
column-predictor purpose; and using `phylo_slope(... | species)` for row-wise
random regression, which conflates model axes. **Confidence:** high, from API
review, matrix oracles, source-current fits, and reader review.

**Decision:** the PCM example uses ordinary `slope(... | trait)` plus a
separate species-axis phylogenetic term. **Rejected:** the old article formula
that placed `phylo_slope(elevation | species)` beside trait columns. It fit via
compatibility code but taught the wrong public contract. **Confidence:** high.

**Decision:** keep wide response-column grammar, latent predictor covariance,
non-Gaussian multi-predictor slopes, simultaneous column-slope sources, and
interval calibration deferred. **Rejected:** guessing a wide grammar or
advertising regimes without recovery evidence. **Confidence:** high.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "article-prescribed-calls|fixed-column-slope-family|ordinary-column-slope-phylo-coexistence|phylo-column-slope-indep|phylo-slope-rhs-routing|animal-slope-recovery|spatial-column-slope", stop_on_failure = TRUE)'
# PASS: 227, FAIL: 0, WARN: 0; six explicit heavy-test skips.
GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "spatial-indep-slope-gaussian|spde-slope-base-engine", stop_on_failure = TRUE)'
# PASS: 30, FAIL: 0, WARN: 0, SKIP: 0; legacy observation-space spatial slopes protected.
Rscript --vanilla -e 'devtools::test(filter = "g2(c-replicated-pa-harness|e-information-diagnostic|f-pa-replication|i-recovery-prerun|n-local-prerun)", stop_on_failure = TRUE)'
# PASS: 60, FAIL: 0, WARN: 0, SKIP: 0.
Rscript --vanilla -e 'devtools::test(filter = "paper1-spde-slope-gauge-nofit-v2-materializer", stop_on_failure = TRUE)'
# PASS after adopting the sibling portable fixture: 47, FAIL: 0, WARN: 0, SKIP: 0.
Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'
# PASS: 16,608, FAIL: 0, WARN: 76, SKIP: 879 on the final integrated candidate.
Rscript --vanilla dev/trait-axis-bridge/source-current-smoke.R
# PASS: PCM objective 3416.127; column objective 1844.128; iSDM objective 126.3114.
Rscript --vanilla dev/trait-axis-bridge/verify-article.R
# PASS: ARTICLE BUILD PASS; pkgdown reports no problems.
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
# PASS: generated reference synchronized; pre-existing aghq S3 roxygen notices only.
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
# 0 errors, 0 warnings, 4 notes in 18m53s. The task-local .unlazy packaging note was fixed through .Rbuildignore;
# remaining notes are pre-existing/environmental.
git diff --check
# PASS.
```

No Totoro/DRAC campaign was run. Every local fit was estimated under 30
minutes; the full suite and package check stayed within their stated limits.

## 6. Tests of the Tests

- **Failure before fix:** mismatched structured RHS/top-level routing,
  spaces-in-worktree Rscript launches, and the old V2 external-fixture
  dependency all failed before their repairs.
- **Boundary cases:** intercepts, response-column names in the slope basis,
  transforms, factors, duplicate/non-finite predictors, source-label
  mismatches, duplicate coordinates, and incompatible axes fail loudly.
- **Feature combinations:** ordinary column slopes coexist with a species-axis
  `phylo_latent()` block; pedigree, dense `A`, and sparse `Ainv` agree; kernel
  permutation and `||` routes agree; spatial `P != T` mapping is checked.
- **Independent oracles:** deterministic trait-major design matrices,
  Kronecker covariance, SPDE normalization, gradients, and known-DGP recovery
  assess the intended quantities rather than convergence alone.
- **Axis-separation recovery:** a fixed joint DGP recovers ordinary
  response-column slope variance and the rank-one species phylogenetic
  covariance on deliberately separated scales; swapping the axes fails its
  scale-order and covariance-shape assertions.

## 8. Consistency Audit

```sh
rg -n '\bS_B\b|\bS_W\b|\\bf S' NEWS.md R/animal-keyword.R R/brms-sugar.R R/extract-sigma.R R/gllvmTMB.R R/mesh.R vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd docs/design/130-response-column-slope-family.md
# PASS: no stale mathematical notation in touched surfaces.
rg -n '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd
# PASS: no deprecated helper taught in the changed articles.
rg -n 'gllvmTMB_wide|meta_known_V|non-Gaussian|planned|deferred|blocked' NEWS.md vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd docs/design/130-response-column-slope-family.md
# PASS: deprecated names are compatibility statements; deferred regimes remain explicit.
rg -n 'gllvmTMB\(' R/animal-keyword.R R/brms-sugar.R R/gllvmTMB.R R/mesh.R vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd NEWS.md docs/design/130-response-column-slope-family.md
# PASS after manual review: changed long-format examples pass trait = explicitly; wide examples use traits(...).
rg -n '^export\((slope|phylo_slope|animal_slope|kernel_slope|spatial_slope)\)' NAMESPACE
rg -n -C 3 'Response-column slope helpers' _pkgdown.yml
# PASS: all five exports appear in one pkgdown reference section.
```

Rose pre-publish verdict: **PASS**. Prose review verdict: **PASS** for an
applied ecology/evolution graduate-student reader. Shannon coordination
verdict: **WARN** because GitHub DNS was unavailable and
`origin/codex/0701-trust-release` contains the same V2 portable-test repair;
the exact stronger repair was adopted and the overlap is declared.

## 7. Roadmap Tick

N/A. Design 130 and validation-debt rows FG-19, RE-03, and SPA-11 are the
authoritative scope inventory. This programme does not change the release
roadmap or claim a non-Gaussian/wide milestone.

## 7a. Issue Ledger

The work implements the response-column scope discussed under #1196 and
protects the routing contract associated with #1192/#1195. No issue was
mutated during closure because `api.github.com` was unreachable. The PR body
must name the deferred wide grammar, latent predictor covariance,
non-Gaussian/mixed regimes, simultaneous column sources, and intervals.

## 9. What Did Not Go Smoothly

The already-merged bridge article used a compatibility form that fit but taught
the wrong axis: `phylo_slope(... | species)` looked like the public
response-column helper even though `species` was a row-wise grouping factor.
The correction required separating ordinary measured-column slopes from the
species phylogenetic term. Full-suite verification also exposed several old
developer harnesses that split paths containing spaces. A final three-test
failure came from an ephemeral `/private/tmp` predecessor; a parallel branch
had already designed the stronger local synthetic fixture, which this branch
adopted rather than retaining a weaker skip.

## 11. Team Learning

**Ada:** kept one semantic contract across implementation, article, tests, and
scope while refusing to guess the deferred wide grammar.

**Boole:** separated the memorable `*_slope()` teaching surface from the
generic `*_indep()`/`*_dep()` machinery and preserved legacy runtime syntax.

**Gauss and Noether:** checked coefficient packing, Kronecker order, SPDE
normalization, predictor covariance parameterisation, and one-predictor
compatibility. The independent spatial review passed.

**Curie:** required design oracles and covariance recovery rather than treating
optimizer convergence as validation.

**Florence and Pat:** retained the four figure programme and made the corrected
axis distinction readable before formulas; Pat's final reader pass found no
blocking ambiguity.

**Rose:** caught stale evidence counts and required a whole-family portability
sweep when the first worktree-space failure appeared.

**Grace:** verified documentation generation, source-current article rendering,
pkgdown, the full local suite, and installed-package check.

**Shannon:** identified the overlapping 0.7.1 branch repair and the stale
`origin/main`; no rebase or remote claim is allowed until connectivity returns.

## 10. Known Residuals

The admitted claim is Gaussian, long-format point estimation. Wide
response-column grammar, transformed/factor slope bases, latent predictor
covariance, non-Gaussian/mixed responses, simultaneous response-column slope
sources, and interval calibration remain deferred. Existing wide models and
historical one-predictor fits are protected.

Closure: the series was rebased cleanly onto `origin/main` at `872ae856` and
safely force-pushed with a lease as `2ad0238a`. PR
[#1208](https://github.com/itchyshin/gllvmTMB/pull/1208) is open and unmerged.
Its explicit full-matrix run
[#32790567062](https://github.com/itchyshin/gllvmTMB/actions/runs/32790567062)
passed macOS (00:08 UTC), Ubuntu (00:22 UTC), and Windows (00:24 UTC) on
2026-08-25. The routine PR check is Ubuntu-only, so this manual matrix is the
required cross-platform evidence. The only next action is maintainer review;
this lane must not self-merge.

## 12. Cross-Product Coverage

This arc covers Gaussian long-format point estimation for ordinary, phylogenetic,
animal, kernel, and spatial response-column slope helpers; their diagonal and
full predictor-covariance routes; named extraction; source-current examples; and
the coexistence of an ordinary response-column slope with a separate row-wise
phylogenetic term.

It does NOT cover wide-format response-column slope grammar, latent
predictor-slope covariance, transformed or factor slope bases, non-Gaussian or
mixed-family multi-predictor slopes, simultaneous response-column relationship
sources, inference intervals, or a public row-wise random-regression spelling.
Those cells remain deferred and are not taught or advertised by this change.
