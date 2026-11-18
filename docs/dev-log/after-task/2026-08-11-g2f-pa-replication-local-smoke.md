# After Task: G2f six-visit PA-replication local smoke

**Branch**: `codex/isdm-g2f-pa-replication`
**Date**: `2026-08-11`
**Roles (engaged)**: Ada, Noether

## 1. Goal

Execute exactly one private local smoke of the frozen six-visit G2f design and
retain its fit, six profiles, decision ledger, manifest, and failure boundary.

## 2. Implemented

The private wrapper at `128d2d60` fit the six-visit fixture with exactly three
retained initializations and profiled all six `theta_diag_B` coordinates across
the five frozen offsets. Root `g2f-smoke-20260811-001` retains the truth, fit,
profiles, decision, receipt, stage ledger, and checksummed manifest.

## 3a. Decisions and Rejected Alternatives

The one authorized smoke is `G2F_SMOKE_HOLD`, with frozen scientific
classification `NONRESPONSIVE`: the GBIF-bias maximum error is 0.3972994,
which is not below 0.371326, and the profile rule also fails. No retry is
authorized or run. No campaign, Totoro/DRAC, public expansion, detection or
spatial extension, empirical data, comparator, zero-inflation, or Issue #953
work was performed.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2f-pa-replication-smoke.R`
- `tests/testthat/test-g2f-pa-replication.R`
- private ignored root `dev/isdm-package-recovery/results/g2f-smoke-20260811-001/`
- this report and its paired plan-actual reconciliation.

No public API, Rd, README, NEWS, vignette, pkgdown, likelihood, formula grammar,
or Issue #953 file changed.

## 5. Checks Run

- Smoke wrapper `--mode=validate`: PASS, no fit.
- `devtools::test(filter = "g2f-pa-replication")`: PASS.
- One `--mode=smoke` invocation: retained a finite fit, all six valid profiles,
  decision ledger, receipt, and manifest.
- Read-only artifact/ledger/checksum audit: PASS.

## 6. Tests of the Tests

The no-fit tests exercise the immutable six-visit fixture, source gate,
conditional-information oracle, provenance preflight, smoke validation, and
the no-fit closure path for a genuinely unclosed post-fit root. The completed
root was separately checked for exact commit, six profile tables of five rows,
classification, eligibility fields, and manifest checksums.

## 7a. Issue Ledger

GitHub PR lookup was unavailable offline. No issue was created or changed; Issue
#953 was explicitly excluded.

## 8. Consistency Audit

G2c remains `G2C_SMOKE_ADMISSION_HOLD`; G2d remains `G2D_SMOKE_HOLD`; G2e
remains `PROFILE_LIMITED`. The G2f decision labels a valid but non-responsive
diagnostic separately from its gradient-based `G2F_SMOKE_HOLD` admission state.

## 9. What Did Not Go Smoothly

The initial terminal poll arrived before profile closure and lacked the final
line. Inspection of the retained root later established that the original smoke
continued to completion. A reconciliation attempt correctly refused to mutate
the now-complete root. The added no-fit reconciliation path remains tested only
as a future failure placeholder and did not alter this root.

## 10. Known Residuals

All profile tables are valid, but `max_abs_gradient = 0.001056337` exceeds the
smoke completeness threshold of 0.001, so the admission status is HOLD. The
single-fixture classification is not recovery evidence and cannot authorize a
campaign.

## 11. Team Learning

The retained stage ledger prevented a premature failure claim. Separating the
scientific decision table from optimizer eligibility made it possible to state
both facts honestly: the diagnostic is non-responsive, and the smoke does not
clear its numerical-admission gate.

## 12. Cross-Product Coverage

This private smoke covers only a six-species, nonspatial, relative-intensity
GBIF Poisson plus six PA-cloglog-visit diagnostic with a GBIF-only bias gate. It
does NOT cover recovery, a campaign, detection estimation, spatial fields,
counts, arbitrary sources, structural zeros, empirical inference, public APIs,
or package-comparison claims.
