# Design 96 plan-versus-actual reconciliation

| Axis | Planned | Actual | Classification |
|---|---|---|---|
| Scope | private q=2 smoke only | new `dev/design96-jj-recovery/` plus records | aligned |
| Attempts | exactly 2 fixtures × 3 starts | 6 attempt records written once | aligned |
| Evidence | invariant recovery and health gate | `SMOKE_STOP`; retained all failures | aligned |
| Safety | no overwrite, no retries | result root now blocks rerun | aligned |
| Claims | local-smoke verdict only | no recovery or general-stability claim | aligned |
| Compute | local smoke only | local TMB compile/fits only | aligned |

No scope or threshold deviation occurred.  The only material result was an
adverse predeclared verdict, which is evidence to retain rather than repair.
