# Resume: temporal source-pair programme

## Current state

- Worktree: `/private/tmp/gllvmTMB-temporal-program`
- Branch: `codex/temporal-program-20260909`
- Current branch includes the simulation repair, bounded lifecycle helpers, and the fail-closed recovery-runner repair `7ad1aff56`.
- Baseline local temporal simulation repair: `f227e7801`
- Additive source contract: `da718f8c6`
- Source-pair previews were deliberately reverted at `a2f71fd88`,
  `b67b4725c`, and `6b17e0397` because they lacked unconditional composed
  simulation, retained recovery, and lifecycle evidence.

## Verified now

```sh
Rscript --vanilla dev/temporal-program/verify.R plan
Rscript --vanilla dev/temporal-program/verify.R simulation
Rscript --vanilla dev/temporal-program/verify.R lifecycle
Rscript --vanilla dev/temporal-sixth-source/verify.R recovery
```

All four commands emit their documented success marker locally. The retained
recovery receipt contains all 80 fixed seed--cell attempts; the two
latent-plus-Psi cells retain two non-success terminals each and still meet the
frozen minimum of eight successes. The ignored ledger has G0, G1, and G4 met;
G2 (three-OS CI), G3 (a source pair), and G5 (closeout) remain unmet. No
`temporal_*` term can currently be combined publicly with spatial,
phylogenetic, animal, or kernel terms.

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

A later 80-series, 16-occasion direct-DGP redesign also remains a failed
admission exercise. Its nine exact-gradient BFGS fits were finite with
optimizer code zero, but three gradients exceeded `1e-3`, leaving strict
success counts 3/3, 1/3, and 2/3 at persistence `-.4`, `0`, and `.6`; the
negative and positive persistence cells also exceeded the frozen mean
fixed-effect error target. See `KERNEL-IDENTIFICATION-REDESIGN.md` for the
retained result.

## Next bounded slice

Obtain explicit authorization to push this branch solely for CI, then inspect
Linux/macOS/Windows results. Do not create a pull request, merge, or release as
part of that step. In parallel, keep every temporal-plus-source parser route
closed until one source pair has passed its own additive dense-oracle,
composition-simulation, lifecycle, and retained-recovery gates.

## Do not claim

Do not describe this work as merged, released, cross-platform verified, or as
general recovery/coverage evidence. The named temporal-only forecast, direct
profile, parametric bootstrap, and supplied-candidate comparison helpers have
separate bounded Gaussian contracts. Generic prediction, generic intervals and
profiles, automatic selection, broad bootstrap, all temporal source pairs, and
source-by-time product kernels remain unavailable.
