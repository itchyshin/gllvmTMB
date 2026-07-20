# After task — R2 mathematical closure

**Branch:** `codex/va-r2-math-closure-20260720`
**Status:** complete and admitted for internal R3 work

## 1. Goal

Close the mathematical receipt gap in the internal q=1/q=2 AGHQ reference
harness before any VA prototype or compute campaign begins.

## 2. Implemented

- Preserved every generated response fixture while rewriting its stored truth
  in the fitted convention `u_i ~ N(0, I)`: the former score scales are now
  absorbed into the effective `Lambda_B`, and `Sigma_B` is computed from that
  effective loading matrix.
- Normalized adaptive-GHQ masses on the log scale and computed each unit's
  posterior mean and population covariance at every declared node order.
- Added `posterior_moments.csv` to the local-only receipt with coordinate and
  source provenance in `manifest.csv`.
- Added independent weighted-node moment checks, covariance symmetry/PSD
  checks, normalization checks, fitted-coordinate truth checks, and receipt
  schema checks.
- Amended Design 85 with a Gaussian exactness anchor, a rank-zero ML candidate
  and not-applicable stop, and frozen practical-advantage plus predictive-loss
  margins for q=4/6.

## 3. Decisions and rejected alternatives

The fixture data were retained byte-identically. Re-simulating them would have
changed the numerical reference and hidden the receipt error. The correction
instead uses the identity `Lambda_effective = Lambda_generating D` when the
historical generator drew `D u`, `u ~ N(0, I)`.

Posterior moments are population moments of the normalized quadrature mass, so
no finite-sample covariance correction is applied. q>=3 tensor quadrature,
public method syntax, ELBO-as-likelihood language, and non-Gaussian REML remain
rejected.

## 4. Files touched

- `tests/testthat/helper-aghq-o3.R`
- `tests/testthat/test-aghq-r2-reference-harness.R`
- `docs/design/85-highdim-nongaussian-va-formal-contract.md`
- `docs/dev-log/audits/2026-07-20-va-r2-mathematical-closure-gate.md`
- `docs/dev-log/after-task/2026-07-20-va-r2-mathematical-closure.md`

No package API, C++, README, NEWS, vignette, roxygen/Rd, pkgdown navigation,
validation-register row, or parked-lane file changed.

## 5. Checks run

- `NOT_CRAN=true devtools::test(filter = "aghq-r2-reference-harness",
  stop_on_failure = TRUE)` — PASS (1,438 expectations reported by testthat).
- Fresh local receipt — seven ordinary fixtures `pass`; the declared condition
  guard is `condition_exceeds_limit`; 2,880 finite posterior-moment rows;
  maximum normalized-weight error `4.0e-15`.
- `git diff --check` — PASS.
- Vignette-complete source tarball followed by `R CMD check --as-cran
  --no-manual` with CRAN-default optional-test routing — PASS with one NOTE
  (`New submission`) and no ERROR or WARNING.
- A diagnostic `NOT_CRAN=true` source check intentionally ran the developer
  visual tests and reproduced only the two pre-existing vdiffr snapshot
  differences; it is not the admission receipt.
- Full-matrix workflow run `29748324495` at exact closure commit `c70538a2` —
  PASS on Windows, macOS, and Ubuntu. PR #776 merged as `0ae825fe`.

## 6. Tests of the tests

The independent moment test reconstructs adaptive nodes, log masses, normalized
weights, means, and covariances outside the production helper and compares them
to the helper result. Fixture tests verify both linear-predictor equality under
the old and standardized parameterizations and `Sigma_B = Lambda_B Lambda_B^T`.
The pre-existing q>=3 mutation and pre-quadrature condition rejection remain.

## 7. Roadmap tick

None. This is an internal mathematical receipt and does not advertise or ship
a method.

## 8. Consistency audit

Noether identified the receipt mismatch and the missing posterior moments.
Rose's public-claim boundary remains unchanged. Final admission requires the
source check and fresh three-OS receipt recorded in the companion audit.

## 9. What did not go smoothly

The original R2 PR was merged before the fresh Noether review returned. The
review then found the truth-coordinate mismatch and missing Gate-2 output.
This change fixes forward immediately; R3 remained paused and no VA or public
claim was built on the incomplete receipt.

## 10. Known residuals

This closure does not implement or validate a VA. Design 85 Gates 0–2 still
need an internal VA prototype, including the Gaussian exactness anchor and
VA-versus-O3 posterior-moment comparisons. R3 remains stopped until this
closure branch is admitted.

## 11. Team learning

**Noether:** a stable objective identity does not validate the truth labels or
the posterior reference needed by the next estimator. Review the DGP coordinate
map and downstream comparison quantities before merge.

**Rose:** a merged research harness can be repaired without claim damage when
the next gate remains closed and the correction is made before any dependent
implementation.

## 12. Cross-product coverage

This receipt covers only fixed-coordinate q=1/q=2 ordinary multi-trial
binomial-logit AGHQ reference algebra. It does not cover q>=3 tensor AGHQ, VA
optimization, high-dimensional recovery, predictive calibration, intervals,
coverage, structured covariance, missing data, mixed families, non-Gaussian
REML, a public API, or release readiness.
