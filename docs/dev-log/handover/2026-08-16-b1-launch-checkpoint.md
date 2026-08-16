# B1 launch checkpoint — everything green except the submitter; ONE step remains

**Date:** 2026-08-16 05:20 MDT · **Lane:** Claude, `claude/mspl-b0-prereqs` (PR #981)
**State:** NOT LAUNCHED, deliberately. Deployment staged and verified; the launch
mechanics need one small piece that must be smoke-tested, not improvised at 5am.

## What is DONE and verified

| Item | Evidence |
|---|---|
| §8 ledger complete + corrected on main | `8d8e06ec` (DEV-1..10; DEV-6/7 wording fixed after re-review adjudication) |
| Harness fix commit | `a3b31e62` — both review blockers fixed (storage sidecars; bootstrap hoisted, budget restored to 17.52 M base) |
| Re-review verdict | **LAUNCH AFTER FIXES**: items 1 (ledger wording) **DONE**, 2 (Totoro timing) partially done, 3 (`--expect-full` + sidecar completeness) is a CONSOLIDATION-time flag, not launch-blocking |
| Totoro worst plain corner | B076 (cloglog 48×12): 237 s / 3 outers = **79 s/outer**, sidecars healthy (242 trace rows) |
| narval deployment | source `a3b31e62` unpacked at `/project/def-snakagaw/snakagaw/gllvmtmb-mspl-b1-a3b31e62/source`; setup job **1085370 RUNNING** (deps + `R CMD INSTALL` + a `max_widen_rounds` presence assertion → writes `setup-narval.receipt`) |

## The blocker found at the last step (why nothing launched)

`scontrol show config` on narval: **`MaxArraySize = 10000`**, and the association's
**`MaxSubmitJobs = 1000`**. The pre-registered shard size (`--outer-per-shard 3`, chosen so
every bootstrap-bearing shard carries exactly one in-subset outer) gives
`132 cells × 200 shards = 26,400 tasks` — **2.6× over the array limit and 26× over the
submit limit**. So B1 cannot go up as a single array.

**Recommended resolution (do NOT change the tested task map):** keep `--outer-per-shard 3`
and add an **offset** to the sbatch wrapper — `task_id = SLURM_ARRAY_TASK_ID +
${MSPL_B1_TASK_OFFSET:-0}` — then submit in chunks of ≤900 with a drain-and-resubmit loop
(27 chunks). The map stays bijective and its test stays valid; only the wrapper changes.
Alternatives considered and rejected: raising `--outer-per-shard` to fit 10,000 tasks makes
bootstrap-bearing shards exceed a 3 h wall (fix-9's own fallback ruled this out);
restructuring into a work-queue would invalidate the tested bijection.

## Next session — exact sequence

1. `cat /project/def-snakagaw/snakagaw/gllvmtmb-mspl-b1-a3b31e62/setup-narval.receipt`
   (job 1085370) — must read `status=ready`; the log must show `PREREQ-OK`.
2. Add the offset line to `inst/sim/b1-calibration/sbatch-b1.sh`; write
   `submit-b1-chunks.sh` (chunks of 900, poll `squeue`, resubmit while offset < 26,400).
   **Test the offset arithmetic against `--print-map` before any submission.**
3. **Smoke:** `sbatch --array=1-1` with offset 0 → verify one shard CSV + its two sidecars,
   non-empty, no NA, correct schema.
4. Release chunk 1; verify a handful of tasks with `seff`; then the loop.
5. Consolidate with `--expect-full --outer-per-shard 3` (re-review item 3) and verify
   sidecar coverage before trusting completeness.

## Open findings from tonight

- **[#1020](https://github.com/itchyshin/gllvmTMB/issues/1020)** — PRE-EXISTING package
  defect (reproduced on unmodified `main`): `estimator = "mspl"` aborts its penalty-off
  decomposition check at large `n_site` on cloglog. Driver is unit count, not data size
  (48×12 passes, 192×3 fails at identical `N_eff`). Affects 5 of 132 B1 cells, all
  hold-out; DEV-10 records that they launch anyway to measure the boundary and that their
  gate failures are attributed, not counted as calibration failures.
  A refuted hypothesis is recorded in the issue (the `p` clamp — min p was 3.4e-10, zero
  observations clamped) so it is not re-tested.
- **Timing still incomplete:** the worst *bootstrap-bearing* registered cell (H3 logit,
  `n_site = 192`) was still running at cutoff — `~/b1-timing-h3logit` + `~/h3logit.log` on
  Totoro. `--time=02:30:00` remains PROVISIONAL until that number lands. Read it before
  releasing chunk 1.
- **Totoro cleanup owed (D-142):** `~/gllvmtmb-b1-timing-a3b31e62`, `~/gllvmtmb-diag-main`,
  `~/gllvmtmb-diag-instrumented`, `~/b1-timing-out-a3b31e62`, `~/b1-timing-h3logit`,
  `~/*.R`, `~/*.rds`, `~/main-repro.log`, `~/h3logit.log`. Left in place ONLY because the
  H3 timing job is still using its clone; sweep them once that number is read.
- The B1-harness subagent hit an API session limit mid-diagnosis (resets 8pm MDT); the
  diagnosis was completed directly and is fully captured in #1020.

## Standing authorization (unchanged)

Shinichi, 2026-08-16: *"do as you recommend … my authorization for everything finishes"* —
covers the whole chain including the array release. **Not covered:** the MSPL-04 register
edit, which the protocol conditions on a hold-out PASS.
