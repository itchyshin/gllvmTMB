# Dependent temporal--kernel long-occasion qualification

## Purpose

This is a separately frozen **candidate qualification** for the direct
Gaussian, replicated AR1 `temporal_dep() + kernel_indep()` model.  It asks
whether doubling the number of equally spaced occasions from 16 to 32 improves
the retained recovery criteria in the same source design.  The independent
nuisance-adjusted-information diagnostic motivates the design change: its
three kernel-information components increased at 32 occasions.  That
diagnostic neither establishes a cause of the earlier failure nor establishes
recovery.

The failed 80-series, 16-occasion campaign and the failed disjoint 160-series
qualification remain immutable evidence.  This qualification does not replace,
pool with, or reinterpret either result.

## Frozen DGP and estimator

The generator is independently authored and must never call production
temporal simulation.  It retains the earlier direct DGP exactly except for
`n_time = 32`:

- 80 labelled series, three traits, and two measurements per
  series--occasion--trait;
- trait intercepts `(.2, -.3, .1)`;
- temporal loading matrix `rbind(c(.55, 0, 0), c(.12, .50, 0),
  c(-.08, .10, .48))`;
- labelled non-proportional kernel and per-trait kernel SDs `(.35, .28, .40)`;
- measurement SD `.30`; and
- AR1 persistence `phi = -.4, 0, .6`.

Each fit uses the same public formula, two-pass BFGS control, maps, likelihood,
and parameter transforms as the failed 16-occasion campaign.  No start,
scaling, tolerance, residual floor, solver, criterion, or source matrix is
changed.

## Cells and retained outputs

The pre-run is `(phi = .6, seed = 2609370)`.  It is timing and terminal-state
evidence only and is not one of the campaign cells.  The campaign consists of
all nine cells formed by `phi = (-.4, 0, .6)` and seeds `2609371:2609373`.
Every attempted cell writes one new RDS receipt atomically under
`dev/temporal-program/results/occasion-32-qualification-20260912/`; successful
and failed fits use the same schema and retain elapsed time and error text.

The summary recomputes the original strict optimizer condition and the
original fixed-DGP criteria: three strict successes per persistence stratum,
mean absolute phi error at most `.15`, median phi error at most `.20`, median
temporal Frobenius error at most `.30`, each median kernel-variance relative
error at most `.35`, and mean fixed-effect error at most `.25`.

## Gates before compute

1. The runner must reject any seed, persistence value, output overwrite, or
   attempt to use production simulation.
2. A focused test must prove the fixed cell plan, public parser admission,
   output-immutability rule, and direct-generator boundary.
3. One local or Totoro pre-run must retain a terminal receipt and measured time.
4. If that time projects the nine retained fits beyond 30 minutes, present the
   measured result and obtain distinct compute approval before launch.  A
   parallel campaign uses one single-thread worker per cell and retains every
   result.
5. A reviewer must confirm that the 32-occasion design changes only the
   declared panel length and that the report preserves the earlier failed
   results.

## Claim boundary

Until all gates pass, this is an unexecuted qualification contract.  Even a
passing nine-cell fixture would be local, direct-DGP evidence only: it would
not establish general recovery, interval coverage, forecast calibration,
source-pair admission beyond this model, cross-platform verification, merge,
or release readiness.
