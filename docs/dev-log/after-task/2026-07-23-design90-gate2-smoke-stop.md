# After Task: Design 90 Gate-2 upstream q=2 EVA smoke stop

## 1. Goal

Run four frozen ordinary q=2 upstream-EVA smoke attempts on Totoro and decide
whether the predeclared 1,152-attempt atlas may start.

## 2. Implemented

Built locked `gllvm` 2.0.13 in an isolated Totoro library and ran the four
predeclared cells once. All four have retained RDS/JSON sidecars. The smoke is
STOP: 0/4 attempts are healthy, so the 10-hour campaign was not launched.

## 3a. Decisions and Rejected Alternatives

**Decision:** stop after the four frozen attempts.  
**Rationale:** every fit fails at least one frozen health predicate.  
**Rejected alternative:** allow all-zero rows, relax the gradient threshold,
change starts, or generate replacement inputs; each changes the contract after
observing results.  
**Confidence:** high.

## 4. Files Touched

- `dev/design90-eva-atlas/design90-atlas.R` and `run-smoke.R`
- `dev/design90-eva-atlas/results/*.{rds,json}`
- `docs/design/90-upstream-eva-reliability-atlas.md`
- this report and `docs/dev-log/check-log.md`

No gllvmTMB package surface changed.

## 5. Checks Run

- Totoro connectivity/R/TMB preflight -> PASS.
- Fresh isolated gllvm build -> PASS after declared dependencies were installed.
- Four-cell smoke -> STOP (exit 2): 0/4 healthy.
- Local RDS audit -> confirms logical convergence for all four; gradients
  0.002283541, 0.455567475, 1.252887510, and 54.348989836; three warnings.
- SHA-256 sidecar manifest -> recorded; `git diff --check` -> PASS.

## 6. Tests of the Tests

The local pure-generator check verified 72 cells and a nonseparable trait-level
fixture without calling gllvm. The smoke is the feature-combination test
(locked upstream source + q=2 generator + EVA + telemetry); it exposed that
trait-level support does not imply the absence of all-zero response rows.

## 7a. Issue Ledger

No issue created. This private stopped design does not change an advertised
package capability.

## 8. Consistency Audit

`git diff --exit-code HEAD -- R src NAMESPACE DESCRIPTION NEWS.md README.md`
remains empty. `rg -n 'Design 90|EVA' README.md ROADMAP.md NEWS.md
docs/dev-log/known-limitations.md _pkgdown.yml` finds no new public claim.

## 9. What Did Not Go Smoothly

Totoro required `fishMod`, `alabama`, and then `nloptr` in the isolated library;
the first two smoke invocations stopped during package-load preflight before
fixture creation or fitting. The subsequent valid four-attempt smoke uncovered
the all-zero-row support gap and large gradients.

## 10. Known Residuals

This STOP does not say whether a new row-support-constrained q=2 design would
be healthy. Such a design would need separate approval and cannot reuse these
fixtures/results as passing evidence.

## 11. Team Learning

Gauss/Noether's requirement for realised-input checks was vindicated: checking
only both outcomes per trait missed an all-zero-row condition. Rose's retained
failure discipline prevents silently removing warnings or replacing fixtures.

## 12. Cross-Product Coverage

The smoke covers four q=2 ordinary upstream-EVA cells on one locked Totoro
environment. It does NOT cover the 72-cell atlas, recovery, calibration,
gllvmTMB parity, structured priors, or public integration.
