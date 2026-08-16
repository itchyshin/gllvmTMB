# After Task: G2d deterministic implementation-contract phase

**Branch**: `codex/isdm-g2d-six-species`
**Date**: `2026-08-11`
**Roles (engaged)**: Ada, Gauss, Noether, Rose

## 1. Goal

Strengthen the private G2d six-species implementation evidence without fitting:
prove the analytic source kernels and support gate, rank-one loading/Psi
packing contract, and ordinary-fixture GBIF/first-visit pairing rule before a
separate fit-gate decision.

## 2. Implemented

Added no-fit analytic tests for the Poisson-log and Bernoulli-cloglog kernels,
known support, and GBIF-only bias. Added a six-trait rank-one loading/Psi test
using the package's rank-one loading packer, including a one-coordinate Psi
perturbation. Added a private exact GBIF/first-visit pairing validator and
made its scenario routing explicit: ordinary fixtures require exact pairs;
disconnected and weak-overlap attacks retain their deliberately non-paired
support.

Mathematical contract: for species \(s\) and cell \(c\),
\(\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs}\),
\(\Sigma_B=\Lambda\Lambda^\top+\operatorname{diag}\{\exp(2\theta_{\rm diag,B})\}\),
GBIF uses Poisson/log with known support and GBIF-only bias, and PA uses
Bernoulli/cloglog with the same ecological state. No public API, likelihood,
family, formula grammar, public documentation, or compiled source changed.

## 4. Files Touched

- `R/isdm-contract.R` — private pairing validator and scenario-routing helper.
- `dev/isdm-package-recovery/run-g2d-six-species-recovery.R` — applies exact
  pairing only to the ordinary fixture.
- `tests/testthat/test-isdm-developer-fit.R` — deterministic kernel, covariance,
  source-gate, and six-trait pairing tests.
- This after-task report and `docs/dev-log/check-log.md`.
- Untouched: `src/`, public API/docs, README, NEWS, ROADMAP, vignettes, Rd,
  empirical data, Totoro, campaign fixtures, and Issue #953.

## 3a. Decisions and Rejected Alternatives

- **Decision**: keep attacks non-paired. **Rationale**: disconnected support is
  a predeclared adversary, not an ordinary-fixture error. **Rejected**: apply
  the exact-pair validator to every scenario. **Confidence**: high.
- **Decision**: stop before TMB-map execution. **Rationale**: the approved plan
  reserved every new fit for a separate gate. **Rejected**: treat no-fit
  algebra as proof of the retained six-coordinate fitted map. **Confidence**: high.

## 5. Checks Run

```sh
Rscript --vanilla -e '<parse test; source pure helpers; exercise rank-one pack,
ordinary pairing, rejected unmatched pairing, and attack routing>'
# PASS: G2D_PURE_CONTRACT_PASS; no optimiser or fit.

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2d-six-species-harness.R", reporter = "summary")'
# PASS: all no-fit ordinary/disconnected/weak-overlap fixture checks.

git diff --check
# PASS.
```

The full `test-isdm-developer-fit.R` file was deliberately not run because its
pre-existing tests fit models. No smoke, Totoro, campaign, empirical,
comparator, survey-count outcome, spatial, source-admission, public-doc/API, or Issue #953
operation ran.

## 6. Tests of the Tests

The new oracle is a failure-before-fix boundary for source leakage: changing
GBIF bias cannot change survey likelihood. The pairing test includes missing
first-visit and missing-pair rejection. The rank-one test perturbs one free
diagonal coordinate and confirms that no other Psi entry changes.

## 8. Consistency Audit

```sh
rg -n 'isdm_assert_gbif_first_visit_pairs|isdm_requires_exact_first_visit_pairing|G2D_SMOKE_(PASS|HOLD)' \
  R/isdm-contract.R dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  tests/testthat/test-isdm-developer-fit.R tests/testthat/test-g2d-six-species-harness.R
```

Verdict: ordinary pairing is explicit and attack routing remains intact; no
test reopens the held smoke or admits remote compute.

### Roadmap Tick

N/A: this is private developer validation, not a public roadmap capability.

## 7a. Issue Ledger

No relevant open issue; no new issue created. Issue #953 remains explicitly
out of scope and was not inspected or updated.

## 9. What Did Not Go Smoothly

The first pairing implementation applied exact overlap to the disconnected
attack and made no-fit validation fail. Independent review identified the
scenario mismatch; the revised routing makes ordinary pairing explicit without
weakening the attack fixture.

The independent method/claim-fence review also found that the phrase "excludes
count data" was ambiguous because GBIF is intentionally a Poisson count
component. The private protocol and this report now say "survey-count
branch/outcomes"; the model and its evidence did not change.

## 10. Known Residuals

No actual six-coordinate `theta_diag_B` TMB-map/extractor alignment has been
exercised under the revised contract. The retained G2d smoke remains
`G2D_SMOKE_HOLD`, and no recovery, Totoro admission, campaign, or Paper-2
numerical claim is earned. A new fit requires explicit approval.

## 11. Team Learning

**Gauss/Noether** required the rank-one test to use the package packing helper
and caught the attack-routing overreach. **Rose** preserved the distinction
between deterministic contract evidence and a fitted admission result.

## 12. Cross-Product Coverage

This phase does NOT cover fitted TMB-map/extractor identity, profile success,
eligibility, recovery, a 30-fixture campaign, Totoro, empirical data, survey-count outcomes,
comparators, spatial/two-bias-field work, detection, absolute intensity, public
API/docs, Issue #953, or a Paper-2 claim.
