# G2n local pre-run plan-versus-actual reconciliation

## Planned

One approved private local diagnostic fit, using the frozen six-species G2i/G2m
fixture, source gate, map, raw threshold, profiles, and recovery metrics; use
the G2n ledger; retain all provenance; make no campaign or scope expansion.

## Actual

The first wrapper invocation created a receipt in the same root that the
retained G2i runner requires to be empty.  It stopped before a fit, retained a
`fit_error`-free structural HOLD root, and did not consume the one-run
authorization.  The wrapper was then corrected and committed as `7a819639`.
Its no-fit validation passed.  One and only one actual fit ran in fresh root
`g2n-local-prerun-20260812-0630`, with one retained fit and 30 frozen profile
optimizations.

The final ledger has valid source gate, three restarts, profiles, raw state,
candidate provenance, recovery metrics, runtime, file manifest, and final
closure. A no-fit addendum makes the source-gate evidence explicit and binds
the map/data/random/bounds/scale/control signatures, ordered parameter vector,
gradient, covariance diagnostics, and runtime versions. A V3 manifest repair
excludes the mutable manifest from its own list while closure V3 binds it;
closure V3 hashes all 20 files. It is `G2N_LOCAL_PRERUN_HOLD`: Case C / `NO_CANDIDATE` (`b_fix`,
gradient `0.002726537`) and diagonal-Psi variance error `0.2156398 > 0.20`.

## Scope reconciliation

No recovery campaign, Totoro/FIR/DRAC job, second fit, optimizer repair,
likelihood/DGP/seed/map/source-gate/metric change, G2k reclassification,
detection/spatial implementation, empirical data, public/package/docs/pkgdown
activity, or Issue #953 work occurred.  Historical G2k and G2c HOLD states
remain intact.
