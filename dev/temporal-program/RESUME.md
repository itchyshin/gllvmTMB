# Resume: temporal source-pair programme

## Current state

- Worktree: `/private/tmp/gllvmTMB-temporal-program`
- Branch: `codex/temporal-program-20260909`
- Resume commit: `6c3f0bb00`
- Baseline local temporal simulation repair: `f227e7801`
- Additive source contract: `da718f8c6`
- Source-pair previews were deliberately reverted at `a2f71fd88`,
  `b67b4725c`, and `6b17e0397` because they lacked unconditional composed
  simulation, retained recovery, and lifecycle evidence.

## Verified now

```sh
Rscript --vanilla dev/temporal-program/verify.R simulation
Rscript --vanilla dev/temporal-program/verify.R plan
```

Both emit their documented success marker at this commit. The ignored ledger
`.unlazy/temporal-program/GATES.md` has G0--G1 met and G2--G5 unmet. In
particular, no temporal plus spatial, phylogenetic, animal, or kernel public
syntax is currently admitted.

## Next bounded slice

Implement and independently verify **unconditional simulation for one proposed
additive source pair before reopening its parser admission**. Start with a
fixed labelled kernel, because its dense covariance is directly available.

1. Claim `R/methods-gllvmTMB.R`, `R/temporal.R`, the new temporal source-pair
   simulation test, and any required source simulator surface.
2. Write a deterministic zero-innovation/zero-residual test proving that an
   unconditional draw removes and redraws both the temporal state and the
   kernel random effect. Add an independently authored moment oracle for the
   sum of the temporal and kernel covariance terms; do not call production
   simulation from that oracle.
3. Preserve `condition_on_RE = TRUE` as an observation-noise draw around the
   full fitted predictor. Keep unimplemented sources/cells fenced.
4. Time one recovery fixture. If the retained campaign projects above thirty
   minutes, present its measured pre-run result and obtain separate compute
   approval before launch.
5. Only after simulation, lifecycle, and retained recovery gates pass may the
   narrow `temporal_indep() + kernel_indep()` public admission be restored.

## Do not claim

Do not describe this work as merged, released, cross-platform verified, or as
general recovery/coverage evidence. Forecasting, intervals, profiles,
bootstrap, selection, all non-`indep` source cells, and source-by-time product
kernels remain separate contracts.
