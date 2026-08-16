# After Task: G2f PA-replication pre-fit preparation

**Branch**: `codex/isdm-g2f-pa-replication`
**Date**: `2026-08-11`
**Roles (engaged)**: Ada, Noether

## 1. Goal

Prepare, without a fit, the private six-visit PA-replication diagnostic from
the closed G2e state and return for explicit approval before any local smoke.

## 2. Implemented

G2f freezes the seed-86101 six-species/120-cell DGP, original G2d support
vectors, six conditionally independent PA-cloglog visits sharing one
cell/species state, a conditional-information oracle, predeclared decision
table, no-fit validator, and provenance preflight receipt.

## 3a. Decisions and Rejected Alternatives

The sole changed design dimension is PA replication (three to six visits).
G2e's doubled supports, G2c/G2d outcomes, spatial terms, detection parameters,
empirical data, zero inflation, package surfaces, campaign computation, and
Issue #953 were retained out of scope.

## 4. Files Touched

- `dev/isdm-package-recovery/g2f-pa-replication-fixture.R`
- `dev/isdm-package-recovery/run-g2f-pa-replication.R`
- `dev/isdm-package-recovery/2026-08-11-g2f-pa-replication-{protocol,decision}.md`
- `tests/testthat/test-g2f-pa-replication.R`
- this report and its paired plan-actual reconciliation.

No public API, Rd, README, NEWS, vignette, pkgdown, likelihood, formula grammar,
or Issue #953 changed.

## 5. Checks Run

- `run-g2f-pa-replication.R --mode=validate`: PASS; no fit.
- `devtools::test(filter = "g2f-pa-replication")`: PASS (18 assertions).
- `--mode=preflight` under `results/g2f-preflight-20260811-143000`: PASS; root
  receipt, truth, oracle, and manifest read back successfully; no fit.

## 6. Tests of the Tests

The tests assert exact original supports, source gating, six nested visits,
conditional cloglog Fisher-information doubling, finite invariant GBIF
information, no-fit validation, and a self-contained preflight receipt.

## 7a. Issue Ledger

GitHub PR lookup was unavailable offline. No issue was created or changed; Issue
#953 was expressly excluded.

## 8. Consistency Audit

`G2C_SMOKE_ADMISSION_HOLD`, `G2D_SMOKE_HOLD`, and G2e's `PROFILE_LIMITED`
remain explicit in the protocol. The runner rejects any G2c/G2d/G2e result root.

## 9. What Did Not Go Smoothly

Independent review initially held the pre-fit lane because the written decision
table, Fisher oracle, and seed/support provenance were incomplete. All three
were added before the final no-fit validation.

## 10. Known Residuals

The conditional oracle does not establish marginal profile improvement or
recovery. No G2f fit, profile, smoke, campaign, or Totoro/DRAC job has run.

## 11. Team Learning

Noether's review separated doubled observation opportunity from a defensible
conditional-information statement and prevented a post-hoc smoke verdict.

## 12. Cross-Product Coverage

This private pre-fit contract covers only the original nonspatial GBIF Poisson
plus six shared-state PA-cloglog observations and a GBIF-only bias gate. It does NOT cover detection estimation, spatial fields, counts, arbitrary sources,
structural zeros, empirical inference, a public interface, or recovery.
