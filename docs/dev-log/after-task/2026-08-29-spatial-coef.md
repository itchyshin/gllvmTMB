# After Task: Spatial response-column coefficients

**Branch**: `codex/spatial-column-coef`
**Base**: `eec9cdde4ec95fe8fb61911621f4620d69e204dc`
**Date**: `2026-08-29`
**Status**: IN PROGRESS — implementation, focused and full tests, recovery,
generated documentation, pkgdown checks, affected article renders, all
independent reviews, and the frozen-candidate package check pass; exact-head
CI, protected merge, exact-main verification, live-site verification, and
lease release remain

## 1. Goal

Complete the serial response-column coefficient family by admitting public
Gaussian `spatial_coef()` random intercepts and slopes for long and
`traits(...)` wide data at the projected-SPDE endpoint `rho = 1`, while
preserving the released warning-free `spatial_slope()` API and every unrelated
lane.

## 2. Implemented

`spatial_coef(formula, mesh, rho = 1)` accepts one response-column-labelled
mesh and an explicit intercept/slope coefficient basis. `|` estimates a full
coefficient covariance and `||` maps its off-diagonals to zero. The first
public route accepts only `rho = 1`; literal or evaluated `rho = NULL` and all
numeric values below one fail with a typed admission error.

The no-intercept endpoint literally rewrites to `spatial_slope()` under both
bars. Intercept-bearing fits reuse the same projected-SPDE engine and add one
literal all-ones design column. `extract_Sigma(level = "column_coef")` reports
the coefficient covariance, source labels and coordinates, fitted `kappa` and
practical range, projected unit-diagonal source covariance, and fixed-rho
metadata. `screen_gllvmTMB()` follows the same admission and rewrite path.

## 3. Mathematical Contract

For response column `t`, sampled row `i`, and coefficient basis `z_i`,

```text
eta_it,coef = z_i^T b_t
Cov(vec(B^T)) = K_spatial(kappa) (x) Sigma_coef
Cov(b_t,p, b_u,q) = K_spatial(kappa)[t,u] Sigma_coef[p,q]
```

The source covariance is

```text
Q(kappa) = kappa^4 M0 + 2 kappa^2 M1 + M2
C_raw = A_column Q(kappa)^(-1) A_column^T
K_spatial = D^(-1/2) C_raw D^(-1/2)
D = diag(diag(C_raw))
```

This is covariance among response-column coefficient vectors, not residual
covariance, observation-space spatial covariance, unit-tier covariance, or a
new mode in the 5 x 3 grid. The slice does not implement a spatial-plus-IID
mixture: `rho < 1` and estimated spatial `rho` require a separate field,
engine, and joint `rho`-range identifiability gate.

## 3a. Decisions and Rejected Alternatives

- The source strength is fixed at `rho = 1`. Mapping `kappa` off or pretending
  the existing projected field contains an IID coefficient nugget would fit a
  different model.
- The no-intercept endpoint is the released `spatial_slope()` call itself,
  protecting exact historical data, maps, objective, gradient, report, fitted
  values, and warnings.
- The intercept is a coefficient-basis column of ones; it is not a second
  SPDE source and does not alter projected normalization.
- Large calibration, non-Gaussian families, intervals, latent coefficient
  covariance, simultaneous sources, multiple spatial axes, transformed/factor
  bases, and prediction at new response-column locations remain out of scope.

## 4. Files Touched

- API/engine: `R/column-coef-foundation.R`, `R/gllvmTMB.R`,
  `R/screen-gllvmTMB.R`, `R/fit-multi.R`, `R/extract-sigma.R`.
- Export/help: `NAMESPACE`, `man/spatial_coef.Rd`, `man/column_coef.Rd`,
  `man/phylo_coef.Rd`, `man/extract_Sigma.Rd`, `man/gllvmTMB.Rd`.
- Tests/evidence: `tests/testthat/helper-column-coef-spatial.R`, the parser,
  equivalence, wide, recovery, and edge spatial test files,
  `data-raw/spatial-coef-recovery.R`, and updated coefficient foundation,
  IID-engine, and public-API regression tests.
- Reader/design surfaces: `NEWS.md`, `_pkgdown.yml`,
  `vignettes/articles/api-keyword-grid.Rmd`,
  `vignettes/articles/where-does-the-tree-go.Rmd`, Designs 01, 130, 131, and
  133, and validation-debt row FG-20.
- Durable lane state: `LOOP/spatial-coef-alignment.md`,
  `LOOP/spatial-coef-ultra-plan.md`, the spatial Ultra Plan, this report,
  `docs/dev-log/check-log.md`, and the ignored Unlazy ledger.

No C++ file, response likelihood, existing `*_slope()` helper body, README,
ROADMAP, AGENTS/CLAUDE rule file, or unrelated article changed.

## 5. Checks Run

- RED-first parser/equivalence run: failed only at the absent export, missing
  spatial rewrite, deliberate engine fence, and not-yet-spatial-specific
  validation. The first GREEN run then proved exact endpoint identity; two
  test expectations were corrected to acknowledge intentional extractor
  dimnames and evaluated `NULL` expressions.
- `devtools::test(filter = "column-coef-spatial")`: PASS after the final
  metadata/map/duplicate-coordinate strengthening; zero failures or warnings.
- `devtools::test(filter = "(column-coef-spatial|spatial-column-slope)")`:
  PASS, including all released spatial-slope regressions.
- `devtools::test(filter = "(column-coef|fixed-column-slope|spatial-column-slope)")`:
  PASS after replacing three stale tests that still expected a spatial fence;
  all five coefficient sources and all released slope helpers passed together.
- `Rscript --vanilla data-raw/spatial-coef-recovery.R`: PASS in 17.2 seconds
  after Curie's review replaced the permissive one-cell script with nine
  retained cells. The ordinary seed recovered coefficient correlation `0.391`
  versus `0.375`, practical range `2.280` versus `2.500`, coefficient-variance
  ratios `0.575/0.843`, projected-`K` RMSE `0.0335`, fixed-effect maximum error
  `0.226`, and maximum gradient `0.000099`. Additional cells passed for
  correlation `0`, `+0.8`, `-0.8`, and `0.98`, low and mesh-extent-limited range, and
  coefficient variances around `0.01` and `25`; the extent-limited range cell
  deliberately gates ordering rather than false precision.
- `devtools::document(quiet = TRUE)`: PASS; generated export/help cascade.
  Only the three pre-existing AIC/BIC/anova S3-tag notices appeared.
- `pkgdown::check_pkgdown()`: PASS, no problems.
- Individual source-current builds of `articles/api-keyword-grid` and
  `articles/where-does-the-tree-go`: PASS; both HTML files contain the new
  public spatial boundary and reference link.
- `pkgdown::build_articles(lazy = FALSE)`: rendered the edited API grid, then
  stopped in unchanged `cross-family-correlations.Rmd` because its fresh-process
  fit still emits the pre-existing predictor-informed-LV family fence. This is
  the same unrelated full-build failure recorded by the kernel lane; both
  affected coefficient articles pass individually.
- The final source/Rd `spatial_coef()` example runs in 3.7 seconds on its
  16-response/24-unit geometry with convergence `0`, maximum gradient
  `7.06e-6`, and the expected spatial source plus intercept/moisture basis.
- `git diff --check`: PASS after each implementation/documentation phase.
- `devtools::document(quiet = TRUE); devtools::test(stop_on_failure = TRUE)`:
  PASS in 2269.2 seconds with 18,383 passes, zero failures, 52 expected
  warnings, and 879 declared dependency/opt-in skips. This single run includes
  every coefficient source, long/wide route, spatial gate, and released
  `*_slope()` regression.
- `devtools::check(args = "--no-manual", error_on = "warning", quiet = TRUE)`:
  PASS in 18m 48.4s with zero errors, zero warnings, and three notes. The notes
  were unavailable remote clock verification, the pre-existing unqualified
  `logLik` diagnostic, and macOS `xcrun_db` temp detritus; none is attributable
  to this slice.

Pending: exact-head three-OS CI, protected merge, exact-main check, live
pkgdown verification, and final
Unlazy/after-task/handover validation.

## 6. Tests of the Tests

The exact endpoint test failed before implementation and would catch any drift
in TMB data, random indices, maps, objective, gradient, optimum, report, fitted
values, or warnings relative to `spatial_slope()`. Parser tests combine positive
formals/source/basis assertions with missing mesh, unknown arguments, literal
and evaluated `NULL`, interior/boundary rho, out-of-range rho, non-Gaussian, and
pre-fit screen routes. The long/wide tests combine the new helper with keyed
C3/C4 column metadata, fixed grand intercepts/slopes, both bars, and both data
shapes, and require identical fitted objects rather than approximate estimates.

The routine DGP is limited to five response columns and 30 units and checks a
converged finite positive-definite route; it does not make a precise covariance
recovery claim. The retained campaign plants fixed C3/C4 intercepts/slopes, a
full intercept/slope covariance, and a projected spatial range, and gates
correlation magnitude, variance ratios, range, projected-`K` error, and a small
gradient. Separate retained cells cover near-zero, +/-0.8, and near-boundary
correlations, low and mesh-extent-limited ranges, and small/large variances. Routine edge tests
cover label permutation, unlabelled/mismatched/duplicate coordinates,
fixed-space saturation, a rare fixed pathway, one missing response, and the
simultaneous-spatial-axis refusal. Existing `spatial_slope()` tests are replayed
unchanged.

## 7a. Issue Ledger

GitHub issue #1212 was inspected. This slice completes the bounded five-source
coefficient series but does not close the issue: the issue also owns broader
structured-rho design, including the deliberately unearned spatial-plus-IID
mixture and possible rho extensions to the 5 x 3 grid. No issue was closed or
created. The landing PR should link #1212 without a closing keyword and state
that spatial rho remains fixed at one.

## 8. Consistency Audit

Exact scans:

```sh
rg -n -i "spatial(_coef)?[^\\n]{0,100}(planned|fenced|unavailable|not exported)|(?:planned|fenced|unavailable|not exported)[^\\n]{0,100}spatial(_coef)?" R man NEWS.md vignettes/articles docs/design _pkgdown.yml pkgdown-site/articles
rg -n -i "deprecat[^\\n]{0,100}(_slope|slope\\()|(_slope|slope\\()[^\\n]{0,100}deprecat" R man NEWS.md vignettes/articles docs/design _pkgdown.yml
rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" NEWS.md R/column-coef-foundation.R R/extract-sigma.R docs/design/130-response-column-slope-family.md docs/design/131-response-column-coefficient-foundation.md docs/design/133-response-column-coefficient-spatial.md vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd
rg -n "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd
rg -n "meta_known_V|gllvmTMB_wide" README.md NEWS.md docs vignettes
rg -n "gllvmTMB\\(" R/column-coef-foundation.R vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd
rg -n "column_coef\\(\\)|phylo_coef\\(\\)|animal_coef\\(\\)|kernel_coef\\(\\)|spatial_coef\\(\\)|All five|five helpers|four helpers|All four" R/column-coef-foundation.R R/gllvmTMB.R R/extract-sigma.R NEWS.md _pkgdown.yml vignettes/articles docs/design/01-formula-grammar.md docs/design/130-response-column-slope-family.md docs/design/131-response-column-coefficient-foundation.md docs/design/133-response-column-coefficient-spatial.md docs/design/35-validation-debt-register.md
```

Verdict: current live surfaces agree that all five coefficient helpers are
public Gaussian long/wide point routes; spatial strength is fixed at one and
spatial IID mixtures remain unavailable. Apparent spatial-planned hits concern
other capabilities (structured latent-score means, observation-space terms, or
multiple axes), not `spatial_coef()`. Designs 55/56 retain historical
deprecation proposals, but current Designs 01 and 130--133, NEWS, help, tests,
and articles explicitly preserve every `*_slope()` helper as current,
warning-free, and non-deprecated. `vcv.phylo()` is the touched-article alias
regex false positive. `meta_known_V()` and `gllvmTMB_wide()` hits are deliberate
compatibility/history statements. All touched long calls pass `trait =`;
wide calls use `traits(...)` without a custom trait argument.

**Roadmap tick**: N/A. README, ROADMAP, and the general known-limitations file
contain no coefficient-family status row; Design 01 and FG-20 are the canonical
status inventory and were updated.

## 9. What Did Not Go Smoothly

The initial RED test loop exposed that an indirect `rho = rho` expression whose
value is `NULL` bypassed the literal-NULL branch; the parser now gives both the
same typed refusal. The first GREEN extractor comparison forgot that the public
matrix intentionally adds dimnames while the raw TMB report does not; the test
now checks values and labels separately. The first broad regression replay
found three stale tests that still expected spatial to be fenced. Finally, the
neighbor walk found a real missed surface: `screen_gllvmTMB()` still carried
the old four-source fence. It was repaired and now has a direct admission test.
Gauss then found that the first intercept implementation would reinterpret a
released `spatial_slope()` predictor literally named `(Intercept)` as a column
of ones. Synthetic intercept construction is now conditioned on the internal
response-column-coefficient marker and a direct legacy regression preserves
the real data column. Curie found that the first recovery gate was too
permissive and too large for routine checks; the routine cell is now 5 columns
by 30 units and the retained script owns the strengthened nine-cell point
evidence. The first exact-head three-OS run then found a Windows-only test
harness failure: PORT emitted `NA/NaN function evaluation` at a transient trial
point in both long and wide versions of the small parity fixture. Ubuntu and
macOS passed, and Windows returned both fit objects before the overly broad
`expect_no_warning()` assertions failed. The repaired test permits only that
exact numerical trial message and retains every exact long/wide object,
objective, parameter, function, gradient, report, fitted-value, and extractor
comparison; any API or other fit warning still fails. Production code and
user-visible warning behavior were not changed.

## 11. Team Learning

**Ada** preserved serial animal → kernel → spatial integration and the umbrella
lease, then treated the pre-fit screen as part of the public API rather than a
secondary utility. **Gauss/Noether** returned PASS after the literal
`(Intercept)` compatibility repair and a 162-assertion replay of the projected
SPDE order, coefficient basis, maps, extractor, and exact slope endpoint.
**Curie** returned PASS after the routine/retained recovery split and nine-cell
edge campaign. **Boole/Rose/Pat** returned terminal PASS on diff fingerprint
`f5dd305...` after the runnable help-example and stale-surface repairs.
**Grace** returned PASS with the full suite, local package check, three-OS
exact-head proof, protected merge, exact-main check, and live site as landing
gates; the full suite has now passed. After the Windows PORT trial-message
failure, Rose and Grace re-reviewed the exact three-file test-and-record repair
and returned PASS; Grace required no broader local rerun before the one paced
replacement push because package and reader-facing code did not change.

## 10. Known Residuals

This is Gaussian native-Laplace point estimation for one labelled
response-column mesh and bare numeric coefficient predictors. It does not
claim spatial `rho < 1`, estimated spatial rho, non-Gaussian or mixed families,
interval calibration, simultaneous coefficient sources, multiple spatial
axes, transformed/factor bases, latent coefficient covariance, or prediction
at new response-column locations. The deterministic recovery cell is bounded
point evidence, not a repeated-seed calibration campaign.

## 12. Cross-Product Coverage

Covered: long and `traits(...)` wide input; intercept-only, slope-only, and
intercept-plus-slope bases; `|` and `||`; fixed `rho = 1`; labelled mesh order
permutation; unlabelled/mismatched/duplicate-coordinate refusals; full and
diagonal coefficient maps; exact released slope endpoints; C3/C4 fixed grand
intercepts/slopes plus plant-specific deviations; one rare pathway level; one missing response;
fixed-space overlap; one-spatial-axis refusal; extractor coordinates, range,
normalization, and source covariance; bounded Gaussian point recovery across
ordinary, correlation, range, and variance regimes. Not covered:
This slice does NOT cover spatial IID mixtures, estimated spatial rho,
non-Gaussian/mixed families,
intervals, broad repeated-seed calibration, simultaneous sources/axes, latent
coefficient covariance, transformed/factor bases, or new-location prediction.

## 13. Next Actions

Freeze and commit the exact candidate; run the local package check; push once
with CI pacing; require routine plus
manual Ubuntu/macOS/Windows success at the exact reviewed head; merge normally;
verify exact-main R-CMD-check and deployed pkgdown pages; release the spatial
and umbrella leases; then send the iJSDM lane the exact final main SHA.
