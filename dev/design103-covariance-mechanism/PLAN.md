```text
GOAL: Design-103 is a private mechanism diagnosis, not another recovery claim.
For fixed Design-102 q=2 data/records, diagnose the selected QD/QF/JD/JF endpoints
under a measured common marginal-GH reference.  The measured N=240 pilot determines
a five-hour DRAC wall-clock budget.  Retain calibration OOMs and every task terminal.
Defer EVA, package paths, public claims, rank changes, and campaign expansion.
```

# Frozen diagnostic logic

For each Design-102 cell, select the already-retained healthy winner using its native
objective only.  The original GH101 four-method atomic cell refit is a failed
calibration, not a result: it exceeded 60 minutes at 16 GB.  The replacement is a
method-level, atomic GH61 refit with an independently measured N=240 budget and
GH101 fixed-coordinate sentinels at its native endpoint and terminal coordinate.
Compare rotation-invariant \(\Lambda\Lambda^T\), beta error, and common-objective
movement before/after refitting.

- A lower-order GH refit that repairs covariance error is *diagnostic evidence
  consistent with an approximation/endpoint mechanism*; it is not an exact-GH101
  recovery claim.
- A fixed-coordinate GH101 objective gap among the three retained starts is a
  selection diagnostic only.  It cannot, by itself, establish approximation.
- A persistent N/regime contrast after the bounded refit is evidence compatible with
  information or chart/scale, but neither label is emitted without the complete
  predeclared contrast.
- No general mechanism label is emitted unless its predeclared contrast is available;
  otherwise the closure is `TECHNICAL_PARTIAL` or `TECHNICAL_INFEASIBLE`.

Calibration chronology is immutable: jobs `50783423` (3 GB) and `50784354`
(8 GB) were OOM; job `50789255` (16 GB) timed out after 59:38 CPU elapsed,
with 11.75 GB maximum RSS, before writing its four-method atomic receipt.  This
rules out an unbounded GH101 global-refit grid inside a five-hour envelope.

The replacement pilot is seed `102001`, `N=240`, `correlated`, method `QF`, GH61,
one method-level receipt, 8 GB, and a 45-minute cap.  It has an iteration cap of
80 and evaluation cap of 120.  Its elapsed time and maximum RSS determine the
number of method-level tasks and worker cap; no campaign array may be submitted
until it finishes.  The GH101 sentinel is a separate 16-GB calibration because
job `50955251` established that a single GH101 AD object exceeds 8 GB before the
GH61 refit begins.  Every future method task writes a standalone RDS and every
non-writing terminal is retained through its Slurm accounting record.

The completed lower-order calibration, job `50956936`, used 14:18 wall time,
14:08 CPU time, and 4.35 GB maximum RSS.  It wrote a receipt but ended at the
80-iteration cap with gradient 0.0469, beta RMSE 13.9, and covariance relative
error 3611.  Therefore the array is explicitly a **bounded optimization-failure
pattern diagnostic**, not a GH-refit recovery study.  It freezes four evenly
spaced seeds (`102001`, `102011`, `102021`, `102031`) crossed with
N={24,80,240}, both regimes, and QD/QF/JD/JF: 96 one-method tasks.  Each task
has 8 GB, 20 minutes, 80 iterations, no GH101 sentinel, and an array cap of
three workers.  If every task cost as much as N=240 the array would require
7.6 wall-clock hours, but the linear-in-N GH tape makes the calibrated planning
estimate about 4 hours (plus retrieval/adjudication); the task must be stopped
and closed `TECHNICAL_PARTIAL` at the five-hour wall-clock boundary rather than
silently overrun it or widen the worker cap.

Early-stop amendment: the first three array receipts (QD/QF/JD, seed `102001`,
N=24, `near_diag`) all returned pathological terminal covariance errors
(1.9e7, 3.6e8, and 9.4e6) despite finite objectives; QF's nominal convergence
code was therefore not a health certificate.  Array `50964478` was cancelled
after these three completed receipts and three in-flight terminals.  A
96-task refit grid would not distinguish the requested mechanisms because its
common refit endpoint is invalid.  The economical final diagnostic is instead
two 16-GB, fixed-coordinate GH101 evaluations for seed `102001`, N=240, both
regimes: score every retained healthy start of QD/QF/JD/JF with no optimization.
This can adjudicate **selection** at two scale regimes.  It cannot establish
approximation, information, or chart/scale as a causal mechanism; those labels
remain unavailable when the common refit is unhealthy.
