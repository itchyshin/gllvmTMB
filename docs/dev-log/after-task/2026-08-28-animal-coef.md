# After Task: Animal response-column coefficients

**Branch**: `codex/structured-column-coef-family`
**Date**: `2026-08-28`
**Status**: IN PROGRESS — exact-head CI and protected landing remain

## 1. Goal

Admit public Gaussian `animal_coef()` response-column random intercepts and
slopes in long and `traits(...)` wide formats, while preserving the released,
warning-free `animal_slope()` API.

## 3. Mathematical Contract

For response column `t` and sampled unit `i`,

```text
y_it = x_it^T beta + z_i^T b_t + epsilon_it
B ~ MN(0, K_rho, Sigma_coef)
K_rho = rho A + (1-rho) diag(A),  0 <= rho <= 1
epsilon_it ~ N(0, sigma_e^2)
```

`|` estimates a full `Sigma_coef`; `||` maps its off-diagonals to zero.
This is coefficient covariance across response columns, not residual
covariance and not an observation-group animal random effect. A no-intercept
dense-`A`, `rho = 1` call inherits the released `animal_slope()` conditioning
`A + 1e-8 I`; pedigree and sparse-`Ainv` endpoints retain their released
precision. Interior `rho` and intercept-bearing fits use the raw equation.

## 2. Implemented

`animal_coef(formula, pedigree = NULL, A = NULL, Ainv = NULL, rho = 1)` now
accepts exactly one animal source and one fixed numeric `rho`. It uses the
existing matrix-normal coefficient engine, supports random intercepts and
slopes under both bars, matches long and wide entry points, exposes animal
source metadata through `extract_Sigma(level = "column_coef")`, and fails
before routing for non-Gaussian families. No-intercept `rho = 1` fits retain
exact `animal_slope()` objective, gradient, map, report, and fitted values.

## 4. Files Touched

- Engine/API: `R/column-coef-foundation.R`, `R/gllvmTMB.R`,
  `R/screen-gllvmTMB.R`, `R/fit-multi.R`, `R/extract-sigma.R`, and the
  installed-namespace source normaliser in `R/brms-sugar.R`.
- Export/help: `NAMESPACE`, `man/animal_coef.Rd`, `man/column_coef.Rd`,
  `man/phylo_coef.Rd`, and `man/gllvmTMB.Rd`.
- Tests: `helper-column-coef-animal.R`, the four new
  `test-column-coef-animal-*.R` files, plus the existing coefficient
  foundation, IID engine, and public-API regressions.
- Public/design surfaces: `NEWS.md`, `_pkgdown.yml`,
  `vignettes/articles/api-keyword-grid.Rmd`, Design 01, Design 131, and
  validation-debt row FG-20.
- Durable lane state: `LOOP/animal-coef-alignment.md`, `LOOP/checkpoint.md`,
  this report, and `docs/dev-log/check-log.md`.

## 3a. Decisions and Rejected Alternatives

- V1 estimates `Sigma_coef` but accepts only fixed animal `rho`, defaulting to
  one. Estimated animal `rho = NULL` is deferred until it has a separate
  identifiability and recovery gate.
- Relationship matrices may contain labelled pedigree levels beyond the fitted
  response columns; the engine subsets to the observed labels but still rejects
  a missing fitted label.
- The released dense-source conditioning seam is preserved and disclosed,
  rather than silently changing `animal_slope()` or claiming raw-`A` identity.
- `kernel_coef()` and `spatial_coef()` remain fenced for fresh serial lanes.

## 5. Checks Run

- RED-first parser, source, Gaussian-boundary, screen, installed-namespace, and
  endpoint tests failed for the intended reasons before their fixes.
- `devtools::test(filter = "column-coef-animal")`: 139/139 PASS at the first
  complete animal checkpoint.
- Foundation plus endpoint replay after source-superset repair: 335/335 PASS.
- `devtools::test(filter = "column-coef|animal-slope-recovery|fixed-column-slope-family")`:
  779 PASS, zero failures/warnings, four existing opt-in heavy skips.
- `pkgdown::check_pkgdown()`: PASS, no problems.
- `pkgdown::build_article("articles/api-keyword-grid", ..., lazy = FALSE)`:
  PASS; source-current HTML written.
- `devtools::document(quiet = TRUE)`: generated the export/help cascade; only
  the three pre-existing AIC/BIC/anova S3-tag notices appeared.
- `git diff --check`: PASS.

Local full package check, exact-head three-OS CI, merge, exact-main check, and
live pkgdown verification remain pending and will be appended before closure.

## 6. Tests of the Tests

The public non-Gaussian test initially reached the legacy slope-family error,
proving that the protected endpoint could bypass coefficient-specific family
diagnostics. The installed-package regression initially failed because a
formula rewrite referenced an internal helper visible only under devtools
export-all semantics. The extra-ancestor test initially reproduced the mismatch
between released `animal_slope()` acceptance and stricter coefficient source
labels. These failures demonstrate that the new tests exercise real boundaries,
not only successful fits.

## 8. Consistency Audit

Exact scans:

```sh
rg -n -i "animal(_coef)?[^\\n]{0,80}(planned|fenced|unavailable|not exported)|(?:planned|fenced|unavailable|not exported)[^\\n]{0,80}animal(_coef)?" R man NEWS.md vignettes/articles docs/design
rg -n -i "deprecat[^\\n]{0,80}(_slope|slope\\()|(_slope|slope\\()[^\\n]{0,80}deprecat" R man NEWS.md vignettes/articles docs/design
rg -n "animal_coef|column_coef|phylo_coef" R man NEWS.md _pkgdown.yml vignettes/articles/api-keyword-grid.Rmd docs/design/01-formula-grammar.md docs/design/131-response-column-coefficient-foundation.md docs/design/35-validation-debt-register.md
rg -n "gllvmTMB\\(" R/column-coef-foundation.R vignettes/articles/api-keyword-grid.Rmd
```

Verdict: current public surfaces agree that IID, phylogenetic, and animal
Gaussian coefficient models are available, while kernel/spatial, intervals,
non-Gaussian models, and estimated animal `rho` remain deferred. Design 55/56
retain explicitly labelled superseded deprecation proposals as historical
text; Design 130 and every current reader surface state that all `*_slope()`
helpers remain current, warning-free, and non-deprecated. Long examples pass
`trait =`; wide examples use `traits(...)` without a custom trait argument.

### Roadmap Tick

N/A: no `ROADMAP.md` row was changed. Capability status is recorded in
Design 01 and validation-debt row FG-20.

## 7a. Issue Ledger

No issue was created, closed, or modified. The lane started only after the open
PR/branch census found no overlapping active response-column coefficient PR.
The protected landing PR remains to be opened after the local candidate gate.

## 9. What Did Not Go Smoothly

The critical review found four gaps hidden by ordinary successful fits:
installed-package evaluation of internal source helpers, missing animal screen
dispatch, the inherited dense-`A` ridge seam, and relationship matrices with
valid extra pedigree levels. A broader coefficient sweep also found one stale
foundation test that still expected source-free, estimated-`rho` animal syntax.
All were repaired with focused regressions rather than exceptions.

## 11. Team Learning

**Ada** kept this as the first serial structured-coefficient lane and protected
kernel/spatial scope. **Boole**'s parser boundary now enforces exactly one
source, fixed `rho`, top-level placement, and animal-specific errors.
**Noether** independently found the installed-package, endpoint-seam, label-
superset, screen, and diagnostic mismatches and issued APPROVE after 119/119
endpoint assertions. **Curie** supplied covariance-scale, malformed-source,
long/wide, and planted-covariance oracles. **Emmy**'s installed-namespace check
prevented export-all visibility from becoming an accidental API dependency.
**Pat**'s reader path keeps the C3/C4 fixed means separate from response-column
random intercepts and slopes. **Rose** is performing the terminal cross-file
pre-publish audit. **Grace** still owns pkgdown, local package, three-OS, and
exact-main landing evidence. **Shannon** confirmed exclusive lane ownership
before edits.

### Documentation and pkgdown

The new reference topic has a runnable Gaussian example. The API keyword grid
shows animal syntax beside IID and phylogenetic coefficient models and states
the fixed-`rho`, dense-source, interval, and family boundaries. Pkgdown
navigation includes `animal_coef`; the affected article renders from source.
The biological tree-placement article remains focused on `phylo_coef()` and was
not broadened merely to mention the new animal source.

## 10. Known Residuals

Estimated animal `rho`, interval inference, non-Gaussian coefficient models,
latent coefficient covariance, `kernel_coef()`, and `spatial_coef()` remain
outside this arc. Next: finish Rose/Grace and Unlazy gates, run the full local
package check, then CI-paced protected PR, exact-head three-OS checks, normal
merge, exact-main check, live pkgdown verification, and lease release before a
fresh kernel lane.

## 12. Cross-Product Coverage

Covered combinations are long and `traits(...)` wide input; intercept-only,
slope-only, and intercept-plus-slope bases; `|` and `||`; pedigree, dense `A`,
sparse `Ainv`, and dense `Ainv`; exact response label sets and valid labelled
supersets; fixed `rho = 0`, one interior fixed value, and `rho = 1`; and
Gaussian point estimation. The exact released endpoint is exercised under both
bars and all three source spellings. This arc does NOT cover estimated animal
`rho`, non-Gaussian or mixed families, intervals, REML-specific coefficient
inference, alternative integration engines, missing-response coefficient
recovery, aggregation, latent coefficient covariance, simultaneous coefficient
sources, `kernel_coef()`, or `spatial_coef()`.
