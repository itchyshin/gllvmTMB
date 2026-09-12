# Temporal dependent-kernel long-occasion qualification: result

## Scope

This record evaluates the frozen direct-DGP qualification in
`TEMPORAL-DEP-KERNEL-OCCASION-QUALIFICATION-CONTRACT.md`.  It is a narrow
80-series, 32-occasion, three-trait, two-measurement temporal
`dep` + fixed non-proportional kernel fixture.  It is not general recovery,
coverage, solver, or release evidence.

## Retained execution

The timing-only pre-run (`phi = 0.6`, seed `2609370`) completed successfully
in 60.728 seconds.  The nine frozen campaign cells (`phi = -0.4, 0, 0.6`;
seeds `2609371:2609373`) were then run with at most four single-thread local
workers.  Every cell receipt and the aggregate summary are retained in
`dev/temporal-program/results/occasion-32-qualification-20260912/`.

All nine fits had terminal status `success`, both requested BFGS passes
converged, and the second pass was accepted.  The fixed strict gradient
criterion was nevertheless not met for `phi = 0`, seed `2609373`:

```
max_gradient = 0.001672432 > 0.001
```

Thus the `phi = 0` group has two, rather than three, strict successes.  The
aggregate qualification verdict is **FAIL**.  No seed was replaced, no fit
was rerun, and no threshold was changed.

The two other persistence groups meet their frozen within-group criteria in
this fixture.  That partial result does not promote the temporal-dependent
kernel pair: the full qualification requires all three persistence groups to
pass.

## Next implication

Longer temporal panels remove much of the nuisance-information weakness seen
in the shorter fixture, but do not yet establish a stable optimizer route.
Any further attempt needs a separate optimizer contract and new independent
evidence; it must not overwrite or reinterpret these receipts.
