# Temporal phylogenetic recovery overrun checkpoint

## State

- Branch: `codex/temporal-program-20260909` at `ae6d2e737`.
- Working tree: clean.
- Current retained phylogenetic receipt: eight successful `phi = -0.4`
  attempts in `dev/temporal-program/results/phylo-recovery-160-20260909.csv`.

## Commands and outcomes

- `Rscript --vanilla -e '... median/mean elapsed ...'` measured 53.5 s median
  and 57.9 s mean among those eight attempts, initially projecting 21.2 minutes
  for 22 remaining fits.
- `OPENBLAS_NUM_THREADS=1 Rscript --vanilla dev/temporal-program/run-phylo-recovery.R`
  was resumed under that estimate. The first uncompleted fit emitted no checkpoint
  after more than 3.5 minutes, so it was interrupted under the estimate-before-run
  rule. No ninth row was written.
- `Rscript --vanilla -e '... read retained receipt ...'` confirmed eight rows and
  eight `success` terminals after interruption.
- `Rscript --vanilla -e 'parse(file = ...)'` passed for the phylogenetic and
  animal runners after adding `error_message` retention and old-checkpoint schema
  upgrading.

## Next action

Do not rerun the remaining 22 phylogenetic attempts locally. Obtain explicit
approval for a retained DRAC Slurm-array campaign using the unchanged fixture,
one BLAS thread per job, and the existing checkpoint as its input. Preserve every
result and do not modify seeds, DGP, thresholds, branch state, or GitHub state.
