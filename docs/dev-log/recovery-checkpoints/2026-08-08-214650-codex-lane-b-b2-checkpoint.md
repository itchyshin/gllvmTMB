# Lane B B2 recovery checkpoint — 2026-08-08 21:46 MDT

## Branch and worktree

- Worktree: `/private/tmp/gllvmtmb-lane-b-mspl`
- Branch: `codex/lane-b-mspl-20260808`
- Base: `origin/main` at `7af5cf00`; branch was 0 ahead / 0 behind before edits.
- `git diff --check`: PASS after the exact-B0 adjudicator and targeted-quasi
  supplement changes.
- The main checkout remains untouched. The tree contains the intended B0/B1/B2
  implementation, tests, docs, and untracked new Lane B files; do not use
  `git add -A`.

## Completed since the previous checkpoint

- Added strict post-launch adjudication in
  `inst/sim/lane-b/lane-b-b2-adjudication.R` and
  `4_adjudicate_lane_b_b2.R`.
- Promotion is keyed by exact realized B0 stratum. Usability differences retain
  every paired attempt; beta/covariance RMSE and log-loss comparisons retain
  only replicate IDs usable in both arms.
- The immutable Totoro fit library lacked `detectseparation`; its B0 hash is
  ignored. A separate exact-B0 v3 supplement completed all 2,880 shards and all
  72,000 unique ordinary datasets.
- Exact ordinary B0 counts: 39,493 overlap, 11,173 complete, 21,329 constant,
  and five quasi-complete. No dataset was `NOT_CHECKED` in v3.
- The five quasi-complete realizations are insufficient for the frozen Wilson
  gate. Added an ADEMP/symbolically aligned conditional supplement with 12 cells
  (three links by q=1:2 by loading RMS 0.5/1.5), 500 replicates per cell, 6,000
  datasets, and 24,000 primary fits. Trait 1 is exactly quasi-complete under a
  full-rank four-column fixed design; recovery claims for its forced coefficient
  are forbidden.
- Local generator tests prove `QUASI_COMPLETE` for all six link-by-rank families.
  A live logit/q=1 fit smoke returned a usable MSPL point.
- The supplement was not launched on Totoro after discovering a separate 96-core
  gllvmTMB campaign alongside Lane B's 120 cores. A single Totoro pilot left one
  stale lock and no result; do not count it as evidence.
- Fir dependency chain submitted through the live ControlMaster socket:
  setup `53826709`; 600-task array `53826711` throttled to 30 one-thread workers;
  aggregation `53826714`. The array depends on successful setup and aggregation
  depends on every array task.

## Compute state

- Main Totoro root:
  `/home/snakagaw/gllvmtmb_lane_b_b2_20260808_v1`
- Last main snapshot: 437 / 8,472 complete shards, zero failed, 120 running.
- Exact B0 v3 root: main root subdirectory `b0-exact-v3`; 2,880 / 2,880.
- Fir source: `/scratch/snakagaw/lane_b_quasi_20260808/source/gllvmTMB`
- Fir results: `/scratch/snakagaw/lane_b_quasi_20260808/results`
- Fir R library: `/home/snakagaw/R/lane_b_4.5`
- Fir setup was pending for priority at this checkpoint. Query all three jobs with
  `squeue -j 53826709,53826711,53826714` through the existing Fir socket.

## Commands already green

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-mspl-simulation-contract.R", reporter="summary")'`
- parse checks for adjudication and quasi runner files
- `bash -n` for the Totoro quasi launcher
- local quasi CLI `prepare`: 12 cells, 6,000 datasets, 24,000 primary fits,
  600 shards
- `git diff --check`

## Still required

1. Monitor Fir setup; if it fails, inspect the setup log and repair in a new
   source/version without altering the submitted frozen source silently.
2. Monitor the immutable Totoro campaign without restarting it.
3. When both campaigns finish, run immutable aggregation, then strict
   `4_adjudicate_lane_b_b2.R`; preserve the original summary and hashes.
4. Reconcile exact promoted cells into the validation register, NEWS, article,
   after-task report, and pkgdown wording.
5. Run focused tests, full package test/check, pkgdown build, and 3-OS CI.
6. Run final Gauss/Noether/Fisher/Rose/Shannon gates, then scoped commit/push/PR
   handoff.

## Next safest action

Wait for Fir setup job `53826709` and inspect its log. Do not add Totoro workers
while the separate 96-core campaign is active. Continue local documentation and
test reconciliation that does not depend on B2 outcomes.
