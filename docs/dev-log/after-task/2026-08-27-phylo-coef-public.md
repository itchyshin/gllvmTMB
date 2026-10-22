# After Task: Public response-column coefficients

**Branch:** `codex/phylo-coef-public`
**Date:** 2026-08-27
**Roles engaged:** Ada, Gauss, Noether, Grace, Rose, Pat, Darwin, Curie, Fisher

## 1. Goal

Finish the smallest honest public response-column coefficient family: Gaussian
point-model `column_coef()` and `phylo_coef()` for long and `traits(...)` wide
data, with fixed or estimated phylogenetic correlation strength, while keeping
all released `*_slope()` helpers current, warning-free, and non-deprecated.

## 2. Implemented

- Exported `column_coef()` and `phylo_coef()` through `gllvmTMB()` with strict
  argument matching and typed source/identifiability failures.
- Added the AD-safe spectral estimated-`rho` engine for
  `K_rho = rho K + (1-rho) diag(K)` and coefficient-specific
  `extract_Sigma(level = "column_coef")` output.
- Preserved exact IID and no-intercept `rho = 1` equivalence to released slope
  routes under `|` and `||`, including the disclosed dense-VCV endpoint seam.
- Added long/wide parity, fixed/estimated objective, gradient, source,
  extraction, and deterministic coefficient-effect recovery tests.
- Rebuilt `where-does-the-tree-go` and the API keyword grid with runnable long
  and wide examples. `phylogenetic-gllvm.Rmd` was inspected and left unchanged
  because it contained no contradiction requiring repair.

## 3. Mathematical Contract

For coefficient basis `z_i` and response column `t`, the additive contribution
is `z_i^T b_t`, with `B ~ MN(0, K_rho, Sigma_coef)`. IID uses `K_rho = I`.
Phylogenetic coefficients use
`K_rho = rho K + (1-rho) diag(K)` on the covariance scale. Estimated rho is
`plogis(eta_rho)` and is evaluated by the standardized-source eigensystem under
automatic differentiation. A diagonal standardized source cannot identify rho
and is rejected.

## 4. Files Touched

Engine and API: `R/column-coef-foundation.R`, `R/gllvmTMB.R`,
`R/fit-multi.R`, `R/extract-sigma.R`, `R/screen-gllvmTMB.R`,
`src/gllvmTMB.cpp`, `NAMESPACE`.

Tests and verification: `tests/testthat/test-column-coef-foundation.R`,
`test-column-coef-engine-iid.R`, `test-column-coef-phylo-fixed-rho.R`,
`test-column-coef-phylo-estimated-rho.R`, `test-column-coef-public-api.R`, and
`dev/phylo-coef-public/`.

Documentation and public examples: `R/column-coef-foundation.R` roxygen,
`R/gllvmTMB.R` and `R/extract-sigma.R` roxygen, generated
`man/column_coef.Rd`, `man/phylo_coef.Rd`, `man/gllvmTMB.Rd`,
`man/extract_Sigma.Rd`, `_pkgdown.yml`, `NEWS.md`,
`vignettes/articles/where-does-the-tree-go.Rmd`, and
`vignettes/articles/api-keyword-grid.Rmd`.

Contracts and closeout: Design 01, Design 131, FG-20 in Design 35, the Ultra
Plan, this report, the plan-vs-actual record, handover, Unlazy ledger, and
`docs/dev-log/check-log.md`.

## 3a. Decisions and Rejected Alternatives

**Decision:** estimate `rho` with a standardized-source eigensystem and an
unconstrained `eta_rho`, rather than differentiating through a dense inverse.
This is algebraically identical to the covariance-scale mixture and keeps the
full transform under AD. Precision interpolation was rejected because it is a
different model.

**Decision:** reject estimated `rho` for a diagonal standardized source. Such a
source has no correlation contrast, so `rho` is unidentified. Silently fitting
or snapping to a boundary was rejected.

**Decision:** keep the exact no-intercept `rho = 1` hard dispatch to released
`phylo_slope()`. This preserves exact lifecycle compatibility; the inherited
dense-VCV `K + 1e-8 I` seam is disclosed rather than hidden.

## 5. Checks Run

- Symbolic, public API, spectral engine, exact slope equivalence, long/wide,
  recovery, focused, and released-slope verifier scripts: all passed.
- Focused public suite: 487 passes, zero failures/warnings/skips.
- Exact slope equivalence suite: 235 passes, zero failures/warnings/skips.
- Released slope regression suite: 222 passes, 17 existing unused-`cluster`
  warnings, two declared heavy skips, zero failures; no lifecycle warning.
- `devtools::document(quiet = TRUE)`: generated the two new topics; only the
  three pre-existing AIC/BIC/anova S3-tag notices appeared.
- Both affected articles built from source and their contract verifier passed.
- Desktop and 390-pixel-width HTML captures were inspected; prose, tables, and
  code remained readable, with horizontal scrolling for long code.
- `pkgdown::check_pkgdown()`: `No problems found`.
- `Rscript --vanilla dev/phylo-coef-public/verify-local-package-candidate.R`:
  passed in about 18 minutes; the installed-package check, including the full
  test suite, had zero errors and warnings.
- `git diff --check`: passed.

Protected landing receipts (terminal exact-main status is updated before this
closeout branch lands):

- Reviewed source head `0cdc8ec90cf9eb89e146eb22039abb5127a75dc9`.
- Routine exact-head run `33135276600`, Ubuntu job `98733730071`: **SUCCESS**.
- Manual exact-head run `33137341941`: macOS job `98740165239`, Windows job
  `98740165303`, and Ubuntu job `98740165342`: **SUCCESS** on all three OSes.
- PR #1220 merged normally without bypass at
  `badb45147f982c2ec34d948c7118261995485576`.
- Exact-main run `33139404505`, Ubuntu job `98746636282`: **SUCCESS** on that
  exact merge SHA (2026-08-28T03:36:53Z--04:16:39Z).

## 6. Tests of the Tests

The public marker tests were RED before export. Estimated-rho tests independently
compare spectral precision, determinant, objective, and AD gradients with
direct covariance or finite-difference oracles. Negative controls cover unknown
and duplicate arguments, both/neither source, malformed sources, non-Gaussian
fits, deferred source helpers, and diagonal-source non-identifiability. The
deterministic recovery DGP whitens the coefficient draw so its generalized
covariance is exact, then checks `rho`, `Sigma_coef`, coefficient correlation,
RMSE, convergence, and optimum gradient.

## 8. Consistency Audit

`rg -n "There is no .*column_coef|internal-only.*column_coef"` over public and
design surfaces found no stale denial. `rg -n -i
"deprecat.*(_slope|slope\\()|(_slope|slope\\().*deprecat"` found no new slope
lifecycle claim. Explicit scans confirmed animal/kernel/spatial coefficient
helpers remain fenced and the coefficient family remains outside the 5 x 3
covariance-keyword grid.

## 7. Roadmap Tick

N/A. The durable capability row is FG-20; no separate ROADMAP row governed this
slice.

## 7a. Issue Ledger

Issue #1212 was inspected. This work advances its response-column IID/phylo
portion but does not close its broader animal/kernel/spatial structured-source
design. The PR will link the issue and leave it open.

## 9. What Did Not Go Smoothly

Early broad test and check runs were stopped when later review repairs changed
the candidate bytes; they are not counted. Review found fail-open marker
argument matching, the missing diagonal-source identifiability guard, stale
generated Rd, a conditioned rather than raw tree covariance in the article
DGP, and incomplete endpoint/source wording. Each was repaired before the
single final package check. A first article verifier used a broad `t(chol(A))`
ban that also matched an unrelated valid example; it was narrowed to the
coefficient DGP assignment.

## 11. Team Learning

**Gauss and Noether:** covariance-scale mixing, spectral log determinants, TMB
maps, recovery, and exact endpoint routing now align; terminal review passed.

**Grace:** source, portability, generated docs, dependencies, pkgdown, and
installed-package checks passed; three-OS exact-head CI remains the landing
gate.

**Rose, Pat, and Darwin:** current/future wording, raw-DGP alignment, scope
boundaries, the long/wide reader path, and its biological question and
interpretation passed terminal review.

**Curie and Fisher:** deterministic recovery earns bounded Gaussian point
estimation, not broad calibration or intervals.

## 10. Known Residuals

Only Gaussian point models are covered. Interval inference, non-Gaussian
coefficient models, latent coefficient covariance, broad recovery/calibration,
and animal/kernel/spatial coefficient helpers remain deferred. Exact-head
routine and three-OS checks passed, PR #1220 merged normally, and exact-main
run `33139404505` passed. Lease release and heartbeat deletion are operational
closeout actions. No `*_slope()` deprecation follows from this work.

## 12. Cross-Product Coverage

The covered cross-product is Gaussian point estimation × long/wide input × IID
or phylogenetic response-column source × intercept/slope basis × `|`/`||`, with
fixed and estimated rho for identifiable phylogenetic sources. Implementation,
recovery tests, public help, runnable articles, check-log/FG-20 records,
independent review, and local package gates are complete. The exact-head matrix
normal protected merge, and exact-main success are complete. The lease-release
receipt is recorded immediately after this closeout lands.

This slice **does NOT cover** animal, kernel, or spatial coefficient sources;
non-Gaussian families; interval inference; latent coefficient covariance;
missing-response combinations; REML; penalties; alternative engines; or broad
recovery/calibration. It does not alter observation residual, unit-tier,
aggregation, or existing slope-provider semantics.
