# Resume: temporal source-pair programme

## Current state

- Worktree: `/private/tmp/gllvmTMB-temporal-program`
- Branch: `codex/temporal-program-20260909`
- Current branch includes the simulation repair, bounded lifecycle helpers, the
  retained kernel source pair (`54904175f`), and an uncommitted fixed-phylo
  source-pair extension under review.
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
G2 (three-OS CI) and G5 (closeout) remain unmet. G3 has retained local kernel
evidence and a pending phylogenetic recovery gate. No `temporal_*` term can
currently be combined publicly with spatial or animal terms, and only the
replicated AR1 diagonal kernel/phylogenetic cells are admitted.

## Kernel result (2026-09-09)

A deliberately narrow replicated-AR1 `temporal_indep() + kernel_indep()` cell
has an independently simulated, retained local recovery fixture.

- DGP: 12 series, 20 occasions, three traits; stationary AR1 persistence
  `(-0.4, 0, 0.6)`; labelled fixed kernel; both source tiers nonzero.
- Nine fixed seed--persistence fits are retained at
  `/private/tmp/temporal-kernel-pair-recovery-20260909.csv`.
- All fits returned a finite objective and convergence code zero, but three
  maximum outer gradients exceeded `1e-3`; the negative-persistence cell also
  exceeded the prespecified mean absolute persistence-error target. Several
  kernel-variance estimates collapsed to the boundary.

The retained final 80-series, 16-occasion direct-DGP redesign is the kernel
evidence: all nine final two-pass BFGS fits converged with maximum final
gradient `3.43e-4`, and its frozen summaries pass. See
`KERNEL-IDENTIFICATION-REDESIGN.md` for the historical failed previews and
the retained valid result.

## Phylogenetic result in progress (2026-09-09)

The next narrow cell is replicated AR1 `temporal_indep()` plus exactly one
fixed labelled `phylo_indep()` source supplied as in-keyword `tree =` or
`vcv =`. Independent dense additive likelihood/gradient, product-control,
long/wide, update, simulation, label, and tree/dense-equivalence tests pass
locally. The first retained 80-series DGP is deliberately preserved under
`results/failed/`: all nine fits met optimizer/gradient requirements, but two
`phi = .6` phylogenetic-variance medians exceeded the unchanged `.35` bound.
The predeclared single follow-up is 160 series, 16 occasions, two measures,
the same covariance construction/truths/settings, three phi values, and ten
fresh seeds per phi. Eight `phi = -.4` attempts are retained with final
optimizer code zero and gradients below `1e-3`. The ninth fit exceeded three
minutes, pushing the full campaign past the 30-minute local boundary; the
runner was stopped and checkpoints every completed attempt. Resume only after
separate compute approval, without replacing any seed or relaxing thresholds.

## Next bounded slice

Obtain explicit authorization to push this branch solely for CI, then inspect
Linux/macOS/Windows results. Do not create a pull request, merge, or release as
part of that step. When the phylogenetic campaign finishes, add it to the
fail-closed verifier only if its frozen result passes. In parallel, keep every temporal-plus-source parser route
closed until one source pair has passed its own additive dense-oracle,
composition-simulation, lifecycle, and retained-recovery gates.

## Do not claim

Do not describe this work as merged, released, cross-platform verified, or as
general recovery/coverage evidence. The named temporal-only forecast, direct
profile, parametric bootstrap, and supplied-candidate comparison helpers have
separate bounded Gaussian contracts. Generic prediction, generic intervals and
profiles, automatic selection, broad bootstrap, all temporal source pairs, and
source-by-time product kernels remain unavailable.
