# Plan versus actual — VA-R3 variance-domain gate

## Planned

Measure complete multi-trial binomial-logit VA-R3 fixtures near observed
projected variance 4, 6, 10, and 20; retain VA and independent truth ladders;
use only stable truth for the ELBO-bound comparison; close privately.

## Actual

The initial nominal fixtures missed their observed bands and were retained as
local calibration receipts. A frozen post-calibration map then realized
4.613715, 5.987552, 8.674338, and 22.190718. Truth was stable in the first
three cells and explicitly uninterpretable in the fourth. No Totoro replication
was launched because Rose judged the instrument-boundary result sufficient for
this limited closeout; a replication packet could not repair the unavailable
high-variance oracle.

## Material deviations

| Axis | Planned | Actual | Classification |
| --- | --- | --- | --- |
| fixture calibration | nominal targets treated as observed targets | retained calibration grid plus frozen cell map | adaptive |
| compute | possible small Totoro packet | no remote run | adaptive; evidence stops at instrument boundary |
| conclusion | determine whether 4 is a hard numerical threshold | no immediate break at 4; high regime not adjudicable | adaptive and scope-preserving |

## Reconciliation

Scope, public-claim, and safety gates were preserved. No deferred public API,
Bernoulli widening, or gate relaxation entered the worktree. Rose and Noether
reviewed the final evidence; there is no unexplained plan drift.
