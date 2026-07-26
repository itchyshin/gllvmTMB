# HVT-1 handoff — private high-variance truth instrument

## Result

HVT-1 landed a private, source-locked q=2 adaptive nested-integration
instrument on `codex/hvt1-high-variance-truth-oracle-20260726`.

- Frozen band 4 is `TRUTH_CERTIFIED_ADAPTIVE`, agreeing with the admissible
  stable product-GH reference; its private ELBO--truth measurement is retained.
- Frozen band 20 is `TRUTH_UNINTERPRETABLE_ADAPTIVE`: all baseline routes agree
  near `-32.32363`, but tightened reverse nesting fails.  No high-cell gap is
  present.
- The overall decision is `ORACLE_NOT_CERTIFIED`, not a VA failure threshold.

## First read

1. `docs/dev-log/after-task/2026-07-26-hvt1-high-variance-truth-oracle.md`
2. `dev/va-variance-gate/hvt1-certification-spec.md`
3. local packets under `/private/tmp/hvt1-20260726-band4-final10/`
   and `/private/tmp/hvt1-20260726-band20-final10/`.

## Do not redo / do not infer

Do not alter the frozen fixture, retry with relaxed tolerances, use AGHQ or
Laplace as truth, report the high-cell ELBO gap, relax `<=4`, widen to
Bernoulli, or start a Totoro campaign.  A later arc must compare a genuinely
different high-variance integration method before any robustness statement.
