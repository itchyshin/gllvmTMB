# After Task: G2g retained six-species identifiability diagnostic

**Branch**: `codex/isdm-g2g-identifiability-diagnostic`
**Date**: `2026-08-11`
**Roles (engaged)**: Ada, Noether

## 1. Goal

Diagnose the retained G2d--G2f failure mechanism without a new fit, retry, or campaign, then give one evidence-based redesign recommendation.

## 2. Implemented

G2g adds a private artifact reader, symbolic certificate, and frozen decision tree. The authoritative no-fit receipt is `results/g2g-retained-audit-20260811-005/`; it verifies all source manifests, the fitted source gate, rank-one Lambda, free diagonal Psi map, separate shared Sigma/Psi extractors, fixed-design rank, profile ledgers, and local covariance diagnostics.

## 3a. Decisions and Rejected Alternatives

The retained evidence gives `COVARIANCE_INFORMATION_LIMITED` for G2f, with an ancillary `NUMERICAL_THRESHOLD_NOTE`. The raw gradient narrowly misses the smoke gate but its retained raw/scaled stationarity and positive-definite Hessian pass, so it does not explain the non-responsive classification. The one recommendation is a 360-cell sample-geometry redesign with three visits, six species, retained GBIF gate, \(|cor(x,b)|\le0.10\), and per-species conditional GBIF information at least 130. This is a design hypothesis only.

No retry, new fit, campaign, Totoro/DRAC, parameterization change, public surface, empirical data, comparator, zero-inflation, spatial/detection work, or Issue #953 update was authorized or performed.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2g-retained-artifact-audit.R`
- `dev/isdm-package-recovery/2026-08-11-g2g-{identifiability-certificate,diagnostic-decision}.md`
- private ignored audit roots under `dev/isdm-package-recovery/results/`
- this report and paired plan-actual reconciliation.

No public API, Rd, README, NEWS, vignette, pkgdown, formula grammar, or likelihood source changed.

## 5. Checks Run

- G2g reader `--mode=validate`: PASS, no fit.
- G2g reader `--mode=audit`: PASS; three retained-source manifests and the fresh audit manifest verify.
- Direct retained-artifact checks: fixed design 24/24; all source-gate/map flags TRUE; all three shared-Sigma/Psi extractor identities TRUE.
- Independent method review: PASS.

## 6. Tests of the Tests

The reader first failed visibly on G2d's floating-point profile offset. It was repaired with a tolerance-based frozen-offset lookup. It then exposed an incorrect reader assumption that `report$Sigma_B` included diagonal Psi; the final reader verifies its actual shared-component meaning and the separately reported `sd_B` component. No historical artifact was rewritten.

## 7a. Issue Ledger

GitHub lookup showed unrelated open PRs only. No issue was created or changed; Issue #953 was expressly out of scope.

## 8. Consistency Audit

G2c remains `G2C_SMOKE_ADMISSION_HOLD`; G2d remains `G2D_SMOKE_HOLD`; G2e remains `PROFILE_LIMITED`; G2f remains `NONRESPONSIVE / G2F_SMOKE_HOLD`. G2g is a diagnosis only and does not alter those records.

## 9. What Did Not Go Smoothly

The first G2g reader version could not locate one historical lower profile due to floating representation, and its initial full-Sigma expectation contradicted the actual separate-extractor contract. Both were caught by no-fit execution and repaired before the authoritative `-005` receipt.

## 10. Known Residuals

The Hessian correlations are local evidence, not a global identifiability proof. One fixed seed and fixture cannot establish recovery of a redesigned 360-cell design. G2g therefore supplies only a next design hypothesis and no authority to fit it.

## 11. Team Learning

Noether required the numerical gradient HOLD to remain an ancillary admission note, rather than inflating it into a second scientific failure mechanism. The artifact reader made the shared-Sigma versus separate-Psi extraction contract explicit, preventing a subtle but consequential interpretive error.

## 12. Cross-Product Coverage

G2g covers retained private G2d--G2f map/extractor, conditional-information, profile, and numerical evidence for the nonspatial six-species iJSDM. It does NOT cover redesigned recovery, campaigns, detection, spatial fields, count surveys, arbitrary sources, structural zeros, empirical data, public APIs, or package-comparison claims.
