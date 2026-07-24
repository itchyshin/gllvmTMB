# After Task: Design 92 private VA foundation

## 1. Goal

Implement and test an independent, private Bernoulli-logit mean-field Gaussian
VA baseline before attempting any EVA objective or gllvmTMB integration.

## 2. Implemented

`dev/design92-va-foundation/va-q1.R` now contains fixed-global-parameter VA
ELBOs and analytic gradients for q=1 and diagonal q=2 variational families.
The q=2 implementation uses the univariate normal distribution of each linear
predictor, so it requires only deterministic one-dimensional quadrature.
`d92_bernoulli_derivatives()` supplies a tested first-to-fourth derivative
kernel for a later EVA derivation; it is not an EVA objective.

### Mathematical Contract

The ELBO is the Bernoulli-logit expected log likelihood minus the exact
Gaussian-prior KL for `q_i = N(m_i, diag(s_i^2))`.  Trait intercepts and
loadings are fixed; only variational means and log standard deviations are
optimized.  No public API, formula grammar, family, TMB template, or C++ file
changed.

## 3. Files Changed

- `docs/design/92-va-first-foundation.md` — private scope, equations, and
  admission checks.
- `dev/design92-va-foundation/va-q1.R` — q=1/q=2 VA prototype, integration
  oracles, gradients, and derivative kernel.
- `dev/design92-va-foundation/run-tests.R` — deterministic test suite.
- This report and the check-log entry.

No README, NEWS, ROADMAP, vignette, Rd, pkgdown, validation-debt, package R,
or `src/gllvmTMB.cpp` file changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: implement fixed-parameter VA before any joint model fit.
  **Rationale**: it isolates ELBO and gradient correctness from loading
  identification and separation.  **Rejected alternative**: immediate TMB or
  package-engine work would make a disagreement non-diagnosable.
  **Confidence**: high.
- **Decision**: include q=2 in the baseline.  **Rationale**: q=1 cannot test
  a mean-field covariance restriction.  **Rejected alternative**: a q=1-only
  success would be too weak to support later rank-two work.  **Confidence**:
  high.
- **Decision**: retain only an EVA derivative kernel.  **Rationale**: a valid
  EVA objective needs separately specified expansion and oracle details.
  **Rejected alternative**: guessing an extended approximation from a passing
  VA test would be mathematically unsafe.  **Confidence**: high.

## 4. Checks Run

- `Rscript --vanilla dev/design92-va-foundation/run-tests.R` — PASS.
  The suite checks scalar integration, a 30-point softplus expectation grid,
  q=1/q=2 analytic versus central-difference gradients, trait permutation,
  q=1 embedding in q=2, a direct log-marginal ELBO bound, optimizer stationarity,
  and invalid/missing response rejection.
- `git diff --check` — PASS.

## 5. Tests of the Tests

The integration and finite-difference comparisons are independent-oracle
checks.  The invalid binary and missing-cell cases are boundary tests.  The
q=1-in-q=2 embedding and optimizer checks are feature-combination tests.  The
first gradient run exposed an incorrect residual-matrix construction, and the
first marginal-oracle run exposed accidental integration-node aggregation; both
were fixed before this green result.

## 6. Consistency Audit

`rg -n -i 'gllvmTMB|public API|C\+\+|EVA objective|recovery|calibration|parity' docs/design/92-va-first-foundation.md dev/design92-va-foundation`
was reviewed to confirm that all such terms occur only as explicit scope
fences.  The prototype contains no call to `gllvmTMB`, `gllvm`, TMB, or C++.

## 7. Roadmap Tick

N/A — this is private developer research infrastructure, not a package roadmap
change.

## 8. What Did Not Go Smoothly

Two cheap oracle checks found bugs early: a residual matrix was constructed
with an invalid `sweep()`, and the direct marginal integrand summed across
`integrate()`'s vectorized nodes.  Neither reached package code or external
compute.

## 9. Team Learning

Gauss — fixed-global q=2 is the smallest meaningful mean-field test.  Noether
— the entropy and Gaussian-prior constants cancel exactly in the implemented
ELBO.  Fisher — a passing ELBO bound is a necessary algebra check, not recovery
or approximation-accuracy evidence.  Rose — the independent oracles caught
two implementation errors before they could become a larger campaign.

## 10. Known Limitations and Next Actions

The prototype has no covariates, missing data, estimated global parameters,
loading identification, joint optimization, recovery study, source comparison,
EVA objective, TMB implementation, or public interface.  Any EVA objective is
a separate new design requiring its own symbolic contract and oracle; no
package integration is authorized by this result.

## GitHub Issue Ledger

No issue was created or changed.  This is a private design foundation.
