# Resume: temporal source-pair programme

## Current state

- Worktree: `/private/tmp/gllvmTMB-temporal-program`
- Branch: `codex/temporal-program-20260909`
- Current branch includes the simulation repair, bounded lifecycle helpers, the
  retained kernel source pair (`54904175f`), fixed phylogenetic and animal
  source-pair extensions, and the local temporal--spatial AR1 cell
  (`b18456b53`).
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

The `plan`, `simulation`, and `lifecycle` commands were rerun after the
spatial change and emit their documented success markers. The retained base
recovery receipt contains all 80 fixed seed--cell attempts; the two
latent-plus-Psi cells retain two non-success terminals each and still meet the
frozen minimum of eight successes. The ignored ledger has G0, G1, and G4 met;
G2 (three-OS CI) and G5 (closeout) remain unmet. G3 retains passing local
kernel evidence and failed phylogenetic, animal, and spatial recovery gates.

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

## Phylogenetic result (2026-09-10)

The narrow replicated-AR1 `temporal_indep()` plus one fixed labelled
`phylo_indep()` cell has independent dense additive likelihood/gradient,
product-control, long/wide, update, simulation, label, and tree/dense-equivalence
tests. Its first retained 80-series DGP remains under `results/failed/` because
two `phi = .6` phylogenetic-variance medians exceeded the unchanged `.35` bound.

The sole predeclared 160-series follow-up completed on Fir DRAC job `59096255`:
the retained 22 task receipts combine with the eight original `phi = -.4`
checkpoints into all 30 frozen `(phi, seed)` cells. Every fit has a terminal
`success`, finite objective, and optimizer code zero. The frozen strict gate
still fails: `strict_successes` are 10/10, 9/10, and 8/10 for `phi = -.4`, `0`,
and `.6`, respectively. The non-strict cells are seeds 2609188 at `phi = 0`
(`max_gradient = 0.001614525`) and 2609183/2609185 at `phi = .6`
(`0.001358263` and `0.002647219`). The combined receipt and summary are retained
under `results/failed/phylo-recovery-160-fir-59096255-20260910/`. The campaign
is therefore a failed engineering gate, not recovery evidence. Do not replace
seeds, relax thresholds, or rerun it as evidence. The separately frozen
six-cell third-BFGS-pass candidate retained in
`results/continuation/phylo-third-pass-local-six-20260910/` also fails: five
cells pass locally, but `phi=.6`, seed `2609185` remains above the unchanged
gradient gate (`0.001105532 > 0.001`). C3 is closed; it does not justify a
fourth pass, a Fir replay, or a changed threshold.

## Spatial result (2026-09-09)

The admitted spatial cell is replicated AR1 `temporal_indep()` plus exactly
one fixed in-keyword `spatial_indep()` term. It has an independent dense
additive likelihood/gradient oracle, product-covariance control, long/wide
syntax, update replay, a proportional-basis refusal, and unconditional SPDE
field redraw checked against dense covariance moments. Its source-pair recovery
campaign retained 30 fixed attempts but failed its frozen gate: strict successes
were 10/10, 9/10, and 8/10 at persistence `-.4`, `0`, and `.6`; spatial scale
and range estimates were unstable at positive persistence. It remains partial.
`SPATIAL-RECOVERY-DIAGNOSTIC.md` verifies that this is not an SPDE
parameter-scale inversion and records the derived-SD evidence.

## Animal result (2026-09-09)

The fixed `animal_indep()` cell has dense/product-control, source-provenance,
long/wide/update, and simulation evidence. Its retained 160-series campaign
completed, but the unchanged strict gradient gate failed in 3/10, 3/10, and
2/10 fits for persistence `-.4`, `0`, and `.6`; it remains partial.
`ANIMAL-RECOVERY-DIAGNOSTIC.md` retains the third-pass check: only two of the
eight failed cells crossed the gradient gate, so it does not repair the campaign.

## Next bounded slice

Treat the phylogenetic, animal, and spatial recovery gates as failed and retain
their results. Any numerical follow-up needs a separate model-level contract
with independent evidence; it cannot be another generic BFGS restart. Do not
create a pull request, merge, release, or push. A separate CI-only
authorization remains necessary before cross-platform claims.

## Do not claim

Do not describe this work as merged, released, cross-platform verified, or as
general recovery/coverage evidence. The named temporal-only forecast, direct
profile, parametric bootstrap, and supplied-candidate comparison helpers have
separate bounded Gaussian contracts. Generic prediction, generic intervals and
profiles, automatic selection, broad bootstrap, all other temporal source
pairs, and source-by-time product kernels remain unavailable.
