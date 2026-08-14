# #897 local-smoke stop checkpoint

- **Branch/worktree:** `codex/897-ordinal-detector-admission` at `2942b654`
  in `/private/tmp/gllvmtmb-897-ordinal-detector-admission`.
- **Status:** one untracked file, `dev/897-ordinal-detector-admission.R`.
- **Goal:** establish an ordinal-specific, truth-free post-fit diagnostic only
  if it can later meet held-out 95% sensitivity and 95% specificity; otherwise
  retain the #897 fence.

## What ran

1. `Rscript --vanilla dev/897-ordinal-detector-admission.R --smoke`
   completed in 8.23 seconds. Its two ordinary ordinal-probit fits were finite,
   convergence `0`, `pdHess = TRUE`, and wrote non-empty CSV/provenance files
   under `~/gllvm_work/results/897-ordinal-detector/`.
2. The 12-seed `--failure-smoke` was intended as a sub-minute local failure
   probe based on the two-fit receipt. It exceeded that estimate and was
   stopped. `sample` of the live R process showed it still in `nlminb` / TMB
   ordinal AD evaluation, not teardown. A previously written CSV contained
   12 retained rows (5 truth-labelled silent degeneracies, 7 controls), but
   came from an interrupted earlier invocation and is not a valid end-to-end
   timing or campaign receipt.

## Do not infer

- Do not launch Totoro, set a campaign runtime, calibrate thresholds, or claim
  a detector from the retained partial CSV.
- Do not change `check_gllvmTMB()`, optimizer controls, `aghq_ridge`, or the
  ordinal likelihood.

## Next safest action

Obtain a new explicit decision on local timing: either run one known-positive
seed with a declared per-fit cap to establish a valid timing receipt, or move
the bounded timing smoke to Totoro. Only after a complete, non-empty receipt
may the pre-registered campaign estimate and separate Totoro approval be made.
