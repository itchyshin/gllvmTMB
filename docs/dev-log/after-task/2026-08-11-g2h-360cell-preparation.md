# After Task: G2h 360-cell covariance-information preparation

## 1. Goal

Prepare, without fitting, the 360-cell private redesign and return for approval before any smoke.

## 2. Implemented

G2h freezes a seed-86121, 360-cell, six-species, three-visit fixture, source gate, information oracle, hashed no-fit preflight, protocol, and decision record.

## 3a. Decisions and Rejected Alternatives

Only sample geometry and the balanced GBIF bias covariate changed. The six-species nonspatial model, rank-one Lambda, free diagonal Psi, GBIF Poisson, three PA-cloglog visits, and source gate did not. No fit, smoke, retry, campaign, or public widening occurred.

## 4. Files Touched

- `dev/isdm-package-recovery/g2h-360cell-fixture.R`
- `dev/isdm-package-recovery/run-g2h-360cell-preflight.R`
- `dev/isdm-package-recovery/2026-08-11-g2h-360cell-{protocol,decision}.md`
- this report and reconciliation.

## 5. Checks Run

The no-fit validator and preflight receipt/readback passed. The conditional gamma-information vector was `228.31, 157.11, 171.53, 158.35, 177.23, 171.16`; all entries exceed 130 and `cor(x,b)` is effectively zero.

## 6. Tests of the Tests

Validation asserts 360 cells, six species, three visits, full `(1,x,b)` rank, all information floors, and finite GBIF/NA survey `B` values.

## 7a. Issue Ledger

No issue was changed; Issue #953 is out of scope.

## 8. Consistency Audit

G2c, G2d, G2e, G2f, and G2g remain immutable evidence. Independent method review PASS confirms no fitting capability in G2h.

## 9. What Did Not Go Smoothly

Nothing material; the first frozen fixture satisfies each geometry condition without a seed search.

## 10. Known Residuals

This is a DGP design hypothesis, not recovery evidence. No local redesigned smoke is authorized.

## 11. Team Learning

Residualising the bias draw on ecology makes the contrast guarantee explicit rather than relying on a lucky random correlation.

## 12. Cross-Product Coverage

G2h covers only private no-fit preparation of the 360-cell nonspatial iJSDM redesign. It does NOT cover a fit, smoke, recovery, campaign, detection, spatial fields, counts, empirical data, public APIs, or comparators.
