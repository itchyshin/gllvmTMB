# After Task: Pathway means with response-column random coefficients

**Branch:** `codex/column-coef-pathway-article`
**Date:** 2026-08-28
**Roles engaged:** Ada, Rose, Pat, Noether

## 1. Goal

Replace Example 2's fixed plant-species intercepts and slope-only random
coefficients with a biologically interpretable partial-pooling model: separate
C3 and C4 mean intercepts and latitude slopes, plus plant-species random
intercepts and slopes around those pathway means. Protect the exact long/wide
equivalence before publishing the new example.

## 2. Implemented

- Reframed Example 2 around pathway differences in baseline biomass, pathway
  differences in latitude response, remaining between-species heterogeneity,
  and phylogenetic structure in that heterogeneity.
- Changed both fits to
  `0 + pathway + latitude:pathway + *_coef(1 + latitude | trait)`.
- Changed the simulation to plant pathway-specific intercepts and slopes plus
  bivariate phylogenetically structured intercept/slope deviations.
- Added the corresponding `traits(...)` wide fit and clarified that it is the
  same hierarchical model, not a slope-only approximation.
- Added a durable exact long/wide regression under both `|` and `||`.
- Extended FG-20 without widening its `partial` Gaussian point-model boundary.

## 3. Mathematical Contract

For plant species `j` in pathway `g(j)` and site `i`,

`E(y_ij | a_j, b_j) = {alpha_g(j) + a_j} + {beta_g(j) + b_j} latitude_i`.

The fixed `alpha` and `beta` coefficients are the C3/C4 pathway means. The
random coefficient matrix has columns `(Intercept)` and `latitude`.
`column_coef()` uses IID row covariance; `phylo_coef()` uses `K_rho`. A single
bar estimates the full coefficient covariance and a double bar maps its
off-diagonal to zero.

## 4. Files Touched

- `tests/testthat/test-column-coef-public-api.R`: combined pathway fixed
  intercept/slope plus response-column random intercept/slope long/wide test.
- `vignettes/articles/where-does-the-tree-go.Rmd`: Example 2 question, DGP,
  long and wide formulas, output, interpretation, figures, captions, and
  closing guidance.
- `docs/design/35-validation-debt-register.md`: FG-20 evidence refinement.
- `docs/dev-log/check-log.md`: exact commands and outcomes.
- `docs/dev-log/after-task/2026-08-28-column-coef-pathway-article.md`: this
  report.

No R function, argument, default, export, generated Rd topic, README example,
NEWS entry, ROADMAP row, or keyword-grid convention changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** use separate C3/C4 fixed intercepts and slopes rather than one
global intercept through the internal `shared()` marker. **Rationale:** pathway
is observed response-column metadata and the public formula can estimate the
two pathway means directly; exact installed-package diagnostics passed.
**Rejected alternative:** advertise `shared()`, which is not exported or
publicly documented and can be shadowed by a user function. **Confidence:**
high.

**Decision:** keep the rendered boundary estimate `rho = 0.00`. **Rationale:**
the article asks whether phylogenetic structure is supported and explicitly
states that one finite sample need not recover planted `rho = 0.60`.
**Rejected alternative:** search seeds for a visually convenient interior
estimate, which would make the demonstration look selectively tuned.
**Confidence:** high.

## 5. Checks Run

- `Rscript --vanilla -e 'devtools::test(filter =
  "column-coef-public-api", reporter = "summary")'`: baseline PASS; after the
  new test, the first run correctly failed because the helper supplied
  `trait = NULL` to wide input; after omitting the argument, PASS.
- `Rscript --vanilla -e 'devtools::test(filter =
  "column-coef-(public-api|phylo-estimated-rho)", reporter = "summary")'`:
  PASS, 52 public-API expectations plus the estimated-rho suite.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE);
  pkgdown::build_article("articles/where-does-the-tree-go", pkg = ".",
  lazy = FALSE, new_process = FALSE, quiet = TRUE)'`: PASS after correcting
  the verified fixed-design coefficient names.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: PASS, no problems found.
- Rendered `community-data-1.png` and `community-wide-1.png` inspected at
  original resolution: labels, pathway panels, response-column layout, and
  plant-species deviations were readable and consistent with the DGP.
- Rose/Pat pre-publish review: initial FAIL on an unconditional expectation
  label and two stale/partial teaching sentences; terminal PASS after repair.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`:
  PASS in 20m37s, 0 errors, 0 warnings, 3 non-attributable notes (clock
  verification, existing `logLik` global note, macOS `xcrun_db`).
- `git diff --check`: PASS.
- `check_after_task(...)`: report structure PASS. The full wrapper's unrelated
  global-ledger stage refused two pre-existing `.unlazy` ledgers owned by prior
  coefficient lanes; they were preserved rather than altered from this lane.

## 6. Tests of the Tests

The new test satisfies the feature-combination rule: it combines response-column
metadata fixed effects, intercept+slope `column_coef()`, `|`/`||`, and both
long and `traits(...)` wide entry points. It compares TMB data, maps,
objective, fitted parameters, fitted values, extracted covariance, fixed-design
names, coefficient basis, convergence, and the double-bar zero covariance.
The initial `trait = NULL` failure demonstrated that the wide call exercises
the public argument guard rather than bypassing preprocessing.

## 8. Consistency Audit

Exact scans:

```sh
rg -n "phylo_coef\\(0 \\+ latitude|column_coef\\(0 \\+ latitude|species-specific fixed intercept|slope-only|traits\\(\\.\\.\\.\\) ~ 1" vignettes/articles/where-does-the-tree-go.Rmd pkgdown-site/articles/where-does-the-tree-go.html
rg -n "shared\\(" vignettes/articles/where-does-the-tree-go.Rmd
rg -n "non-Gaussian|interval|Gaussian|point estimates|point models|animal|kernel|spatial|\\*_slope" vignettes/articles/where-does-the-tree-go.Rmd
rg -n "gllvmTMB\\(" vignettes/articles/where-does-the-tree-go.Rmd
rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/where-does-the-tree-go.Rmd
```

Verdict: no stale slope-only formula or public `shared()` claim; every long
call supplies `trait`, the wide call omits it, the Gaussian point-only boundary
is explicit, deferred sources and intervals remain deferred, and no stale API
or notation appeared. The phrase “not a slope-only approximation” is an
intentional correction, not a stale capability claim.

## 7. Roadmap Tick

N/A. This is a reader-first correction within existing FG-20 scope, not a new
ROADMAP capability.

## 7a. Issue Ledger

N/A. Issue #1212 remains open for the broader animal/kernel/spatial coefficient
programme; this article correction neither closes nor widens that programme.

## 9. What Did Not Go Smoothly

The first narrow pkgdown command omitted the required `articles/` prefix and
failed before knitting. The first full render then exposed the actual fixed
design names as `pathwayC3:latitude` and `pathwayC4:latitude`, which replaced a
stale name-order assumption. Rose/Pat also caught an unconditional expectation
label containing random effects and two remaining slope-only teaching phrases.
All were corrected before the final render and package check.
The after-task wrapper also scans every historical `.unlazy` ledger in the
worktree and stopped on two unmet prior-lane ledgers. Direct report validation
passed; this lane did not claim, abandon, or rewrite those protected records.

## 11. Team Learning

**Noether:** an exact installed-package diagnostic established that pathway
means plus random intercepts/slopes are bit-identical in long and wide forms;
that diagnostic is now a permanent regression test.

**Rose and Pat:** the biologically useful example begins with pathway-level
questions and partial pooling. Their terminal review passed the equation,
formulas, DGP, figures, interpretation, scope boundary, and applied-user path.

## 10. Known Residuals

This remains Gaussian point estimation. It does not add intervals,
non-Gaussian coefficients, multiple simultaneous coefficient sources, latent
coefficient covariance, or animal/kernel/spatial coefficient engines. The
example estimates one coefficient covariance shared by C3 and C4; it does not
fit pathway-specific random-effect covariance matrices. `shared()` remains
internal and is not taught. The next API programme remains separate.

## 12. Cross-Product Coverage

The protected combination is Gaussian point model x long/wide input x
pathway fixed intercepts/slopes x response-column random intercepts/slopes x
`|`/`||` for IID `column_coef()`. The article additionally demonstrates the
already-covered phylogenetic source with estimated `rho`; it does not claim
recovery or interval calibration from this single illustrative dataset.

This slice **does NOT cover** non-Gaussian or mixed-family responses,
coefficient intervals, REML, penalties, missing responses, aggregation,
alternative integration engines, pathway-specific random-effect covariance,
multiple simultaneous coefficient sources, or animal/kernel/spatial
coefficient helpers. It does not change any existing `*_slope()` provider.
