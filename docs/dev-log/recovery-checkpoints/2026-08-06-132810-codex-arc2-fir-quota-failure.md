# Arc 2 Fir project-file-quota failure checkpoint

## Repository state

- Worktree: `/private/tmp/gllvmtmb-va-gh-all-families`
- Branch: `codex/va-gh-all-families`
- HEAD before this checkpoint: `66a6e2e397a591438f689d15743db4614b46a049`
- `git status --short --branch`: clean before this checkpoint.

## Frozen campaign state

At `2026-08-06T19:28:10Z`, Fir retained exactly 10,549 immutable
`COMPLETE.dcf` bundles. Slurm accounting for jobs `53407355` through
`53407390` reported:

- 10,549 `COMPLETED|0:0` array tasks;
- 284 `FAILED|1:0` array tasks;
- 378 `FAILED|0:53` array tasks;
- 662 failed tasks in total;
- all 36 array jobs pending and no array task running.

No job was cancelled or resubmitted. The 36,000-row plan, thresholds, bundles,
and public fences were not changed.

## Cause and retained evidence

`diskusage_report` reported `/project (project def-snakagaw)` at
`498K / 500K` files while using only `195 GiB / 954 GiB` space. This is a
file-count quota failure, not a storage-byte limit and not a statistical
verdict.

Representative retained error logs:

- `/project/def-snakagaw/snakagaw/gllvm_work/va-gh-h7-drac-campaign-e46d7977/logs/va-gh-h7-b1-53407355-456.err`
- `/project/def-snakagaw/snakagaw/gllvm_work/va-gh-h7-drac-campaign-e46d7977/logs/va-gh-h7-b14-53407368-251.err`

Both say `Disk quota exceeded` while creating an immutable bundle staging
directory and then fail to write `result.csv`. Representative task
`53407355_456` ran for seven seconds on `fc30558` and exited `1:0`;
`53407368_251` ran for 97 seconds on `fc30555` and exited `1:0`. Later
`0:53` tasks often have no log because the quota also prevented Slurm from
creating the output/error file; for example `53407355_468` and
`53407368_260` ran for three seconds and have no retained log file.

The exact compact failure manifest at the checkpoint is below. Each row is
`job_id|exit_code|array_task_range`; separate rows preserve non-contiguous
indices.

```text
53407355|0:53|468-482
53407355|1:0|456-467
53407356|0:53|468-482
53407356|1:0|456-467
53407357|0:53|448-461
53407357|1:0|436-447
53407358|0:53|447-460
53407358|1:0|435-446
53407359|0:53|379-390
53407359|1:0|366-378
53407360|0:53|378-390
53407360|1:0|366-377
53407361|0:53|427-441
53407361|1:0|415-426
53407362|0:53|436
53407362|0:53|438-449
53407362|1:0|424-435
53407362|1:0|437
53407363|0:53|436-449
53407363|1:0|424-435
53407364|0:53|444
53407364|0:53|446-457
53407364|1:0|432-443
53407364|1:0|445
53407365|0:53|447-461
53407365|1:0|435-446
53407366|0:53|443-457
53407366|1:0|431-442
53407367|0:53|271-285
53407367|1:0|259-270
53407368|0:53|260-266
53407368|1:0|251
53407368|1:0|253-259
53407369|0:53|399-413
53407369|1:0|390-398
53407370|0:53|369-383
53407370|1:0|360-368
53407371|0:53|305-319
53407371|1:0|295-304
53407372|0:53|289-302
53407372|1:0|280-288
53407373|0:53|186-200
53407373|1:0|175
53407373|1:0|179-185
53407374|0:53|182-196
53407374|1:0|171
53407374|1:0|175
53407374|1:0|177-181
53407375|0:53|269-280
53407375|1:0|260-268
53407376|0:53|234-239
53407376|1:0|226-233
53407377|0:53|233-238
53407377|1:0|230-232
53407378|0:53|227-232
53407378|1:0|224-226
53407379|0:53|232-237
53407379|1:0|229-231
53407380|0:53|231-236
53407380|1:0|228-230
53407381|0:53|227-232
53407381|1:0|224-226
53407382|0:53|223-228
53407382|1:0|220-222
53407383|0:53|138-141
53407383|1:0|127
53407383|1:0|131
53407383|1:0|135-137
53407384|0:53|135-140
53407384|1:0|123
53407384|1:0|127
53407384|1:0|131-134
53407385|0:53|193-197
53407385|1:0|187
53407385|1:0|190-192
53407386|0:53|190-195
53407386|1:0|187-189
53407387|0:53|214-219
53407387|1:0|211-213
53407388|0:53|212-217
53407388|1:0|209-211
53407389|0:53|213-218
53407389|1:0|210-212
53407390|0:53|214-219
53407390|1:0|211-213
```

## Commands already run

- Ownership guard from the VA worktree — PASS.
- `find .../results/replicates -name COMPLETE.dcf` — 10,549.
- `squeue`/`sacct` over jobs `53407355-53407390` — failure counts and exact
  task manifest above.
- `diskusage_report` — `/project` file quota `498K / 500K`.
- Representative `sacct` and retained-log reads — cause confirmed as project
  file-count quota exhaustion.

## Next safest action

The active parent must resolve the shared `/project` file-count quota outside
the frozen campaign, preferably by a quota increase or by removing/moving
unrelated, independently verified project files. Do not delete or rewrite this
campaign's immutable bundles. After capacity is restored, derive the missing
plan rows from the immutable denominator and obtain explicit authority before
any resubmission or continuation action. The heartbeat itself must not cancel,
resubmit, alter the plan, or reinterpret these infrastructure failures as model
verdicts.

## Blocking question

Which project files outside this campaign may be safely moved or removed, or
can the `/project` file quota be increased? The monitor has no authority to
choose that scope.
