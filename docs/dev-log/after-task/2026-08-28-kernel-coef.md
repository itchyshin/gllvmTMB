# After Task: Dense-kernel response-column coefficients

**Branch**: `codex/kernel-column-coef`
**Date**: `2026-08-28`
**Status**: IN PROGRESS — every local implementation, documentation, review,
and package-check gate passes; exact-head CI, protected merge, exact-main
CI/site verification, and lease release remain

## 1. Goal

Admit public Gaussian `kernel_coef()` response-column random intercepts and
slopes for long and `traits(...)` wide data, while preserving the released,
warning-free `kernel_slope()` API and every unrelated lane.

## 2. Implemented

`kernel_coef(formula, K, name = "kernel", rho = NULL)` accepts one labelled
dense positive-definite covariance. Numeric `rho` fixes the source-strength
mixture; `NULL` estimates one interior value through the existing spectral
matrix-normal engine. `|` estimates a full coefficient covariance and `||`
maps its off-diagonals to zero. Extraction reports the basis covariance,
effective source covariance, `rho`, source name, labels, and supplied-scale
metadata.

The no-intercept `rho = 1` endpoint hard-rewrites to `kernel_slope()` under
both bars. It therefore retains raw `K`, with no phylogenetic/animal ridge, and
is identical in TMB data, maps, random indices, objective, gradient, optimum,
report, and fitted values.

## 3. Mathematical Contract

For response column `t` and row/unit `i`,

```text
eta_it,coef = z_i^T b_t
B ~ MN(0, K_rho, Sigma_coef)
K_rho = rho K + (1-rho) diag(K),  0 <= rho <= 1
```

With `K = D R D`, estimated `rho` uses
`K_rho = D[(1-rho)I + rho R]D`; the TMB precision and log determinant use the
eigenvectors/eigenvalues of `R`. The supplied marginal scale is preserved.
This is covariance among response-column coefficient vectors, not response
residual covariance, unit-tier covariance, or a new 5 x 3 covariance mode.

## 3a. Decisions and Rejected Alternatives

- Public `K` is a dense covariance only. Sparse input is rejected because
  sparse matrices elsewhere can mean precision, making the same argument
  ambiguous.
- Raw diagonal scale is preserved; automatic standardisation would change the
  meaning of user-supplied covariance. Standardisation is internal only for
  the estimated-`rho` eigendecomposition.
- The `rho = 1`, no-intercept endpoint reuses `kernel_slope()` instead of a
  merely equivalent new path, protecting exact historical fits.
- Large recovery belongs in `data-raw`, not routine package checks. Broad
  calibration, transformed/factor bases, non-Gaussian families, intervals,
  simultaneous sources, and spatial coefficients were rejected as scope
  expansion for this lane.

## 4. Files Touched

- API/engine: `R/column-coef-foundation.R`, `R/gllvmTMB.R`,
  `R/screen-gllvmTMB.R`, `R/fit-multi.R`, `R/extract-sigma.R`.
- Export/help: `NAMESPACE`, `man/kernel_coef.Rd`, `man/column_coef.Rd`,
  `man/phylo_coef.Rd`, `man/gllvmTMB.Rd`.
- Tests/evidence: `tests/testthat/helper-column-coef-kernel.R`, the parser,
  equivalence, wide, recovery, and edge kernel test files,
  `data-raw/kernel-coef-recovery.R`, plus the existing coefficient foundation,
  IID-engine, and public-API regressions.
- Reader/design surfaces: `NEWS.md`, `_pkgdown.yml`,
  `vignettes/articles/api-keyword-grid.Rmd`,
  `vignettes/articles/where-does-the-tree-go.Rmd`, Designs 01, 131, and 132,
  and validation-debt row FG-20.
- Durable lane state: `LOOP/GOAL.md`, `LOOP/kernel-coef-alignment.md`,
  `LOOP/kernel-coef-ultra-plan.md`, this report, and
  `docs/dev-log/check-log.md`.

No C++ file, likelihood family, released slope helper, README, ROADMAP, or
AGENTS/CLAUDE rule file changed.

## 5. Checks Run

- RED-first kernel tests failed only at the missing export, parser rewrite,
  source resolver, and engine fence before implementation.
- `devtools::test(filter = "column-coef|fixed-column-slope-family")`: PASS
  after implementation and again after review repairs; zero failures or
  warnings.
- `devtools::test(filter = "column-coef-kernel-(edge|recovery|wide)")`: PASS
  after the final evidence repairs.
- `Rscript --vanilla data-raw/kernel-coef-recovery.R`: PASS in 25.3 seconds.
  Main cell: `rho_hat = 0.5306293` for truth `0.58`, grand mean `0.2128484`
  for truth `0.25`, max gradient `0.0004049`, coefficient RMSE `0.02304`.
  Stress cells: truth/estimate `0.05/3.14e-8` and `0.80/0.66375`.
- `devtools::document(quiet = TRUE)`: PASS; generated the new export/help and
  repaired stale `phylo_coef()` wording. Only the three pre-existing
  AIC/BIC/anova S3-tag notices appeared.
- `pkgdown::check_pkgdown()`: PASS, no problems.
- `pkgdown::build_article("articles/api-keyword-grid", lazy = FALSE)`: PASS.
- `devtools::load_all(); pkgdown::build_article("articles/where-does-the-tree-go",
  lazy = FALSE, new_process = FALSE)`: PASS with the actual IID/phylogenetic
  coefficient fits executed. The first isolated subprocess used an older
  installed package and failed to find `column_coef()`; source-current render
  resolved that environment mismatch.
- Full `pkgdown::build_articles(lazy = FALSE)` rendered the edited API article,
  then stopped in unchanged `cross-family-correlations.Rmd` because its
  non-Gaussian predictor-informed latent-score fit is currently rejected. This
  is retained as an unrelated main-branch article failure.
- `git diff --check`: PASS.
- Gauss/Noether engine review: PASS. Curie recovery/fidelity re-review: PASS.
  Rose/Boole API and pre-publish re-review: PASS.
- `devtools::check(args = "--no-manual", quiet = TRUE)`: PASS in 20m 7.2s
  with 0 errors, 0 warnings, and three non-blocking notes: unavailable remote
  clock verification, the pre-existing unqualified `logLik` diagnostic, and
  an external `xcrun_db` temp-directory file.

Exact-head three-OS CI, protected merge, exact-main check, and live-site
verification remain before closure.

## 6. Tests of the Tests

The exact endpoint tests would catch any ridge, map, parameter, gradient,
report, fitted-value, or warning drift from `kernel_slope()`. Direct fixed and
spectral precision/log-determinant oracles would catch covariance/precision
mixing or lost diagonal scale. Fixed/estimated label permutations would catch
positional rather than labelled alignment. Fixed/estimated long/wide tests
combine the new helper with keyed C3/C4 `column_data`, both bars, and both data
shapes. Malformed/sparse/identity-source tests cover rejection paths.

The simulation review initially failed because the routine suite contained a
30-response, 70-unit cell and lacked public-contract edge breadth. That cell
now lives in `data-raw/`; routine tests stay at no more than five response
columns and 30 units. Boundary/combination tests cover coefficient variances
0.01 and 100, correlations 0 and plus/minus 0.8, one missing response, a 4:1
rare C3/C4 pathway, full-covariance recovery, grand-mean recovery, and
estimated source strength near 0 and 0.8.

## 7a. Issue Ledger

GitHub issue #1212 was inspected. This kernel slice advances its
response-column source-strength design but does not close it because the
spatial and wider-grid questions remain. No issue was closed or created; the
landing PR will be linked to #1212 without a closing keyword.

## 8. Consistency Audit

Exact scans:

```sh
rg -n "kernel_coef|spatial_coef|kernel.*planned|animal.*deferred|kernel.*deferred|three public|four public" README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design R vignettes _pkgdown.yml man
rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" NEWS.md R/column-coef-foundation.R docs/design/131-response-column-coefficient-foundation.md docs/design/132-response-column-coefficient-kernel.md vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd
rg -n "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd
rg -n "meta_known_V|gllvmTMB_wide" README.md NEWS.md docs vignettes
rg -n -i "kernel(_coef)?[^\\n]{0,80}(planned|fenced|unavailable|not exported)|(?:planned|fenced|unavailable|not exported)[^\\n]{0,80}kernel(_coef)?" R man NEWS.md vignettes/articles docs/design
rg -n -i "deprecat[^\\n]{0,80}(_slope|slope\\()|(_slope|slope\\()[^\\n]{0,80}deprecat" R man NEWS.md vignettes/articles docs/design
rg -n "gllvmTMB\\(" R/column-coef-foundation.R vignettes/articles/api-keyword-grid.Rmd vignettes/articles/where-does-the-tree-go.Rmd
```

Verdict: current surfaces agree that IID, phylogenetic, animal, and dense-kernel
Gaussian coefficient models are public, while spatial, intervals,
non-Gaussian regimes, simultaneous sources, and broad calibration remain
deferred. `vcv.phylo()` was the only deprecated-alias regex false positive in
the two touched articles. `meta_known_V()` and `gllvmTMB_wide()` matches are
intentional compatibility/history records, not new teaching syntax. Designs
55/56 contain superseded slope-deprecation proposals; current Designs 01,
130--132, NEWS, tests, and articles state that every `*_slope()` helper remains
current, warning-free, and non-deprecated. All touched long calls pass
`trait =`; wide calls use `traits(...)` and no custom trait argument.

**Roadmap tick**: N/A. No `ROADMAP.md` row changed; capability status is in
Design 01 and validation-debt row FG-20.

## 9. What Did Not Go Smoothly

The first full article build exposed an unrelated cross-family LV article
failure after rendering the edited API grid. The first individual worked-
article render used an older installed package; rendering against current
source fixed the environment mismatch. Critical review then found that the API
grid's initial wide `traits(...) ~ 1 + kernel_coef(1 + ...)` example duplicated
response-specific fixed/random intercept spaces. It now teaches the valid
biological model: C3/C4 grand intercepts and slopes with response-column random
intercept/slope deviations. Curie also forced the large recovery cell out of
routine checks and exposed missing covariance/edge evidence. No engine repair
was required after the mathematical review.

## 11. Team Learning

**Ada** kept animal, kernel, and spatial serial and protected the umbrella
lease. **Gauss/Noether** independently verified the covariance-scale mixture,
spectral precision/log determinant, maps, raw-`K` endpoint, and unchanged C++
engine. **Curie** rejected the first evidence bundle, required CRAN-safe routine
fixtures and Gaussian edge cells, and returned PASS after the optional/routine
split. **Boole/Rose** found the invalid wide fixed/random-intercept overlap and
three stale deferred-capability surfaces, then returned terminal PASS after
the help/article cascade. **Pat/Darwin**'s reader model is now the requested
C3/C4 grand means/slopes plus plant-specific deviations. **Grace** still owns
the full package, three-OS, exact-main, and deployed-site gates.

## 10. Known Residuals

This is Gaussian native-Laplace point estimation for one dense covariance and
bare numeric coefficient predictors. It does not claim intervals,
non-Gaussian or mixed families, sparse/precision kernel input, simultaneous
coefficient sources, transformed/factor coefficient bases, latent coefficient
covariance, estimated animal strength, spatial coefficients, or broad
calibration. The optional recovery cells are deterministic bounded evidence,
not a coverage campaign.

## 12. Cross-Product Coverage

Covered: long and `traits(...)` wide input; intercept-only, slope-only, and
intercept-plus-slope bases; `|` and `||`; fixed `rho = 0`, interior values, and
`rho = 1`; estimated `rho` in ordinary, near-zero, and high-signal cells;
label-order permutations; raw non-unit diagonal scale; full and diagonal
coefficient covariance; one missing response; a rare fixed pathway; variance
and coefficient-correlation edges; exact released slope endpoints; Gaussian
point estimation. This arc does NOT cover sparse/precision `K`, non-Gaussian or mixed
families, interval calibration, broad repeated-seed recovery, transformed or
factor coefficient bases, simultaneous coefficient sources, latent
coefficient covariance, estimated animal strength, or spatial coefficients.

## 13. Next Actions

Create one CI-paced protected PR; require routine plus manual
Ubuntu/macOS/Windows success at the exact reviewed head; merge normally;
verify exact-main R-CMD-check and pkgdown/live pages; release the kernel lease;
then start a fresh spatial lane from that exact main. The umbrella
`codex:structured-column-coef-family` lease remains held until spatial and the
final cross-series audit are green.
