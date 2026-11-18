# After-task — G3 full-vector numerical-admission no-fit design

**Status:** `PRIVATE_DESIGN_GO_PENDING_GATE_B`. G3 specifies a prospective
estimator candidate only. Historical Paper 1 Case D and Paper 2 Case C/Psi
HOLD records are unchanged.

## 1. Goal

Implement the approved G3 steps 1--3: a symbolic full-vector same-objective
candidate contract, adversarial no-fit tests, all-attempt ledger schema, and a
time-estimated smallest-smoke proposal for the two private iSDM families.

## 2. Implemented

`g3-full-vector-polish-contract.R` specifies the bounded Newton grid
\(\theta_0-\alpha H_0^{-1}g_0\), aligned Hessian/bounds/gradient checks,
signature identity, acceptance at the unchanged raw `1e-3` gate, sealed
historical comparators, and a raw-plus-candidate all-attempt record.

## 3a. Decisions and Rejected Alternatives

G3 is a new prospective estimator, not a relaxed threshold, a reclassified
historical result, a covariance-scaled convergence rule, extra restart, map
change, altered DGP, AGHQ, ridge, or empirical analysis. Any later rejected
candidate remains visible with its raw state and rejection reason.

## 4. Files Touched

- `dev/isdm-package-recovery/g3-full-vector-polish-contract.R`
- `dev/isdm-package-recovery/2026-08-13-g3-full-vector-numerical-admission-design.md`
- `dev/isdm-package-recovery/run-g3-full-vector-no-fit-validation.R`
- `tests/testthat/test-g3-full-vector-polish-contract.R`
- C1/C2 receipt helpers/runners/tests, hardened to bind retained provenance.
- This report and the private check log.

No `src/`, public R API, README, NEWS, ROADMAP, pkgdown, vignette, roxygen, or
generated Rd file changed.

## 5. Checks Run

- `run-g3-full-vector-no-fit-validation.R`: PASS.
- Targeted G3/C1/C2 `devtools::test()` suite: PASS.
- C1 immutable-ledger validation: PASS.
- C2 frozen-contract validation: PASS.
- `git diff --check`: PASS.

## 6. Tests of the Tests

Hand-built inputs cover symmetric/non-PD curvature, Hessian and bound name/order,
tied maxima, out-of-bounds trial, signature drift, candidate gradient failure,
off-grid step prevention, and static absence of execution calls. They are not
compiled-object or recovery tests.

## 7a. Issue Ledger

No issue, PR, CI, remote compute, data download, or public action was created.

## 8. Consistency Audit

G3 has no model constructor, optimiser, profile, simulator, or download path.
Paper 1 is sealed to `paper1-spatial-b2-86202`, Case D, and its SHA-256 ledger;
Paper 2 is sealed to `paper2-s6-86122`, Case C, and its frozen fixture hash.

## 9. What Did Not Go Smoothly

Independent review caught missing candidate-vector/Hessian/bounds/provenance
checks before any compute. The initial bounds test also used a feasible value;
it was corrected to a genuinely out-of-bounds trial.

## 10. Known Residuals

G3 has no compiled-unit evidence yet. It does NOT cover a fit, profile,
simulation, spatial or Psi recovery, empirical data, scale, or public claim.

## 11. Team Learning

Gauss/Noether required candidate equality to a predeclared Newton grid and
full coordinate integrity. Fisher required full candidate curvature/bounds and
all-attempt provenance. Rose required sealed historical comparators and a
broadened no-execution fence.

## 12. Cross-Product Coverage

G3 covers private prospective numerical admission for exactly Paper 1's
two-field spatial and Paper 2's nonspatial frozen comparators. It does NOT cover likelihood/DGP/map/transform changes, RE/REML alternatives, missing data,
aggregation, empirical prediction, or reader-facing outputs.

### Next action

Gate B must separately approve compilation of the exact G3 candidate path and
its compiled-unit checks. Only after that review can it request either
time-estimated fresh smoke; no smoke is authorised by this report.
