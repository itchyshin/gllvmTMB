# After Task: G2e observation-support diagnostic

**Branch**: `codex/isdm-g2e-information-diagnostic`
**Date**: `2026-08-11`
**Roles (engaged)**: Ada, Noether, Rose

## 1. Goal

Privately test whether doubling only GBIF and PA support changes the held G2d
information pattern, without a recovery campaign or public capability claim.

## 2. Implemented

G2e adds a support-only fixture, no-fit preflight, dormant smoke launcher,
private protocol/decision records, and tests. The sole completed smoke is
classified `PROFILE_LIMITED`.

## 3a. Decisions and Rejected Alternatives

G2e is a separate DGP, rather than an amended G2d run, because G2d's frozen
design changed only species dimension. More species, new visits, spatial terms,
zero inflation, and campaign scaling were rejected as confounding extensions.

## 4. Files Touched

- `dev/isdm-package-recovery/g2e-support-fixture.R`
- `dev/isdm-package-recovery/run-g2e-information-diagnostic.R`
- `dev/isdm-package-recovery/run-g2e-information-smoke.R`
- `dev/isdm-package-recovery/2026-08-11-g2e-*.md`
- `tests/testthat/test-g2e-information-diagnostic.R`
- this report and the paired plan-actual reconciliation.

No public API, Rd, README, NEWS, ROADMAP, vignette, pkgdown, likelihood, or
formula grammar file changed.

## 5. Checks Run

- G2e fixture and smoke-launcher `--mode=validate`: PASS, no fit.
- `devtools::test(filter = "g2e-information-diagnostic")`: PASS.
- Final no-fit preflight receipt/read-back: PASS.
- Replacement-root manifest, stages, classification, and retained profiles:
  `G2E_REPLACEMENT_AUDIT_PASS`.

## 6. Tests of the Tests

The tests assert exact 2x supports, the GBIF-only `B` gate, one/three-visit
pairing, finite analytic oracle values, no-fit launcher validation, and
serialized preflight provenance. Noether's review additionally caught the
previous non-exhaustive decision partition and invalid-profile closure risk.

## 7a. Issue Ledger

No relevant open issue was available to inspect because GitHub access was
offline; no issue was created or changed. Issue #953 was explicitly out of
scope.

## 8. Consistency Audit

`rg -n 'G2C_SMOKE_ADMISSION_HOLD|G2D_SMOKE_HOLD|Totoro|DRAC|Issue #953'
dev/isdm-package-recovery docs/dev-log` found only the intended fences.
Verdict: G2c/G2d holds and the no-campaign boundary remain explicit.

## 9. What Did Not Go Smoothly

The first root was retained incomplete after the local tool session returned
before profile closure. The replacement smoke was explicitly authorized, then
completed. The incomplete root is excluded from interpretation.

## 10. Known Residuals

`PROFILE_LIMITED` means stronger support improved the GBIF-bias error but did
not meet the lower-profile response rule. It is one-fixture local evidence, not
recovery evidence and not authority for a campaign. A future within-cell
PA-replication design is a separate decision.

## 11. Team Learning

Ada kept G2d frozen and retained the failed root rather than overwrite it.
Noether required exhaustive classifications and prevented failed profiles from
being mistaken for a result. Rose's provenance standard made the final manifest
and the incomplete-root distinction load-bearing.

## 12. Cross-Product Coverage

Not applicable: the private fixture has no public cross-product surface. The
covered combinations are GBIF Poisson and three PA-cloglog events with the
GBIF-only bias gate and support multiplier. It does NOT cover spatial fields,
detection estimation, count-survey outcomes, arbitrary sources, structural-zero
models, empirical inference, public APIs, or any recovery campaign provider.
