# After Task: G2d retained diagnostic map audit

**Branch**: `codex/isdm-g2d-six-species`
**Date**: `2026-08-11`
**Roles (engaged)**: Ada, Gauss, Noether, Rose

## 1. Goal

Prove or falsify actual six-species private G2d TMB-map and covariance-extractor identity on one expressly approved ordinary three-visit fit, without a smoke, profile, retry, campaign, or remote compute.

## 2. Implemented

Added a private `diagnostic` mode which runs exactly one ordinary three-visit fit (`86101`, `n_init = 1`, no profile) and retains a map/Sigma audit. It verifies six packed rank-one `theta_rr_B` coordinates, six free finite `theta_diag_B` coordinates, `theta_rr_B -> Lambda_B`, `theta_diag_B -> exp(theta_diag_B) -> sd_B`, and:
\[
\Sigma_{shared}=\Lambda\Lambda^\top,\quad\Psi=\operatorname{diag}(sd_B^2),\quad\Sigma_{total}=\Lambda\Lambda^\top+\Psi.
\]

The single fit returned `G2D_DIAGNOSTIC_MAP_HOLD` only because labelled extractor matrices were compared with unnamed reconstructions. The immutable original root was not changed. Two fresh, manifest-verified, no-fit audit roots re-read that exact fit object; after independent review required the raw diagonal link, the final audit passed all 12 checks.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2d-six-species-recovery.R`
- `dev/isdm-package-recovery/2026-08-10-g2d-six-species-protocol.md`
- `tests/testthat/test-g2d-six-species-harness.R`
- This report, reconciliation, and `docs/dev-log/check-log.md`.

Untouched: `src/`, public API/docs, empirical data, survey-count outcomes, comparators, spatial/two-bias work, detection, absolute intensity, Totoro, campaign roots, and Issue #953.

## 3a. Decisions and Rejected Alternatives

- Preserve the original HOLD and re-audit its manifest-verified fit object; do not rerun or overwrite it.
- Compare covariance matrices numerically after dimension checking, and independently test the raw diagonal transform; do not rely on `sd_B` alone.

## 5. Checks Run

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2d-six-species-harness.R", reporter = "summary")'
# PASS: targeted no-fit harness.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R --mode=diagnostic ...
# One fit only: G2D_DIAGNOSTIC_MAP_HOLD; elapsed_s=3.027995.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R --mode=diagnostic_audit ...
# PASS: G2D_DIAGNOSTIC_AUDIT_PASS; no optimiser or fit.

git diff --check
# PASS.
```

No profile, smoke, retry, recovery calculation, campaign, Totoro, empirical, public-surface, or Issue #953 action ran.

## 6. Tests of the Tests

The initial false HOLD demonstrates that the checker can fail. The corrected audit preserves dimension checks and directly verifies `theta_diag_B -> exp() -> sd_B`; the independent reviewer re-hashed both manifests and required that raw-parameter assertion.

## 8. Consistency Audit

```sh
rg -n 'G2D_DIAGNOSTIC_(MAP|AUDIT)_(PASS|HOLD)|theta_diag_matches_report|single-fit-tmb-map-extractor-diagnostic' dev/isdm-package-recovery/run-g2d-six-species-recovery.R dev/isdm-package-recovery/2026-08-10-g2d-six-species-protocol.md tests/testthat/test-g2d-six-species-harness.R
```

Verdict: the only fit is named diagnostic; audit roots preserve input/provenance; no route grants smoke or campaign admission.

### Roadmap Tick

N/A: private developer evidence only.

## 7a. Issue Ledger

No issue created or updated. Issue #953 was not inspected or modified.

## 9. What Did Not Go Smoothly

The initial checker treated extractor labels as numerical mismatch. Independent review then correctly found the raw diagonal link missing. Both checker defects were repaired without rerunning the fit.

## 10. Known Residuals

This establishes assembly identity only. It does not overturn `G2D_SMOKE_HOLD`, establish numerical eligibility, profile curvature, recovery, campaign performance, Totoro admission, empirical validity, or a Paper-2 efficacy claim.

## 11. Team Learning

**Gauss/Noether** required every covariance link to begin with a raw TMB parameter. **Rose** required manifest-bound re-audits instead of a silent retry.

## 12. Cross-Product Coverage

Covered: private six-species mixed Poisson/cloglog map assembly, rank-one `Lambda`, six free diagonal `Psi` coordinates, and numerical `extract_Sigma` decomposition on one retained fit. This does NOT cover smoke/recovery, comparators, spatial/two-bias work, detection, absolute intensity, empirical data, public API/docs, Totoro, campaigns, Issue #953, or Paper-2 numerical claims.
