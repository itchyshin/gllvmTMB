# Resume: temporal source-pair programme

## Current state

- Worktree: `/private/tmp/gllvmTMB-temporal-program`
- Branch: `codex/temporal-program-20260909`
- Resume commit: `800f57d82`
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

## Kernel candidate result (2026-09-09)

A deliberately narrow, temporary `temporal_indep() + kernel_indep()` parser
preview was used only to run an independently simulated, retained local
recovery smoke campaign. It was closed again immediately after the result.

- DGP: 12 series, 20 occasions, three traits; stationary AR1 persistence
  `(-0.4, 0, 0.6)`; labelled fixed kernel; both source tiers nonzero.
- Nine fixed seed--persistence fits are retained at
  `/private/tmp/temporal-kernel-pair-recovery-20260909.csv`.
- All fits returned a finite objective and convergence code zero, but three
  maximum outer gradients exceeded `1e-3`; the negative-persistence cell also
  exceeded the prespecified mean absolute persistence-error target. Several
  kernel-variance estimates collapsed to the boundary.

This is a **failed admission experiment**, not evidence for a kernel pair.
The public parser remains closed. The throwaway runner is deliberately left
uncommitted because its formula is refused by the supported public contract.

## Next bounded slice

Define and implement a temporal-only **forecasting contract** before reopening
any source pair. The implementation must condition a joint Gaussian response
on observed temporal data, preserve time/series labels, and retain the existing
refusal for unsupported source combinations and forecast layouts.

1. Freeze the estimand: existing series, future occasions, Gaussian identity
   response prediction, fitted parameters, and the complete observed response
   vector. New series and source pairs remain refused.
2. Implement a dedicated helper rather than widening generic `predict(newdata)`
   by accident. Use independent dense Gaussian conditioning as its initial
   oracle, including negative AR1 odd/even lags and OU time-shift invariance.
3. Keep profile, bootstrap, interval and selection refusals until their own
   profile/refit/candidate contracts are implemented and independently tested.

## Do not claim

Do not describe this work as merged, released, cross-platform verified, or as
general recovery/coverage evidence. Forecasting, intervals, profiles,
bootstrap, selection, all non-`indep` source cells, and source-by-time product
kernels remain separate contracts.
