# Independent 160-series qualification for dependent temporal--kernel recovery

## Purpose

The retained 80-series `temporal_dep() + kernel_indep()` recovery fixture
fails two positive-persistence kernel-variance criteria. The completed
information diagnostic used the same direct DGP at 160 series and found lower
median error for those two components. This qualification asks whether that
pattern holds in a **new**, fully disjoint recovery experiment.

It is a separate engineering qualification. It cannot rewrite, replace, or
turn the 80-series receipt into a passing result.

## Frozen design

The new design uses the existing additive Gaussian model, direct DGP, kernel,
time grid, two measurements per state, three traits, two-pass BFGS control,
parameter maps, estimands, and acceptance criteria. The only design change is
the number of independent series, fixed to 160.

The complete plan is the Cartesian product:

| Quantity | Frozen value |
|---|---|
| Persistence | `-.4`, `0`, `.6` |
| Seed | `2609341:2609343` |
| Series | `160` |
| Occasions | `16` |
| Measurements per state | `2` |
| Traits | `3` |
| Fits | `9` |

The seeds are disjoint from both the failed 80-series recovery
(`2609221:2609223`) and the completed information diagnostic
(`2609221:2609223`). No result from the information ladder can count as a
qualification attempt.

For every cell, retain terminal status, both optimizer-pass records, objective,
outer gradient, Hessian status, persistence, temporal covariance, three kernel
variances, and fixed effects. Apply the existing strict convergence gate and
the unchanged per-persistence criteria: mean absolute persistence error at most
`.15`, median absolute persistence error at most `.20`, median temporal
Frobenius error at most `.30`, median relative error at most `.35` for each
kernel variance, and mean fixed-effect error at most `.25`.

## Evidence and compute envelope

The six completed diagnostic fits at 160 series took 38.981--43.586 seconds
each after setup (total 121.576 seconds for its three 160-series cells). A
nine-worker Totoro array is therefore provisionally expected to finish in well
under 30 minutes including package setup and receipt collection. Before the
campaign, a separate non-campaign terminal pre-run must use the same runner at
160 series and seed `2609340`; it must retain its timing but is not one of the
nine qualification cells.

The eventual launcher must pin one BLAS/OpenMP thread per worker, use no more
than nine Totoro workers, pin an exact clean commit, refuse overwritten
receipts, and preserve every terminal result. If the measured pre-run or
collection process projects the campaign above 30 minutes, stop and obtain
separate compute approval before launching it.

## Decision boundary

This campaign may establish only whether the named 160-series fixture meets
its frozen engineering thresholds. Passing it would not establish general
recovery, interval coverage, a solver improvement, release readiness, or any
new source-pair lifecycle route. Failure retains all receipts and leaves the
source pair partial. No threshold relaxation, changed optimizer tolerance,
seed replacement, extra generic pass, or source-by-time product term is
permitted.
