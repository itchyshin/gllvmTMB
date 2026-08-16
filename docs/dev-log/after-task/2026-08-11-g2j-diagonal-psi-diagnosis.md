# After Task: G2j diagonal-Psi recovery diagnosis

## 1. Goal

Diagnose the held six-species G2i diagonal-Psi recovery result from retained
artifacts only, distinguish information from extraction/numerical/criterion
causes, and provide a bounded campaign specification without launching it.

## 2. Implemented

Fresh branch `codex/isdm-g2j-psi-diagnostic` starts at committed G2i closure
`8c092ba5`. It adds a private reader that binds to the retained seed-86122 G2i
root and proves the diagonal-variance scale, shared covariance scale, profile
structure, and local component-information predicates. It wrote one ignored
no-fit audit root: `dev/isdm-package-recovery/results/g2j-retained-psi-audit-20260811-002`.

The verdict is `COMPONENT_INFORMATION_LIMITED_NOT_EXTRACTION_MISMATCH`.

## 3a. Decisions and Rejected Alternatives

The extractor and scale hypotheses are rejected: the audit proves
\(\widehat\Psi_{ss}=\widehat{sd}_{B,s}^2=\exp(2\widehat\theta_{\rm diag,s})\)
and \(\widehat\Sigma_B^{\rm shared}=\widehat\Lambda\widehat\Lambda^\mathsf T\).
It does not confuse the latter with the full covariance.

The retained evidence meets all executable component-information predicates:
held Psi error `0.2156398 > 0.20`; three of six lower profiles have
\(\Delta\)NLL below 2; and maximum local loading--diagonal correlation is
`0.415` above `0.25`. The numerical gradient is a separate admission hold,
not proof of a Psi bug. The `0.20` threshold is not relaxed: one seed cannot
show that it is inappropriate.

The only recommendation is a separately approved 150-seed calibration
campaign under the unchanged fixture/estimator, after its own runner and local
pre-run gates.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2j-psi-diagnostic.R` and its targeted test.
- G2j protocol, certificate, and G2k non-executing campaign specification.
- This report, reconciliation, and check-log entry.

No public API/docs, likelihood, formula grammar, DGP, threshold, fixture,
empirical data, spatial/detection/count/comparator/zero-inflation work,
Totoro, DRAC, or Issue #953 changed.

## 5. Checks Run

```sh
Rscript --vanilla -e '<static no-fit contract assertions>'
# PASS.
Rscript --vanilla dev/isdm-package-recovery/run-g2j-psi-diagnostic.R --mode=validate
# PASS: no fit.
Rscript --vanilla dev/isdm-package-recovery/run-g2j-psi-diagnostic.R \
  --mode=audit --output=dev/isdm-package-recovery/results/g2j-retained-psi-audit-20260811-002
# PASS: G2J_RETAINED_PSI_DIAGNOSTIC_COMPLETE.
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2j-psi-diagnostic.R", reporter="summary")'
# PASS: 7 expectations.
```

Independent method review first held a hard-coded classification. The reader
was repaired, rerun in fresh root `-002`, and independently re-reviewed PASS.

## 6. Tests of the Tests

The test rejects fitter/objective/package-load tokens in the audit reader and
requires all three verdict predicates. The reader verifies G2i provenance
closure before it reports any metric.

## 7a. Issue Ledger

Issue #953 was untouched. The relevant internal ledger item is the G2i
pre-run HOLD, retained without relabeling.

## 8. Consistency Audit

G2c remains `G2C_SMOKE_ADMISSION_HOLD`; G2h remains `G2H_SMOKE_HOLD`. G2j is
a diagnosis only. The proposed campaign is explicitly not authorized and makes
no Paper 2 or public capability claim.

## 9. What Did Not Go Smoothly

The first reader compared matrices with differing dimname attributes and
hard-coded its conclusion. The equality check is now value-based, and the
verdict requires retained evidence predicates. No fit was triggered.

## 10. Known Residuals

The diagnosis cannot separate finite-sample component-allocation bias from a
rare one-seed realization, nor validate a revised threshold. A campaign is
needed for frequency, not a retry.

## 11. Team Learning

The independent reviewer caught that a plausible conclusion is not enough:
the audit must operationalize the evidence that selects it. Shared versus total
covariance remains a critical iJSDM recovery check.

## 12. Cross-Product Coverage

G2j covers one retained private six-species covariance decomposition audit and
a non-executing 150-core campaign proposal. It **does NOT cover** campaign
execution, changed sample geometry/species number, spatial fields, detection
parameters, count surveys, additional sources, empirical data, public API/docs,
or a Paper 2 efficacy claim.
