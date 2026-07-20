# After Task: R2 low-dimensional AGHQ reference harness

**Branch**: `codex/aghq-r2-reference-20260719`
**Date**: 2026-07-19
**Roles (engaged)**: Ada / Rose

## 1. Goal

Implement the approved R2 research harness for fixed-coordinate ordinary
multi-trial binomial `latent(..., unique = FALSE)` fits at `q = 1` and `q = 2`.
The result is numerical reference evidence only: it must not fit a VA model,
add an API, calculate tensor AGHQ at `q >= 3`, or make a non-Gaussian REML or
inference claim.

## 2. Implemented

- Extended the existing test-only O3 helper with a fixed-coordinate q=1/q=2
  adaptive-GHQ evaluator, conditional-curvature telemetry, canonical unit and
  within-unit permutation checks, and a pre-quadrature condition rejection.
- Added deterministic baseline, low/high-signal, intercept-shift, and
  near-collinear fixtures. Each ordinary fixture refits ML, then compares its
  held-coordinate one-node reconstruction to that refit's TMB objective.
- Added a caller-directed local receipt writer. It writes the required
  manifest, unit diagnostics, fixture summaries, truth inputs, and rerun
  README only to a supplied directory; no CI artifact or package surface is
  created.
- Added negative tests that reject `q >= 3` both before a fixture can run and
  at the receipt boundary.

## 4. Files Touched

- `tests/testthat/helper-aghq-o3.R` — research-only evaluator, fixture runner,
  curvature guard, and local receipt writer.
- `tests/testthat/test-aghq-r2-reference-harness.R` — R2 identity, receipt,
  and q>=3-fence tests.
- `docs/dev-log/research/2026-07-19-highdim-inference-reference-harness-spec.md`
  — implementation/admission status and receipt boundary.
- `docs/dev-log/after-task/2026-07-19-aghq-r2-reference-harness.md` — this
  report.

No README, NEWS, ROADMAP, generated Rd, NAMESPACE, vignette, pkgdown
configuration, formula grammar, likelihood, family, or C++ file changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain tensor quadrature strictly at q=1/2 and make the
condition threshold a pre-quadrature rejection. **Rationale:** these are the
only low-dimensional fixed-coordinate references allowed by Design 85 and the
R2 contract. **Rejected:** q>=3 grids, a TMB refit, a new method argument, or
an ELBO/REML interpretation. **Confidence:** high; Rose audited both code and
receipt boundaries.

## 5. Checks Run

- `NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(...);
  testthat::test_file("tests/testthat/test-aghq-r2-reference-harness.R",
  reporter = "summary")'` → PASS after final Rose-requested receipt fixes.
- Targeted existing O3 q=1, q=2, and scalar test files → PASS before the
  final R2 closeout.
- A fresh local receipt from `o3_r2_write_receipt(o3_r2_run_default(), ... )`
  → seven ordinary rows `pass`; condition row
  `condition_exceeds_limit` at `kappa = 9259259261`.
- `git diff --check` → PASS.
- `R CMD build .` followed by `R CMD check --as-cran --no-manual
  gllvmTMB_0.5.0.tar.gz` on the final source state → package tests passed;
  final status `1 NOTE` only (the normal new-submission note), with no ERROR
  or WARNING.
- Final `NOT_CRAN=true devtools::test()` completed the non-CRAN suite but
  regenerated two untracked vdiffr `.new.svg` files for the pre-existing
  dispatcher communality/variance-partition visual snapshots. They were not
  accepted or staged. The R2 targeted test and its raw receipt pass; this
  unrelated visual-snapshot drift keeps the broad developer suite from being
  a clean zero-failure gate.

## 6. Tests of the Tests

- The initial implementation used incorrect tensor weights. The explicit
  receipt showed q=2 ladder failures; correcting the tensor-product weights
  made all declared terminal ladders pass. This is the intended failure-before-
  fix test of the numerical identity.
- The condition fixture is an analytic zero-mode case. Its test proves that a
  finite positive Hessian with condition number above `1e8` is rejected before
  calling quadrature, rather than changing a tolerance.
- A deliberately mutated q=3 result is rejected by the receipt writer; a q=3
  fixture request is rejected before fitting.
- The receipt test asserts provenance fields, an explicit condition-diagnostic
  row, and exact held-coordinate input values in `truth.rds`.

## 8. Consistency Audit

- `rg -n 'R2|AGHQ|variational' README.md NEWS.md ROADMAP.md
  docs/dev-log/known-limitations.md docs/design/01-formula-grammar.md
  _pkgdown.yml` → only pre-existing scope statements; no public-surface
  promotion was introduced.
- `git diff --check` → no whitespace errors.
- Rose's read-only audit → PASS after it required and verified the q fence,
  separate row permutation, receipt schema, full-fit gradient norm, and
  condition-fixture manifest parameters.

## 7. Roadmap Tick

**Roadmap tick:** N/A. `ROADMAP.md` is a shared coordination file and its
latent-rank status needs maintainer reconciliation; this internal R2 receipt
does not alter a public roadmap chip.

## 7a. Issue Ledger

Inspected [#705](https://github.com/itchyshin/gllvmTMB/issues/705): it concerns
matrix-free Gaussian REML scalability and is not this fixed-coordinate,
non-Gaussian reference harness. No relevant open issue; no comment, close, or
new issue created.

## 9. What Did Not Go Smoothly

The first generalized evaluator had incorrect tensor weights, and its first
receipt also exposed incomplete q-fence/provenance fields. These were caught
by raw numerical output and Rose's audit before review closure. A redundant
full `devtools::test()` was stopped because it was competing with the stronger
source-package check; targeted post-fix R2 tests remain the direct evidence
for this change.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** kept R2 limited to existing fixed coordinates and converted every
specification output into a checked receipt field. The next numerical harness
should build its receipt schema before the first run.

**Rose:** caught five P1 omissions that a passing identity test alone would
miss: q>=3 receipt ingress, distinct row permutations, condition-fixture
provenance, full-fit gradients, and manifest completeness. Future admission
should inspect raw CSVs, not just test success.

## 10. Known Residuals

R2 is a fixed-coordinate reference only. It gives no VA, high-dimensional,
recovery, predictive-calibration, coverage, non-Gaussian REML, Cox--Reid, or
public-method evidence. R2b's optional q<=2 Totoro screen remains deferred.

The next possible action is **not automatic**: it requires the distinct R3
maintainer authorization to build an internal full-covariance VA prototype.
Until then, retain the Laplace route and this reference receipt only.

## 12. Cross-Product Coverage

This R2 receipt **does NOT cover** q>=3 tensor AGHQ, any VA implementation,
ELBO optimisation, joint refitting, structured covariance, missing data,
additional families, parameter recovery, predictive calibration, interval
coverage, non-Gaussian REML, Cox--Reid, a public API, NEWS/README/pkgdown
promotion, or a release claim. Each requires a separately approved arc.
