# Kernel-pair identification redesign

The failed kernel rehearsal used an ordered kernel over the same 12 series that
carried the temporal trajectories. The next DGP must use a fixed labelled,
non-proportional kernel and enough independently replicated series that its
static variation is distinguishable from persistent temporal variation. It
must include an explicit proportional-kernel negative control, retain all
seeds and gradients, and compare source-specific variance recovery before any
parser preview is reopened.

## Retained 80-series redesign result (2026-09-09)

A second disposable, direct-DGP campaign increased the number of independent
series from 12 to 80 and used 16 occasions and a fixed labelled kernel built
from two non-proportional coordinates. It retained AR1 persistence `-.4`, `0`,
and `.6`, three traits, and seeds `2609151:2609153`; every fit used the same
exact-gradient BFGS control. The DGP did not call package simulation code.

All nine objectives were finite and every optimizer returned code zero. The
frozen strict gradient criterion still failed for three fits: two of three
`phi = 0` fits and one of three `phi = .6` fits exceeded `1e-3`. Aggregated
strict successes were therefore 3/3, 1/3, and 2/3 for `phi = -.4`, `0`, and
`.6`. The `phi = -.4` and `.6` cells also exceeded the `.25` mean fixed-effect
error criterion (`.266` and `.279` respectively). The source and temporal
variance medians, calculated only over strict successes, were not used to
waive those failures.

Retained disposable evidence is
`/private/tmp/temporal-kernel-redesign-recovery-20260909.csv` and
`/private/tmp/temporal-kernel-redesign-summary-20260909.csv`. This is a second
failed admission exercise, not a basis for opening the public kernel parser.

## Public optimizer-contract rerun (2026-09-09)

The earlier post-polish script must not be used as admission evidence: it
overwrote fitted parameters after the public optimizer had returned, retained
the first-pass convergence code, and computed fixed-effect errors with a
recycling mistake. Its results remain retained only as a diagnostic.

The replacement is the saved native-Laplace control
`gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS", ...),
optimizer_passes = 2L)`. A candidate second pass is retained only when its own
convergence code is zero and its objective is non-increasing. `update()`
replays the control, and the fit refreshes its report from the selected final
parameters. The runner stores and checks both convergence codes and the final
gradient for every attempt.

The retained result is
`dev/temporal-program/results/kernel-recovery-20260909.csv`, with the
per-persistence summary in
`dev/temporal-program/results/kernel-recovery-summary-20260909.csv`. All nine
attempts had two accepted converged passes and final maximum gradient at most
`3.43e-4`; all three frozen persistence-cell summaries pass. The timing fit was
10.8 seconds and the nine-fit local run completed in 88 seconds. This supports
only the replicated AR1 diagonal temporal plus labelled diagonal-kernel cell.
