# Recovery checkpoint — private LA-MSPL Wald/profile/bootstrap trio

## Repository state

- Worktree: `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`
- Branch: `codex/lane-b-mspl-interval-feasibility`
- HEAD: `5598f9e44d758f764a9239adb7e0066d5671538e`
- Status before this checkpoint: one intended historical-withdrawal banner
  added to the old jackknife checkpoint; no source change after HEAD.

## Landed work

- `8dcef28a` removed the active private jackknife implementation, tests, and
  runner route while retaining withdrawn historical records.
- `7bf697df` completed the private nuisance-reoptimised penalised profile map
  and the penalty-off likelihood-curvature diagnostic.
- `392ba7db`, `0608a1fb`, and `5598f9e4` added and hardened the fixed private
  unconditional parametric-bootstrap runner, including the requirement that
  every usable row confirm unconditional redraw.

## Evidence already run

- `Rscript --vanilla -e 'devtools::test(filter = "mspl", stop_on_failure = TRUE)'`
  passed 1,239 expectations with zero failures and warnings and one
  pre-existing skip in 142.7 seconds.
- The deterministic profile map has 36/36 matched centres and finite,
  converged, refined two-sided penalised-objective brackets.
- The paper-style Wald map has 7/12 positive-definite fit-level Hessians
  (21/36 target diagnostics) and 5/12 non-PD fit-level blockers (15/36
  targets). The penalty-off tape is evaluated only at the penalised MSPL
  estimate and is never optimised.
- Exact-source Rorqual setup job `19016944` passed at source SHA `5598f9e4`;
  all-12-case smoke job `19017079` passed with 12 fixture files and 36 finite,
  unconditional estimator-ID-1 target rows.

## Campaign state and next safe action

Fir and Rorqual project-library extraction hit file-count quota; the corrected
Rorqual route uses `$SLURM_TMPDIR`. Nibi's existing ControlMaster stopped
returning remote commands. Narval job `911531` rejected the Fir-built
dependency library with an illegal CPU instruction before any refit. Rorqual
therefore owns all 12 unchanged manifest cases; case IDs and seeds did not
change.

Array `19017182` failed ten tasks before any fit because the Bash `read`
process substitution lacked a trailing newline; no shard file was written and
the remainder was cancelled. Diagnostic task `19017433_1` proved that exact
cause. The repaired mapping prints a newline and passed a local Bash check.
Exact array `19017652` is queued with the same 120 shard keys and no replacement
draws. Next: wait for it, require exactly 120 atomic CSV files and 36,000 target
rows, retrieve outside the repository, run the exact summariser, then complete
the method map, Arc Card actuals, check log, and after-task report. Do not make
a calibrated-SE, confidence-interval, or coverage claim.
