# Dependent temporal--kernel native-`nlminb` candidate: retained result

The frozen native-`nlminb` candidate **failed** its qualification. This is a
local direct-DGP numerical result, not a general comparison of optimizers.

The retained timing pre-run took 208.593 seconds and returned convergence code
1 on both passes, with a rejected second pass. The nine frozen campaign cells
used seeds `2609381:2609383` for each of `phi = -.4, 0, .6`, with four
single-thread local workers. All nine receipts completed and are retained in
`results/occasion-32-nlminb-qualification-20260912/`, together with
`qualification-summary-v1.rds`.

Every cell returned terminal success but convergence code 1 for both passes;
every second pass was rejected. Therefore each persistence stratum had zero of
three strict successes, and the campaign failed before its recovery-error
criteria could be evaluated. The strict native gradient threshold was also
breached in three cells: `phi=-.4, seed=2609381` (`.0011866514`), `phi=0,
seed=2609382` (`.0014683901`), and `phi=0, seed=2609383` (`.0016442088`).

The recorded source commit for the campaign is `3910f3d2f`. The earlier failed
BFGS qualification remains separate immutable evidence. This candidate does
not establish an optimizer mechanism, repair source-pair recovery, admit the
source pair, or establish recovery, coverage, forecasts, cross-platform
readiness, merge, or release.
