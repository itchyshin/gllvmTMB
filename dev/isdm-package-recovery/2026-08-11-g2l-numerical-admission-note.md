# G2l numerical-admission note — campaign not launched

## Exact result

The screened local pre-run retained at
`results/g2l-local-prerun-20260811-001/seeds/seed-86201/` has a valid fixture,
three retained starts, six finite/converged five-offset profiles, and all five
known-truth recovery metrics within their frozen bounds.  It is nevertheless
`PRE_RUN_RECOVERY_HOLD` because the selected estimator has

\[
\max_j |g_j|=0.00188706 > 0.001.
\]

The existing private same-objective iJSDM polish is eligible and was attempted.
It retained the same map and one named `near_zero_sd_B` boundary, with a
non-increasing objective and positive-definite Hessian, but its candidate raw
gradient was `0.001479`, still above the frozen bound.  It was therefore
correctly rejected.

## What this means

This is not a new source-gate or DGP failure.  The deterministic no-fit screen
selected the first 150 fixtures satisfying `g2h_validate_fixture()` from
candidate seeds `86201:87000`; 672 candidates were eligible, and the manifest
records all rejected candidates.  The current issue is solely whether the
predeclared raw-gradient admission rule should remain the gate after a
diagnostic review of this otherwise stationary TMB optimum.

The retained fit reports a scaled gradient of `3.68e-7`, a positive-definite
Hessian, and convergence code zero.  Those facts are supporting numerical
evidence, not a substitute for the frozen raw-gradient criterion.

## No campaign verdict

The G2l 150-seed Totoro campaign was **not launched**.  The plan required a
healthy local pre-run first, and this one is held.  It would be invalid to
interpret the earlier 128-start G2k output as a replacement campaign because
its 22 omitted fixtures were not source-design-admissible.

## Next permissible decision

Before any new local smoke or campaign, a dedicated numerical-admission arc
must decide between:

1. a demonstrably stronger same-objective optimizer/polish route that reaches
   the existing `1e-3` raw-gradient bound while preserving map, objective,
   Hessian, and boundary provenance; or
2. a revised numerical admission criterion justified prospectively by a
   symbolic and scaled-gradient analysis, with its own new protocol and
   recovery campaign identity.

Neither option is authorized by this note.  No likelihood, DGP, recovery
threshold, public interface, detection extension, or spatial term changed.
